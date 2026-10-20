import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../data/services/api_service.dart';
import '../../domain/models/maintenance_request.dart';
import '../providers/auth_provider.dart';
import '../widgets/maintenance_badges.dart';
import 'maintenance_request_detail_screen.dart';

enum _Assignment { all, mine, unassigned }

/// Solicitudes de mantenimiento: vista de **solo lectura** para admin y
/// manager. Por ahora no se cambia estado, prioridad ni responsable.
///
/// Solo se muestran las asignadas al usuario o sin responsable. La API no deja
/// combinar `assigned_user_id` con `unassigned`, así que se hacen dos llamadas
/// y se mezclan. Siempre en línea: el detalle trae datos personales del
/// reportante y no conviene dejarlos en el dispositivo.
///
/// Estado, prioridad, asignación y búsqueda se filtran en local sobre lo ya
/// descargado; solo "Mostrar cerradas" vuelve a la red.
class MaintenanceRequestsScreen extends StatefulWidget {
  const MaintenanceRequestsScreen({super.key});

  @override
  State<MaintenanceRequestsScreen> createState() =>
      _MaintenanceRequestsScreenState();
}

class _MaintenanceRequestsScreenState extends State<MaintenanceRequestsScreen> {
  static const _pageLimit = 500;

  final _searchController = TextEditingController();

  List<MaintenanceRequest> _requests = [];
  bool _loading = true;
  String? _error;

  /// Alguna de las dos consultas llegó al límite: puede haber más antiguas.
  bool _truncated = false;

  bool _showClosed = false;
  _Assignment _assignment = _Assignment.all;
  final Set<String> _statusFilter = {};
  final Set<String> _priorityFilter = {};
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final statuses = [
      ...MaintenanceStatus.active,
      if (_showClosed) MaintenanceStatus.cerrada,
    ];
    final userId = context.read<AuthProvider>().user?.id;

    try {
      final results = await Future.wait([
        ApiService.getMaintenanceRequests(
          statuses: statuses,
          unassigned: true,
          limit: _pageLimit,
        ),
        // Sin id (sesión guardada antes de que el login lo trajera) solo se
        // pueden pedir las libres; el aviso pide volver a iniciar sesión.
        if (userId != null)
          ApiService.getMaintenanceRequests(
            statuses: statuses,
            assignedUserId: userId,
            limit: _pageLimit,
          ),
      ]);

      final byId = <int, MaintenanceRequest>{};
      for (final page in results) {
        for (final request in MaintenanceRequest.listFromJson(page)) {
          byId[request.id] = request;
        }
      }
      final merged = byId.values.toList()
        ..sort(
          (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
            a.createdAt ?? DateTime(0),
          ),
        );

      if (!mounted) return;
      setState(() {
        _requests = merged;
        _truncated = results.any((page) => page.length >= _pageLimit);
        _loading = false;
      });
    } catch (e) {
      debugPrint('⚠️ Error cargando mantenimientos: $e');
      if (!mounted) return;
      setState(() {
        _error = _errorMessage(e);
        _loading = false;
      });
    }
  }

  String _errorMessage(Object e) {
    if (e is DioException) {
      switch (e.response?.statusCode) {
        case 401:
          return 'Tu sesión expiró. Vuelve a iniciar sesión.';
        case 403:
          return 'Tu usuario no tiene acceso a los mantenimientos.';
      }
    }
    return 'No se pudieron cargar las solicitudes. Revisa tu conexión.';
  }

  List<MaintenanceRequest> _filtered(int? userId) {
    return _requests.where((r) {
      if (_assignment == _Assignment.mine &&
          (userId == null || r.assignedUserId != userId)) {
        return false;
      }
      if (_assignment == _Assignment.unassigned && !r.isUnassigned) {
        return false;
      }
      if (_statusFilter.isNotEmpty && !_statusFilter.contains(r.status)) {
        return false;
      }
      if (_priorityFilter.isNotEmpty && !_priorityFilter.contains(r.priority)) {
        return false;
      }
      return r.matchesQuery(_query);
    }).toList();
  }

  int get _activeFilterCount =>
      _statusFilter.length + _priorityFilter.length + (_showClosed ? 1 : 0);

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null || !user.isManagerOrAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mantenimientos')),
        body: const Center(
          child: Text(
            'Esta sección es solo para administradores y managers.',
            style: TextStyle(color: AppColors.textColor2),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mantenimientos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilterRow(),
          const Divider(height: 1),
          if (user.id == null) _buildMissingIdBanner(),
          if (_error != null) _buildErrorBanner(),
          Expanded(child: _buildBody(user.id)),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Radicado, nombre, dirección, municipio o contrato',
          hintStyle: const TextStyle(fontSize: 13),
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: 'Limpiar',
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                ),
          isDense: true,
          filled: true,
          fillColor: AppColors.backgroundLevel1,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.borderLight),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.borderLight),
          ),
        ),
        onChanged: (value) => setState(() => _query = value),
      ),
    );
  }

  Widget _buildFilterRow() {
    const labels = {
      _Assignment.all: 'Todas',
      _Assignment.mine: 'Asignadas a mí',
      _Assignment.unassigned: 'Sin responsable',
    };
    final filterCount = _activeFilterCount;

    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ActionChip(
              avatar: Icon(
                Icons.tune,
                size: 18,
                color: filterCount > 0
                    ? AppColors.pureWhite
                    : AppColors.primaryColor,
              ),
              label: Text(
                filterCount > 0 ? 'Filtros ($filterCount)' : 'Filtros',
              ),
              labelStyle: TextStyle(
                color: filterCount > 0
                    ? AppColors.pureWhite
                    : AppColors.textColor,
              ),
              backgroundColor: filterCount > 0 ? AppColors.primaryColor : null,
              onPressed: _openFilterSheet,
            ),
          ),
          ...labels.entries.map((entry) {
            final selected = entry.key == _assignment;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(entry.value),
                selected: selected,
                selectedColor: AppColors.primaryColor,
                labelStyle: TextStyle(
                  color: selected ? AppColors.pureWhite : AppColors.textColor,
                ),
                showCheckmark: false,
                onSelected: (_) => setState(() => _assignment = entry.key),
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _openFilterSheet() async {
    final previousShowClosed = _showClosed;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          void update(VoidCallback change) {
            setSheetState(change);
            setState(() {});
          }

          final statusOptions = [
            ...MaintenanceStatus.active,
            if (_showClosed) MaintenanceStatus.cerrada,
          ];

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Filtros',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _activeFilterCount == 0
                            ? null
                            : () => update(() {
                                _statusFilter.clear();
                                _priorityFilter.clear();
                                _showClosed = false;
                              }),
                        child: const Text('Limpiar'),
                      ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Mostrar cerradas'),
                    subtitle: const Text(
                      'Las canceladas no se muestran',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: _showClosed,
                    onChanged: (value) => update(() {
                      _showClosed = value;
                      if (!value) {
                        _statusFilter.remove(MaintenanceStatus.cerrada);
                      }
                    }),
                  ),
                  const SizedBox(height: 8),
                  _sheetSectionTitle('Prioridad'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: MaintenancePriority.all
                        .map(
                          (p) => FilterChip(
                            label: Text(MaintenancePriority.label(p)),
                            selected: _priorityFilter.contains(p),
                            onSelected: (on) => update(
                              () => on
                                  ? _priorityFilter.add(p)
                                  : _priorityFilter.remove(p),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  _sheetSectionTitle('Estado'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: statusOptions
                        .map(
                          (s) => FilterChip(
                            label: Text(MaintenanceStatus.label(s)),
                            selected: _statusFilter.contains(s),
                            onSelected: (on) => update(
                              () => on
                                  ? _statusFilter.add(s)
                                  : _statusFilter.remove(s),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    // Las cerradas no vienen en la consulta por defecto: hay que pedirlas.
    if (mounted && _showClosed != previousShowClosed) _load();
  }

  Widget _sheetSectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textColor2,
      ),
    ),
  );

  Widget _buildMissingIdBanner() => _banner(
    icon: Icons.info_outline,
    color: AppColors.info,
    text:
        'Solo se muestran las solicitudes sin responsable. Cierra sesión '
        'y vuelve a entrar para ver también las asignadas a ti.',
  );

  Widget _buildErrorBanner() => _banner(
    icon: Icons.cloud_off,
    color: AppColors.error,
    text: _requests.isEmpty ? _error! : '$_error Mostrando la última consulta.',
  );

  Widget _banner({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      color: color.withValues(alpha: 0.1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 12, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(int? userId) {
    if (_loading && _requests.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final items = _filtered(userId);

    return RefreshIndicator(
      onRefresh: _load,
      child: items.isEmpty
          ? ListView(
              children: [
                const SizedBox(height: 120),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _requests.isEmpty
                          ? (_error == null
                                ? 'No hay solicitudes de mantenimiento.'
                                : '')
                          : 'Ninguna solicitud coincide con los filtros.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textColor2),
                    ),
                  ),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: items.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) return _buildCountLine(items.length);
                return _buildRequestCard(items[index - 1]);
              },
            ),
    );
  }

  Widget _buildCountLine(int count) {
    final text =
        '$count ${count == 1 ? 'solicitud' : 'solicitudes'}'
        '${_truncated ? ' · se muestran las $_pageLimit más recientes' : ''}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, color: AppColors.textColor2),
      ),
    );
  }

  Widget _buildRequestCard(MaintenanceRequest request) {
    final location = [
      if (request.fullAddress.isNotEmpty) request.fullAddress,
      ?request.city,
    ].join(' · ');

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
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MaintenanceRequestDetailScreen(summary: request),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        request.ticket,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textColor,
                        ),
                      ),
                    ),
                    MaintenanceBadge.priority(request.priority),
                    const SizedBox(width: 6),
                    MaintenanceBadge.status(request.status),
                  ],
                ),
                if (request.categoryText.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    request.categoryText,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryColor,
                    ),
                  ),
                ],
                if (request.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    request.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textColor,
                    ),
                  ),
                ],
                if (location.isNotEmpty)
                  _iconLine(Icons.place_outlined, location),
                if (request.reporterName != null)
                  _iconLine(Icons.person_outline, request.reporterName!),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (request.isHappeningNow)
                      const MaintenanceBadge(
                        label: 'Ocurriendo ahora',
                        color: AppColors.error,
                        icon: Icons.warning_amber,
                      ),
                    if (request.needsReview)
                      const MaintenanceBadge(
                        label: 'Requiere revisión',
                        color: AppColors.warning,
                        icon: Icons.flag_outlined,
                      ),
                    MaintenanceBadge(
                      label: request.assignedUserName ?? 'Sin responsable',
                      color: request.isUnassigned
                          ? AppColors.warning
                          : AppColors.textColor2,
                      icon: Icons.engineering_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      formatMaintenanceDate(request.createdAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textColor2,
                      ),
                    ),
                    const Spacer(),
                    if (request.attachmentCount > 0) ...[
                      const Icon(
                        Icons.attach_file,
                        size: 14,
                        color: AppColors.textColor2,
                      ),
                      Text(
                        '${request.attachmentCount}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textColor2,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconLine(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppColors.textColor2),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: AppColors.textColor2),
            ),
          ),
        ],
      ),
    );
  }
}
