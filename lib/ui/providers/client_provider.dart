import 'package:flutter/foundation.dart';
import '../../data/services/api_service.dart';
import '../../data/services/cache_service.dart';
import '../../data/services/wasi_api_service.dart';
import '../../domain/models/client.dart';

/// Provider de clientes CRM: obtiene la propiedad dummy del asesor desde el
/// backend (`/crm/advisor-map`, cacheada sin TTL hasta logout) y con ella
/// trae los clientes directo de WASI (`/client/search?id_property=...`).
///
/// La lista se cachea con TTL de 6h; la red solo se llama al abrir la
/// pantalla de Clientes sin caché válido, o con pull-to-refresh.
class ClientProvider extends ChangeNotifier {
  final WasiApiService _apiService;
  final CacheService _cacheService;

  List<Client> _clients = [];
  bool _isLoading = false;
  String? _error;
  Future<void>? _initialLoad;
  String? _advisorPropertyId;

  ClientProvider({
    required WasiApiService apiService,
    required CacheService cacheService,
  })  : _apiService = apiService,
        _cacheService = cacheService;

  List<Client> get clients => _clients;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Resuelve la propiedad dummy del asesor: memoria → caché → backend.
  /// Idempotente y silencioso ante error (p. ej. sin sesión aún); se llama
  /// no bloqueante al iniciar la app y se reintenta desde loadClients.
  Future<String?> ensureAdvisorMap() async {
    if (_advisorPropertyId != null) return _advisorPropertyId;
    try {
      final cached = await _cacheService.loadAdvisorMap();
      final cachedId = cached?['id_property_wasi']?.toString();
      if (cachedId != null && cachedId.isNotEmpty) {
        _advisorPropertyId = cachedId;
        return _advisorPropertyId;
      }

      final advisorMap = await ApiService.getAdvisorMap();
      final id = advisorMap['id_property_wasi']?.toString();
      if (id != null && id.isNotEmpty) {
        _advisorPropertyId = id;
        await _cacheService.saveAdvisorMap(advisorMap);
      }
    } catch (e) {
      debugPrint('⚠️ No se pudo obtener advisor-map: $e');
    }
    return _advisorPropertyId;
  }

  /// Llamado al abrir la pantalla de Clientes: carga caché y, si no hay
  /// caché válido, va a red. No bloquea y no repite si ya se ejecutó.
  Future<void> ensureLoaded() {
    return _initialLoad ??= _loadInitial();
  }

  Future<void> _loadInitial() async {
    try {
      final cached = await _cacheService.loadClients();
      if (cached != null && cached.isNotEmpty) {
        _clients = cached;
        notifyListeners();
        return;
      }
    } catch (e) {
      debugPrint('❌ Error cargando clientes desde caché: $e');
    }
    await loadClients();
  }

  /// Carga desde red: clientes de WASI filtrados por la propiedad dummy
  /// del asesor, en orden alfabético.
  Future<void> loadClients() async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final propertyId = await ensureAdvisorMap();
      if (propertyId == null) {
        throw Exception('El asesor no tiene propiedad CRM asignada');
      }

      final wasiClients = await _apiService.getClientsByProperty(propertyId);
      final clients = wasiClients.map(Client.fromWasi).toList()
        ..sort((a, b) =>
            a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));

      _clients = clients;
      await _cacheService.saveClients(clients);
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Error cargando clientes: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Crea un cliente en WASI, le asocia la propiedad dummy del asesor y
  /// refresca la lista. Lanza excepción si el asesor no tiene propiedad
  /// asignada o si alguna llamada falla.
  Future<void> createClient({
    required String firstName,
    required String cellPhone,
    String? lastName,
    String? email,
    String? query,
  }) async {
    final propertyId = await ensureAdvisorMap();
    if (propertyId == null) {
      throw Exception('El asesor no tiene propiedad CRM asignada');
    }

    final idClient = await _apiService.createClient(
      firstName: firstName,
      cellPhone: cellPhone,
      lastName: lastName,
      email: email,
      query: query,
    );
    await _apiService.addPropertyToClient(idClient, propertyId);
    await loadClients();
  }

  /// Refresh forzado (pull-to-refresh).
  Future<void> refresh() => loadClients();

  /// Resetea el estado en memoria (al cerrar sesión), para que otro asesor
  /// en el mismo dispositivo no vea la lista anterior.
  void clear() {
    _clients = [];
    _error = null;
    _initialLoad = null;
    _advisorPropertyId = null;
    notifyListeners();
  }
}
