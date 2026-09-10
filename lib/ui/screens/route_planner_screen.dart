import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../data/services/api_service.dart';
import '../../data/services/cache_service.dart';
import '../../domain/models/advisor_route.dart';

/// Rutero del asesor: vista de **solo lectura** de `GET /scheduling/routes`.
///
/// Las rutas las arma el staff en su propio panel; aquí no se crean, editan ni
/// eliminan. El asesor solo consulta a dónde le toca prospectar.
///
/// Se pide la semana completa en una sola llamada y se filtra por día en local:
/// el rutero se consulta en calle, donde la cobertura falla, así que cachearlo
/// entero vale más que ahorrar bytes por día. El botón de refrescar es lo que
/// trae los cambios del staff.
class RoutePlannerScreen extends StatefulWidget {
  const RoutePlannerScreen({super.key});

  @override
  State<RoutePlannerScreen> createState() => _RoutePlannerScreenState();
}

class _RoutePlannerScreenState extends State<RoutePlannerScreen> {
  /// Lunes a sábado (ISODOW 1-6). El domingo no hay prospección: el backend
  /// rechaza `day_of_week=7` y devuelve lista vacía para `today=true`.
  static const _weekDayLabels = <int, String>{
    1: 'Lun',
    2: 'Mar',
    3: 'Mié',
    4: 'Jue',
    5: 'Vie',
    6: 'Sáb',
  };

  static const _weekDayNames = <int, String>{
    1: 'lunes',
    2: 'martes',
    3: 'miércoles',
    4: 'jueves',
    5: 'viernes',
    6: 'sábado',
  };

  /// ISODOW de hoy (1 = lunes … 7 = domingo). `DateTime.weekday` ya usa esa
  /// numeración, así que coincide con el `EXTRACT(ISODOW …)` del backend.
  final int _todayDow = DateTime.now().weekday;

  late int _selectedDow;

  List<AdvisorRouteDay> _days = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // En domingo no hay ruta de hoy: se abre en lunes para que la pantalla
    // muestre algo útil, con el aviso correspondiente.
    _selectedDow = _todayDow == DateTime.sunday ? DateTime.monday : _todayDow;
    _load();
  }

  /// Pinta primero lo cacheado y luego va a la red.
  ///
  /// Con [force] (botón de refrescar y pull-to-refresh) se salta el caché.
  Future<void> _load({bool force = false}) async {
    final cacheService = context.read<CacheService>();

    if (!force) {
      final cached = await cacheService.loadAdvisorRoutes();
      if (cached != null && mounted) {
        setState(() {
          _days = AdvisorRouteDay.listFromJson(cached.data);
          _loading = false;
        });
        // Caché vigente: no se vuelve a la red hasta que el asesor refresque.
        if (!cached.isStale) return;
      }
    }

    if (mounted) setState(() => _loading = _days.isEmpty);

    try {
      final fresh = await ApiService.getAdvisorRoutes();
      await cacheService.saveAdvisorRoutes(fresh);
      if (!mounted) return;
      setState(() {
        _days = AdvisorRouteDay.listFromJson(fresh);
        _error = null;
        _loading = false;
      });
    } catch (e) {
      debugPrint('⚠️ Error cargando el rutero: $e');
      if (!mounted) return;
      // Nunca se descarta lo cacheado: sin red es lo único que el asesor tiene.
      setState(() {
        _error = _errorMessage(e);
        _loading = false;
      });
    }
  }

  String _errorMessage(Object e) {
    if (e is DioException && e.response?.statusCode == 401) {
      return 'Tu sesión expiró. Vuelve a iniciar sesión.';
    }
    return 'No se pudo cargar el rutero. Revisa tu conexión.';
  }

  /// Rutas del día seleccionado. El backend omite los días sin rutas, así que
  /// no encontrarlo es lo normal, no un error.
  List<AdvisorRoute> get _routesForSelectedDay {
    for (final day in _days) {
      if (day.dayOfWeek == _selectedDow) return day.routes;
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rutero'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar rutas',
            onPressed: _loading ? null : () => _load(force: true),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildDaySelector(),
          const Divider(height: 1),
          if (_error != null) _buildErrorBanner(),
          if (_todayDow == DateTime.sunday) _buildSundayBanner(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildDaySelector() {
    return SizedBox(
      height: 62,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        children: _weekDayLabels.entries.map((entry) {
          final dow = entry.key;
          final selected = dow == _selectedDow;
          final isToday = dow == _todayDow;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(isToday ? 'Hoy · ${entry.value}' : entry.value),
              selected: selected,
              selectedColor: AppColors.primaryColor,
              labelStyle: TextStyle(
                color: selected ? AppColors.pureWhite : AppColors.textColor,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
              ),
              onSelected: (_) => setState(() => _selectedDow = dow),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildErrorBanner() {
    final hasFallback = _days.isNotEmpty;
    return Container(
      width: double.infinity,
      color: AppColors.error.withValues(alpha: 0.1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, size: 18, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hasFallback
                  ? '$_error Mostrando la última versión guardada.'
                  : _error!,
              style: const TextStyle(fontSize: 12, color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSundayBanner() {
    return Container(
      width: double.infinity,
      color: AppColors.info.withValues(alpha: 0.1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: const Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: AppColors.info),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Hoy es domingo: no hay prospección programada.',
              style: TextStyle(fontSize: 12, color: AppColors.info),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _days.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final routes = _routesForSelectedDay;

    return RefreshIndicator(
      onRefresh: () => _load(force: true),
      child: routes.isEmpty
          ? ListView(
              children: [
                const SizedBox(height: 120),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'No tienes rutas asignadas para el '
                      '${_weekDayNames[_selectedDow]}.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textColor2),
                    ),
                  ),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: routes.length,
              itemBuilder: (context, index) => _buildRouteCard(routes[index]),
            ),
    );
  }

  Widget _buildRouteCard(AdvisorRoute route) {
    final count = route.complexes.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Card(
        margin: EdgeInsets.zero,
        color: AppColors.backgroundLevel1,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.route,
                          size: 20, color: AppColors.primaryColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          route.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textColor,
                          ),
                        ),
                      ),
                      Text(
                        '$count ${count == 1 ? 'conjunto' : 'conjuntos'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textColor2,
                        ),
                      ),
                    ],
                  ),
                  if (route.notes != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      route.notes!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textColor2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            ...route.complexes.asMap().entries.map(
                  (e) => _buildComplexTile(e.value, e.key + 1),
                ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  /// [fallbackOrder] es la posición en la lista: `visit_order` es opcional en
  /// el backend (`NULLS LAST`), pero el orden de llegada sí es el correcto.
  Widget _buildComplexTile(RouteComplex complex, int fallbackOrder) {
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 14,
        backgroundColor: AppColors.primaryColor.withValues(alpha: 0.12),
        child: Text(
          '${complex.visitOrder ?? fallbackOrder}',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryColor,
          ),
        ),
      ),
      title: Text(
        complex.name,
        style: const TextStyle(fontSize: 14, color: AppColors.textColor),
      ),
      subtitle: complex.address == null
          ? null
          : Text(
              complex.address!,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textColor2,
              ),
            ),
    );
  }
}
