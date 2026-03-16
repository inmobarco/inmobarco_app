import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/sync_service.dart';
import '../providers/property_provider.dart';

/// Muestra el dialog de información de caché y almacenamiento.
///
/// Requiere un [PropertyProvider] para obtener info de caché y storage.
Future<void> showCacheInfoDialog(
  BuildContext context,
  PropertyProvider provider, {
  required SyncService syncService,
}) async {
  final cacheInfo = await provider.getCacheInfo();
  final storageInfo = await provider.getTotalStorageInfo();
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString('appointments_pending_sync');
  final List<dynamic> queue =
      (raw != null && raw.isNotEmpty) ? json.decode(raw) : [];

  if (!context.mounted) return;

  final files = storageInfo['files'] as Map<String, int>;

  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Información del Caché'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Sección: Tamaño total del almacenamiento ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.backgroundLevel2,
                borderRadius: AppTheme.buttonBorderRadius,
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.storage,
                          color: AppColors.primaryColor, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Almacenamiento Total',
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryColor,
                                ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    storageInfo['totalFormatted'] as String,
                    style:
                        Theme.of(context).textTheme.headlineLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.dark,
                            ),
                  ),
                  const SizedBox(height: 8),
                  _buildStorageRow(Icons.folder_open, 'Archivos locales',
                      storageInfo['filesFormatted'] as String),
                  const SizedBox(height: 4),
                  _buildStorageRow(
                      Icons.settings_applications,
                      'SharedPreferences (${storageInfo['prefsKeyCount']} claves)',
                      storageInfo['prefsFormatted'] as String),
                ],
              ),
            ),

            // ── Detalle de archivos ──
            if (files.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.description,
                      color: AppColors.textColor, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Detalle de Archivos',
                    style:
                        Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textColor,
                            ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ...files.entries.map((entry) {
                final name = entry.key;
                final bytes = entry.value;
                String sizeStr;
                if (bytes < 1024) {
                  sizeStr = '$bytes B';
                } else if (bytes < 1024 * 1024) {
                  sizeStr = '${(bytes / 1024).toStringAsFixed(1)} KB';
                } else {
                  sizeStr =
                      '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      const SizedBox(width: 4),
                      const Icon(Icons.insert_drive_file_outlined,
                          size: 14, color: AppColors.textColor2),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        sizeStr,
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textColor2,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                );
              }),
            ],

            // ── Sección de caché de propiedades ──
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Icons.home_work,
                    color: AppColors.info, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Caché de Propiedades',
                  style:
                      Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.info,
                          ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
                'Propiedades en caché: ${cacheInfo['propertiesCount']}'),
            const SizedBox(height: 8),
            if (cacheInfo['hasCache'])
              Text(
                  'Última actualización: ${_formatDate(cacheInfo['lastUpdate'])}')
            else
              const Text('Sin caché disponible'),
            const SizedBox(height: 8),
            if (cacheInfo['hasCache'])
              Text(
                  'Antigüedad: ${cacheInfo['cacheAgeHours'].toStringAsFixed(1)} horas'),

            // ── Sección: Cola de sincronización ──
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Icons.sync,
                    color: AppColors.warning, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Cola de Sincronización',
                  style:
                      Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.warning,
                          ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (queue.isEmpty)
              const Text(
                'La cola está vacía \u2714\ufe0f',
                style: TextStyle(color: AppColors.success, fontSize: 14),
              )
            else
              ...queue.map((op) {
                final action =
                    (op as Map<String, dynamic>)['action'] as String;
                final localId = op['localId'] as String;
                final timestamp = op['timestamp'] as String? ?? '';

                IconData icon;
                Color color;
                switch (action) {
                  case 'create':
                    icon = Icons.add_circle_outline;
                    color = AppColors.success;
                    break;
                  case 'update':
                    icon = Icons.edit_outlined;
                    color = AppColors.info;
                    break;
                  case 'delete':
                    icon = Icons.delete_outline;
                    color = AppColors.error;
                    break;
                  default:
                    icon = Icons.help_outline;
                    color = AppColors.textColor2;
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(icon, color: color, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              action.toUpperCase(),
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              'ID: ${localId.length > 16 ? '${localId.substring(0, 16)}...' : localId}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            if (timestamp.isNotEmpty)
                              Text(
                                timestamp,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textColor2,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
      actions: [
        if (cacheInfo['hasCache'])
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(dialogContext);
              final scaffoldMessenger = ScaffoldMessenger.of(context);

              await provider.clearCache();
              navigator.pop();

              if (context.mounted) {
                scaffoldMessenger.showSnackBar(
                  const SnackBar(content: Text('Caché limpiado')),
                );
              }
            },
            child: const Text('Limpiar Caché'),
          ),
        if (queue.isNotEmpty) ...[
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(dialogContext);
              await syncService.syncPendingQueue();
              navigator.pop();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Sincronización ejecutada')),
                );
              }
            },
            child: const Text('Sincronizar ahora'),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(dialogContext);
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('appointments_pending_sync');
              navigator.pop();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cola eliminada'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            style:
                TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Eliminar cola'),
          ),
        ],
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
}

Widget _buildStorageRow(IconData icon, String label, String value) {
  return Row(
    children: [
      Icon(icon, size: 14, color: AppColors.primaryColor),
      const SizedBox(width: 6),
      Expanded(
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
      Text(
        value,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.dark,
        ),
      ),
    ],
  );
}

String _formatDate(DateTime? date) {
  if (date == null) return 'Desconocida';
  return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
}
