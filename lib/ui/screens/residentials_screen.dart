import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/global_data_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/services/api_service.dart';
import 'add_residential_screen.dart';

class ResidentialsScreen extends StatefulWidget {
  const ResidentialsScreen({super.key});

  @override
  State<ResidentialsScreen> createState() => _ResidentialsScreenState();
}

class _ResidentialsScreenState extends State<ResidentialsScreen> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    final globalData = context.read<GlobalDataService>();
    setState(() => _refreshing = true);
    // Solo residenciales y sus zonas: no hace falta traer ciudades y
    // características para actualizar esta lista.
    await globalData.reloadResidentials();
    if (mounted) setState(() => _refreshing = false);
  }

  Future<void> _createNew() async {
    final created = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const AddResidentialScreen()),
    );
    if (created != null && mounted) {
      setState(() {}); // los datos ya los recargó la screen
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Residencial creado'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    // Trae residenciales si el caché ya pasó su TTL de 10 min.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GlobalDataService>().refreshStale();
    });
  }

  @override
  Widget build(BuildContext context) {
    // watch, no read: un refresco en background debe repintar la lista.
    final globalData = context.watch<GlobalDataService>();
    // ponytail: filter active only if the field exists; endpoint may already return active
    final complexes = globalData.residentialComplexes
        .where((c) => c['active'] != false)
        .toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'add_residential_fab',
        backgroundColor: AppColors.primaryColor,
        onPressed: _createNew,
        tooltip: 'Nuevo residencial',
        child: const Icon(Icons.add, color: AppColors.pureWhite),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: (_refreshing && complexes.isEmpty)
            ? const Center(child: CircularProgressIndicator())
            : complexes.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      Center(
                        child: Text(
                          'No hay residenciales',
                          style: TextStyle(color: AppColors.textColor2),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    itemCount: complexes.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final c = complexes[index];
                      return _buildTile(globalData, c);
                    },
                  ),
      ),
    );
  }

  Widget _buildTile(GlobalDataService globalData, Map<String, dynamic> c) {
    final address = c['address']?.toString() ?? '';
    final cityName = lookupNameById(globalData.cities, c['id_city']?.toString());
    final zoneName = lookupNameById(globalData.zones, c['id_zone']?.toString());
    final stratum = c['stratum']?.toString();

    final meta = [
      if (cityName != null) cityName,
      if (zoneName != null) zoneName,
      if (stratum != null && stratum.isNotEmpty) 'Estrato $stratum',
    ].join(' · ');

    return ListTile(
      isThreeLine: address.isNotEmpty && meta.isNotEmpty,
      leading: const Icon(Icons.apartment, color: AppColors.primaryColor),
      title: Text(c['name']?.toString() ?? ''),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (address.isNotEmpty) Text(address),
          if (meta.isNotEmpty)
            Text(meta, style: const TextStyle(color: AppColors.textColor2)),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.info_outline, color: AppColors.textColor2),
        tooltip: 'Ver información',
        onPressed: () => _showDetails(globalData, c),
      ),
    );
  }

  void _showDetails(GlobalDataService globalData, Map<String, dynamic> c) {
    String value(dynamic v) {
      final s = v?.toString().trim() ?? '';
      return s.isEmpty ? '—' : s;
    }

    final lat = c['latitude'];
    final lng = c['longitude'];
    final location =
        (lat == null || lng == null) ? '—' : '$lat, $lng';

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.backgroundLevel1,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value(c['name']),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _detailRow(Icons.location_on, 'Dirección', value(c['address'])),
                      _detailRow(Icons.location_city, 'Ciudad',
                          value(lookupNameById(globalData.cities, c['id_city']?.toString()))),
                      _detailRow(Icons.map, 'Barrio',
                          value(lookupNameById(globalData.zones, c['id_zone']?.toString()))),
                      _detailRow(Icons.layers, 'Estrato', value(c['stratum'])),
                      _detailRow(Icons.phone, 'Tel. admin', value(c['admin_phone'])),
                      _detailRow(Icons.email, 'Email admin', value(c['admin_email'])),
                      _detailRow(Icons.meeting_room, 'Portería', value(c['front_desk_phone'])),
                      _detailRow(Icons.my_location, 'Ubicación', location),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _editComplex(c),
                              icon: const Icon(Icons.edit),
                              label: const Text('Editar'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextButton.icon(
                              onPressed: () => _confirmDelete(c),
                              icon: const Icon(Icons.delete, color: AppColors.error),
                              label: const Text('Eliminar',
                                  style: TextStyle(color: AppColors.error)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editComplex(Map<String, dynamic> c) async {
    Navigator.pop(context); // cierra el bottom sheet
    final updated = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => AddResidentialScreen(complex: c)),
    );
    if (updated != null && mounted) {
      setState(() {}); // los datos ya los recargó la screen
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Residencial actualizado'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar residencial'),
        content: Text(
            '¿Eliminar "${c['name'] ?? ''}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final globalData = context.read<GlobalDataService>();
    Navigator.pop(context); // cierra el sheet
    try {
      await ApiService.deleteResidentialComplex(c['id'] as int);
      await globalData.reloadResidentials();
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Residencial eliminado'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error eliminando residencial: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo eliminar. Intente de nuevo.')),
        );
      }
    }
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textColor2),
          const SizedBox(width: 12),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textColor2, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppColors.textColor, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
