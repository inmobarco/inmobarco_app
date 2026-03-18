import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme/app_colors.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen>
    with WidgetsBindingObserver {
  final Map<Permission, PermissionStatus> _statuses = {};
  bool _loading = true;

  static const _permissions = [
    _PermissionInfo(
      permission: Permission.notification,
      title: 'Notificaciones',
      description: 'Recordatorios de citas programadas',
      icon: Icons.notifications_active,
    ),
    _PermissionInfo(
      permission: Permission.scheduleExactAlarm,
      title: 'Alarmas exactas',
      description: 'Programar recordatorios puntuales de citas',
      icon: Icons.alarm,
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAll();
    }
  }

  Future<void> _checkAll() async {
    final statuses = <Permission, PermissionStatus>{};
    for (final info in _permissions) {
      statuses[info.permission] = await info.permission.status;
    }
    if (mounted) {
      setState(() {
        _statuses.addAll(statuses);
        _loading = false;
      });
    }
  }

  Future<void> _requestPermission(_PermissionInfo info) async {
    final status = await info.permission.request();

    if (status.isPermanentlyDenied) {
      if (mounted) {
        final shouldOpenSettings = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Permiso denegado'),
            content: Text(
              'El permiso de "${info.title}" fue denegado permanentemente. '
              'Debes habilitarlo manualmente desde la configuración del teléfono.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Abrir configuración'),
              ),
            ],
          ),
        );
        if (shouldOpenSettings == true) {
          await openAppSettings();
        }
      }
    }

    _checkAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Permisos de la App'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _permissions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final info = _permissions[index];
                final status = _statuses[info.permission];
                return _buildPermissionCard(info, status);
              },
            ),
    );
  }

  Widget _buildPermissionCard(_PermissionInfo info, PermissionStatus? status) {
    final isGranted = status?.isGranted ?? false;
    final isLimited = status?.isLimited ?? false;
    final isAllowed = isGranted || isLimited;

    return Card(
      child: ListTile(
        leading: Icon(
          info.icon,
          color: isAllowed ? AppColors.success : AppColors.textColor2,
          size: 28,
        ),
        title: Text(
          info.title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        subtitle: Text(info.description),
        trailing: isAllowed
            ? const Icon(Icons.check_circle, color: AppColors.success)
            : OutlinedButton(
                onPressed: () => _requestPermission(info),
                child: const Text('Habilitar'),
              ),
      ),
    );
  }
}

class _PermissionInfo {
  final Permission permission;
  final String title;
  final String description;
  final IconData icon;

  const _PermissionInfo({
    required this.permission,
    required this.title,
    required this.description,
    required this.icon,
  });
}
