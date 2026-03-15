import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:inmobarco_app/core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../data/services/sync_service.dart';
import '../providers/property_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/inmobarco_app_bar.dart';
import 'property_list_screen.dart';
import 'calendar_screen.dart';
import 'login_screen.dart';

/// Pantalla principal de la aplicación.
/// 
/// Contiene la estructura general de la app incluyendo:
/// - AppBar con opciones de usuario y caché
/// - Contenido principal (PropertyListScreen)
/// - BottomNavigationBar con navegación
/// 
/// Esta pantalla está diseñada para ser extensible y permitir
/// agregar navegación con tabs u otras secciones en el futuro.
class HomeScreen extends StatefulWidget {
  final int initialTab;
  
  const HomeScreen({super.key, this.initialTab = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
    
    // Cargar datos iniciales
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<PropertyProvider>();
      // Solo hacer refresh si no hay propiedades cargadas desde caché
      if (provider.properties.isEmpty) {
        provider.refresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final isLoggedIn = authProvider.isLoggedIn;
        
        // Construir items de navegación dinámicamente
        final navItems = <BottomNavigationBarItem>[
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_work),
            label: 'Propiedades',
          ),
        ];
        
        if (isLoggedIn) {
          navItems.addAll([
            const BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month),
              label: 'Agenda',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.people),
              label: 'Clientes',
            ),
          ]);
        }
        
        navItems.add(const BottomNavigationBarItem(
          icon: Icon(Icons.settings),
          label: 'Configuración',
        ));
        
        // Ajustar índice si cambia el número de tabs
        final maxIndex = navItems.length - 1;
        final safeIndex = _currentIndex > maxIndex ? 0 : _currentIndex;
        
        return Scaffold(
          appBar: const InmobarcoAppBar(),
          body: _buildBody(isLoggedIn, safeIndex, navItems.length),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: safeIndex,
            onTap: _onTabTapped,
            type: BottomNavigationBarType.fixed,
            items: navItems,
          ),
        );
      },
    );
  }

  Widget _buildBody(bool isLoggedIn, int index, int totalTabs) {
    // Configuración siempre es el último tab
    final configIndex = totalTabs - 1;
    
    if (index == 0) {
      return const PropertyListScreen();
    } else if (index == configIndex) {
      return _buildSettingsScreen();
    } else if (isLoggedIn) {
      // Solo accesible si está logueado
      if (index == 1) {
        return const CalendarScreen();
        //return _buildPlannerPlaceholder();
      } else if (index == 2) {
        return _buildClientsPlaceholder();
      }
    }
    
    return const PropertyListScreen();
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  Widget _buildClientsPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Clientes',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Próximamente',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textColor2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsScreen() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Sección de autenticación
            if (!authProvider.isLoggedIn)
              // Botón para iniciar sesión
              Card(
                child: ListTile(
                  leading: const Icon(Icons.login),
                  title: const Text('Iniciar Sesión'),
                  subtitle: const Text('Accede para ver más funciones'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _navigateToLogin(),
                ),
              )
            else
              // Ficha de información del usuario
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            child: Text(
                              authProvider.user?.firstName.isNotEmpty == true
                                  ? authProvider.user!.firstName[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                color: AppColors.pureWhite,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        authProvider.fullName,
                                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    if (authProvider.user?.phone.isNotEmpty == true)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.phone,
                                            size: 16,
                                            color: AppColors.textColor2,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            authProvider.user!.phone,
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              color: AppColors.textColor2,
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '@${authProvider.user?.username ?? ''}',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textColor2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () async {
                          await authProvider.logout();
                        },
                        child: const Text('Cerrar sesión'),
                      ),
                    ],
                  ),
                ),
              ),
            
            const SizedBox(height: 12),
            
            // Sección de Caché
            Card(
              child: ListTile(
                leading: const Icon(Icons.storage),
                title: const Text('Información del Caché'),
                subtitle: const Text('Ver y limpiar datos en caché'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showCacheInfo(context),
              ),
            ),
            const SizedBox(height: 12),
            // Sección de Versión
            Card(
              child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Versión de la App'),
                subtitle: Text('v${AppConstants.appVersion}'),
              ),
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  Future<void> _navigateToLogin() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Bienvenido!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _showCacheInfo(BuildContext context) async {
    final provider = context.read<PropertyProvider>();
    final cacheInfo = await provider.getCacheInfo();
    final storageInfo = await provider.getTotalStorageInfo();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('appointments_pending_sync');
    final List<dynamic> queue = (raw != null && raw.isNotEmpty)
        ? json.decode(raw)
        : [];
    if (!mounted) return;

    final files = storageInfo['files'] as Map<String, int>;

    showDialog(
      // ignore: use_build_context_synchronously
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
                        const Icon(Icons.storage, color: AppColors.primaryColor, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Almacenamiento Total',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      storageInfo['totalFormatted'] as String,
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.dark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildStorageRow(Icons.folder_open, 'Archivos locales', storageInfo['filesFormatted'] as String),
                    const SizedBox(height: 4),
                    _buildStorageRow(Icons.settings_applications, 'SharedPreferences (${storageInfo['prefsKeyCount']} claves)', storageInfo['prefsFormatted'] as String),
                  ],
                ),
              ),

              // ── Detalle de archivos ──
              if (files.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.description, color: AppColors.textColor, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'Detalle de Archivos',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                    sizeStr = '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        const SizedBox(width: 4),
                        const Icon(Icons.insert_drive_file_outlined, size: 14, color: AppColors.textColor2),
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
                          style: const TextStyle(fontSize: 11, color: AppColors.textColor2, fontWeight: FontWeight.w500),
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
                  const Icon(Icons.home_work, color: AppColors.info, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Caché de Propiedades',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.info,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Propiedades en caché: ${cacheInfo['propertiesCount']}'),
              const SizedBox(height: 8),
              if (cacheInfo['hasCache'])
                Text('Última actualización: ${_formatDate(cacheInfo['lastUpdate'])}')
              else
                const Text('Sin caché disponible'),
              const SizedBox(height: 8),
              if (cacheInfo['hasCache'])
                Text('Antigüedad: ${cacheInfo['cacheAgeHours'].toStringAsFixed(1)} horas'),

              // ── Sección: Cola de sincronización ──
              const Divider(height: 24),
              Row(
                children: [
                  const Icon(Icons.sync, color: AppColors.warning, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Cola de Sincronización',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                  final action = (op as Map<String, dynamic>)['action'] as String;
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
                
                if (mounted) {
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
                await SyncService.instance.syncPendingQueue();
                navigator.pop();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sincronización ejecutada')),
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
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Cola eliminada'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              },
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
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

}
