import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'core/encription.dart';
import 'data/services/arrendasoft_api_service.dart';
import 'ui/providers/property_provider.dart';
import 'ui/screens/property_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Cargar variables de entorno
  await dotenv.load(fileName: ".env");
  
  // Inicializar encriptación
  propertyEncryption.init();
  
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
            apiService: ArrendasoftApiService(
              apiKey: AppConstants.defaultApiKey,
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
