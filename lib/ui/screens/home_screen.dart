import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
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
import 'notifications_screen.dart';
import 'settings_screen.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<PropertyProvider>();
      if (provider.properties.isEmpty) provider.refresh();
      // Prefetch no bloqueante de la propiedad CRM del asesor
      context.read<ClientProvider>().ensureAdvisorMap();
    });
  }

  @override
  Widget build(BuildContext context) {
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
      drawer: _buildDrawer(context),
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          PropertyListScreen(),
          CalendarScreen(),
          ResidentialsScreen(),
          DashboardScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_work), label: 'Propiedades'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Agenda'),
          BottomNavigationBarItem(icon: Icon(Icons.apartment), label: 'Residenciales'),
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
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
