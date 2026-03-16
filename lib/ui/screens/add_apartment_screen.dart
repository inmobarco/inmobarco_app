import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/cache_service.dart';
import '../../../data/services/wasi_api_service.dart';
import '../../../data/services/webhook_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/global_data_service.dart';
import '../../../domain/models/apartment_photo.dart';
import '../../../core/utils/formatters.dart';
import '../widgets/add_apartment/basic_info_section.dart';
import '../widgets/add_apartment/location_section.dart';
import '../widgets/add_apartment/pricing_section.dart';
import '../widgets/add_apartment/features_section.dart';
import '../widgets/add_apartment/photos_section.dart';
import '../widgets/add_apartment/private_data_section.dart';

class AddApartmentScreen extends StatefulWidget {
  const AddApartmentScreen({super.key});

  @override
  State<AddApartmentScreen> createState() => _AddApartmentScreenState();
}

class _AddApartmentScreenState extends State<AddApartmentScreen> {
  late final GlobalDataService _globalData;
  late final CacheService _cacheService;
  final _formKey = GlobalKey<FormState>();

  // ── Text controllers ──────────────────────────────────────────────────
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
  final _porterNameController = TextEditingController();
  final _porterPhoneController = TextEditingController();

  // ── Photo state ───────────────────────────────────────────────────────
  final ImagePicker _imagePicker = ImagePicker();
  Uint8List? _serviceRoomPhotoBytes;
  String? _serviceRoomPhotoFileName;
  Uint8List? _parkingLotPhotoBytes;
  String? _parkingLotPhotoFileName;
  final List<ApartmentPhoto> _photos = <ApartmentPhoto>[];

  // ── Feature state ─────────────────────────────────────────────────────
  final Set<String> _selectedFeatureIds = <String>{};
  final Set<String> _pendingFeatureNames = <String>{};
  List<Map<String, dynamic>> _internalFeatures = [];
  List<Map<String, dynamic>> _externalFeatures = [];
  List<Map<String, dynamic>> _otherFeatures = [];
  bool _loadingFeatures = false;

  // ── Boolean toggles ───────────────────────────────────────────────────
  bool _hasVeredalWater = false;
  bool _hasGasInstallation = false;
  bool _hasLegalizacionEpm = false;
  bool _hasInternetOperators = false;

  // ── Dropdown state ────────────────────────────────────────────────────
  String _operation = 'alquiler';
  String _statusOnPageId = '1';
  String _propertyConditionId = '1';
  String _bedrooms = '1';
  String _bathrooms = '1';
  String _garages = '0';
  String _stratum = '3';

  // ── City / Zone ───────────────────────────────────────────────────────
  String? _selectedCityId;
  String? _selectedZoneId;
  List<Map<String, dynamic>> _cities = [];
  List<Map<String, dynamic>> _zones = [];
  bool _loadingCities = false;
  bool _loadingZones = false;

  // ── Residential complex ───────────────────────────────────────────────
  List<Map<String, dynamic>> _residentialComplexes = [];
  Map<String, dynamic>? _selectedComplex;
  bool _isManualUnitName = false;
  bool _fieldsLockedByComplex = false;
  int? _selectedComplexId;
  double? _selectedLatitude;
  double? _selectedLongitude;
  bool _unitNameHasError = false;

  // ── Timers / submission ───────────────────────────────────────────────
  Timer? _autoSaveTimer;
  bool _loadingDraft = true;
  bool _saving = false;
  bool _isSubmitting = false;
  DateTime? _lastSaved;
  bool _cooldownActive = false;
  Timer? _cooldownTimer;

  // ── User profile ──────────────────────────────────────────────────────
  String? _userFirstName;
  String? _userLastName;
  String? _userPhone;
  String? _userName;

  // ── Constants ─────────────────────────────────────────────────────────
  static const _autoSaveInterval = Duration(seconds: 5);
  static const Duration _cooldownDuration = Duration(seconds: 60);
  static const String _fixedUserId = '271266';
  static const String _fixedPropertyTypeId = '2';
  static const String _fixedCountryId = '1';
  static const String _fixedRegionId = '2';
  static const Set<String> _allowedImageExtensions = {'png', 'jpg', 'jpeg', 'gif'};
  static const int _maxPhotoCount = 30;

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

  // ═══════════════════════════════════════════════════════════════════════
  // Lifecycle
  // ═══════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _globalData = context.read<GlobalDataService>();
    _cacheService = context.read<CacheService>();
    _loadInitialData();
    _startAutoSave();
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _cooldownTimer?.cancel();
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
    _porterNameController.dispose();
    _porterPhoneController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Data loading
  // ═══════════════════════════════════════════════════════════════════════

  void _startAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer.periodic(_autoSaveInterval, (_) => _autoSave());
  }

  Future<void> _loadInitialData() async {
    final draft = await _cacheService.loadAddApartmentDraft();
    if (draft != null) _restoreDraft(draft);

    await _loadUserProfile();
    await _loadCities();
    await _loadFeatures();
    await _loadResidentialComplexes();

    if (_selectedCityId != null) {
      await _loadZones(_selectedCityId!);
    }

    if (mounted) setState(() => _loadingDraft = false);
  }

  Future<void> _loadUserProfile() async {
    final data = await _cacheService.loadAuthSession();
    if (!mounted) return;
    if (data == null) {
      setState(() {
        _userFirstName = null;
        _userLastName = null;
        _userPhone = null;
        _userName = null;
      });
      return;
    }
    setState(() {
      _userFirstName = normalizeProfileValue(data['first_name']);
      _userLastName = normalizeProfileValue(data['last_name']);
      _userPhone = normalizeProfileValue(data['phone']);
      _userName = normalizeProfileValue(data['username']);
    });
  }

  Future<void> _loadCities() async {
    if (mounted) setState(() => _loadingCities = true);
    try {
      final cached = AppConstants.filterAllowedCities(_globalData.cities);
      if (cached.isNotEmpty) {
        _cities = List<Map<String, dynamic>>.from(cached);
      } else {
        final api = WasiApiService(
          apiToken: AppConstants.wasiApiToken,
          companyId: AppConstants.wasiApiId,
        );
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
    if (mounted) {
      setState(() {
        _loadingZones = true;
        _zones = [];
      });
    }
    try {
      final api = WasiApiService(
        apiToken: AppConstants.wasiApiToken,
        companyId: AppConstants.wasiApiId,
      );
      _zones = await api.getZonesByCity(cityId);
      if (_selectedZoneId != null &&
          !_zones.any((z) => z['id'] == _selectedZoneId)) {
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
      List<Map<String, dynamic>> rawFeatures = List<Map<String, dynamic>>.from(_globalData.features);
      if (rawFeatures.isEmpty) {
        final api = WasiApiService(
          apiToken: AppConstants.wasiApiToken,
          companyId: AppConstants.wasiApiId,
        );
        rawFeatures = await api.getFeatures();
      } else {
        rawFeatures = List<Map<String, dynamic>>.from(rawFeatures);
      }

      final normalized = rawFeatures
          .map((feature) {
            final id = feature['id']?.toString() ?? '';
            final name = (feature['name'] ?? feature['nombre'] ?? '')
                .toString()
                .trim();
            final category = (feature['category'] ?? feature['type'] ?? '')
                .toString()
                .toLowerCase();
            if (id.isEmpty || name.isEmpty) return null;
            return {'id': id, 'name': name, 'category': category};
          })
          .whereType<Map<String, dynamic>>()
          .toList();

      _internalFeatures = normalized
          .where((f) => f['category'] == 'internal')
          .toList()
        ..sort(_compareFeaturesByName);
      _externalFeatures = normalized
          .where((f) => f['category'] == 'external')
          .toList()
        ..sort(_compareFeaturesByName);
      _otherFeatures = normalized
          .where((f) =>
              f['category'] != 'internal' && f['category'] != 'external')
          .toList()
        ..sort(_compareFeaturesByName);

      final validIds =
          normalized.map((f) => f['id'] as String).toSet();
      _selectedFeatureIds.removeWhere((id) => !validIds.contains(id));

      if (_pendingFeatureNames.isNotEmpty) {
        final nameToId = <String, String>{
          for (final f in normalized)
            (f['name'] as String).toLowerCase(): f['id'] as String,
        };
        for (final name in _pendingFeatureNames) {
          final id = nameToId[name.toLowerCase()];
          if (id != null) _selectedFeatureIds.add(id);
        }
        _pendingFeatureNames.clear();
      }
    } catch (e) {
      debugPrint('Error cargando características: $e');
    } finally {
      if (mounted) setState(() => _loadingFeatures = false);
    }
  }

  Future<void> _loadResidentialComplexes() async {
    try {
      final cached = List<Map<String, dynamic>>.from(_globalData.residentialComplexes);
      if (cached.isNotEmpty) {
        _residentialComplexes = List<Map<String, dynamic>>.from(cached);
      } else {
        try {
          _residentialComplexes = await ApiService.getResidentialComplexes();
        } catch (_) {
          _residentialComplexes = [];
        }
      }
      if (_residentialComplexes.isEmpty) {
        _isManualUnitName = true;
      } else if (_selectedComplexId != null) {
        try {
          _selectedComplex = _residentialComplexes.firstWhere(
            (c) => c['id'] == _selectedComplexId,
          );
        } catch (_) {
          _selectedComplex = null;
          _selectedComplexId = null;
          _fieldsLockedByComplex = false;
        }
      }
      debugPrint(
          '🏢 Unidades residenciales disponibles: ${_residentialComplexes.length}');
    } catch (e) {
      debugPrint('Error cargando unidades residenciales: $e');
      _residentialComplexes = [];
      _isManualUnitName = true;
    }
    if (mounted) setState(() {});
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Draft restore / save
  // ═══════════════════════════════════════════════════════════════════════

  void _restoreDraft(Map<String, dynamic> draft) {
    final storedApartmentNumber =
        draft['_apartment_number_text'] ?? draft['apartment_number'];
    final storedUnitName = draft['_unit_name_text'] ?? draft['unit_name'];
    if (storedApartmentNumber != null) {
      _apartmentNumberController.text =
          digitsOnly(storedApartmentNumber.toString());
    }
    if (storedUnitName != null) {
      _unitNameController.text = storedUnitName.toString();
    }
    if (_apartmentNumberController.text.isEmpty && draft['title'] != null) {
      final parts = draft['title'].toString().split('-');
      if (parts.isNotEmpty) {
        _apartmentNumberController.text = digitsOnly(parts.first);
        if (parts.length > 1) {
          _unitNameController.text = parts.sublist(1).join('-').trim();
        }
      }
    }

    // Operation
    if (draft['business_type'] != null) {
      _operation = draft['business_type'] == 'venta' ? 'venta' : 'alquiler';
    } else if (draft['for_rent'] == true) {
      _operation = 'alquiler';
    } else if (draft['for_sale'] == true) {
      _operation = 'venta';
    }

    final storedStatus = draft['id_status_on_page']?.toString();
    if (storedStatus != null &&
        _statusOptions.any((o) => o['id'] == storedStatus)) {
      _statusOnPageId = storedStatus;
    }

    // Prices
    if (draft['rent_price'] != null) {
      _rentPriceController.text = draft['rent_price'].toString();
    }
    if (_rentPriceController.text.isEmpty && draft['price'] != null) {
      _rentPriceController.text = draft['price'].toString();
    }
    applyThousandsFormat(_rentPriceController);
    if (draft['sale_price'] != null) {
      _salePriceController.text = draft['sale_price'].toString();
    }
    applyThousandsFormat(_salePriceController);

    // Text fields
    if (draft['address'] != null) _addressController.text = draft['address'];
    if (draft['area'] != null) {
      _areaController.text = draft['area'].toString();
    }
    if (draft['observations'] != null) {
      _observationsController.text = draft['observations'];
    }
    if (draft['building_date'] != null) {
      _buildingDateController.text = draft['building_date'].toString();
    }
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

    // Dropdowns
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

    // Features
    if (draft['features'] is List) {
      for (final dynamic item in (draft['features'] as List)) {
        if (item == null) continue;
        final id = item.toString().trim();
        if (id.isEmpty) continue;
        _selectedFeatureIds.add(id);
      }
    } else if (draft['features'] is String) {
      _selectedFeatureIds.addAll(extractFeatures(draft['features'].toString()));
    }
    if (draft['_internal_features_text'] != null) {
      _pendingFeatureNames
          .addAll(extractFeatures(draft['_internal_features_text'].toString()));
    }
    if (draft['_external_features_text'] != null) {
      _pendingFeatureNames
          .addAll(extractFeatures(draft['_external_features_text'].toString()));
    }

    // Prompts / contact info
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
    final storedLandlordPhone =
        draft['_landlord_phone_text'] ?? draft['landlordPhone'];
    if (storedLandlordPhone != null) {
      _landlordPhoneController.text =
          digitsOnly(storedLandlordPhone.toString());
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
    final storedAdminPhone =
        draft['_admin_phone_text'] ?? draft['adminPhone'];
    if (storedAdminPhone != null) {
      _adminPhoneController.text = digitsOnly(storedAdminPhone.toString());
    }
    final storedLodgePhone =
        draft['_lodge_phone_text'] ?? draft['lodgePhone'];
    if (storedLodgePhone != null) {
      _lodgePhoneController.text = digitsOnly(storedLodgePhone.toString());
    }
    if (draft['_porter_name_text'] != null) {
      _porterNameController.text = draft['_porter_name_text'].toString();
    } else if (draft['porterName'] != null) {
      _porterNameController.text = draft['porterName'].toString();
    }
    final storedPorterPhone =
        draft['_porter_phone_text'] ?? draft['porterPhone'];
    if (storedPorterPhone != null) {
      _porterPhoneController.text = digitsOnly(storedPorterPhone.toString());
    }
    if (_keysController.text.trim().isEmpty) {
      _keysController.text = 'PORTERIA';
    }

    // Photos
    _loadPhotosFromDraft(draft);

    // Boolean toggles
    _hasVeredalWater = parseBool(
      draft['agua_veredal'] ??
          draft['_agua_veredal_bool'] ??
          draft['aguaVeredal'],
    );
    _hasGasInstallation = parseBool(
      draft['instalacion_gas_cubierta'] ??
          draft['_instalacion_gas_cubierta_bool'] ??
          draft['instalacionGasCubierta'],
    );
    _hasLegalizacionEpm = parseBool(
      draft['legalizacion_epm'] ??
          draft['_legalizacion_epm_bool'] ??
          draft['legalizacionEpm'],
    );
    _hasInternetOperators = parseBool(
      draft['operadores_internet'] ??
          draft['_operadores_internet_bool'] ??
          draft['operadoresInternet'],
    );

    // Residential complex state
    final storedComplexId = draft['_selected_complex_id'];
    if (storedComplexId != null) {
      _selectedComplexId = storedComplexId is int
          ? storedComplexId
          : int.tryParse(storedComplexId.toString());
    }
    _isManualUnitName = parseBool(draft['_is_manual_unit_name']);
    _fieldsLockedByComplex = parseBool(draft['_fields_locked_by_complex']);
    final storedLat = draft['_selected_latitude'];
    if (storedLat != null) {
      _selectedLatitude = storedLat is num
          ? storedLat.toDouble()
          : double.tryParse(storedLat.toString());
    }
    final storedLng = draft['_selected_longitude'];
    if (storedLng != null) {
      _selectedLongitude = storedLng is num
          ? storedLng.toDouble()
          : double.tryParse(storedLng.toString());
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Photo draft restore helpers
  // ═══════════════════════════════════════════════════════════════════════

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
        draft['photos_file_names'] ??
            draft['photosFileNames'] ??
            draft['photoFileNames'],
      );
      if (photosList.isNotEmpty) {
        _addPhotosFromLists(photosList, photoNamesList);
        restoredFromTuples = _photos.isNotEmpty;
      }
    }

    if (!restoredFromTuples) {
      final singlePhotoBase64 = draft['photo_base64'] ?? draft['photoBase64'];
      final storedPhotoName =
          draft['_photo_file_name'] ?? draft['photoFileName'];
      if (singlePhotoBase64 is String && singlePhotoBase64.isNotEmpty) {
        try {
          final bytes = base64Decode(singlePhotoBase64);
          final rawName =
              storedPhotoName is String ? storedPhotoName.trim() : '';
          final resolvedName = rawName.isEmpty ? 'foto_01.jpg' : rawName;
          if (_photos.length < _maxPhotoCount) {
            _photos
                .add(ApartmentPhoto(bytes: bytes, fileName: resolvedName));
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

    ApartmentPhoto? decodeAuxPhoto({
      dynamic raw,
      dynamic legacyBase64,
      dynamic legacyFileName,
      required String fallbackName,
    }) {
      final photo = _decodeSinglePhoto(raw, fallbackName: fallbackName);
      if (photo != null) return photo;
      if (legacyBase64 is String && legacyBase64.isNotEmpty) {
        try {
          final bytes = base64Decode(legacyBase64);
          final rawName = legacyFileName?.toString() ?? '';
          final resolvedName =
              rawName.trim().isEmpty ? fallbackName : rawName.trim();
          return ApartmentPhoto(bytes: bytes, fileName: resolvedName);
        } catch (e) {
          debugPrint(
              'Error decodificando foto auxiliar (fallback $fallbackName): $e');
        }
      }
      return null;
    }

    final servicePhoto = decodeAuxPhoto(
      raw: draft['service_room_photo'],
      legacyBase64: draft['_service_room_photo_base64'] ??
          draft['serviceRoomPhotoBase64'],
      legacyFileName: draft['_service_room_photo_file_name'] ??
          draft['serviceRoomPhotoFileName'],
      fallbackName: 'cuarto_util.jpg',
    );
    if (servicePhoto != null) {
      _serviceRoomPhotoBytes = servicePhoto.bytes;
      _serviceRoomPhotoFileName = servicePhoto.fileName;
    }

    final parkingPhoto = decodeAuxPhoto(
      raw: draft['parking_lot_photo'],
      legacyBase64: draft['_parking_lot_photo_base64'] ??
          draft['parkingLotPhotoBase64'],
      legacyFileName: draft['_parking_lot_photo_file_name'] ??
          draft['parkingLotPhotoFileName'],
      fallbackName: 'parqueo.jpg',
    );
    if (parkingPhoto != null) {
      _parkingLotPhotoBytes = parkingPhoto.bytes;
      _parkingLotPhotoFileName = parkingPhoto.fileName;
    }
  }

  List<List<String>> _extractPhotoPairs(dynamic raw) {
    final pairs = <List<String>>[];
    if (raw is! List) return pairs;
    for (final item in raw) {
      String? base64;
      String name = '';
      if (item is List) {
        if (item.isNotEmpty && item[0] != null) base64 = item[0].toString();
        if (item.length > 1 && item[1] != null) name = item[1].toString();
      } else if (item is Map) {
        final base =
            item['base64'] ?? item['bytes'] ?? item['data'] ?? item['photo'];
        final nameCandidate =
            item['name'] ?? item['fileName'] ?? item['filename'] ?? item['title'];
        if (base != null) base64 = base.toString();
        if (nameCandidate != null) name = nameCandidate.toString();
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
      return raw.map((e) => e == null ? '' : e.toString()).toList();
    }
    return <String>[];
  }

  void _addPhotosFromLists(List<String> base64List, List<String> nameList) {
    for (var i = 0;
        i < base64List.length && _photos.length < _maxPhotoCount;
        i++) {
      final encoded = base64List[i];
      if (encoded.isEmpty) continue;
      try {
        final bytes = base64Decode(encoded);
        final candidateName = (i < nameList.length) ? nameList[i].trim() : '';
        final resolvedName = candidateName.isEmpty
            ? 'foto_${(_photos.length + 1).toString().padLeft(2, '0')}.jpg'
            : candidateName;
        _photos.add(ApartmentPhoto(bytes: bytes, fileName: resolvedName));
      } catch (e) {
        debugPrint('Error decodificando foto del borrador (índice $i): $e');
      }
    }
  }

  ApartmentPhoto? _decodeSinglePhoto(
    dynamic raw, {
    required String fallbackName,
  }) {
    if (raw == null) return null;

    String? base64Data;
    String? name;

    if (raw is List) {
      if (raw.isEmpty) return null;
      if (raw.length == 1 && raw.first is List) {
        final nested = raw.first as List;
        if (nested.isEmpty) return null;
        base64Data = nested.first?.toString();
        if (nested.length > 1) name = nested[1]?.toString();
      } else {
        base64Data = raw.first?.toString();
        if (raw.length > 1) name = raw[1]?.toString();
      }
    } else if (raw is Map) {
      final base = raw['base64'] ??
          raw['bytes'] ??
          raw['data'] ??
          raw['photo'] ??
          raw['value'];
      final nameCandidate =
          raw['name'] ?? raw['fileName'] ?? raw['filename'] ?? raw['title'];
      if (base != null) base64Data = base.toString();
      if (nameCandidate != null) name = nameCandidate.toString();
    } else if (raw is String) {
      base64Data = raw;
    }

    if (base64Data == null || base64Data.isEmpty) return null;

    try {
      final bytes = base64Decode(base64Data);
      final resolvedName =
          (name ?? '').trim().isEmpty ? fallbackName : name!.trim();
      return ApartmentPhoto(bytes: bytes, fileName: resolvedName);
    } catch (e) {
      debugPrint('Error decodificando foto auxiliar: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Auto-save
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _autoSave() async {
    if (!mounted) return;
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
        (_keysController.text.trim().isEmpty ||
            _keysController.text.trim().toUpperCase() == 'PORTERIA') &&
        _adminMailController.text.isEmpty &&
        _adminPhoneController.text.isEmpty &&
        _lodgePhoneController.text.isEmpty &&
        _porterNameController.text.isEmpty &&
        _porterPhoneController.text.isEmpty &&
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
    final serviceRoomPhotoBase64 = _serviceRoomPhotoBytes == null
        ? null
        : base64Encode(_serviceRoomPhotoBytes!);
    final parkingLotPhotoBase64 = _parkingLotPhotoBytes == null
        ? null
        : base64Encode(_parkingLotPhotoBytes!);
    final data = {
      ..._currentData(),
      '_apartment_number_text': digitsOnly(_apartmentNumberController.text),
      '_unit_name_text': _unitNameController.text,
      '_service_room_text': _serviceRoomController.text,
      '_parking_lot_text': _parkingLotController.text,
      '_prompts_text': _promptsController.text,
      '_landlord_name_text': _landlordNameController.text,
      '_landlord_phone_text': digitsOnly(_landlordPhoneController.text),
      '_keys_text': _keysController.text,
      '_admin_mail_text': _adminMailController.text,
      '_admin_phone_text': digitsOnly(_adminPhoneController.text),
      '_lodge_phone_text': digitsOnly(_lodgePhoneController.text),
      '_porter_name_text': _porterNameController.text,
      '_porter_phone_text': digitsOnly(_porterPhoneController.text),
      '_selected_complex_id': _selectedComplexId,
      '_is_manual_unit_name': _isManualUnitName,
      '_fields_locked_by_complex': _fieldsLockedByComplex,
      '_selected_latitude': _selectedLatitude,
      '_selected_longitude': _selectedLongitude,
      'photos': photoTuples,
      '_service_room_photo_file_name': _serviceRoomPhotoFileName,
      '_parking_lot_photo_file_name': _parkingLotPhotoFileName,
      '_service_room_photo_base64': serviceRoomPhotoBase64,
      '_parking_lot_photo_base64': parkingLotPhotoBase64,
    };
    _saving = true;
    await _cacheService.saveAddApartmentDraft(data);
    _lastSaved = DateTime.now();
    if (mounted) setState(() => _saving = false);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Data building
  // ═══════════════════════════════════════════════════════════════════════

  Map<String, dynamic> _currentData() {
    final isForRent = _operation == 'alquiler';
    final rentPrice = digitsOnly(_rentPriceController.text);
    final salePrice = digitsOnly(_salePriceController.text);
    final area = numericString(_areaController.text);
    final buildingDate = digitsOnly(_buildingDateController.text, maxLength: 4);
    final apartmentNumber = digitsOnly(_apartmentNumberController.text);
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
    final cityName = lookupNameById(_cities, _selectedCityId);
    final zoneName = lookupNameById(_zones, _selectedZoneId);
    final serviceRoomPhotoTuple = _buildSinglePhotoTuple(
        _serviceRoomPhotoBytes, _serviceRoomPhotoFileName, 'cuarto_util.jpg');
    final parkingLotPhotoTuple = _buildSinglePhotoTuple(
        _parkingLotPhotoBytes, _parkingLotPhotoFileName, 'parqueo.jpg');
    final prompts = _promptsController.text.trim();
    final landlordName = _landlordNameController.text.trim();
    final landlordPhone = digitsOnly(_landlordPhoneController.text);
    final keysRaw = _keysController.text.trim();
    final keys = keysRaw.isEmpty ? 'PORTERIA' : keysRaw;
    final adminMail = _adminMailController.text.trim();
    final adminPhone = digitsOnly(_adminPhoneController.text);
    final lodgePhone = digitsOnly(_lodgePhoneController.text);
    final porterName = _porterNameController.text.trim();
    final porterPhone = digitsOnly(_porterPhoneController.text);
    final photoTuples = _buildPhotoTuples();

    final List<String> titleParts = [];
    if (apartmentNumber.isNotEmpty) titleParts.add(apartmentNumber);
    if (unitName.isNotEmpty) titleParts.add(unitName);
    final computedTitle = titleParts.join(' ');
    final effectiveTitle =
        computedTitle.isEmpty ? 'Apartamento sin título' : computedTitle;

    return {
      'id_company': AppConstants.wasiApiId,
      'id_user': _fixedUserId,
      'id_property_type': _fixedPropertyTypeId,
      'id_country': _fixedCountryId,
      'id_region': _fixedRegionId,
      'id_availability': '1',
      'id_publish_on_map': '2',
      'title': 'Apartamento en ${cityName ?? 'Medellin'}',
      'registration_number': effectiveTitle,
      'portals': <String>[],
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
      'id_residential_complex': _selectedComplexId,
      'latitude': _selectedLatitude,
      'longitude': _selectedLongitude,
      'user_first_name': _userFirstName,
      'user_last_name': _userLastName,
      'user_phone': _userPhone,
      'username': _userName,
      'landlordName': landlordName,
      'landlordPhone': landlordPhone,
      'keys': keys,
      'adminMail': adminMail.isEmpty ? null : adminMail,
      'adminPhone': adminPhone.isEmpty ? null : adminPhone,
      'lodgePhone': lodgePhone.isEmpty ? null : lodgePhone,
      'porterName': porterName.isEmpty ? null : porterName,
      'porterPhone': porterPhone.isEmpty ? null : porterPhone,
      'photos': photoTuples,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Feature helpers
  // ═══════════════════════════════════════════════════════════════════════

  int _compareFeaturesByName(Map<String, dynamic> a, Map<String, dynamic> b) {
    return normalizeSortText(a['name']?.toString() ?? '')
        .compareTo(normalizeSortText(b['name']?.toString() ?? ''));
  }

  Map<String, String> _featureIdToNameMap() {
    final map = <String, String>{};
    for (final list in [_internalFeatures, _externalFeatures, _otherFeatures]) {
      for (final f in list) {
        final id = f['id']?.toString();
        final name = f['name']?.toString();
        if (id != null && name != null && id.isNotEmpty && name.isNotEmpty) {
          map[id] = name;
        }
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

  List<List<String>> _selectedFeatureNameList() {
    final internalNames = <String>[];
    final externalNames = <String>[];
    final catalog = <String, Map<String, dynamic>>{};
    void collect(List<Map<String, dynamic>> source) {
      for (final f in source) {
        final id = f['id']?.toString();
        if (id == null || id.isEmpty) continue;
        catalog[id] = f;
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

    if (internalNames.isEmpty &&
        externalNames.isEmpty &&
        _pendingFeatureNames.isNotEmpty) {
      final pending = _pendingFeatureNames.toList();
      pending.sort(
          (a, b) => normalizeSortText(a).compareTo(normalizeSortText(b)));
      return [pending, <String>[]];
    }

    int cmp(String a, String b) =>
        normalizeSortText(a).compareTo(normalizeSortText(b));
    internalNames.sort(cmp);
    externalNames.sort(cmp);
    return [internalNames, externalNames];
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Photo helpers
  // ═══════════════════════════════════════════════════════════════════════

  List<String>? _buildSinglePhotoTuple(
      Uint8List? bytes, String? fileName, String fallbackName) {
    if (bytes == null) return null;
    final resolvedName =
        (fileName ?? '').trim().isEmpty ? fallbackName : fileName!.trim();
    return [base64Encode(bytes), resolvedName];
  }

  List<List<String>> _buildPhotoTuples() {
    final tuples = <List<String>>[];
    for (var i = 0; i < _photos.length && i < _maxPhotoCount; i++) {
      final photo = _photos[i];
      final fallbackName = 'foto_${(i + 1).toString().padLeft(2, '0')}.jpg';
      final name =
          photo.fileName.trim().isNotEmpty ? photo.fileName.trim() : fallbackName;
      tuples.add([base64Encode(photo.bytes), name]);
    }
    return tuples;
  }

  int get _remainingPhotoSlots {
    final remaining = _maxPhotoCount - _photos.length;
    return remaining < 0 ? 0 : remaining;
  }

  Future<ApartmentPhoto?> _readPhotoFromXFile(XFile file) async {
    final nameOrPath = file.name.isNotEmpty ? file.name : file.path;
    final extension =
        p.extension(nameOrPath).replaceFirst('.', '').toLowerCase();
    if (extension.isEmpty || !_allowedImageExtensions.contains(extension)) {
      _showSnackBarMessage(
          'Formato de imagen no permitido. Usa archivos PNG, JPG, JPEG o GIF.');
      return null;
    }
    try {
      final bytes = await file.readAsBytes();
      final resolvedName =
          file.name.isNotEmpty ? file.name : p.basename(nameOrPath);
      return ApartmentPhoto(bytes: bytes, fileName: resolvedName);
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
          imageQuality: 85);
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
          imageQuality: 85);
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

  Future<int> _pickPhotos() async {
    final remaining = _remainingPhotoSlots;
    if (remaining <= 0) {
      _showSnackBarMessage(
          'Ya se cargaron las $_maxPhotoCount fotos permitidas.');
      return 0;
    }

    List<XFile> files;
    try {
      files = await _imagePicker.pickMultiImage(
          maxWidth: 1600, maxHeight: 1600, imageQuality: 85);
    } catch (e) {
      debugPrint('Error abriendo selector múltiple de imágenes: $e');
      _showSnackBarMessage('No se pudo abrir el selector de imágenes.');
      return 0;
    }

    if (files.isEmpty) return 0;

    final limitApplied = files.length > remaining;
    final newPhotos = <ApartmentPhoto>[];
    for (final file in files.take(remaining)) {
      final photo = await _readPhotoFromXFile(file);
      if (photo != null) newPhotos.add(photo);
    }

    if (newPhotos.isEmpty || !mounted) {
      if (limitApplied) {
        _showSnackBarMessage('Se alcanzó el máximo de fotos permitidas.');
      }
      return 0;
    }

    setState(() => _photos.addAll(newPhotos));
    await _autoSave();

    if (limitApplied) {
      _showSnackBarMessage(
          'Solo se agregaron ${newPhotos.length} fotos (límite alcanzado).');
    }
    return newPhotos.length;
  }

  Future<void> _removePhotoAt(int index) async {
    if (index < 0 || index >= _photos.length) return;
    setState(() => _photos.removeAt(index));
    await _autoSave();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // UI actions
  // ═══════════════════════════════════════════════════════════════════════

  void _showSnackBarMessage(String message, {Duration? duration}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 150,
          left: 10,
          right: 10,
        ),
        duration: duration ?? const Duration(seconds: 4),
      ),
    );
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    if (!mounted) return;
    setState(() => _cooldownActive = true);
    _showSnackBarMessage(
      'Datos enviados correctamente, por favor espere antes de volver a captar.',
      duration: const Duration(seconds: 10),
    );
    _cooldownTimer = Timer(_cooldownDuration, () {
      if (!mounted) return;
      setState(() => _cooldownActive = false);
    });
  }

  void _onResidentialComplexSelected(Map<String, dynamic> complex) {
    setState(() {
      _selectedComplex = complex;
      _selectedComplexId = complex['id'] as int?;
      _isManualUnitName = false;
      _fieldsLockedByComplex = true;
      _unitNameHasError = false;

      final name = complex['name']?.toString() ?? '';
      _unitNameController.text = name;
      final address = complex['address']?.toString();
      if (address != null && address.isNotEmpty) {
        _addressController.text = address;
      } else {
        _addressController.clear();
      }
      final idCity = complex['id_city']?.toString();
      if (idCity != null && idCity.isNotEmpty) _selectedCityId = idCity;
      final idZone = complex['id_zone']?.toString();
      if (idZone != null && idZone.isNotEmpty) _selectedZoneId = idZone;
      final stratum = complex['stratum']?.toString();
      if (stratum != null && stratum.isNotEmpty) {
        final stratumInt = int.tryParse(stratum);
        if (stratumInt != null && stratumInt >= 1 && stratumInt <= 6) {
          _stratum = stratum;
        }
      }
      final adminPhone = complex['admin_phone']?.toString();
      if (adminPhone != null && adminPhone.isNotEmpty) {
        _adminPhoneController.text = digitsOnly(adminPhone);
      }
      final adminEmail = complex['admin_email']?.toString();
      if (adminEmail != null && adminEmail.isNotEmpty) {
        _adminMailController.text = adminEmail;
      }
      final frontDeskPhone = complex['front_desk_phone']?.toString();
      if (frontDeskPhone != null && frontDeskPhone.isNotEmpty) {
        _lodgePhoneController.text = digitsOnly(frontDeskPhone);
      }
      final lat = complex['latitude'];
      _selectedLatitude =
          lat is num ? lat.toDouble() : double.tryParse(lat?.toString() ?? '');
      final lng = complex['longitude'];
      _selectedLongitude =
          lng is num ? lng.toDouble() : double.tryParse(lng?.toString() ?? '');
    });
    if (_selectedCityId != null) _loadZones(_selectedCityId!);
  }

  void _enableManualUnitName() {
    setState(() {
      _isManualUnitName = true;
      _selectedComplex = null;
      _selectedComplexId = null;
      _selectedLatitude = null;
      _selectedLongitude = null;
      _fieldsLockedByComplex = false;
      _unitNameHasError = false;
      _unitNameController.clear();
    });
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
    _porterNameController.clear();
    _porterPhoneController.clear();
    _selectedFeatureIds.clear();
    _pendingFeatureNames.clear();
    _selectedCityId = null;
    _selectedZoneId = null;
    _selectedComplex = null;
    _selectedComplexId = null;
    _selectedLatitude = null;
    _selectedLongitude = null;
    _isManualUnitName = _residentialComplexes.isEmpty;
    _fieldsLockedByComplex = false;
    _unitNameHasError = false;
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
    _cooldownTimer?.cancel();
    _cooldownActive = false;
  }

  Future<void> _confirmClearDraft() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar borrador'),
        content: const Text(
            '¿Desea eliminar el borrador actual? Esta acción es irreversible.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (shouldClear != true) return;
    await _cacheService.clearAddApartmentDraft();
    if (!mounted) return;
    setState(() => _resetFormState());
    _showSnackBarMessage('Borrador eliminado.');
  }

  Future<void> _openFeatureSelector() async {
    if (_loadingFeatures) return;
    if (_internalFeatures.isEmpty &&
        _externalFeatures.isEmpty &&
        _otherFeatures.isEmpty) {
      await _loadFeatures();
      if (!mounted ||
          (_internalFeatures.isEmpty &&
              _externalFeatures.isEmpty &&
              _otherFeatures.isEmpty)) {
        return;
      }
    }

    final result = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) {
        final tempSelected = Set<String>.from(_selectedFeatureIds);
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            Widget buildCategory(
                String title, List<Map<String, dynamic>> features) {
              if (features.isEmpty) return const SizedBox.shrink();
              return ExpansionTile(
                key: PageStorageKey<String>('feature_$title'),
                initiallyExpanded: true,
                title: Text('$title (${features.length})'),
                children: features.map((f) {
                  final id = f['id']?.toString();
                  final name = f['name']?.toString() ?? '';
                  if (id == null || id.isEmpty || name.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return CheckboxListTile(
                    value: tempSelected.contains(id),
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
                          child: Text(
                              'No se encontraron características disponibles.'),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () =>
                        Navigator.of(ctx).pop<Set<String>>(null),
                    child: const Text('Cancelar')),
                ElevatedButton(
                    onPressed: () => Navigator.of(ctx)
                        .pop<Set<String>>(Set<String>.from(tempSelected)),
                    child: const Text('Guardar')),
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

  Future<void> _openPhotosManager() async {
    if (_isSubmitting) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setStateSheet) {
            return PhotosManagerSheet(
              photos: _photos,
              maxPhotoCount: _maxPhotoCount,
              remainingPhotoSlots: _remainingPhotoSlots,
              onAddPhotos: () async {
                final added = await _pickPhotos();
                if (added > 0) setStateSheet(() {});
              },
              onRemovePhoto: (index) async {
                await _removePhotoAt(index);
                setStateSheet(() {});
              },
            );
          },
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Submission
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _onSavePressed() async {
    final isValid = _formKey.currentState!.validate();
    if (!isValid) {
      _showSnackBarMessage('Faltan campos obligatorios por completar.');
      return;
    }
    if (!_isManualUnitName &&
        _selectedComplexId == null &&
        _residentialComplexes.isNotEmpty) {
      setState(() => _unitNameHasError = true);
      _showSnackBarMessage(
          'Seleccione una unidad residencial o ingrese una nueva.');
      return;
    }
    if (_unitNameController.text.trim().isEmpty) {
      setState(() => _unitNameHasError = true);
      _showSnackBarMessage('Ingrese el nombre de la unidad.');
      return;
    }
    if (_photos.length < 22) {
      _showSnackBarMessage(
          'Agrega al menos 22 fotos del apartamento. Actualmente tienes ${_photos.length}.');
      return;
    }
    if (_userFirstName == null || _userFirstName!.trim().isEmpty) {
      _showSnackBarMessage('Completa los datos del asesor antes de captar.');
      return;
    }
    if (_selectedCityId == null) {
      _showSnackBarMessage('Seleccione una ciudad');
      return;
    }
    if (_selectedZoneId == null) {
      _showSnackBarMessage('Seleccione un barrio');
      return;
    }
    if (_serviceRoomController.text.trim().isNotEmpty &&
        _serviceRoomPhotoBytes == null) {
      _showSnackBarMessage(
          'Si ingresa información del cuarto útil, debe agregar su foto.');
      return;
    }
    if (_parkingLotController.text.trim().isNotEmpty &&
        _parkingLotPhotoBytes == null) {
      _showSnackBarMessage(
          'Si ingresa información del parqueo, debe agregar su foto.');
      return;
    }

    final confirmed = await _showConfirmationDialog();
    if (confirmed != true) return;

    final data = _currentData();
    final payloadSize = WebhookService.estimatePayloadSizeBytes(data);
    final payloadSizeFormatted = WebhookService.formatBytes(payloadSize);
    debugPrint('Tamaño estimado del payload: $payloadSizeFormatted');

    if (payloadSize > AppConstants.webhookPayloadWarningSizeBytes) {
      if (!mounted) return;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Contenido muy pesado'),
          content: Text(
            'El tamaño de los datos a enviar es de $payloadSizeFormatted. '
            'Esto puede tardar varios minutos o fallar con conexiones lentas.\n\n'
            '¿Desea continuar de todas formas?',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancelar')),
            ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Continuar')),
          ],
        ),
      );
      if (proceed != true) return;
    }

    setState(() => _isSubmitting = true);

    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  'Enviando datos ($payloadSizeFormatted)...\n'
                  'Esto puede tardar unos minutos.',
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final result = await WebhookService.send(data);
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      if (!result.success) {
        if (!mounted) return;
        _showSnackBarMessage(result.userFriendlyMessage,
            duration: const Duration(seconds: 8));
        return;
      }
      if (!mounted) return;
      _startCooldown();
    } catch (_) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      rethrow;
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      } else {
        _isSubmitting = false;
      }
    }
  }

  Future<bool?> _showConfirmationDialog() async {
    final cityName =
        lookupNameById(_cities, _selectedCityId) ?? 'Sin ciudad';
    final zoneName =
        lookupNameById(_zones, _selectedZoneId) ?? 'Sin barrio';
    final tipoNegocio = _operation == 'alquiler' ? 'Alquiler' : 'Venta';
    final valor = _operation == 'alquiler'
        ? _rentPriceController.text
        : _salePriceController.text;
    final valorFormateado = valor.isEmpty ? 'No especificado' : '\$$valor';

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmar datos del apartamento'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildConfirmationRow('Número y Unidad',
                  '${_apartmentNumberController.text} - ${_unitNameController.text}'),
              const Divider(),
              _buildConfirmationRow('Tipo de negocio', tipoNegocio),
              _buildConfirmationRow('Valor', valorFormateado),
              const Divider(),
              _buildConfirmationRow('Ciudad', cityName),
              _buildConfirmationRow('Barrio', zoneName),
              _buildConfirmationRow('Estrato', _stratum),
              const Divider(),
              _buildConfirmationRow('Habitaciones', _bedrooms),
              _buildConfirmationRow('Baños', _bathrooms),
              _buildConfirmationRow('Parqueos', _garages),
              _buildConfirmationRow('Área', '${_areaController.text} m²'),
              const Divider(),
              _buildConfirmationRow(
                  'Cuarto útil',
                  _serviceRoomController.text.trim().isEmpty
                      ? 'No especificado'
                      : _serviceRoomController.text),
              _buildConfirmationRow(
                  'Parqueo',
                  _parkingLotController.text.trim().isEmpty
                      ? 'No especificado'
                      : _parkingLotController.text),
              const Divider(),
              _buildConfirmationRow('Fotos', '${_photos.length}'),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Corregir')),
          ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Confirmar y Captar')),
        ],
      ),
    );
  }

  Widget _buildConfirmationRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text('$label:',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Build
  // ═══════════════════════════════════════════════════════════════════════

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
            const Padding(
              padding: EdgeInsets.only(right: 12.0),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
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
                      BasicInfoSection(
                        apartmentNumberController: _apartmentNumberController,
                        unitNameController: _unitNameController,
                        buildingDateController: _buildingDateController,
                        operation: _operation,
                        statusOnPageId: _statusOnPageId,
                        propertyConditionId: _propertyConditionId,
                        isManualUnitName: _isManualUnitName,
                        fieldsLockedByComplex: _fieldsLockedByComplex,
                        unitNameHasError: _unitNameHasError,
                        selectedComplexId: _selectedComplexId,
                        residentialComplexes: _residentialComplexes,
                        propertyConditions: _propertyConditions,
                        statusOptions: _statusOptions,
                        isSubmitting: _isSubmitting,
                        onOperationChanged: (v) =>
                            setState(() => _operation = v),
                        onStatusChanged: (v) =>
                            setState(() => _statusOnPageId = v),
                        onPropertyConditionChanged: (v) =>
                            setState(() => _propertyConditionId = v),
                        onComplexSelected: _onResidentialComplexSelected,
                        onEnableManualUnitName: _enableManualUnitName,
                      ),
                      const SizedBox(height: 16),
                      LocationSection(
                        addressController: _addressController,
                        selectedCityId: _selectedCityId,
                        selectedZoneId: _selectedZoneId,
                        stratum: _stratum,
                        cities: _cities,
                        zones: _zones,
                        loadingCities: _loadingCities,
                        loadingZones: _loadingZones,
                        fieldsLockedByComplex: _fieldsLockedByComplex,
                        selectedComplex: _selectedComplex,
                        onCityChanged: (value) async {
                          if (value == _selectedCityId) return;
                          setState(() {
                            _selectedCityId = value;
                            _selectedZoneId = null;
                            _zones = [];
                          });
                          if (value != null) await _loadZones(value);
                        },
                        onZoneChanged: (value) =>
                            setState(() => _selectedZoneId = value),
                        onStratumChanged: (value) =>
                            setState(() => _stratum = value),
                      ),
                      const SizedBox(height: 16),
                      PricingSection(
                        rentPriceController: _rentPriceController,
                        salePriceController: _salePriceController,
                        areaController: _areaController,
                        operation: _operation,
                        bedrooms: _bedrooms,
                        bathrooms: _bathrooms,
                        garages: _garages,
                        onBedroomsChanged: (v) =>
                            setState(() => _bedrooms = v),
                        onBathroomsChanged: (v) =>
                            setState(() => _bathrooms = v),
                        onGaragesChanged: (v) =>
                            setState(() => _garages = v),
                      ),
                      const SizedBox(height: 16),
                      FeaturesSection(
                        promptsController: _promptsController,
                        selectedFeatureIds: _selectedFeatureIds,
                        featureSummaryText: _featureSummaryText,
                        loadingFeatures: _loadingFeatures,
                        onOpenFeatureSelector: _openFeatureSelector,
                        onClearSelection: () async {
                          setState(() => _selectedFeatureIds.clear());
                          await _autoSave();
                        },
                      ),
                      const SizedBox(height: 16),
                      PhotosSection(
                        photos: _photos,
                        maxPhotoCount: _maxPhotoCount,
                        isSubmitting: _isSubmitting,
                        serviceRoomController: _serviceRoomController,
                        parkingLotController: _parkingLotController,
                        serviceRoomPhotoBytes: _serviceRoomPhotoBytes,
                        serviceRoomPhotoFileName: _serviceRoomPhotoFileName,
                        parkingLotPhotoBytes: _parkingLotPhotoBytes,
                        parkingLotPhotoFileName: _parkingLotPhotoFileName,
                        onOpenPhotosManager: _openPhotosManager,
                        onPickServiceRoomPhoto: _pickServiceRoomPhoto,
                        onPickParkingLotPhoto: _pickParkingLotPhoto,
                      ),
                      const SizedBox(height: 16),
                      PrivateDataSection(
                        observationsController: _observationsController,
                        landlordNameController: _landlordNameController,
                        landlordPhoneController: _landlordPhoneController,
                        keysController: _keysController,
                        adminMailController: _adminMailController,
                        adminPhoneController: _adminPhoneController,
                        lodgePhoneController: _lodgePhoneController,
                        porterNameController: _porterNameController,
                        porterPhoneController: _porterPhoneController,
                        hasVeredalWater: _hasVeredalWater,
                        hasGasInstallation: _hasGasInstallation,
                        hasLegalizacionEpm: _hasLegalizacionEpm,
                        hasInternetOperators: _hasInternetOperators,
                        isSubmitting: _isSubmitting,
                        cooldownActive: _cooldownActive,
                        fieldsLockedByComplex: _fieldsLockedByComplex,
                        selectedComplex: _selectedComplex,
                        lastSaved: _lastSaved,
                        onVeredalWaterChanged: (v) {
                          setState(() => _hasVeredalWater = v);
                          _autoSave();
                        },
                        onGasInstallationChanged: (v) {
                          setState(() => _hasGasInstallation = v);
                          _autoSave();
                        },
                        onLegalizacionEpmChanged: (v) {
                          setState(() => _hasLegalizacionEpm = v);
                          _autoSave();
                        },
                        onInternetOperatorsChanged: (v) {
                          setState(() => _hasInternetOperators = v);
                          _autoSave();
                        },
                        onSavePressed: _onSavePressed,
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
