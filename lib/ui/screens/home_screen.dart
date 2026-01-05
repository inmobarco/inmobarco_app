import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/notification_service.dart';
import '../providers/property_provider.dart';
import '../widgets/inmobarco_app_bar.dart';
import 'property_list_screen.dart';
import 'calendar_screen.dart';

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
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    
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
    return Scaffold(
      appBar: const InmobarcoAppBar(),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_work),
            label: 'Propiedades',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Agenda',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Clientes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Configuración',
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return const PropertyListScreen();
      case 1:
        return const CalendarScreen();
      case 2:
        return _buildClientsPlaceholder();
      case 3:
        return _buildSettingsScreen();
      default:
        return const PropertyListScreen();
    }
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

  Widget _buildSettingsScreen() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
