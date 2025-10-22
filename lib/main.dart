import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'core/encription.dart';
import 'core/services/global_data_service.dart';
import 'data/services/wasi_api_service.dart';
import 'ui/providers/property_provider.dart';
import 'ui/screens/property_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Cargar variables de entorno
  await dotenv.load(fileName: "assets/config/.env");
  
  // Inicializar encriptación
  propertyEncryption.init();
  
  // Inicializar datos globales (ciudades, etc.)
  await GlobalDataService().initialize();
  
  runApp(const InmobarcoApp());
}

class InmobarcoApp extends StatelessWidget {
  const InmobarcoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => PropertyProvider(
            apiService: WasiApiService(
              apiToken: AppConstants.wasiApiToken,
              companyId: AppConstants.wasiApiId,
            ),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Inmobarco',
        theme: AppTheme.lightTheme,
        home: const PropertyListScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
