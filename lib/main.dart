import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'core/encription.dart';
import 'core/services/global_data_service.dart';
import 'core/services/notification_service.dart';
import 'data/services/cache_service.dart';
import 'data/services/wasi_api_service.dart';
import 'data/services/sync_service.dart';
import 'ui/providers/property_provider.dart';
import 'data/repositories/appointment_repository.dart';
import 'ui/providers/appointment_provider.dart';
import 'ui/providers/auth_provider.dart';
import 'ui/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cargar variables de entorno
  await dotenv.load(fileName: "assets/config/.env");

  // Cargar versión desde pubspec.yaml (única fuente de verdad)
  final packageInfo = await PackageInfo.fromPlatform();
  AppConstants.appVersion = packageInfo.version;

  // Inicializar encriptación
  propertyEncryption.init();

  // Crear instancias de servicios
  final globalDataService = GlobalDataService();
  final notificationService = NotificationService();
  final cacheService = CacheService();
  final syncService = SyncService(notificationService: notificationService);

  // Verificar versión: si cambió, limpiar caché
  final cachedVersion = await cacheService.getAppVersion();
  if (cachedVersion != AppConstants.appVersion) {
    debugPrint('🔄 Versión cambió: $cachedVersion → ${AppConstants.appVersion}. Limpiando caché...');
    await cacheService.clearAllCache();
    await cacheService.saveAppVersion(AppConstants.appVersion);
  }

  // Inicializar datos globales (ciudades, etc.)
  await globalDataService.initialize();

  // Inicializar servicio de notificaciones
  await notificationService.initialize();

  // Inicializar localización para fechas en español
  try {
    await initializeDateFormatting('es_ES');
  } catch (e) {
    debugPrint('Error inicializando locale: $e');
  }

  // Iniciar SyncService: escucha de red + timer periódico cada 5 min +
  // vaciado inmediato de la cola al arrancar la app.
  syncService.startListening();

  runApp(InmobarcoApp(
    globalDataService: globalDataService,
    notificationService: notificationService,
    cacheService: cacheService,
    syncService: syncService,
  ));
}

class InmobarcoApp extends StatelessWidget {
  final GlobalDataService globalDataService;
  final NotificationService notificationService;
  final CacheService cacheService;
  final SyncService syncService;

  const InmobarcoApp({
    super.key,
    required this.globalDataService,
    required this.notificationService,
    required this.cacheService,
    required this.syncService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Servicios base (no-ChangeNotifier)
        Provider<GlobalDataService>.value(value: globalDataService),
        Provider<NotificationService>.value(value: notificationService),
        Provider<CacheService>.value(value: cacheService),
        Provider<SyncService>.value(value: syncService),
        // Providers de estado
        ChangeNotifierProvider(
          create: (context) {
            final authProvider = AuthProvider(cacheService: cacheService);
            // Cargar sesión guardada al iniciar
            authProvider.loadSession();
            return authProvider;
          },
        ),
        ChangeNotifierProvider(
          create: (context) => PropertyProvider(
            apiService: WasiApiService(
              apiToken: AppConstants.wasiApiToken,
              companyId: AppConstants.wasiApiId,
              globalDataService: globalDataService,
            ),
            cacheService: cacheService,
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => AppointmentProvider(
            repository: AppointmentRepository(syncService: syncService),
            notificationService: notificationService,
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Inmobarco',
        theme: AppTheme.lightTheme,
        home: const HomeScreen(),
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          return DefaultTextStyle(
            style: GoogleFonts.quicksand(
              fontWeight: AppTheme.defaultFontWeight,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            child: child!,
          );
        },
      ),
    );
  }
}
