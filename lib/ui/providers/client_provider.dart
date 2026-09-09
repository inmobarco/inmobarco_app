import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../data/services/api_service.dart';
import '../../data/services/cache_service.dart';
import '../../data/services/sync_service.dart';
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
  final SyncService? _syncService;

  List<Client> _clients = [];
  bool _isLoading = false;
  String? _error;
  Future<void>? _initialLoad;
  String? _advisorPropertyId;
  Map<int, ClientNote> _latestNotes = {};

  ClientProvider({
    required WasiApiService apiService,
    required CacheService cacheService,
    SyncService? syncService,
  })  : _apiService = apiService,
        _cacheService = cacheService,
        _syncService = syncService {
    // Cuando la cola vacía una operación de CRM, la lista en pantalla dejó de
    // reflejar el servidor.
    _syncService?.setOnCrmSynced(() {
      debugPrint('🔄 Operación CRM sincronizada → recargando clientes');
      loadClients();
    });
  }

  /// True si la última operación no se pudo enviar y quedó encolada.
  bool _lastOperationQueued = false;

  /// True si la última operación quedó pendiente de conexión en vez de
  /// ejecutarse. La UI lo usa para avisar en lugar de reportar un error.
  bool get lastOperationQueued => _lastOperationQueued;

  List<Client> get clients => _clients;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Propiedad dummy del asesor activo (null si aún no se ha obtenido).
  String? get advisorPropertyId => _advisorPropertyId;

  /// Última entrada de bitácora del cliente (null si no tiene).
  ClientNote? latestNoteFor(int idClientWasi) => _latestNotes[idClientWasi];

  /// Carga la última nota de cada cliente del asesor.
  ///
  /// Cache-first con TTL de 15 min: pinta lo guardado y solo va a la red si
  /// venció o no hay nada. Falla silenciosa: la bitácora es un
  /// enriquecimiento, no debe tumbar la lista.
  Future<void> loadLatestNotes({bool force = false}) async {
    if (!force) {
      final cached = await _cacheService.loadLatestNotes();
      if (cached != null) {
        _applyLatestNotes(cached.data);
        if (!cached.isStale) return;
        debugPrint('🔄 Últimas notas vencidas → refrescando');
      }
    }

    try {
      final rows = await ApiService.getLatestClientNotes();
      _applyLatestNotes(rows);
      await _cacheService.saveLatestNotes(rows);
    } catch (e) {
      debugPrint('⚠️ No se pudieron cargar las últimas notas: $e');
    }
  }

  void _applyLatestNotes(List<Map<String, dynamic>> rows) {
    _latestNotes = {
      for (final row in rows)
        if (row['id_client_wasi'] != null)
          int.parse(row['id_client_wasi'].toString()): ClientNote.fromJson(row),
    };
    notifyListeners();
  }

  /// Crea una nota en la bitácora del cliente y actualiza la última
  /// entrada visible en la lista.
  Future<void> addNote(int idClientWasi, String note, String noteType) async {
    _lastOperationQueued = false;
    final Map<String, dynamic> created;
    try {
      created = await ApiService.createClientNote(idClientWasi, note, noteType);
    } catch (e) {
      if (await _enqueueCrm(
        entity: SyncService.entityClientNote,
        action: 'create',
        localId: 'note_${idClientWasi}_${DateTime.now().millisecondsSinceEpoch}',
        payload: {
          'id_client_wasi': idClientWasi,
          'note': note,
          'note_type': noteType,
        },
        error: e,
      )) {
        return;
      }
      rethrow;
    }
    _latestNotes[idClientWasi] = ClientNote.fromJson(created);
    notifyListeners();

    // El caché queda desactualizado por la nota nueva: se reescribe con lo que
    // hay en memoria y se invalida la bitácora del cliente.
    await _cacheService.saveLatestNotes([
      for (final entry in _latestNotes.entries)
        {
          'id_client_wasi': entry.key,
          'note': entry.value.note,
          'note_type': entry.value.noteType,
          'created_at': entry.value.createdAt,
          'note_id': entry.value.id,
        },
    ]);
    await _cacheService.saveClientNotes(idClientWasi, const []);
  }

  /// Bitácora de un cliente: caché primero, red si venció o falta.
  ///
  /// Retorna la lista cruda del backend. Lanza si no hay nada en caché y la
  /// red falla, para que la hoja de detalle pueda mostrar el error.
  Future<List<Map<String, dynamic>>> notesFor(int idClientWasi) async {
    final cached = await _cacheService.loadClientNotes(idClientWasi);
    if (cached != null && cached.data.isNotEmpty && !cached.isStale) {
      return cached.data;
    }

    try {
      final rows = await ApiService.getClientNotes(idClientWasi);
      await _cacheService.saveClientNotes(idClientWasi, rows);
      return rows;
    } catch (e) {
      if (cached != null && cached.data.isNotEmpty) {
        debugPrint('⚠️ Bitácora de $idClientWasi servida desde caché: $e');
        return cached.data;
      }
      rethrow;
    }
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

      // Sin sesión no hay asesor que resolver: la app en modo público no debe
      // gastar la petición (ni comerse el timeout).
      if (!await ApiService.hasSession()) return null;

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
      if (cached != null && cached.data.isNotEmpty) {
        _clients = cached.data;
        notifyListeners();
        // Lista desde caché, pero las notas siempre frescas (query liviana)
        await loadLatestNotes();
        // Caché vencido: se pinta de inmediato y se refresca sin bloquear.
        if (cached.isStale) {
          debugPrint('🔄 Clientes en caché vencidos → refrescando en background');
          loadClients();
        }
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
        loadLatestNotes(force: true),
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
    _lastOperationQueued = false;
    final propertyId = await ensureAdvisorMap();
    if (propertyId == null) {
      throw Exception('El asesor no tiene propiedad CRM asignada');
    }

    try {
      final idClient = await _apiService.createClient(
        firstName: firstName,
        cellPhone: cellPhone,
        lastName: lastName,
        email: email,
        query: query,
      );
      await _apiService.addPropertyToClient(idClient, propertyId);
      await loadClients();
    } catch (e) {
      if (!await _enqueueCrm(
        entity: SyncService.entityClient,
        action: 'create',
        localId: 'client_$cellPhone',
        payload: {
          'first_name': firstName,
          'cell_phone': cellPhone,
          'last_name': lastName,
          'email': email,
          'query': query,
          'id_property': propertyId,
        },
        error: e,
      )) {
        rethrow;
      }
    }
  }

  /// Actualiza un cliente en WASI y refresca la lista. El celular no se
  /// envía (bloqueado en edición).
  Future<void> updateClient(
    int idClientWasi, {
    required String firstName,
    required String lastName,
    String? email,
    String? query,
    required int idClientStatus,
  }) async {
    _lastOperationQueued = false;
    final fields = <String, dynamic>{
      'first_name': firstName,
      'last_name': lastName,
      'email': email ?? '',
      'query': query ?? '',
      'id_client_status': idClientStatus,
    };

    try {
      await _apiService.updateClient(idClientWasi.toString(), fields);
      await loadClients();
    } catch (e) {
      if (!await _enqueueCrm(
        entity: SyncService.entityClient,
        action: 'update',
        localId: 'client_$idClientWasi',
        payload: {...fields, 'id_client': idClientWasi},
        error: e,
      )) {
        rethrow;
      }
    }
  }

  /// Encola una operación de CRM que no salió por falta de conexión.
  ///
  /// Retorna true si quedó encolada. Solo se encolan fallos de red: un
  /// rechazo del servidor (datos inválidos, cliente duplicado) no mejora con
  /// reintentos y debe llegarle al asesor de una vez.
  Future<bool> _enqueueCrm({
    required String entity,
    required String action,
    required String localId,
    required Map<String, dynamic> payload,
    required Object error,
  }) async {
    final sync = _syncService;
    if (sync == null || !_isConnectionError(error)) return false;

    await sync.enqueue(
      entity: entity,
      action: action,
      localId: localId,
      payload: payload,
    );
    _lastOperationQueued = true;
    debugPrint('📋 $entity/$action encolado para reintento: $error');
    return true;
  }

  /// Distingue "no hay red" de "el servidor dijo que no".
  bool _isConnectionError(Object error) {
    if (error is DioException) {
      return error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout;
    }
    // Los servicios de WASI envuelven los DioException en Exception.
    final message = error.toString().toLowerCase();
    return message.contains('error de conexión') ||
        message.contains('timeout') ||
        message.contains('socketexception');
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
