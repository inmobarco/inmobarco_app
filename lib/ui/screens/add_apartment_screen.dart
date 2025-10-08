import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/services/cache_service.dart';
import '../../data/services/wasi_api_service.dart';
import '../../core/constants/app_constants.dart';

class AddApartmentScreen extends StatefulWidget {
  const AddApartmentScreen({super.key});

  @override
  State<AddApartmentScreen> createState() => _AddApartmentScreenState();
}

class _AddApartmentScreenState extends State<AddApartmentScreen> {
  final _formKey = GlobalKey<FormState>();

  // Campos relevantes para creación en WASI
  final _titleController = TextEditingController(); // Nombre / Título del inmueble
  final _priceController = TextEditingController();
  String _operation = 'alquiler'; // Control interno UI -> se mapea a for_rent / for_sale
  // Condición de la propiedad (WASI: id_property_condition)
  String _propertyConditionId = '1'; // 1 Nuevo (default)
  static const List<Map<String, String>> _propertyConditions = [
    {'id': '1', 'label': 'Nuevo'},
    {'id': '2', 'label': 'Usado'},
    {'id': '3', 'label': 'Proyecto'},
    {'id': '4', 'label': 'En Construcción'},
  ];

  // Selección dinámica
  String? _selectedCityId;
  String? _selectedZoneId;
  List<Map<String, dynamic>> _cities = [];
  List<Map<String, dynamic>> _zones = [];
  bool _loadingCities = false;
  bool _loadingZones = false;

  // Estado autosave
  Timer? _autoSaveTimer;
  bool _loadingDraft = true;
  bool _saving = false;
  DateTime? _lastSaved;

  static const _autoSaveInterval = Duration(seconds: 5);

  // IDs fijos según requerimiento
  static const String _fixedUserId = '271266';
  static const String _fixedPropertyTypeId = '2';
  static const String _fixedCountryId = '1';
  static const String _fixedRegionId = '2'; // Antioquia

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _startAutoSave();
  }

  void _startAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer.periodic(_autoSaveInterval, (_) => _autoSave());
  }

  Future<void> _loadInitialData() async {
    // Cargar draft primero
    final draft = await CacheService.loadAddApartmentDraft();
    if (draft != null) {
      if (draft['title'] != null) _titleController.text = draft['title'];
      // Compatibilidad: antes se guardaba 'business_type'; ahora solo for_rent / for_sale
      if (draft['business_type'] != null) {
        _operation = draft['business_type'] == 'venta' ? 'venta' : 'alquiler';
      } else if (draft['for_rent'] == true) {
        _operation = 'alquiler';
      } else if (draft['for_sale'] == true) {
        _operation = 'venta';
      }
      if (draft['price'] != null) _priceController.text = draft['price'].toString();
      _selectedCityId = draft['id_city']?.toString();
      _selectedZoneId = draft['id_zone']?.toString();
      if (draft['id_property_condition'] != null) {
        final cond = draft['id_property_condition'].toString();
        if (_propertyConditions.any((c) => c['id'] == cond)) {
          _propertyConditionId = cond;
        }
      }
    }

    // Cargar ciudades desde GlobalData si está inicializado, si no llamar API
    await _loadCities();

    // Si hay city en draft, cargar zonas
    if (_selectedCityId != null) {
      await _loadZones(_selectedCityId!);
    }

    if (mounted) setState(() => _loadingDraft = false);
  }

  Future<void> _loadCities() async {
    if (mounted) setState(() => _loadingCities = true);
    try {
      // Usar AppConstants.cities cacheadas si existen
      final cached = AppConstants.cities;
      if (cached.isNotEmpty) {
        _cities = cached;
      } else {
        final api = WasiApiService(apiToken: AppConstants.wasiApiToken, companyId: AppConstants.wasiApiId);
        _cities = await api.getCities();
      }
    } catch (e) {
      debugPrint('Error cargando ciudades: $e');
    } finally {
      if (mounted) setState(() => _loadingCities = false);
    }
  }

  Future<void> _loadZones(String cityId) async {
    if (cityId.isEmpty) return;
    if (mounted) setState(() { _loadingZones = true; _zones = []; });
    try {
      final api = WasiApiService(apiToken: AppConstants.wasiApiToken, companyId: AppConstants.wasiApiId);
      _zones = await api.getZonesByCity(cityId);
      // Si la zona seleccionada ya no pertenece, limpiar
      if (_selectedZoneId != null && !_zones.any((z) => z['id'] == _selectedZoneId)) {
        _selectedZoneId = null;
      }
    } catch (e) {
      debugPrint('Error cargando zonas: $e');
    } finally {
      if (mounted) setState(() => _loadingZones = false);
    }
  }

  Future<void> _autoSave() async {
    if (!mounted) return;
    // No guardar si formulario está completamente vacío
    if (_titleController.text.isEmpty && _priceController.text.isEmpty && _selectedCityId == null) return;
    final data = _currentData();
    _saving = true;
    await CacheService.saveAddApartmentDraft(data);
    _lastSaved = DateTime.now();
    if (mounted) setState(() => _saving = false);
  }

  Map<String, dynamic> _currentData() {
    final isForRent = _operation == 'alquiler';
    return {
      // Fijos / derivables
      'id_company': AppConstants.wasiApiId,
      'id_user': _fixedUserId,
      'id_property_type': _fixedPropertyTypeId,
      'id_country': _fixedCountryId,
      'id_region': _fixedRegionId,
  'id_status_on_page': '1', // Fijo según requerimiento
  'id_availability': '1',   // Fijo según requerimiento (Disponible)
  'id_publish_on_map': '2', // Fijo según requerimiento
  'reference': 'prueba', // Fijo para pruebas
  'id_property_condition': _propertyConditionId, // Seleccionado por el usuario
      // Dinámicos
      'id_city': _selectedCityId,
      'id_zone': _selectedZoneId,
      'title': _titleController.text.trim(),
      'for_rent': isForRent,
      'for_sale': !isForRent,
      'price': _priceController.text.trim(),
      // Metadatos
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  Future<void> _onSavePressed() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCityId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seleccione una ciudad')));
      return;
    }
    final data = _currentData();

    // Copiar al portapapeles
    await Clipboard.setData(ClipboardData(text: jsonEncode(data)));

    // Borrar borrador
    await CacheService.clearAddApartmentDraft();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Datos copiados y borrador eliminado')),
      );
      Navigator.pop(context, data);
    }
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _titleController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo Apartamento (WASI)'),
        actions: [
          if (_saving)
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: SizedBox(
                width: 18,
                height: 18,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: _loadingDraft
          ? const Center(child: CircularProgressIndicator())
          : GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Título / Nombre del inmueble',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingrese un título' : null,
                      ),
                      const SizedBox(height: 16),
                      InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Tipo de negocio',
                          border: OutlineInputBorder(),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _operation,
                            items: const [
                              DropdownMenuItem(value: 'alquiler', child: Text('Alquiler')),
                              DropdownMenuItem(value: 'venta', child: Text('Venta')),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _operation = value);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Condición de la propiedad
                      InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Condición de la propiedad',
                          border: OutlineInputBorder(),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _propertyConditionId,
                            isExpanded: true,
                            items: _propertyConditions
                                .map((c) => DropdownMenuItem(
                                      value: c['id'],
                                      child: Text('${c['id']}. ${c['label']}'),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _propertyConditionId = value);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Ciudad
                      InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Ciudad',
                          border: OutlineInputBorder(),
                        ),
                        child: _loadingCities
                            ? const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                            : DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedCityId,
                                  isExpanded: true,
                                  hint: const Text('Seleccione ciudad'),
                                  items: _cities
                                      .map((c) => DropdownMenuItem(
                                            value: c['id'] as String,
                                            child: Text(c['name'] as String),
                                          ))
                                      .toList(),
                                  onChanged: (value) async {
                                    if (value == _selectedCityId) return;
                                    setState(() {
                                      _selectedCityId = value;
                                      _selectedZoneId = null; // reset zona
                                      _zones = [];
                                    });
                                    if (value != null) await _loadZones(value);
                                  },
                                ),
                              ),
                      ),
                      const SizedBox(height: 16),
                      // Zona
                      InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Zona / Barrio',
                          border: OutlineInputBorder(),
                        ),
                        child: (_selectedCityId == null)
                            ? const Text('Seleccione primero una ciudad')
                            : _loadingZones
                                ? const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                                : DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedZoneId,
                                      isExpanded: true,
                                      hint: const Text('Seleccione zona (opcional)'),
                                      items: _zones
                                          .map((z) => DropdownMenuItem(
                                                value: z['id'] as String,
                                                child: Text(z['name'] as String),
                                              ))
                                          .toList(),
                                      onChanged: (value) {
                                        setState(() => _selectedZoneId = value);
                                      },
                                    ),
                                  ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Precio',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Ingrese un precio';
                          final num? parsed = num.tryParse(v.replaceAll(',', ''));
                          if (parsed == null) return 'Precio inválido';
                          if (parsed < 0) return 'Debe ser positivo';
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.save),
                          label: const Text('Guardar'),
                          onPressed: _onSavePressed,
                        ),
                      ),
                      if (_lastSaved != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Último guardado automático: ${_lastSaved!.hour.toString().padLeft(2, '0')}:${_lastSaved!.minute.toString().padLeft(2, '0')}:${_lastSaved!.second.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        )
                      ]
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

