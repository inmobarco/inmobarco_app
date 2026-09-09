import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/global_data_service.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/api_service.dart';
import '../../data/services/sync_service.dart';
import '../providers/property_provider.dart';
import '../widgets/cache_info_dialog.dart';
import 'permissions_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _MasterDataTile(),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.storage),
              title: const Text('Información del Caché'),
              subtitle: const Text('Ver y limpiar datos en caché'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                final provider = context.read<PropertyProvider>();
                final syncService = context.read<SyncService>();
                showCacheInfoDialog(context, provider, syncService: syncService);
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.security),
              title: const Text('Permisos de la App'),
              subtitle: const Text('Ver y gestionar permisos'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PermissionsScreen()),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Versión de la App'),
              subtitle: Text('v${AppConstants.appVersion}'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fuerza la descarga de ciudades, barrios, características y residenciales,
/// ignorando sus TTL.
///
/// Los residenciales ya se refrescan solos (TTL de 10 min, y pull-to-refresh
/// en su pantalla); esto existe sobre todo para ciudades y barrios, que tienen
/// un TTL de 24 h y ninguna otra forma de forzarse.
class _MasterDataTile extends StatefulWidget {
  const _MasterDataTile();

  @override
  State<_MasterDataTile> createState() => _MasterDataTileState();
}

class _MasterDataTileState extends State<_MasterDataTile> {
  bool _refreshing = false;

  String _summary(GlobalDataService data) =>
      '${data.cities.length} ciudades · ${data.zones.length} barrios · '
      '${data.features.length} características · '
      '${data.residentialComplexes.length} residenciales';

  Future<void> _refresh() async {
    final globalData = context.read<GlobalDataService>();
    final messenger = ScaffoldMessenger.of(context);
    final hasSession = await ApiService.hasSession();

    if (!mounted) return;
    setState(() => _refreshing = true);
    await globalData.refresh();
    if (!mounted) return;
    setState(() => _refreshing = false);

    messenger.showSnackBar(
      SnackBar(
        content: Text(hasSession
            ? 'Datos actualizados: ${_summary(globalData)}'
            : 'Inicie sesión para actualizar ciudades y residenciales. '
                'Datos actuales: ${_summary(globalData)}'),
        backgroundColor: hasSession ? AppColors.success : AppColors.warning,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final globalData = context.watch<GlobalDataService>();

    return Card(
      child: ListTile(
        leading: const Icon(Icons.cloud_sync),
        title: const Text('Actualizar datos maestros'),
        subtitle: Text(_refreshing ? 'Actualizando…' : _summary(globalData)),
        trailing: _refreshing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.refresh),
        onTap: _refreshing ? null : _refresh,
      ),
    );
  }
}
