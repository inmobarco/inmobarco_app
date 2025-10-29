import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import '../../data/services/cache_service.dart';
import '../../data/services/wasi_api_service.dart';
import '../../core/constants/app_constants.dart';

class _WebhookResult {
  final bool success;
  final bool isConnectionError;
  final String? message;

  const _WebhookResult({
    required this.success,
    this.isConnectionError = false,
    this.message,
  });
}

String _formatWithThousandsSeparator(String digits) {
  if (digits.isEmpty) {
    return '';
  }
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    buffer.write(digits[i]);
    final remaining = digits.length - i - 1;
    if (remaining > 0 && remaining % 3 == 0) {
      buffer.write('.');
    }
  }
  return buffer.toString();
}

class _ThousandsSeparatorFormatter extends TextInputFormatter {
  const _ThousandsSeparatorFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final formatted = _formatWithThousandsSeparator(digits);
    var selectionEnd = newValue.selection.end;
    if (selectionEnd < 0) {
      selectionEnd = 0;
    } else if (selectionEnd > newValue.text.length) {
      selectionEnd = newValue.text.length;
    }
    final digitsToRight = newValue.text
        .substring(selectionEnd)
        .replaceAll(RegExp(r'[^0-9]'), '')
        .length;
    var selectionIndex = formatted.length - digitsToRight;
    if (selectionIndex < 0) {
      selectionIndex = 0;
    } else if (selectionIndex > formatted.length) {
      selectionIndex = formatted.length;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: selectionIndex),
    );
  }
}

class _ApartmentPhoto {
  final Uint8List bytes;
  final String fileName;

  const _ApartmentPhoto({
    required this.bytes,
    required this.fileName,
  });
}

class AddApartmentScreen extends StatefulWidget {
  const AddApartmentScreen({super.key});

  @override
  State<AddApartmentScreen> createState() => _AddApartmentScreenState();
}

class _AddApartmentScreenState extends State<AddApartmentScreen> {
  final _formKey = GlobalKey<FormState>();

  // Campos relevantes para creación en WASI
  final _apartmentNumberController = TextEditingController();
  final _unitNameController = TextEditingController();
  final _rentPriceController = TextEditingController();
  final _salePriceController = TextEditingController();
  final _addressController = TextEditingController();
  final _areaController = TextEditingController();
  final _observationsController = TextEditingController();
  final _buildingDateController = TextEditingController();
  final _serviceRoomController = TextEditingController();
  final _parkingLotController = TextEditingController();
  final _promptsController = TextEditingController();
  final _landlordNameController = TextEditingController();
  final _landlordPhoneController = TextEditingController();
  final _keysController = TextEditingController(text: 'PORTERIA');
  final _adminMailController = TextEditingController();
  final _adminPhoneController = TextEditingController();
  final _lodgePhoneController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  Uint8List? _serviceRoomPhotoBytes;
  String? _serviceRoomPhotoFileName;
  Uint8List? _parkingLotPhotoBytes;
  String? _parkingLotPhotoFileName;
  final List<_ApartmentPhoto> _photos = <_ApartmentPhoto>[];
  final Set<String> _selectedFeatureIds = <String>{};
  final Set<String> _pendingFeatureNames = <String>{};
  bool _hasVeredalWater = false;
  bool _hasGasInstallation = false;
  bool _hasLegalizacionEpm = false;
  bool _hasInternetOperators = false;
  List<Map<String, dynamic>> _internalFeatures = [];
  List<Map<String, dynamic>> _externalFeatures = [];
  List<Map<String, dynamic>> _otherFeatures = [];
  bool _loadingFeatures = false;
  String _operation = 'alquiler'; // Control interno UI -> se mapea a for_rent / for_sale
  String _statusOnPageId = '1'; // 1 Activo, 2 Inactivo
  // Condición de la propiedad (WASI: id_property_condition)
  String _propertyConditionId = '1'; // 1 Nuevo (default)
  static const List<Map<String, String>> _propertyConditions = [
    {'id': '1', 'label': 'Nuevo'},
    {'id': '2', 'label': 'Usado'},
    {'id': '3', 'label': 'Proyecto'},
    {'id': '4', 'label': 'En Construcción'},
  ];

  static const List<Map<String, String>> _statusOptions = [
    {'id': '1', 'label': 'Activo'},
    {'id': '2', 'label': 'Inactivo'},
  ];

  // Dropdowns numéricos
  String _bedrooms = '1';
  String _bathrooms = '1';
  String _garages = '0';
  String _stratum = '3';

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
  bool _isSubmitting = false;
  DateTime? _lastSaved;

  String? _userFirstName;
  String? _userLastName;
  String? _userPhone;

  static const _autoSaveInterval = Duration(seconds: 5);

  // IDs fijos según requerimiento
  static const String _fixedUserId = '271266';
  static const String _fixedPropertyTypeId = '2';
  static const String _fixedCountryId = '1';
  static const String _fixedRegionId = '2'; // Antioquia
  static const String _webhookUrl = 'https://automa-inmobarco-n8n.druysh.easypanel.host/webhook/wasi';
  static const Set<String> _allowedImageExtensions = {'png', 'jpg', 'jpeg', 'gif'};
  static const int _maxPhotoCount = 30;

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
      final storedApartmentNumber = draft['_apartment_number_text'] ?? draft['apartment_number'];
      final storedUnitName = draft['_unit_name_text'] ?? draft['unit_name'];
      if (storedApartmentNumber != null) {
        final sanitizedNumber = _digitsOnly(storedApartmentNumber.toString());
        _apartmentNumberController.text = sanitizedNumber;
      }
      if (storedUnitName != null) {
        _unitNameController.text = storedUnitName.toString();
      }
      if (_apartmentNumberController.text.isEmpty && draft['title'] != null) {
        final rawTitle = draft['title'].toString();
        final parts = rawTitle.split('-');
        if (parts.isNotEmpty) {
          final sanitizedNumber = _digitsOnly(parts.first);
          _apartmentNumberController.text = sanitizedNumber;
          if (parts.length > 1) {
            _unitNameController.text = parts.sublist(1).join('-').trim();
          }
        }
      }
      // Compatibilidad: antes se guardaba 'business_type'; ahora solo for_rent / for_sale
      if (draft['business_type'] != null) {
        _operation = draft['business_type'] == 'venta' ? 'venta' : 'alquiler';
      } else if (draft['for_rent'] == true) {
        _operation = 'alquiler';
      } else if (draft['for_sale'] == true) {
        _operation = 'venta';
      }
      final storedStatusOnPage = draft['id_status_on_page']?.toString();
      if (storedStatusOnPage != null &&
          _statusOptions.any((option) => option['id'] == storedStatusOnPage)) {
        _statusOnPageId = storedStatusOnPage;
      }
      if (draft['rent_price'] != null) _rentPriceController.text = draft['rent_price'].toString();
      if (_rentPriceController.text.isEmpty && draft['price'] != null) {
        _rentPriceController.text = draft['price'].toString();
      }
      _applyThousandsFormat(_rentPriceController);
      if (draft['sale_price'] != null) _salePriceController.text = draft['sale_price'].toString();
      _applyThousandsFormat(_salePriceController);
      if (draft['address'] != null) _addressController.text = draft['address'];
      if (draft['area'] != null) _areaController.text = draft['area'].toString();
      if (draft['observations'] != null) _observationsController.text = draft['observations'];
      if (draft['building_date'] != null) _buildingDateController.text = draft['building_date'].toString();
      if (draft['service_room'] != null) {
        _serviceRoomController.text = draft['service_room'].toString();
      } else if (draft['_service_room_text'] != null) {
        _serviceRoomController.text = draft['_service_room_text'].toString();
      }
      if (draft['parking_lot'] != null) {
        _parkingLotController.text = draft['parking_lot'].toString();
      } else if (draft['_parking_lot_text'] != null) {
        _parkingLotController.text = draft['_parking_lot_text'].toString();
      }
      _selectedCityId = draft['id_city']?.toString();
      _selectedZoneId = draft['id_zone']?.toString();
      if (draft['id_property_condition'] != null) {
        final cond = draft['id_property_condition'].toString();
        if (_propertyConditions.any((c) => c['id'] == cond)) {
          _propertyConditionId = cond;
        }
      }
      if (draft['bedrooms'] != null) _bedrooms = draft['bedrooms'].toString();
      if (draft['bathrooms'] != null) _bathrooms = draft['bathrooms'].toString();
      if (draft['garages'] != null) _garages = draft['garages'].toString();
      if (draft['stratum'] != null) _stratum = draft['stratum'].toString();
      if (draft['features'] is List) {
        for (final dynamic item in (draft['features'] as List)) {
          if (item == null) continue;
          final id = item.toString().trim();
          if (id.isEmpty) continue;
          _selectedFeatureIds.add(id);
        }
      } else if (draft['features'] is String) {
        final ids = _extractFeatures(draft['features'].toString());
        for (final id in ids) {
          _selectedFeatureIds.add(id);
        }
      }

      if (draft['_internal_features_text'] != null) {
        _pendingFeatureNames.addAll(_extractFeatures(draft['_internal_features_text'].toString()));
      }
      if (draft['_external_features_text'] != null) {
        _pendingFeatureNames.addAll(_extractFeatures(draft['_external_features_text'].toString()));
      }
      if (draft['_prompts_text'] != null) {
        _promptsController.text = draft['_prompts_text'].toString();
      } else if (draft['prompts'] != null) {
        _promptsController.text = draft['prompts'].toString();
      }
      if (draft['_landlord_name_text'] != null) {
        _landlordNameController.text = draft['_landlord_name_text'].toString();
      } else if (draft['landlordName'] != null) {
        _landlordNameController.text = draft['landlordName'].toString();
      }
      final storedLandlordPhone = draft['_landlord_phone_text'] ?? draft['landlordPhone'];
      if (storedLandlordPhone != null) {
        _landlordPhoneController.text = _digitsOnly(storedLandlordPhone.toString());
      }
      if (draft['_keys_text'] != null) {
        _keysController.text = draft['_keys_text'].toString();
      } else if (draft['keys'] != null) {
        _keysController.text = draft['keys'].toString();
      }
      if (draft['_admin_mail_text'] != null) {
        _adminMailController.text = draft['_admin_mail_text'].toString();
      } else if (draft['adminMail'] != null) {
        _adminMailController.text = draft['adminMail'].toString();
      }
      final storedAdminPhone = draft['_admin_phone_text'] ?? draft['adminPhone'];
      if (storedAdminPhone != null) {
        _adminPhoneController.text = _digitsOnly(storedAdminPhone.toString());
      }
      final storedLodgePhone = draft['_lodge_phone_text'] ?? draft['lodgePhone'];
      if (storedLodgePhone != null) {
        _lodgePhoneController.text = _digitsOnly(storedLodgePhone.toString());
      }
      if (_keysController.text.trim().isEmpty) {
        _keysController.text = 'PORTERIA';
      }
      _loadPhotosFromDraft(draft);

      _hasVeredalWater = _parseBool(
        draft['agua_veredal'] ?? draft['_agua_veredal_bool'] ?? draft['aguaVeredal'],
      );
      _hasGasInstallation = _parseBool(
        draft['instalacion_gas_cubierta'] ??
            draft['_instalacion_gas_cubierta_bool'] ??
            draft['instalacionGasCubierta'],
      );
      _hasLegalizacionEpm = _parseBool(
        draft['legalizacion_epm'] ?? draft['_legalizacion_epm_bool'] ?? draft['legalizacionEpm'],
      );
      _hasInternetOperators = _parseBool(
        draft['operadores_internet'] ??
            draft['_operadores_internet_bool'] ??
            draft['operadoresInternet'],
      );
    }

  // Cargar perfil de usuario si existe
  await _loadUserProfile();

  // Cargar ciudades desde GlobalData si está inicializado, si no llamar API
    await _loadCities();

  // Cargar características disponibles en WASI
  await _loadFeatures();

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
        _cities = List<Map<String, dynamic>>.from(cached);
      } else {
        final api = WasiApiService(apiToken: AppConstants.wasiApiToken, companyId: AppConstants.wasiApiId);
        _cities = await api.getCities();
      }

      _cities = AppConstants.filterAllowedCities(_cities);

      if (_selectedCityId != null &&
          !_cities.any((city) => city['id']?.toString() == _selectedCityId)) {
        _selectedCityId = null;
        _selectedZoneId = null;
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

  Future<void> _loadFeatures() async {
    if (mounted) setState(() => _loadingFeatures = true);
    try {
      List<Map<String, dynamic>> rawFeatures = AppConstants.features;
      if (rawFeatures.isEmpty) {
        final api = WasiApiService(apiToken: AppConstants.wasiApiToken, companyId: AppConstants.wasiApiId);
        rawFeatures = await api.getFeatures();
      } else {
        rawFeatures = List<Map<String, dynamic>>.from(rawFeatures);
      }

      final normalized = rawFeatures
          .map((feature) {
            final id = feature['id']?.toString() ?? '';
            final name = (feature['name'] ?? feature['nombre'] ?? '').toString().trim();
            final category = (feature['category'] ?? feature['type'] ?? '').toString().toLowerCase();
            if (id.isEmpty || name.isEmpty) return null;
            return {
              'id': id,
              'name': name,
              'category': category,
            };
          })
          .whereType<Map<String, dynamic>>()
          .toList();

      _internalFeatures = normalized
          .where((feature) => feature['category'] == 'internal')
          .toList()
        ..sort(_compareFeaturesByName);

      _externalFeatures = normalized
          .where((feature) => feature['category'] == 'external')
          .toList()
        ..sort(_compareFeaturesByName);

      _otherFeatures = normalized
          .where((feature) => feature['category'] != 'internal' && feature['category'] != 'external')
          .toList()
        ..sort(_compareFeaturesByName);

      final validIds = normalized.map((feature) => feature['id'] as String).toSet();
      _selectedFeatureIds.removeWhere((id) => !validIds.contains(id));

      if (_pendingFeatureNames.isNotEmpty) {
        final nameToId = <String, String>{
          for (final feature in normalized)
            (feature['name'] as String).toLowerCase(): feature['id'] as String,
        };
        for (final name in _pendingFeatureNames) {
          final id = nameToId[name.toLowerCase()];
          if (id != null) {
            _selectedFeatureIds.add(id);
          }
        }
        _pendingFeatureNames.clear();
      }
    } catch (e) {
      debugPrint('Error cargando características: $e');
    } finally {
      if (mounted) setState(() => _loadingFeatures = false);
    }
  }

  Future<void> _loadUserProfile() async {
    final data = await CacheService.loadUserProfile();
    if (!mounted) return;
    if (data == null) {
      setState(() {
        _userFirstName = null;
        _userLastName = null;
        _userPhone = null;
      });
      return;
    }

    setState(() {
      _userFirstName = _normalizeProfileValue(data['first_name']);
      _userLastName = _normalizeProfileValue(data['last_name']);
      _userPhone = _normalizeProfileValue(data['phone']);
    });
  }

  void _loadPhotosFromDraft(Map<String, dynamic> draft) {
    _serviceRoomPhotoBytes = null;
    _serviceRoomPhotoFileName = null;
    _parkingLotPhotoBytes = null;
    _parkingLotPhotoFileName = null;
    _photos.clear();

    var restoredFromTuples = false;

    final tuplePairs = _extractPhotoPairs(draft['photos']);
    if (tuplePairs.isNotEmpty) {
      final base64List = <String>[];
      final nameList = <String>[];
      for (final pair in tuplePairs) {
        if (pair.isEmpty) continue;
        base64List.add(pair[0]);
        nameList.add(pair.length > 1 ? pair[1] : '');
      }
      if (base64List.isNotEmpty) {
        _addPhotosFromLists(base64List, nameList);
        restoredFromTuples = _photos.isNotEmpty;
      }
    }

    if (!restoredFromTuples) {
      final photosList = _extractStringList(
        draft['photos_base64'] ?? draft['photosBase64'],
      );
      final photoNamesList = _extractStringList(
        draft['photos_file_names'] ?? draft['photosFileNames'] ?? draft['photoFileNames'],
      );

      if (photosList.isNotEmpty) {
        _addPhotosFromLists(photosList, photoNamesList);
        restoredFromTuples = _photos.isNotEmpty;
      }
    }

    if (!restoredFromTuples) {
      final singlePhotoBase64 = draft['photo_base64'] ?? draft['photoBase64'];
      final storedPhotoName = draft['_photo_file_name'] ?? draft['photoFileName'];
      if (singlePhotoBase64 is String && singlePhotoBase64.isNotEmpty) {
        try {
          final bytes = base64Decode(singlePhotoBase64);
          final rawName = storedPhotoName is String ? storedPhotoName.trim() : '';
          final resolvedName = rawName.isEmpty ? 'foto_01.jpg' : rawName;
          if (_photos.length < _maxPhotoCount) {
            _photos.add(_ApartmentPhoto(bytes: bytes, fileName: resolvedName));
          }
        } catch (e) {
          debugPrint('Error decodificando foto principal del borrador: $e');
        }
      }
    }

    final legacyAdditionalBase64 = _extractStringList(
      draft['additional_photos_base64'] ?? draft['additionalPhotosBase64'],
    );
    final legacyAdditionalNames = _extractStringList(
      draft['additional_photo_names'] ?? draft['additionalPhotoNames'],
    );

    if (legacyAdditionalBase64.isNotEmpty) {
      _addPhotosFromLists(legacyAdditionalBase64, legacyAdditionalNames);
    }

    _ApartmentPhoto? decodeAuxPhoto({
      dynamic raw,
      dynamic legacyBase64,
      dynamic legacyFileName,
      required String fallbackName,
    }) {
      final photo = _decodeSinglePhoto(raw, fallbackName: fallbackName);
      if (photo != null) {
        return photo;
      }
      if (legacyBase64 is String && legacyBase64.isNotEmpty) {
        try {
          final bytes = base64Decode(legacyBase64);
          final rawName = legacyFileName?.toString() ?? '';
          final resolvedName = rawName.trim().isEmpty ? fallbackName : rawName.trim();
          return _ApartmentPhoto(bytes: bytes, fileName: resolvedName);
        } catch (e) {
          debugPrint('Error decodificando foto auxiliar (fallback $fallbackName): $e');
        }
      }
      return null;
    }

    final servicePhoto = decodeAuxPhoto(
      raw: draft['service_room_photo'],
      legacyBase64: draft['_service_room_photo_base64'] ?? draft['serviceRoomPhotoBase64'],
      legacyFileName: draft['_service_room_photo_file_name'] ?? draft['serviceRoomPhotoFileName'],
      fallbackName: 'cuarto_util.jpg',
    );
    if (servicePhoto != null) {
      _serviceRoomPhotoBytes = servicePhoto.bytes;
      _serviceRoomPhotoFileName = servicePhoto.fileName;
    }

    final parkingPhoto = decodeAuxPhoto(
      raw: draft['parking_lot_photo'],
      legacyBase64: draft['_parking_lot_photo_base64'] ?? draft['parkingLotPhotoBase64'],
      legacyFileName: draft['_parking_lot_photo_file_name'] ?? draft['parkingLotPhotoFileName'],
      fallbackName: 'parqueo.jpg',
    );
    if (parkingPhoto != null) {
      _parkingLotPhotoBytes = parkingPhoto.bytes;
      _parkingLotPhotoFileName = parkingPhoto.fileName;
    }
  }

  List<List<String>> _extractPhotoPairs(dynamic raw) {
    final pairs = <List<String>>[];
    if (raw is! List) {
      return pairs;
    }
    for (final item in raw) {
      String? base64;
      String name = '';
      if (item is List) {
        if (item.isNotEmpty && item[0] != null) {
          base64 = item[0].toString();
        }
        if (item.length > 1 && item[1] != null) {
          name = item[1].toString();
        }
      } else if (item is Map) {
        final base = item['base64'] ?? item['bytes'] ?? item['data'] ?? item['photo'];
        final nameCandidate = item['name'] ?? item['fileName'] ?? item['filename'] ?? item['title'];
        if (base != null) {
          base64 = base.toString();
        }
        if (nameCandidate != null) {
          name = nameCandidate.toString();
        }
      } else if (item != null) {
        base64 = item.toString();
      }
      if (base64 != null && base64.isNotEmpty) {
        pairs.add([base64, name]);
      }
    }
    return pairs;
  }

  List<String> _extractStringList(dynamic raw) {
    if (raw is List) {
      return raw.map((entry) => entry == null ? '' : entry.toString()).toList();
    }
    return <String>[];
  }

  void _addPhotosFromLists(List<String> base64List, List<String> nameList) {
    for (var i = 0; i < base64List.length && _photos.length < _maxPhotoCount; i++) {
      final encoded = base64List[i];
      if (encoded.isEmpty) {
        continue;
      }
      try {
        final bytes = base64Decode(encoded);
        final candidateName = (i < nameList.length) ? nameList[i].trim() : '';
        final resolvedName = candidateName.isEmpty
            ? 'foto_${(_photos.length + 1).toString().padLeft(2, '0')}.jpg'
            : candidateName;
        _photos.add(_ApartmentPhoto(bytes: bytes, fileName: resolvedName));
      } catch (e) {
        debugPrint('Error decodificando foto del borrador (índice $i): $e');
      }
    }
  }

  _ApartmentPhoto? _decodeSinglePhoto(dynamic raw, {required String fallbackName}) {
    if (raw == null) {
      return null;
    }

    String? base64Data;
    String? name;

    if (raw is List) {
      if (raw.isEmpty) {
        return null;
      }
      if (raw.length == 1 && raw.first is List) {
        final nested = raw.first as List;
        if (nested.isEmpty) return null;
        base64Data = nested.first?.toString();
        if (nested.length > 1) {
          name = nested[1]?.toString();
        }
      } else {
        base64Data = raw.first?.toString();
        if (raw.length > 1) {
          name = raw[1]?.toString();
        }
      }
    } else if (raw is Map) {
      final base = raw['base64'] ?? raw['bytes'] ?? raw['data'] ?? raw['photo'] ?? raw['value'];
      final nameCandidate = raw['name'] ?? raw['fileName'] ?? raw['filename'] ?? raw['title'];
      if (base != null) {
        base64Data = base.toString();
      }
      if (nameCandidate != null) {
        name = nameCandidate.toString();
      }
    } else if (raw is String) {
      base64Data = raw;
    }

    if (base64Data == null || base64Data.isEmpty) {
      return null;
    }

    try {
      final bytes = base64Decode(base64Data);
      final resolvedName = (name ?? '').trim().isEmpty ? fallbackName : name!.trim();
      return _ApartmentPhoto(bytes: bytes, fileName: resolvedName);
    } catch (e) {
      debugPrint('Error decodificando foto auxiliar: $e');
      return null;
    }
  }

  String? _normalizeProfileValue(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  int _compareFeaturesByName(Map<String, dynamic> a, Map<String, dynamic> b) {
    final nameA = _normalizeSortText(a['name']?.toString() ?? '');
    final nameB = _normalizeSortText(b['name']?.toString() ?? '');
    return nameA.compareTo(nameB);
  }

  String _normalizeSortText(String value) {
    final lower = value.toLowerCase();
    return lower
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('ä', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ë', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ì', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('î', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ò', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ù', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('û', 'u')
        .replaceAll('ñ', 'n')
        .replaceAll('ç', 'c');
  }

  Map<String, String> _featureIdToNameMap() {
    final map = <String, String>{};
    for (final feature in _internalFeatures) {
      final id = feature['id']?.toString();
      final name = feature['name']?.toString();
      if (id != null && name != null && id.isNotEmpty && name.isNotEmpty) {
        map[id] = name;
      }
    }
    for (final feature in _externalFeatures) {
      final id = feature['id']?.toString();
      final name = feature['name']?.toString();
      if (id != null && name != null && id.isNotEmpty && name.isNotEmpty) {
        map[id] = name;
      }
    }
    for (final feature in _otherFeatures) {
      final id = feature['id']?.toString();
      final name = feature['name']?.toString();
      if (id != null && name != null && id.isNotEmpty && name.isNotEmpty) {
        map[id] = name;
      }
    }
    return map;
  }

  List<String> _selectedFeatureNames() {
    final lookup = _featureIdToNameMap();
    final names = _selectedFeatureIds
        .map((id) => lookup[id])
        .whereType<String>()
        .toList();
    if (names.isEmpty && _pendingFeatureNames.isNotEmpty) {
      names.addAll(_pendingFeatureNames);
    }
    names.sort();
    return names;
  }

  String? _lookupNameById(List<Map<String, dynamic>> items, String? targetId) {
    if (targetId == null || targetId.isEmpty) {
      return null;
    }
    for (final item in items) {
      final id = item['id']?.toString();
      if (id == targetId) {
        final rawName = item['name'] ?? item['nombre'] ?? item['text'];
        if (rawName == null) {
          return null;
        }
        final name = rawName.toString().trim();
        return name.isEmpty ? null : name;
      }
    }
    return null;
  }

  List<List<String>> _selectedFeatureNameList() {
    final internalNames = <String>[];
    final externalNames = <String>[];

    final catalog = <String, Map<String, dynamic>>{};
    void collect(List<Map<String, dynamic>> source) {
      for (final feature in source) {
        final id = feature['id']?.toString();
        if (id == null || id.isEmpty) continue;
        catalog[id] = feature;
      }
    }

    collect(_internalFeatures);
    collect(_externalFeatures);
    collect(_otherFeatures);

    for (final id in _selectedFeatureIds) {
      final feature = catalog[id];
      if (feature == null) continue;
      final name = feature['name']?.toString().trim() ?? '';
      if (name.isEmpty) continue;
      final category = (feature['category'] ?? '').toString().toLowerCase();
      if (category == 'internal') {
        internalNames.add(name);
      } else {
        externalNames.add(name);
      }
    }

    if (internalNames.isEmpty && externalNames.isEmpty && _pendingFeatureNames.isNotEmpty) {
      final pending = _pendingFeatureNames.toList();
      pending.sort((a, b) => _normalizeSortText(a).compareTo(_normalizeSortText(b)));
      return [pending, <String>[]];
    }

    int compareByNormalizedText(String a, String b) {
      return _normalizeSortText(a).compareTo(_normalizeSortText(b));
    }

    internalNames.sort(compareByNormalizedText);
    externalNames.sort(compareByNormalizedText);

    return [internalNames, externalNames];
  }

  String get _featureSummaryText {
    if (_selectedFeatureIds.isEmpty) {
      return 'No hay características seleccionadas';
    }
    final names = _selectedFeatureNames();
    if (names.isEmpty) {
      return 'Seleccionadas: ${_selectedFeatureIds.length}';
    }
    if (names.length <= 3) {
      return 'Seleccionadas: ${names.join(', ')}';
    }
    final remaining = names.length - 3;
    return 'Seleccionadas: ${names.take(3).join(', ')} y $remaining más';
  }

  Future<void> _openFeatureSelector() async {
    if (_loadingFeatures) return;

    if (_internalFeatures.isEmpty &&
        _externalFeatures.isEmpty &&
        _otherFeatures.isEmpty) {
      await _loadFeatures();
      if (!mounted || (_internalFeatures.isEmpty && _externalFeatures.isEmpty && _otherFeatures.isEmpty)) {
        return;
      }
    }

    final result = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) {
        final tempSelected = Set<String>.from(_selectedFeatureIds);

        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            Widget buildCategory(String title, List<Map<String, dynamic>> features) {
              if (features.isEmpty) {
                return const SizedBox.shrink();
              }
              return ExpansionTile(
                key: PageStorageKey<String>('feature_$title'),
                initiallyExpanded: true,
                title: Text('$title (${features.length})'),
                children: features.map((feature) {
                  final id = feature['id']?.toString();
                  final name = feature['name']?.toString() ?? '';
                  if (id == null || id.isEmpty || name.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  final isSelected = tempSelected.contains(id);
                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (checked) {
                      setStateDialog(() {
                        if (checked == true) {
                          tempSelected.add(id);
                        } else {
                          tempSelected.remove(id);
                        }
                      });
                    },
                    title: Text(name),
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                }).toList(),
              );
            }

            return AlertDialog(
              title: const Text('Seleccionar características'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_internalFeatures.isNotEmpty)
                        buildCategory('Internas', _internalFeatures),
                      if (_externalFeatures.isNotEmpty)
                        buildCategory('Externas', _externalFeatures),
                      if (_otherFeatures.isNotEmpty)
                        buildCategory('Otras', _otherFeatures),
                      if (_internalFeatures.isEmpty &&
                          _externalFeatures.isEmpty &&
                          _otherFeatures.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('No se encontraron características disponibles.'),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop<Set<String>>(null),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop<Set<String>>(Set<String>.from(tempSelected)),
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted) return;
    if (result != null) {
      setState(() {
        _selectedFeatureIds
          ..clear()
          ..addAll(result);
      });
      await _autoSave();
    }
  }

  void _showSnackBarMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showInvalidImageFormatMessage() {
    _showSnackBarMessage('Formato de imagen no permitido. Usa archivos PNG, JPG, JPEG o GIF.');
  }

  List<String>? _buildSinglePhotoTuple(Uint8List? bytes, String? fileName, String fallbackName) {
    if (bytes == null) {
      return null;
    }
    final resolvedName = (fileName ?? '').trim().isEmpty ? fallbackName : fileName!.trim();
    return [base64Encode(bytes), resolvedName];
  }

  List<List<String>> _buildPhotoTuples() {
    final tuples = <List<String>>[];
    for (var i = 0; i < _photos.length && i < _maxPhotoCount; i++) {
      final photo = _photos[i];
      final fallbackName = 'foto_${(i + 1).toString().padLeft(2, '0')}.jpg';
      final name = photo.fileName.trim().isNotEmpty ? photo.fileName.trim() : fallbackName;
      tuples.add([base64Encode(photo.bytes), name]);
    }
    return tuples;
  }

  Future<_ApartmentPhoto?> _readPhotoFromXFile(XFile file) async {
    final nameOrPath = file.name.isNotEmpty ? file.name : file.path;
    final extension = p.extension(nameOrPath).replaceFirst('.', '').toLowerCase();
    if (extension.isEmpty || !_allowedImageExtensions.contains(extension)) {
      _showInvalidImageFormatMessage();
      return null;
    }
    try {
      final bytes = await file.readAsBytes();
      final resolvedName = file.name.isNotEmpty ? file.name : p.basename(nameOrPath);
      return _ApartmentPhoto(bytes: bytes, fileName: resolvedName);
    } catch (e) {
      debugPrint('Error leyendo imagen: $e');
      _showSnackBarMessage('No se pudo cargar la imagen seleccionada.');
      return null;
    }
  }

  Future<void> _pickServiceRoomPhoto() async {
    try {
      final XFile? file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (file == null) return;
      final photo = await _readPhotoFromXFile(file);
      if (photo == null || !mounted) return;
      setState(() {
        _serviceRoomPhotoBytes = photo.bytes;
        _serviceRoomPhotoFileName = photo.fileName;
      });
      await _autoSave();
    } catch (e) {
      debugPrint('Error seleccionando foto de cuarto útil: $e');
    }
  }

  Future<void> _pickParkingLotPhoto() async {
    try {
      final XFile? file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (file == null) return;
      final photo = await _readPhotoFromXFile(file);
      if (photo == null || !mounted) return;
      setState(() {
        _parkingLotPhotoBytes = photo.bytes;
        _parkingLotPhotoFileName = photo.fileName;
      });
      await _autoSave();
    } catch (e) {
      debugPrint('Error seleccionando foto de parqueo: $e');
    }
  }

  int get _remainingPhotoSlots {
    final remaining = _maxPhotoCount - _photos.length;
    return remaining < 0 ? 0 : remaining;
  }

  Future<int> _pickPhotos() async {
    final remaining = _remainingPhotoSlots;
    if (remaining <= 0) {
      _showSnackBarMessage('Ya se cargaron las $_maxPhotoCount fotos permitidas.');
      return 0;
    }

    List<XFile> files;
    try {
      files = await _imagePicker.pickMultiImage(
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
    } catch (e) {
      debugPrint('Error abriendo selector múltiple de imágenes: $e');
      _showSnackBarMessage('No se pudo abrir el selector de imágenes.');
      return 0;
    }

    if (files.isEmpty) {
      return 0;
    }

    final limitApplied = files.length > remaining;
    final newPhotos = <_ApartmentPhoto>[];
    for (final file in files.take(remaining)) {
      final photo = await _readPhotoFromXFile(file);
      if (photo != null) {
        newPhotos.add(photo);
      }
    }

    if (newPhotos.isEmpty || !mounted) {
      if (limitApplied) {
        _showSnackBarMessage('Se alcanzó el máximo de fotos permitidas.');
      }
      return 0;
    }

    setState(() {
      _photos.addAll(newPhotos);
    });
    await _autoSave();

    if (limitApplied) {
      _showSnackBarMessage('Solo se agregaron ${newPhotos.length} fotos (límite alcanzado).');
    }

    return newPhotos.length;
  }

  Future<void> _removePhotoAt(int index) async {
    if (index < 0 || index >= _photos.length) return;
    setState(() {
      _photos.removeAt(index);
    });
    await _autoSave();
  }

  Future<void> _openPhotosManager() async {
    if (_isSubmitting) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setStateSheet) {
            Future<void> handleAddPhotos() async {
              final added = await _pickPhotos();
              if (added > 0) {
                setStateSheet(() {});
              }
            }

            Future<void> handleRemovePhoto(int index) async {
              await _removePhotoAt(index);
              setStateSheet(() {});
            }

            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.6,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Fotos del apartamento',
                            style: Theme.of(ctx).textTheme.titleMedium,
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: 'Cerrar',
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Agregar fotos'),
                        onPressed: _remainingPhotoSlots <= 0 ? null : handleAddPhotos,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Fotos cargadas: ${_photos.length} de $_maxPhotoCount',
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _photos.isEmpty
                            ? const Center(
                                child: Text('No se han agregado fotos.'),
                              )
                            : GridView.builder(
                                itemCount: _photos.length,
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                ),
                                itemBuilder: (gridContext, index) {
                                  final photo = _photos[index];
                                  return Stack(
                                    children: [
                                      Positioned.fill(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.memory(
                                            photo.bytes,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: InkWell(
                                          onTap: () => handleRemovePhoto(index),
                                          child: Container(
                                            decoration: const BoxDecoration(
                                              color: Colors.black54,
                                              shape: BoxShape.circle,
                                            ),
                                            padding: const EdgeInsets.all(4),
                                            child: const Icon(
                                              Icons.close,
                                              size: 16,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        left: 4,
                                        right: 4,
                                        bottom: 4,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.5),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            photo.fileName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(color: Colors.white, fontSize: 10),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _resetFormState() {
    _formKey.currentState?.reset();
    _apartmentNumberController.clear();
    _unitNameController.clear();
    _rentPriceController.clear();
    _salePriceController.clear();
    _addressController.clear();
    _areaController.clear();
    _observationsController.clear();
    _buildingDateController.clear();
    _serviceRoomController.clear();
    _parkingLotController.clear();
    _promptsController.clear();
    _landlordNameController.clear();
    _landlordPhoneController.clear();
    _keysController.text = 'PORTERIA';
    _adminMailController.clear();
    _adminPhoneController.clear();
    _lodgePhoneController.clear();
    _selectedFeatureIds.clear();
    _pendingFeatureNames.clear();
    _selectedCityId = null;
    _selectedZoneId = null;
    _operation = 'alquiler';
  _statusOnPageId = '1';
    _propertyConditionId = '1';
    _bedrooms = '1';
    _bathrooms = '1';
    _garages = '0';
    _stratum = '3';
  _hasVeredalWater = false;
  _hasGasInstallation = false;
  _hasLegalizacionEpm = false;
  _hasInternetOperators = false;
    _serviceRoomPhotoBytes = null;
    _serviceRoomPhotoFileName = null;
    _parkingLotPhotoBytes = null;
    _parkingLotPhotoFileName = null;
    _photos.clear();
    _lastSaved = null;
  }

  Future<void> _confirmClearDraft() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Eliminar borrador'),
          content: const Text('¿Desea eliminar el borrador actual? Esta acción es irreversible.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (shouldClear != true) return;

    await CacheService.clearAddApartmentDraft();
    if (!mounted) return;

    setState(() {
      _resetFormState();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Borrador eliminado.')),
    );
  }

  Future<void> _autoSave() async {
    if (!mounted) return;
    // No guardar si formulario está completamente vacío
  if (_apartmentNumberController.text.isEmpty &&
    _unitNameController.text.isEmpty &&
        _rentPriceController.text.isEmpty &&
        _salePriceController.text.isEmpty &&
        _addressController.text.isEmpty &&
        _selectedCityId == null &&
        _serviceRoomController.text.isEmpty &&
        _parkingLotController.text.isEmpty &&
        _selectedFeatureIds.isEmpty &&
        _promptsController.text.isEmpty &&
        _landlordNameController.text.isEmpty &&
        _landlordPhoneController.text.isEmpty &&
        (_keysController.text.trim().isEmpty || _keysController.text.trim().toUpperCase() == 'PORTERIA') &&
  _adminMailController.text.isEmpty &&
  _adminPhoneController.text.isEmpty &&
  _lodgePhoneController.text.isEmpty &&
  _photos.isEmpty &&
        !_hasVeredalWater &&
        !_hasGasInstallation &&
        !_hasLegalizacionEpm &&
        !_hasInternetOperators &&
        _serviceRoomPhotoBytes == null &&
        _parkingLotPhotoBytes == null) {
      return;
    }
    final photoTuples = _buildPhotoTuples();
    final serviceRoomPhotoBase64 =
        _serviceRoomPhotoBytes == null ? null : base64Encode(_serviceRoomPhotoBytes!);
    final parkingLotPhotoBase64 =
        _parkingLotPhotoBytes == null ? null : base64Encode(_parkingLotPhotoBytes!);
    final data = {
      ..._currentData(),
      '_apartment_number_text': _digitsOnly(_apartmentNumberController.text),
      '_unit_name_text': _unitNameController.text,
      '_service_room_text': _serviceRoomController.text,
      '_parking_lot_text': _parkingLotController.text,
      '_prompts_text': _promptsController.text,
      '_landlord_name_text': _landlordNameController.text,
      '_landlord_phone_text': _digitsOnly(_landlordPhoneController.text),
      '_keys_text': _keysController.text,
      '_admin_mail_text': _adminMailController.text,
      '_admin_phone_text': _digitsOnly(_adminPhoneController.text),
      '_lodge_phone_text': _digitsOnly(_lodgePhoneController.text),
      'photos': photoTuples,
      '_service_room_photo_file_name': _serviceRoomPhotoFileName,
      '_parking_lot_photo_file_name': _parkingLotPhotoFileName,
      '_service_room_photo_base64': serviceRoomPhotoBase64,
      '_parking_lot_photo_base64': parkingLotPhotoBase64,
    };
    _saving = true;
    await CacheService.saveAddApartmentDraft(data);
    _lastSaved = DateTime.now();
    if (mounted) setState(() => _saving = false);
  }

  String _numericString(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^0-9.,]'), '').replaceAll(',', '');
    return cleaned;
  }

  String _digitsOnly(String value, {int? maxLength}) {
    var digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (maxLength != null && digits.length > maxLength) {
      digits = digits.substring(0, maxLength);
    }
    return digits;
  }

  void _applyThousandsFormat(TextEditingController controller) {
    final digits = _digitsOnly(controller.text);
    if (digits.isEmpty) {
      controller.value = const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
      return;
    }
    final formatted = _formatWithThousandsSeparator(digits);
    controller.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  List<String> _extractFeatures(String raw) {
    return raw
        .split(RegExp(r'[\n,;]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  bool _parseBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final text = value.trim().toLowerCase();
      if (text.isEmpty) return false;
      return text == 'true' || text == '1' || text == 'si' || text == 'yes';
    }
    return false;
  }

  Map<String, dynamic> _currentData() {
    final isForRent = _operation == 'alquiler';
  final rentPrice = _digitsOnly(_rentPriceController.text);
  final salePrice = _digitsOnly(_salePriceController.text);
    final area = _numericString(_areaController.text);
    final buildingDate = _digitsOnly(_buildingDateController.text, maxLength: 4);
  final apartmentNumber = _digitsOnly(_apartmentNumberController.text);
    final unitName = _unitNameController.text.trim();
    final address = _addressController.text.trim();
    final comment = _observationsController.text.trim();
    final serviceRoom = _serviceRoomController.text.trim();
    final parkingLot = _parkingLotController.text.trim();
    final featureIds = _selectedFeatureIds
        .map((id) => int.tryParse(id))
        .whereType<int>()
        .toList()
      ..sort();
    final featureNameList = _selectedFeatureNameList();
    final cityName = _lookupNameById(_cities, _selectedCityId);
    final zoneName = _lookupNameById(_zones, _selectedZoneId);
  final serviceRoomPhotoTuple =
    _buildSinglePhotoTuple(_serviceRoomPhotoBytes, _serviceRoomPhotoFileName, 'cuarto_util.jpg');
  final parkingLotPhotoTuple =
    _buildSinglePhotoTuple(_parkingLotPhotoBytes, _parkingLotPhotoFileName, 'parqueo.jpg');
    final prompts = _promptsController.text.trim();
    final landlordName = _landlordNameController.text.trim();
    final landlordPhone = _digitsOnly(_landlordPhoneController.text);
    final keysRaw = _keysController.text.trim();
    final keys = keysRaw.isEmpty ? 'PORTERIA' : keysRaw;
    final adminMail = _adminMailController.text.trim();
    final adminPhone = _digitsOnly(_adminPhoneController.text);
    final lodgePhone = _digitsOnly(_lodgePhoneController.text);
    final photoTuples = _buildPhotoTuples();

    final List<String> titleParts = [];
    if (apartmentNumber.isNotEmpty) titleParts.add(apartmentNumber);
    if (unitName.isNotEmpty) titleParts.add(unitName);
    final computedTitle = titleParts.join(' ');
    final effectiveTitle = computedTitle.isEmpty ? 'Apartamento sin título' : computedTitle;
    return {
      // Fijos / derivables
      'id_company': AppConstants.wasiApiId,
      'id_user': _fixedUserId,
      'id_property_type': _fixedPropertyTypeId,
      'id_country': _fixedCountryId,
      'id_region': _fixedRegionId,
      'id_availability': '1',   // Fijo según requerimiento (Disponible)
      'id_publish_on_map': '2', // Fijo según requerimiento
      'title': 'Apartamento en ${cityName ?? 'Medellin'}',
      'registration_number': effectiveTitle,
      'portals': <String>[], // Fijo según requerimiento (Portal Inmuebles24)
      // Dinámicos
      'id_status_on_page': _statusOnPageId,
      'id_property_condition': _propertyConditionId,
      'id_city': _selectedCityId,
      'id_zone': _selectedZoneId,
  'city_name': cityName,
  'zone_name': zoneName,
      'reference': effectiveTitle,
      'comment': comment,
      'for_rent': isForRent,
      'for_sale': !isForRent,
      'rent_price': rentPrice.isEmpty ? null : rentPrice,
      'sale_price': salePrice.isEmpty ? null : salePrice,
      'address': address,
      'area': area,
      'built_area': area,
      'private_area': area,
      'bedrooms': _bedrooms,
      'bathrooms': _bathrooms,
      'garages': _garages,
      'stratum': _stratum,
      'observations': 'Apartamento en ${cityName ?? 'Medellin'}',
      'building_date': buildingDate,
      'service_room': serviceRoom.isEmpty ? null : serviceRoom,
    'service_room_photo': serviceRoomPhotoTuple,
      'parking_lot': parkingLot.isEmpty ? null : parkingLot,
    'parking_lot_photo': parkingLotPhotoTuple,
  'features': featureIds,
  'featureNameList': featureNameList,
    'agua_veredal': _hasVeredalWater,
    'instalacion_gas_cubierta': _hasGasInstallation,
    'legalizacion_epm': _hasLegalizacionEpm,
    'operadores_internet': _hasInternetOperators,
      'prompts': prompts.isEmpty ? null : prompts,
    'apartment_number': apartmentNumber.isEmpty ? null : apartmentNumber,
    'unit_name': unitName.isEmpty ? null : unitName,
      'user_first_name': _userFirstName,
      'user_last_name': _userLastName,
      'user_phone': _userPhone,
      'landlordName': landlordName.isEmpty ? null : landlordName,
      'landlordPhone': landlordPhone.isEmpty ? null : landlordPhone,
      'keys': keys,
      'adminMail': adminMail.isEmpty ? null : adminMail,
      'adminPhone': adminPhone.isEmpty ? null : adminPhone,
  'lodgePhone': lodgePhone.isEmpty ? null : lodgePhone,
  'photos': photoTuples,
      // Metadatos
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  Future<void> _onSavePressed() async {
    if (!_formKey.currentState!.validate()) return;
    if (_photos.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Agrega al menos una foto del apartamento.')));
      return;
    }
    if (_userFirstName == null || _userFirstName!.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Completa los datos del asesor antes de captar.')));
      return;
    }
    if (_selectedCityId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seleccione una ciudad')));
      return;
    }
    final data = _currentData();

    setState(() => _isSubmitting = true);

    try {
      final result = await _sendToWebhook(data);
      if (!result.success) {
        if (!mounted) return;
        final message = result.isConnectionError
            ? 'No se pudo enviar la información. Verifique su conexión a internet.'
            : (result.message ?? 'No se pudo enviar la información al webhook. Intente nuevamente.');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Datos enviados correctamente.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      } else {
        _isSubmitting = false;
      }
    }
  }

  Future<_WebhookResult> _sendToWebhook(Map<String, dynamic> data) async {
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      final response = await dio.post(_webhookUrl, data: data);
      final status = response.statusCode ?? 0;
      if (status >= 200 && status < 300) {
        return const _WebhookResult(success: true);
      }

      debugPrint('Webhook responded with status $status: ${response.data}');
      return _WebhookResult(
        success: false,
        message: 'El servidor respondió con un estado inesperado ($status).',
      );
    } on DioException catch (dioError, stackTrace) {
      debugPrint('Error enviando al webhook: $dioError');
      debugPrint(stackTrace.toString());
      final isConnectionError = dioError.type == DioExceptionType.connectionTimeout ||
          dioError.type == DioExceptionType.sendTimeout ||
          dioError.type == DioExceptionType.receiveTimeout ||
      dioError.type == DioExceptionType.connectionError ||
      dioError.type == DioExceptionType.badCertificate ||
          dioError.type == DioExceptionType.unknown;
      return _WebhookResult(
        success: false,
        isConnectionError: isConnectionError,
        message: dioError.message ?? dioError.error?.toString() ?? 'Ocurrió un error enviando la información.',
      );
    } catch (e, stackTrace) {
      debugPrint('Error enviando al webhook: $e');
      debugPrint(stackTrace.toString());
      return _WebhookResult(
        success: false,
        message: e.toString(),
      );
    }
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
  _apartmentNumberController.dispose();
  _unitNameController.dispose();
    _rentPriceController.dispose();
    _salePriceController.dispose();
    _addressController.dispose();
    _areaController.dispose();
    _observationsController.dispose();
    _buildingDateController.dispose();
    _serviceRoomController.dispose();
    _parkingLotController.dispose();
    _promptsController.dispose();
    _landlordNameController.dispose();
    _landlordPhoneController.dispose();
    _keysController.dispose();
    _adminMailController.dispose();
    _adminPhoneController.dispose();
    _lodgePhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo Apartamento (WASI)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: 'Eliminar borrador',
            onPressed: (_saving || _isSubmitting) ? null : _confirmClearDraft,
          ),
          if (_saving || _isSubmitting)
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
                        controller: _apartmentNumberController,
                        decoration: const InputDecoration(
                          labelText: 'Número de apartamento',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: (v) {
                          final digits = _digitsOnly(v ?? '');
                          if (digits.isEmpty) {
                            return 'Ingrese el número de apartamento';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _unitNameController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre de la unidad',
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Ingrese el nombre de la unidad';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Tipo de negocio',
                                border: OutlineInputBorder(),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isDense: true,
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
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Disponibilidad',
                                border: OutlineInputBorder(),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isDense: true,
                                  value: _statusOnPageId,
                                  items: _statusOptions
                                      .map(
                                        (option) => DropdownMenuItem<String>(
                                          value: option['id'],
                                          child: Text(option['label'] ?? ''),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setState(() => _statusOnPageId = value);
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Condición de la propiedad',
                                border: OutlineInputBorder(),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isDense: true,
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
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _buildingDateController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Año de construcción',
                                border: OutlineInputBorder(),
                                hintText: 'Ej: 2015',
                              ),
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              validator: (v) {
                                final raw = (v ?? '').trim();
                                if (raw.isEmpty) return 'Ingrese el año de construcción';
                                final digits = _digitsOnly(raw, maxLength: 4);
                                if (digits.length != 4) return 'Ingrese un año válido (4 dígitos)';
                                return null;
                              },
                            ),
                          ),
                        ],
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
                                  isDense: true,
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
                      Row(
                        children: [
                          Expanded(
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Zona / Barrio',
                                border: OutlineInputBorder(),
                              ),
                              child: (_selectedCityId == null)
                                  ? const Text('Seleccione primero una ciudad')
                                  : _loadingZones
                                      ? const SizedBox(
                                          height: 40,
                                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                        )
                                      : DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            isDense: true,
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
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _stratum,
                              decoration: const InputDecoration(
                                labelText: 'Estrato',
                                border: OutlineInputBorder(),
                              ),
                              isExpanded: true,
                              items: List.generate(6, (index) {
                                final value = (index + 1).toString();
                                return DropdownMenuItem(value: value, child: Text(value));
                              }),
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _stratum = value);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(
                          labelText: 'Dirección',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingrese la dirección' : null,
                      ),
                      const SizedBox(height: 16),
                      // Precios
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _rentPriceController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Precio arriendo',
                                border: OutlineInputBorder(),
                              ),
                              inputFormatters: const [_ThousandsSeparatorFormatter()],
                              validator: (v) {
                                final digits = _digitsOnly(v ?? '');
                                if (_operation == 'alquiler' && digits.isEmpty) {
                                  return 'Ingrese el precio de arriendo';
                                }
                                if (digits.isEmpty && (v ?? '').trim().isNotEmpty) {
                                  return 'Solo números';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _salePriceController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Precio venta',
                                border: OutlineInputBorder(),
                              ),
                              inputFormatters: const [_ThousandsSeparatorFormatter()],
                              validator: (v) {
                                final digits = _digitsOnly(v ?? '');
                                if (_operation == 'venta' && digits.isEmpty) {
                                  return 'Ingrese el precio de venta';
                                }
                                if (digits.isEmpty && (v ?? '').trim().isNotEmpty) {
                                  return 'Solo números';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _bedrooms,
                              decoration: const InputDecoration(
                                labelText: 'Habitaciones',
                                border: OutlineInputBorder(),
                              ),
                              isExpanded: true,
                              items: List.generate(10, (index) {
                                final value = (index + 1).toString();
                                return DropdownMenuItem(value: value, child: Text(value));
                              }),
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _bedrooms = value);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _bathrooms,
                              decoration: const InputDecoration(
                                labelText: 'Baños',
                                border: OutlineInputBorder(),
                              ),
                              isExpanded: true,
                              items: List.generate(10, (index) {
                                final value = (index + 1).toString();
                                return DropdownMenuItem(value: value, child: Text(value));
                              }),
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _bathrooms = value);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _garages,
                              decoration: const InputDecoration(
                                labelText: 'Parqueaderos',
                                border: OutlineInputBorder(),
                              ),
                              isExpanded: true,
                              items: List.generate(10, (index) {
                                final value = index.toString();
                                return DropdownMenuItem(value: value, child: Text(value));
                              }),
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _garages = value);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _areaController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Área (m²)',
                                border: OutlineInputBorder(),
                              ),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                              validator: (v) {
                                final numeric = _numericString(v ?? '');
                                if (numeric.isEmpty) return 'Ingrese el área';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_loadingFeatures)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else ...[
                        OutlinedButton.icon(
                          icon: const Icon(Icons.list_alt),
                          label: const Text('Seleccionar características'),
                          onPressed: _openFeatureSelector,
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _featureSummaryText,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        if (_internalFeatures.isEmpty &&
                            _externalFeatures.isEmpty &&
                            _otherFeatures.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 8.0),
                            child: Text('No se encontraron características disponibles.'),
                          ),
                        if (_selectedFeatureIds.isNotEmpty)
                          TextButton(
                            onPressed: () async {
                              setState(() {
                                _selectedFeatureIds.clear();
                              });
                              await _autoSave();
                            },
                            child: const Text('Limpiar selección'),
                          ),
                      ],
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _promptsController,
                        decoration: const InputDecoration(
                          labelText: 'Prompts / Descripciones adicionales para IA',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 4,
                      ),
                      const SizedBox(height: 16),
                      if (_photos.isNotEmpty) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: AspectRatio(
                            aspectRatio: 4 / 3,
                            child: Image.memory(
                              _photos.first.bytes,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        if (_photos.first.fileName.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _photos.first.fileName,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        const SizedBox(height: 16),
                      ] else ...[
                        const Text(
                          'Añade al menos una foto desde el gestor para continuar.',
                          style: TextStyle(fontStyle: FontStyle.italic),
                        ),
                        const SizedBox(height: 16),
                      ],
                      OutlinedButton.icon(
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Fotos del apartamento'),
                        onPressed: _isSubmitting ? null : _openPhotosManager,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Fotos cargadas: ${_photos.length} de $_maxPhotoCount',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 24),
                      const Divider(),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Datos privados de la compañía',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextFormField(
                                  controller: _serviceRoomController,
                                  decoration: const InputDecoration(
                                    labelText: 'Cuarto útil',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  icon: Icon(
                                    _serviceRoomPhotoBytes == null
                                        ? Icons.add_a_photo
                                        : Icons.check_circle,
                                  ),
                                  label: Text(
                                    _serviceRoomPhotoBytes == null
                                        ? 'Agregar foto cuarto útil'
                                        : 'Cambiar foto cuarto útil',
                                  ),
                                  onPressed: _isSubmitting ? null : _pickServiceRoomPhoto,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _serviceRoomPhotoBytes == null
                                      ? 'Sin foto cargada'
                                      : 'Foto cargada: ${(_serviceRoomPhotoFileName ?? 'cuarto_util.jpg')}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextFormField(
                                  controller: _parkingLotController,
                                  decoration: const InputDecoration(
                                    labelText: 'Número parqueo',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  icon: Icon(
                                    _parkingLotPhotoBytes == null
                                        ? Icons.add_a_photo
                                        : Icons.check_circle,
                                  ),
                                  label: Text(
                                    _parkingLotPhotoBytes == null
                                        ? 'Agregar foto parqueo'
                                        : 'Cambiar foto parqueo',
                                  ),
                                  onPressed: _isSubmitting ? null : _pickParkingLotPhoto,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _parkingLotPhotoBytes == null
                                      ? 'Sin foto cargada'
                                      : 'Foto cargada: ${(_parkingLotPhotoFileName ?? 'parqueo.jpg')}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _observationsController,
                        decoration: const InputDecoration(
                          labelText: 'Observaciones / Comentarios internos',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 4,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: CheckboxListTile(
                              value: _hasVeredalWater,
                              onChanged: _isSubmitting
                                  ? null
                                  : (checked) {
                                      setState(() {
                                        _hasVeredalWater = checked ?? false;
                                      });
                                      _autoSave();
                                    },
                              title: const Text('Agua veredal'),
                              controlAffinity: ListTileControlAffinity.leading,
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CheckboxListTile(
                              value: _hasGasInstallation,
                              onChanged: _isSubmitting
                                  ? null
                                  : (checked) {
                                      setState(() {
                                        _hasGasInstallation = checked ?? false;
                                      });
                                      _autoSave();
                                    },
                              title: const Text('Instalación gas cubierta'),
                              controlAffinity: ListTileControlAffinity.leading,
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: CheckboxListTile(
                              value: _hasLegalizacionEpm,
                              onChanged: _isSubmitting
                                  ? null
                                  : (checked) {
                                      setState(() {
                                        _hasLegalizacionEpm = checked ?? false;
                                      });
                                      _autoSave();
                                    },
                              title: const Text('Legalización EPM'),
                              controlAffinity: ListTileControlAffinity.leading,
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CheckboxListTile(
                              value: _hasInternetOperators,
                              onChanged: _isSubmitting
                                  ? null
                                  : (checked) {
                                      setState(() {
                                        _hasInternetOperators = checked ?? false;
                                      });
                                      _autoSave();
                                    },
                              title: const Text('Operadores de internet'),
                              controlAffinity: ListTileControlAffinity.leading,
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _landlordNameController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre propietario',
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _landlordPhoneController,
                        decoration: const InputDecoration(
                          labelText: 'Celular propietario',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.phone,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _keysController,
                        decoration: const InputDecoration(
                          labelText: 'Llaves',
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _adminMailController,
                        decoration: const InputDecoration(
                          labelText: 'Correo Admin',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _adminPhoneController,
                        decoration: const InputDecoration(
                          labelText: 'Celular Admin',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.phone,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _lodgePhoneController,
                        decoration: const InputDecoration(
                          labelText: 'Celular Porteria',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.phone,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.save),
                          label: const Text('Captar!'),
                          onPressed: _isSubmitting ? null : _onSavePressed,
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

