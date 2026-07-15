import 'package:flutter/foundation.dart';
import '../../data/services/api_service.dart';
import '../../data/services/cache_service.dart';
import '../../data/services/wasi_api_service.dart';
import '../../domain/models/client.dart';
import '../../domain/models/client_note.dart';

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
  Map<int, ClientNote> _latestNotes = {};

  ClientProvider({
    required WasiApiService apiService,
    required CacheService cacheService,
  })  : _apiService = apiService,
        _cacheService = cacheService;

  List<Client> get clients => _clients;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Propiedad dummy del asesor activo (null si aún no se ha obtenido).
  String? get advisorPropertyId => _advisorPropertyId;

  /// Última entrada de bitácora del cliente (null si no tiene).
  ClientNote? latestNoteFor(int idClientWasi) => _latestNotes[idClientWasi];

  /// Carga la última nota de cada cliente del asesor. Falla silenciosa:
  /// la bitácora es un enriquecimiento, no debe tumbar la lista.
  Future<void> loadLatestNotes() async {
    try {
      final rows = await ApiService.getLatestClientNotes();
      _latestNotes = {
        for (final row in rows)
          if (row['id_client_wasi'] != null)
            int.parse(row['id_client_wasi'].toString()):
                ClientNote.fromJson(row),
      };
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ No se pudieron cargar las últimas notas: $e');
    }
  }

  /// Crea una nota en la bitácora del cliente y actualiza la última
  /// entrada visible en la lista.
  Future<void> addNote(int idClientWasi, String note, String noteType) async {
    final created =
        await ApiService.createClientNote(idClientWasi, note, noteType);
    _latestNotes[idClientWasi] = ClientNote.fromJson(created);
    notifyListeners();
  }

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
        notifyListeners();
        return _advisorPropertyId;
      }

      final advisorMap = await ApiService.getAdvisorMap();
      final id = advisorMap['id_property_wasi']?.toString();
      if (id != null && id.isNotEmpty) {
        _advisorPropertyId = id;
        await _cacheService.saveAdvisorMap(advisorMap);
        notifyListeners();
      } else {
        debugPrint('⚠️ advisor-map sin id_property_wasi: $advisorMap');
      }
    } catch (e, st) {
      debugPrint('⚠️ No se pudo obtener advisor-map: $e\n$st');
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
        // Lista desde caché, pero las notas siempre frescas (query liviana)
        await loadLatestNotes();
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
      // Primero resolver la propiedad del asesor (memoria → caché → backend).
      // Sin propiedad no se llama a WASI: lista vacía ("No hay clientes").
      final propertyId = await ensureAdvisorMap();
      if (propertyId == null) {
        _clients = [];
        return;
      }

      final results = await Future.wait([
        _apiService.getClientsByProperty(propertyId),
        loadLatestNotes(),
      ]);
      final wasiClients = results[0] as List<Map<String, dynamic>>;
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
    _latestNotes = {};
    notifyListeners();
  }
}
