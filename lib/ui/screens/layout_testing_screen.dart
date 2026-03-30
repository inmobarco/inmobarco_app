import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Pantalla de prueba de layouts para evaluar dos opciones de navegación.
///
/// Esta pantalla NO contiene funcionalidad real — solo placeholders y TODOs
/// para planificar la reorganización de la app con las nuevas secciones.
///
/// Opción A: Bottom Nav con 5 tabs (Propiedades, Agenda, Rutero, Herramientas, Perfil)
/// Opción B: Bottom Nav con 4 tabs (Inicio/Dashboard, Propiedades, Agenda, Más)
/// Opción C: Drawer lateral (Guías, Calculadoras, Config) + Bottom Nav 4 tabs (Propiedades, Agenda, Clientes, Dashboard)
class LayoutTestingScreen extends StatefulWidget {
  const LayoutTestingScreen({super.key});

  @override
  State<LayoutTestingScreen> createState() => _LayoutTestingScreenState();
}

class _LayoutTestingScreenState extends State<LayoutTestingScreen> {
  int _selectedLayout = 0; // 0 = Opción A, 1 = Opción B, 2 = Opción C
  int _currentTabA = 0;
  int _currentTabB = 0;
  int _currentTabC = 0;
  final GlobalKey<ScaffoldState> _scaffoldKeyC = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Layout Testing'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('A')),
                ButtonSegment(value: 1, label: Text('B')),
                ButtonSegment(value: 2, label: Text('C')),
              ],
              selected: {_selectedLayout},
              onSelectionChanged: (value) {
                setState(() => _selectedLayout = value.first);
              },
            ),
          ),
        ),
      ),
      body: switch (_selectedLayout) {
        0 => _buildOptionA(),
        1 => _buildOptionB(),
        _ => _buildOptionC(),
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // OPCIÓN A: Bottom Nav 5 tabs
  // [ Propiedades | Agenda | Rutero | Herramientas | Perfil ]
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildOptionA() {
    return Column(
      children: [
        // Descripción del layout
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: AppColors.primaryColor.withValues(alpha: 0.08),
          child: const Text(
            'Opción A: 5 tabs — Propiedades como principal, Rutero acceso directo, '
            'herramientas secundarias agrupadas en grid',
            style: TextStyle(fontSize: 13, color: AppColors.textColor),
          ),
        ),
        // Contenido del tab seleccionado
        Expanded(
          child: IndexedStack(
            index: _currentTabA,
            children: [
              _buildPropertyPlaceholder(),
              _buildAgendaPlaceholder(),
              _buildRuteroPlaceholder(),
              _buildHerramientasGrid(),
              _buildPerfilPlaceholder(),
            ],
          ),
        ),
        // Bottom Navigation
        BottomNavigationBar(
          currentIndex: _currentTabA,
          onTap: (i) => setState(() => _currentTabA = i),
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
              icon: Icon(Icons.route),
              label: 'Rutero',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_rounded),
              label: 'Herramientas',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Perfil',
            ),
          ],
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // OPCIÓN B: Bottom Nav 4 tabs
  // [ Inicio | Propiedades | Agenda | Más ]
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildOptionB() {
    return Column(
      children: [
        // Descripción del layout
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: AppColors.secondaryColor.withValues(alpha: 0.08),
          child: const Text(
            'Opción B: 4 tabs — Inicio con dashboard + accesos rápidos, '
            'Propiedades y Agenda directos, lo demás en "Más"',
            style: TextStyle(fontSize: 13, color: AppColors.textColor),
          ),
        ),
        // Contenido del tab seleccionado
        Expanded(
          child: IndexedStack(
            index: _currentTabB,
            children: [
              _buildDashboardHome(),
              _buildPropertyPlaceholder(),
              _buildAgendaPlaceholder(),
              _buildMasScreen(),
            ],
          ),
        ),
        // Bottom Navigation
        BottomNavigationBar(
          currentIndex: _currentTabB,
          onTap: (i) => setState(() => _currentTabB = i),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard),
              label: 'Inicio',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.home_work),
              label: 'Propiedades',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month),
              label: 'Agenda',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.more_horiz),
              label: 'Más',
            ),
          ],
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // OPCIÓN C: Drawer lateral + Bottom Nav 4 tabs
  // AppBar: [☰ Menú] Inmobarco
  // Drawer: Guías, Calculadoras, Rutero — abajo: Configuración
  // Bottom: [ Propiedades | Agenda | Clientes | Dashboard ]
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildOptionC() {
    return Scaffold(
      key: _scaffoldKeyC,
      drawer: _buildDrawerC(),
      body: Column(
        children: [
          // Descripción del layout
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: AppColors.success.withValues(alpha: 0.08),
            child: const Text(
              'Opción C: Drawer lateral con herramientas secundarias (Guías, '
              'Calculadoras, Rutero) + Config abajo. Bottom Nav con 4 tabs principales.',
              style: TextStyle(fontSize: 13, color: AppColors.textColor),
            ),
          ),
          // Simulación del AppBar con botón de menú
          Container(
            height: 56,
            color: AppColors.primaryColor,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.menu, color: AppColors.pureWhite),
                  onPressed: () {
                    _scaffoldKeyC.currentState?.openDrawer();
                  },
                ),
                const SizedBox(width: 8),
                const Text(
                  'Inmobarco',
                  style: TextStyle(
                    color: AppColors.pureWhite,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                // TODO: Acciones del AppBar (notificaciones, perfil rápido)
                IconButton(
                  icon: const Icon(Icons.notifications_none, color: AppColors.pureWhite),
                  onPressed: () {},
                ),
              ],
            ),
          ),
          // Contenido del tab seleccionado
          Expanded(
            child: IndexedStack(
              index: _currentTabC,
              children: [
                _buildPropertyPlaceholder(),
                _buildAgendaPlaceholder(),
                _buildClientesPlaceholder(),
                _buildDashboardWithProfile(),
              ],
            ),
          ),
          // Bottom Navigation
          BottomNavigationBar(
            currentIndex: _currentTabC,
            onTap: (i) => setState(() => _currentTabC = i),
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
                icon: Icon(Icons.dashboard),
                label: 'Dashboard',
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Drawer lateral con herramientas secundarias y configuración al fondo
  Widget _buildDrawerC() {
    return Drawer(
      child: Column(
        children: [
          // Header del drawer
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
            color: AppColors.primaryColor,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inmobarco',
                  style: TextStyle(
                    color: AppColors.pureWhite,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Herramientas del asesor',
                  style: TextStyle(
                    color: AppColors.pureWhite,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          // Opciones del menú
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const SizedBox(height: 8),
                _buildDrawerItem(
                  icon: Icons.calculate,
                  title: 'Calculadoras',
                  subtitle: 'Primer canon, pago propietario, comisiones',
                  color: AppColors.primaryColor,
                ),
                _buildDrawerItem(
                  icon: Icons.checklist,
                  title: 'Guías',
                  subtitle: 'Checklists de visita y captación',
                  color: AppColors.success,
                ),
                _buildDrawerItem(
                  icon: Icons.route,
                  title: 'Rutero',
                  subtitle: 'Ruta planeada del día',
                  color: AppColors.info,
                ),
                const Divider(indent: 16, endIndent: 16),
                _buildDrawerItem(
                  icon: Icons.notifications_none,
                  title: 'Notificaciones',
                  subtitle: 'Centro de avisos',
                  color: AppColors.warning,
                ),
              ],
            ),
          ),
          // Configuración fija al fondo
          const Divider(height: 1),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.textColor2.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.settings, color: AppColors.textColor2),
            ),
            title: const Text('Configuración'),
            subtitle: const Text('Caché, permisos, versión'),
            trailing: const Icon(Icons.chevron_right, color: AppColors.textColor2),
            onTap: () {
              Navigator.pop(context); // Cerrar drawer
              // TODO: Navigator.push → SettingsScreen
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textColor2),
      onTap: () {
        Navigator.pop(context); // Cerrar drawer
        // TODO: Navigator.push → pantalla correspondiente
      },
    );
  }

  /// Placeholder de clientes / mini CRM (Opción C)
  Widget _buildClientesPlaceholder() {
    return _buildSectionPlaceholder(
      icon: Icons.people,
      title: 'Clientes',
      subtitle: 'Mini CRM — Próximamente',
      color: AppColors.info,
      todos: const [
        'CRUD de clientes/prospectos',
        'Asociar cliente a citas y visitas',
        'Historial de interacciones',
        'Filtros por estado y búsqueda',
      ],
    );
  }

  /// Dashboard con métricas + info del perfil + cerrar sesión (Opción C)
  Widget _buildDashboardWithProfile() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Perfil del asesor
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primaryColor,
                  child: Icon(Icons.person, color: AppColors.pureWhite, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nombre del Asesor',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const Text(
                        '@username • 310 555 1234',
                        style: TextStyle(fontSize: 13, color: AppColors.textColor2),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // TODO: Cerrar sesión
                  },
                  child: const Text(
                    'Salir',
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Toggle semana / mes
        Row(
          children: [
            _buildPeriodChip('Semana', selected: true),
            const SizedBox(width: 8),
            _buildPeriodChip('Mes', selected: false),
          ],
        ),
        const SizedBox(height: 16),

        // Métricas
        Row(
          children: [
            Expanded(child: _buildMetricCard('Captaciones', '12', Icons.add_home_work, AppColors.primaryColor)),
            const SizedBox(width: 12),
            Expanded(child: _buildMetricCard('Visitas', '28', Icons.calendar_month, AppColors.info)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildMetricCard('Rutas', '8', Icons.route, AppColors.success)),
            const SizedBox(width: 12),
            Expanded(child: _buildMetricCard('Proyectos', '15', Icons.apartment, AppColors.warning)),
          ],
        ),
        const SizedBox(height: 24),

        // TODO badge
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
          ),
          child: const Text(
            'TODO: Métricas reales desde backend.\n'
            'TODO: Gráfica de tendencia semanal (fl_chart).\n'
            'TODO: Info de perfil desde AuthProvider.\n'
            'TODO: Cerrar sesión real con AuthProvider.logout().',
            style: TextStyle(fontSize: 12, color: AppColors.warning),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PLACEHOLDERS COMPARTIDOS
  // ══════════════════════════════════════════════════════════════════════════

  /// Placeholder de la lista de propiedades (funcionalidad existente)
  Widget _buildPropertyPlaceholder() {
    return _buildSectionPlaceholder(
      icon: Icons.home_work,
      title: 'Propiedades',
      subtitle: 'Lista de inmuebles — YA IMPLEMENTADO',
      color: AppColors.primaryColor,
      todos: const [
        'PropertyListScreen ya existente',
        'Búsqueda con debounce, filtros, paginación',
        'Este tab se reemplaza con PropertyListScreen()',
      ],
    );
  }

  /// Placeholder de la agenda (funcionalidad existente)
  Widget _buildAgendaPlaceholder() {
    return _buildSectionPlaceholder(
      icon: Icons.calendar_month,
      title: 'Agenda',
      subtitle: 'Calendario de citas — YA IMPLEMENTADO',
      color: AppColors.info,
      todos: const [
        'CalendarScreen ya existente',
        'CRUD de citas, sync offline, vista mensual',
        'Este tab se reemplaza con CalendarScreen()',
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // RUTERO — Placeholder
  // ══════════════════════════════════════════════════════════════════════════

  // TODO: Rutero
  //   - Modelo: RutaDia { fecha, List<ParadaRuta> paradas }
  //   - ParadaRuta { idPropiedad, direccion, horaEstimada, visitada, horaVisita, ubicacionGPS }
  //   - Vista: TabBar con 5 días (hoy + 4 siguientes), cada día muestra lista de paradas
  //   - Marcar visitada: registra DateTime.now() + Geolocator.getCurrentPosition()
  //   - Fuente de datos: endpoint del backend custom (GET /routes/advisor/{id}?days=5)
  //   - Integración con Google Maps para ver ruta optimizada
  //   - Notificaciones push para recordar siguiente parada

  Widget _buildRuteroPlaceholder() {
    return Column(
      children: [
        // Simulación de TabBar de días
        Container(
          height: 48,
          color: AppColors.primaryColor,
          child: Row(
            children: List.generate(5, (i) {
              final labels = ['Hoy', 'Mañana', 'Día 3', 'Día 4', 'Día 5'];
              return Expanded(
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: i == 0
                        ? const Border(
                            bottom: BorderSide(color: AppColors.pureWhite, width: 3),
                          )
                        : null,
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      color: i == 0
                          ? AppColors.pureWhite
                          : AppColors.pureWhite.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        // Simulación de lista de paradas del día
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildRuteroStopCard(
                order: 1,
                address: 'Cra 43A #14-109, El Poblado',
                time: '9:00 AM',
                visited: true,
              ),
              _buildRuteroStopCard(
                order: 2,
                address: 'Cl 10 #32-45, Envigado Centro',
                time: '10:30 AM',
                visited: true,
              ),
              _buildRuteroStopCard(
                order: 3,
                address: 'Cra 48 #20-15, Sabaneta',
                time: '12:00 PM',
                visited: false,
              ),
              _buildRuteroStopCard(
                order: 4,
                address: 'Cl 77S #45-20, La Estrella',
                time: '2:30 PM',
                visited: false,
              ),
              const SizedBox(height: 24),
              // TODO badge
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                ),
                child: const Text(
                  'TODO: Integrar Geolocator para registrar ubicación al marcar visitada.\n'
                  'TODO: Endpoint backend GET /routes/advisor/{id}\n'
                  'TODO: Botón "Ver en mapa" con ruta optimizada (Google Maps Intent)',
                  style: TextStyle(fontSize: 12, color: AppColors.warning),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRuteroStopCard({
    required int order,
    required String address,
    required String time,
    required bool visited,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: visited ? AppColors.success : AppColors.gray,
          child: visited
              ? const Icon(Icons.check, color: AppColors.pureWhite, size: 20)
              : Text(
                  '$order',
                  style: const TextStyle(
                    color: AppColors.textColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
        title: Text(
          address,
          style: TextStyle(
            decoration: visited ? TextDecoration.lineThrough : null,
            color: visited ? AppColors.textColor2 : AppColors.textColor,
          ),
        ),
        subtitle: Text(time),
        trailing: visited
            ? const Text(
                '9:15 AM',
                style: TextStyle(color: AppColors.success, fontSize: 12),
              )
            : OutlinedButton(
                onPressed: () {
                  // TODO: Registrar visita con hora + GPS
                },
                child: const Text('Visitar'),
              ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HERRAMIENTAS — Grid de funciones secundarias (Opción A)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildHerramientasGrid() {
    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.all(16),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [
        _buildToolCard(
          icon: Icons.calculate,
          title: 'Calculadoras',
          subtitle: 'Financieras',
          color: AppColors.primaryColor,
          todos: const [
            // TODO: Calculadora - Liquidación Primer Canon
            //   - Campos: canon mensual, depósito, admin, honorarios, fecha inicio
            //   - Desglose: canon proporcional, depósito, admin proporcional, honorarios
            //   - Exportar como imagen (RepaintBoundary + dart:ui)
            'Liquidación primer canon',
            // TODO: Calculadora - Pago a Propietario
            //   - Campos: canon mensual
            //   - Descuentos: comisión inmobiliaria (%), IVA (19%), 4x1000, otros
            //   - Resultado: pago neto al propietario
            //   - Exportar como imagen
            'Pago a propietario',
            // TODO: Calculadora - Comisiones
            //   - Campos: valor inmueble, tipo negocio, % comisión
            //   - Resultado: total comisión, IVA, retención, neto
            //   - Exportar como imagen
            'Comisiones',
          ],
        ),
        _buildToolCard(
          icon: Icons.checklist,
          title: 'Guías',
          subtitle: 'Checklists',
          color: AppColors.success,
          todos: const [
            // TODO: Guías / Checklists
            //   - ChecklistVisita: items de qué mostrar al cliente en la visita
            //   - ChecklistCaptacion: items de qué revisar al captar un apartamento
            //   - Persistir progreso con SharedPreferences
            //   - Posibilidad de checklists dinámicos desde backend
            'Checklist visita cliente',
            'Checklist captación',
          ],
        ),
        _buildToolCard(
          icon: Icons.people,
          title: 'Clientes',
          subtitle: 'Mini CRM',
          color: AppColors.info,
          todos: const [
            // TODO: Mini CRM
            //   - CRUD de clientes/prospectos
            //   - Asociar cliente a citas y visitas
            //   - Historial de interacciones
            //   - Filtros por estado (activo, interesado, cerrado)
            'CRUD clientes',
            'Asociar a citas',
            'Historial interacciones',
          ],
        ),
        _buildToolCard(
          icon: Icons.bar_chart,
          title: 'Dashboard',
          subtitle: 'Métricas',
          color: AppColors.warning,
          todos: const [
            // TODO: Dashboard Asesor
            //   - Métricas: captaciones totales, visitas agendadas, rutas recorridas
            //   - Filtro: semana actual / mes actual
            //   - Fuente: endpoint backend (GET /dashboard/advisor/{id})
            //   - Widgets: cards con número + tendencia, gráficas (fl_chart)
            'Captaciones totales',
            'Visitas agendadas',
            'Rutas recorridas',
          ],
        ),
      ],
    );
  }

  Widget _buildToolCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required List<String> todos,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () {
          // TODO: Navigator.push → pantalla correspondiente
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.textColor,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: AppColors.textColor2),
              ),
              const Spacer(),
              // Mini lista de TODOs
              ...todos.take(2).map((t) => Row(
                    children: [
                      Container(
                        width: 4,
                        height: 4,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color.withValues(alpha: 0.5),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          t,
                          style: const TextStyle(fontSize: 11, color: AppColors.textColor2),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  )),
              if (todos.length > 2)
                Text(
                  '+${todos.length - 2} más',
                  style: TextStyle(
                    fontSize: 11,
                    color: color.withValues(alpha: 0.7),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PERFIL — Placeholder (Opción A)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildPerfilPlaceholder() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Info del usuario
        const Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primaryColor,
              child: Icon(Icons.person, color: AppColors.pureWhite),
            ),
            title: Text('Nombre del Asesor'),
            subtitle: Text('@username — Configuración de cuenta'),
          ),
        ),
        const SizedBox(height: 8),
        // Opciones de configuración
        ...[
          (Icons.storage, 'Información del Caché', 'Ver y limpiar datos en caché'),
          (Icons.security, 'Permisos de la App', 'Ver y gestionar permisos'),
          (Icons.info_outline, 'Versión de la App', 'v1.x.x'),
          (Icons.logout, 'Cerrar Sesión', 'Salir de la cuenta'),
        ].map((item) => Card(
              child: ListTile(
                leading: Icon(item.$1),
                title: Text(item.$2),
                subtitle: Text(item.$3),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: Navegación a cada sección de configuración
                },
              ),
            )),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DASHBOARD HOME — Inicio con métricas + accesos rápidos (Opción B)
  // ══════════════════════════════════════════════════════════════════════════

  // TODO: Dashboard Asesor
  //   - Métricas: captaciones totales, visitas agendadas, rutas recorridas, proyectos visitados
  //   - Filtro: semana actual / mes actual (ToggleButtons o SegmentedButton)
  //   - Fuente: endpoint backend custom (GET /dashboard/advisor/{id}?period=week|month)
  //   - Widgets: cards con número + tendencia, gráficas simples con fl_chart
  //   - Actualización: pull-to-refresh + auto cada 5 min

  Widget _buildDashboardHome() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Saludo
        Text(
          'Hola, Asesor',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Resumen de tu actividad',
          style: TextStyle(color: AppColors.textColor2),
        ),
        const SizedBox(height: 16),

        // Toggle semana / mes
        Row(
          children: [
            _buildPeriodChip('Semana', selected: true),
            const SizedBox(width: 8),
            _buildPeriodChip('Mes', selected: false),
          ],
        ),
        const SizedBox(height: 16),

        // Métricas en grid 2x2
        Row(
          children: [
            Expanded(child: _buildMetricCard('Captaciones', '12', Icons.add_home_work, AppColors.primaryColor)),
            const SizedBox(width: 12),
            Expanded(child: _buildMetricCard('Visitas', '28', Icons.calendar_month, AppColors.info)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildMetricCard('Rutas', '8', Icons.route, AppColors.success)),
            const SizedBox(width: 12),
            Expanded(child: _buildMetricCard('Proyectos', '15', Icons.apartment, AppColors.warning)),
          ],
        ),
        const SizedBox(height: 24),

        // Accesos rápidos
        const Text(
          'Accesos rápidos',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: AppColors.textColor,
          ),
        ),
        const SizedBox(height: 12),

        // Grid de accesos rápidos
        Row(
          children: [
            Expanded(
              child: _buildQuickAccessCard(Icons.route, 'Rutero', AppColors.primaryColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickAccessCard(Icons.calculate, 'Calculadoras', AppColors.info),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickAccessCard(Icons.checklist, 'Guías', AppColors.success),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickAccessCard(Icons.people, 'Clientes', AppColors.warning),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // TODO badge
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
          ),
          child: const Text(
            'TODO: Conectar métricas reales desde backend.\n'
            'TODO: Agregar gráfica de tendencia semanal (fl_chart).\n'
            'TODO: Pull-to-refresh para actualizar dashboard.',
            style: TextStyle(fontSize: 12, color: AppColors.warning),
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodChip(String label, {required bool selected}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? AppColors.primaryColor : AppColors.backgroundLevel2,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? AppColors.pureWhite : AppColors.textColor2,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
                // TODO: Indicador de tendencia (↑ ↓)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '+3',
                    style: TextStyle(fontSize: 11, color: AppColors.success),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppColors.textColor2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAccessCard(IconData icon, String label, Color color) {
    return Card(
      child: InkWell(
        onTap: () {
          // TODO: Navigator.push → pantalla correspondiente
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textColor,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: AppColors.textColor2.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // "MÁS" — Lista de opciones restantes (Opción B)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildMasScreen() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...[
          (Icons.person, 'Mi Perfil', 'Configuración de cuenta', AppColors.primaryColor),
          (Icons.storage, 'Caché', 'Ver y limpiar datos en caché', AppColors.info),
          (Icons.security, 'Permisos', 'Ver y gestionar permisos', AppColors.warning),
          (Icons.info_outline, 'Versión', 'v1.x.x', AppColors.textColor2),
          (Icons.logout, 'Cerrar Sesión', 'Salir de la cuenta', AppColors.error),
        ].map((item) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: item.$4.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(item.$1, color: item.$4),
                ),
                title: Text(item.$2),
                subtitle: Text(item.$3),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: Navegación a cada sección
                },
              ),
            )),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HELPER GENÉRICO
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildSectionPlaceholder({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required List<String> todos,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: color),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(color: AppColors.textColor2),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Lista de TODOs
            ...todos.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline, size: 16, color: color.withValues(alpha: 0.5)),
                      const SizedBox(width: 8),
                      Text(
                        t,
                        style: const TextStyle(fontSize: 13, color: AppColors.textColor2),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════════
// TODOs GLOBALES — Resumen de implementación futura
// ════════════════════════════════════════════════════════════════════════════════

// TODO: Calculadora - Liquidación Primer Canon
//   - Campos: canon mensual, depósito, administración, honorarios, fecha inicio
//   - Desglose: canon proporcional por días, depósito, admin proporcional, honorarios
//   - Resultado: total a cobrar en primer pago con tabla de desglose
//   - Exportar como imagen (RepaintBoundary + RenderRepaintBoundary.toImage())
//   - Widget: formulario con campos numéricos + DatePicker + tabla resultado

// TODO: Calculadora - Pago a Propietario
//   - Campos: canon mensual bruto
//   - Descuentos automáticos:
//       • Comisión inmobiliaria (% configurable, default 10%)
//       • IVA sobre comisión (19%)
//       • 4x1000 (0.4%)
//       • Otros cobros (campo libre)
//   - Resultado: pago neto al propietario con tabla de descuentos
//   - Exportar como imagen

// TODO: Calculadora - Comisiones
//   - Campos: valor del inmueble, tipo de negocio (venta/alquiler), % comisión
//   - Resultado: total comisión, IVA, retención en la fuente, neto a recibir
//   - Exportar como imagen

// TODO: Rutero
//   - Modelo: RutaDia { fecha, List<ParadaRuta> paradas }
//   - ParadaRuta { idPropiedad, direccion, horaEstimada, visitada, horaVisita, ubicacionGPS }
//   - Vista: TabBar con 5 días (hoy + 4 siguientes), cada día muestra lista de paradas
//   - Marcar visitada: registra DateTime.now() + Geolocator.getCurrentPosition()
//   - Fuente de datos: endpoint del backend custom (GET /routes/advisor/{id}?days=5)
//   - Integración opcional: Google Maps intent para navegación entre paradas
//   - Notificaciones: recordatorio 15 min antes de cada parada

// TODO: Guías / Checklists
//   - ChecklistVisita: qué mostrar al cliente durante la visita del inmueble
//       • Verificar acceso, llaves, estado general
//       • Mostrar amenidades, parqueadero, cuarto útil
//       • Explicar costos de administración, reglamento
//   - ChecklistCaptacion: qué revisar al captar un nuevo apartamento
//       • Documentación del propietario
//       • Estado de pisos, paredes, cocina, baños
//       • Fotos requeridas (fachada, habitaciones, cocina, baños, vista)
//       • Servicios públicos, estrato, antigüedad
//   - Persistir progreso localmente con SharedPreferences
//   - Posibilidad futura: checklists dinámicos desde backend

// TODO: Dashboard Asesor
//   - Métricas principales:
//       • Captaciones totales (inmuebles captados)
//       • Visitas agendadas (citas programadas)
//       • Rutas recorridas (días con ruta completada)
//       • Proyectos visitados (inmuebles distintos visitados)
//   - Filtro temporal: semana actual / mes actual
//   - Fuente: endpoint backend custom (GET /dashboard/advisor/{id}?period=week|month)
//   - Widgets: cards numéricas con indicador de tendencia (+/-)
//   - Gráficas: barras o líneas con fl_chart para tendencia semanal
//   - Pull-to-refresh + actualización automática cada 5 min

// TODO: Clientes (Mini CRM)
//   - CRUD de clientes/prospectos
//   - Campos: nombre, teléfono, email, presupuesto, tipo interés (compra/alquiler)
//   - Estados: nuevo, contactado, en visita, interesado, cerrado, descartado
//   - Asociar cliente a citas y visitas
//   - Historial de interacciones (notas, llamadas, visitas)
//   - Filtros por estado y búsqueda por nombre
//   - Fuente: endpoint backend custom (GET/POST /clients)
