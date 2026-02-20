/// Servicio de sincronización entre almacenamiento local y la API.
///
/// Responsabilidades planificadas:
/// - **Delta sync**: descarga solo los cambios desde la última sincronización
///   (usa un timestamp `last_synced_at`).
/// - **Cola de pendientes**: almacena operaciones (create / update / delete)
///   que fallaron por falta de conexión y las reintenta automáticamente
///   cuando vuelve la conectividad.
/// - **Resolución de conflictos**: si el servidor devuelve datos más recientes,
///   prioriza la versión del servidor (server-wins).
///
/// Ejemplo de uso futuro:
/// ```dart
/// final syncService = SyncService();
/// await syncService.syncAll();          // Delta sync completo
/// await syncService.retryPending();     // Reintentar cola pendiente
/// ```
///
/// TODO: implementar lógica completa.
class SyncService {
  // Singleton
  SyncService._();
  static final SyncService instance = SyncService._();

  // --- Delta sync ---
  // Future<void> syncAll() async { ... }

  // --- Cola de pendientes ---
  // Future<void> enqueue(PendingOperation op) async { ... }
  // Future<void> retryPending() async { ... }
}
