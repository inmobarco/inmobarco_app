import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/property_provider.dart';
import '../widgets/inmobarco_app_bar.dart';
import 'property_list_screen.dart';

/// Pantalla principal de la aplicación.
/// 
/// Contiene la estructura general de la app incluyendo:
/// - AppBar con opciones de usuario y caché
/// - Contenido principal (PropertyListScreen)
/// 
/// Esta pantalla está diseñada para ser extensible y permitir
/// agregar navegación con tabs u otras secciones en el futuro.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
      body: const PropertyListScreen(),
    );
  }
}
