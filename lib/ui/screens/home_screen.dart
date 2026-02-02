import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
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
        //return const CalendarScreen();
        return _buildPlannerPlaceholder();
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
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlannerPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_month,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Agenda',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Próximamente',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey,
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
                                color: Colors.white,
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
                                          Icon(
                                            Icons.phone,
                                            size: 16,
                                            color: Colors.grey.shade600,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            authProvider.user!.phone,
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              color: Colors.grey.shade600,
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
                                    color: Colors.grey.shade600,
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
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showCacheInfo(BuildContext context) async {
    final provider = context.read<PropertyProvider>();
    final cacheInfo = await provider.getCacheInfo();
    if (!mounted) return;

    showDialog(
      // ignore: use_build_context_synchronously
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Información del Caché'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Propiedades en caché: ${cacheInfo['propertiesCount']}'),
            const SizedBox(height: 8),
            if (cacheInfo['hasCache'])
              Text('Última actualización: ${_formatDate(cacheInfo['lastUpdate'])}')
            else
              const Text('Sin caché disponible'),
            const SizedBox(height: 8),
            if (cacheInfo['hasCache'])
              Text('Antigüedad: ${cacheInfo['cacheAgeHours'].toStringAsFixed(1)} horas'),
          ],
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
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Desconocida';
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
