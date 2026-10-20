import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/global_data_service.dart';
import '../providers/auth_provider.dart';
import '../providers/property_provider.dart';
import '../providers/client_provider.dart';
import 'property_list_screen.dart';
import 'calendar_screen.dart';
import 'clients_screen.dart';
import 'dashboard_screen.dart';
import 'calculators_screen.dart';
import 'guides_screen.dart';
import 'route_planner_screen.dart';
import 'residentials_screen.dart';
import 'login_screen.dart';
import 'maintenance_requests_screen.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final int initialTab;

  const HomeScreen({super.key, this.initialTab = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// Una pestaña de la barra inferior.
class _Tab {
  const _Tab({
    required this.label,
    required this.icon,
    required this.builder,
    this.employeeOnly = false,
  });

  final String label;
  final IconData icon;
  final Widget Function() builder;

  /// Solo para usuarios con sesión: sin verificar, se asume que no es
  /// empleado de la inmobiliaria.
  final bool employeeOnly;
}

class _HomeScreenState extends State<HomeScreen> {
  late int _currentIndex;

  /// Pestañas en orden. Las de empleado desaparecen sin sesión, así que el
  /// índice visible se calcula sobre la lista ya filtrada.
  static final List<_Tab> _allTabs = [
    _Tab(
      label: 'Propiedades',
      icon: Icons.home_work,
      builder: () => const PropertyListScreen(),
    ),
    _Tab(
      label: 'Agenda',
      icon: Icons.calendar_month,
      builder: () => const CalendarScreen(),
      employeeOnly: true,
    ),
    _Tab(
      label: 'Residenciales',
      icon: Icons.apartment,
      builder: () => const ResidentialsScreen(),
      employeeOnly: true,
    ),
    _Tab(
      label: 'Dashboard',
      icon: Icons.dashboard,
      builder: () => const DashboardScreen(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final propertyProvider = context.read<PropertyProvider>();
      final clientProvider = context.read<ClientProvider>();

      // Prefetch no bloqueante de la propiedad CRM del asesor
      clientProvider.ensureAdvisorMap();

      // Esperar la lectura del caché antes de decidir: así el arranque con
      // caché vigente no dispara una descarga innecesaria.
      await propertyProvider.hydration;
      if (propertyProvider.properties.isEmpty || propertyProvider.isCacheStale) {
        propertyProvider.refresh();
      }
    });
  }

  void _onTabTapped(List<_Tab> tabs, int index) {
    setState(() => _currentIndex = index);
    // Al entrar a Residenciales: refrescar si el caché venció (TTL 10 min).
    // Con IndexedStack la pantalla no se reconstruye, así que el disparo va
    // aquí; la lista se repinta sola porque escucha al GlobalDataService.
    if (tabs[index].label == 'Residenciales') {
      context.read<GlobalDataService>().refreshStale();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isLoggedIn = auth.isLoggedIn;
    final tabs = _allTabs
        .where((tab) => isLoggedIn || !tab.employeeOnly)
        .toList();

    // Al cerrar sesión la lista se acorta: el índice guardado puede quedar
    // fuera de rango (cerrar sesión desde Dashboard deja el foco en Dashboard,
    // que pasa de la posición 3 a la 1).
    final index = _currentIndex.clamp(0, tabs.length - 1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inmobarco'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
          ),
        ],
      ),
      drawer: _buildDrawer(
        context,
        isLoggedIn,
        canSeeMaintenance: auth.user?.isManagerOrAdmin ?? false,
      ),
      body: IndexedStack(
        index: index,
        children: [for (final tab in tabs) tab.builder()],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: (i) => _onTabTapped(tabs, i),
        type: BottomNavigationBarType.fixed,
        items: [
          for (final tab in tabs)
            BottomNavigationBarItem(icon: Icon(tab.icon), label: tab.label),
        ],
      ),
    );
  }

  Widget _buildDrawer(
    BuildContext context,
    bool isLoggedIn, {
    required bool canSeeMaintenance,
  }) {
    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
            color: AppColors.primaryColor,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inmobarco',
                  style: TextStyle(color: AppColors.pureWhite, fontSize: 22, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 4),
                Text(
                  'Herramientas del asesor',
                  style: TextStyle(color: AppColors.pureWhite, fontSize: 13),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const SizedBox(height: 8),
                // Herramientas internas: solo con sesión. Sin verificar, se
                // asume que quien usa la app no es empleado.
                if (isLoggedIn) ...[
                  _drawerItem(
                    context,
                    icon: Icons.calculate,
                    title: 'Calculadoras',
                    subtitle: 'Primer canon, pago propietario, comisiones',
                    screen: const CalculatorsScreen(),
                  ),
                  _drawerItem(
                    context,
                    icon: Icons.checklist,
                    title: 'Guías',
                    subtitle: 'Checklists de visita y captación',
                    screen: const GuidesScreen(),
                  ),
                  _drawerItem(
                    context,
                    icon: Icons.route,
                    title: 'Rutero',
                    subtitle: 'Ruta planeada del día',
                    screen: const RoutePlannerScreen(),
                  ),
                  _drawerItem(
                    context,
                    icon: Icons.people,
                    title: 'Clientes',
                    subtitle: 'Ver y gestionar clientes',
                    screen: const ClientsScreen(),
                  ),
                  if (canSeeMaintenance)
                    _drawerItem(
                      context,
                      icon: Icons.handyman,
                      title: 'Mantenimientos',
                      subtitle: 'Solicitudes activas',
                      screen: const MaintenanceRequestsScreen(),
                    ),
                ] else
                  _drawerItem(
                    context,
                    icon: Icons.login,
                    title: 'Iniciar sesión',
                    subtitle: 'Acceso a las herramientas del asesor',
                    screen: const LoginScreen(),
                  ),
                const Divider(indent: 16, endIndent: 16),
              ],
            ),
          ),
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Configuración'),
              subtitle: const Text('Caché, permisos, versión'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  ListTile _drawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget screen,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textColor2),
      onTap: () {
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
      },
    );
  }
}
