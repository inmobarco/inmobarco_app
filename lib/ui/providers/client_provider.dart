import 'package:flutter/foundation.dart';
import '../../data/services/api_service.dart';
import '../../data/services/cache_service.dart';
import '../../data/services/wasi_api_service.dart';
import '../../domain/models/client.dart';

/// Provider de clientes CRM: cruza la tabla interna del backend
/// (`/crm/clients`) con los datos personales de WASI (`/client/search`).
///
/// Caché local con TTL de 6h; la red solo se llama al abrir la pantalla
/// de Clientes sin caché válido, o con pull-to-refresh.
class ClientProvider extends ChangeNotifier {
  final WasiApiService _apiService;
  final CacheService _cacheService;

  List<Client> _clients = [];
  bool _isLoading = false;
  String? _error;
  Future<void>? _initialLoad;

  ClientProvider({
    required WasiApiService apiService,
    required CacheService cacheService,
  })  : _apiService = apiService,
        _cacheService = cacheService;

  List<Client> get clients => _clients;
  bool get isLoading => _isLoading;
  String? get error => _error;

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

  /// Carga desde red: backend CRM + WASI en paralelo, cruce por
  /// id_client_wasi == id_client (inner join) y orden alfabético.
  Future<void> loadClients() async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        ApiService.getCrmClients(),
        _apiService.getAllClients(),
      ]);
      final crmRows = results[0];
      final wasiClients = results[1];

      final wasiById = {
        for (final w in wasiClients) w['id_client']?.toString(): w,
      };

      final merged = <Client>[];
      for (final crm in crmRows) {
        final wasi = wasiById[crm['id_client_wasi']?.toString()];
        if (wasi != null) {
          merged.add(Client.fromCrmAndWasi(crm, wasi));
        }
      }
      merged.sort((a, b) =>
          a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));

      _clients = merged;
      await _cacheService.saveClients(merged);
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Error cargando clientes: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh forzado (pull-to-refresh).
  Future<void> refresh() => loadClients();
}
