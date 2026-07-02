import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
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
