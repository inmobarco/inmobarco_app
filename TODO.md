# TODO — Optimización de sincronización y caché

Plan derivado del análisis de red/caché de la app (ver sección "Contexto" al final).
Estado: `[ ]` pendiente · `[~]` en curso · `[x]` hecho.

---

## P0 — Bugs de datos ✅

> Completado. Verificado con `flutter analyze` (limpio) y `flutter test`
> (135 tests, incluido `test/data/services/appointment_store_test.dart` que
> cubre la carrera de escritura).

- [x] **P0.1 — Mutex de `fullSync` y un único escritor de citas**
  - El lock cubre push y pull; hoy `_isSyncing` solo protege la cola, así que el
    timer de 5 min y el evento de conectividad pueden solaparse.
  - Nuevo `AppointmentStore` (singleton) dueño de la clave `appointments_cache`,
    con read-modify-write serializado. `SyncService` deja de manipular el JSON
    crudo y la clave deja de estar duplicada en dos archivos.
  - `AppointmentProvider` pasa de `saveAll(listaCompleta)` a operaciones
    puntuales (`upsert` / `remove` / `setServerId`), que es lo que elimina el
    clobber contra el merge del pull.
  - Archivos: `data/services/appointment_store.dart` (nuevo),
    `data/services/sync_service.dart`, `data/repositories/appointment_repository.dart`,
    `ui/providers/appointment_provider.dart`.

- [x] **P0.2 — Caché de propiedades sin contaminar por filtros**
  - Solo se persiste el inventario sin filtros; los resultados de un filtro
    activo nunca sobrescriben el snapshot de arranque.
  - Archivos: `ui/providers/property_provider.dart`.

- [x] **P0.3 — Last-known-good en propiedades y clientes**
  - Al expirar el TTL se devuelven los datos con bandera `isStale` en vez de
    borrar el archivo (como ya hace `loadAllowedCities`), y se refresca en
    background. Sin red y con caché vencido la app deja de quedar vacía.
  - Nota: no aumenta el consumo de disco — el archivo se sobrescribe en cada
    refresh, así que el tamaño está acotado por el dataset (<1,5 MB en total),
    no por el tiempo. Los cachés que sí crecen sin límite se acotan donde se
    crean: tope LRU en P2.10 y límite de imágenes en P3.16.
  - Archivos: `data/services/cache_service.dart`,
    `ui/providers/property_provider.dart`, `ui/providers/client_provider.dart`.

- [x] **P0.4 — Reanudación tras login y gating por sesión**
  - Sin `access_token` no se llaman endpoints autenticados (hoy el arranque
    dispara `allowed-cities`, `residential-complexes`, `advisor-map` y el pull
    de citas contra 401, o se come 10 s de timeout por llamada).
  - Al login exitoso se disparan `globalData.refresh()`, `fullSync()` y
    `ensureAdvisorMap()`. Hoy nada reintenta después del login y ciudades y
    residenciales quedan vacíos hasta un pull-to-refresh manual.
  - Archivos: `data/services/api_service.dart`, `data/services/sync_service.dart`,
    `core/services/global_data_service.dart`, `ui/screens/login_screen.dart`.

**Descartado por decisión del equipo:** el borrador de propiedad
(`add_property_draft.json`) **sigue borrándose** al cambiar de versión de la app.
`clearAllCache()` queda como está.

---

## P1 — Arranque instantáneo ✅

> Completado. `flutter analyze` limpio y `flutter test` en verde (144 tests,
> con `test/core/services/global_data_service_test.dart` nuevo).
> Extra no planeado: el pull-to-refresh de Residenciales ahora usa
> `reloadResidentials()` en vez de recargar también ciudades y características.

- [x] **P1.5 — Catálogos WASI y residenciales a disco**
  - `features_cache.json`, `zones_cache.json`, `residentials_cache.json` con
    stale-while-revalidate y un TTL por catálogo según su volatilidad real:
    - características: **7 días**
    - ciudades y barrios: **24 h**
    - residenciales: **10 min** — varios asesores los crean para captar
      inmuebles (proyectos nuevos son frecuentes); si uno no ve el que acabó de
      crear otro, lo sube duplicado.
  - Helper genérico de caché con TTL en `CacheService` que reemplaza los ~7
    bloques duplicados de read/write/clear.
  - Disparadores del TTL de 10 min (un TTL corto solo sirve si algo lo
    consulta): al entrar a la pestaña de Residenciales, al abrir Agregar
    propiedad (no bloqueante, repuebla el desplegable al terminar) y al
    arrancar. `GlobalDataService` es `ChangeNotifier`, así que el refresco en
    background repinta las pantallas que lo escuchan.
  - Las zonas no se re-descargan en cada ciclo de residenciales: solo si
    vencieron (24 h) o si llegó un residencial cuyo barrio no está en el caché.
  - Forzado manual: pull-to-refresh en Residenciales, y **Configuración →
    Actualizar datos maestros** para ciudades y barrios (que no tenían otra
    forma de forzarse), con conteos y aviso si no hay sesión.

- [x] **P1.6 — `main()` sin red en el camino crítico**
  - `GlobalDataService.initialize()` se parte en `hydrateFromCache()` (local, se
    espera) y `refreshStale()` (background, después de `runApp`). Hoy `main()`
    espera features + residenciales + ~6 llamadas de zonas: sin cobertura son
    ~30 s de splash nativa antes del primer frame.
  - Corregir también el doble fetch de ciudades en `refresh()` (usar un flag
    `force` en lugar de llamar `_refreshAllowedCities()` dos veces).

- [x] **P1.7 — Fin de la carrera del arranque de propiedades**
  - `PropertyProvider` expone el `Future` de hidratación y `HomeScreen` lo
    espera antes de decidir si refresca (hoy evalúa `properties.isEmpty` en el
    mismo frame, así que el caché casi nunca se aprovecha).
  - `loadProperties(refresh: true)` deja de hacer `clear()` antes del await
    (elimina el parpadeo a spinner).

---

## P2 — Inventario offline completo

- [ ] **P2.8 — Full sync del inventario**
  - Paginar `/property/search` hasta agotar usando el `total` que WASI ya
    devuelve y que hoy el parser descarta (<500 propiedades ⇒ ≤5 páginas), a
    `inventory_cache.json`. TTL 6 h, refresh en background con indicador,
    conservando el anterior si falla.

- [ ] **P2.9 — Búsqueda y filtro locales**
  - Filtro y búsqueda se resuelven sobre el inventario local. Requiere añadir
    `idCity`, `idZone` e `idPropertyType` al modelo `Apartment` y al caché
    (verificar primero si `short=true` los devuelve; si no, resolver por mapeo
    etiqueta→id con los catálogos cacheados en P1.5).
  - Gana precisión sobre la API: hoy `minBanos`/`minGarages` se mandan a los
    parámetros `bathrooms`/`garages` de WASI, que son coincidencia exacta y no
    mínimo; y `min_price`/`max_price` no distinguen arriendo de venta.
  - `_applyApiFilters` se conserva como fallback para cuando no hay caché de
    inventario (primera instalación, sync en curso). Sin regresión.
  - A futuro: si el inventario creciera a 2.000–3.000, la salida no es volver a
    filtrar en WASI (que no tiene búsqueda por referencia) sino espejar el
    inventario en el backend propio con `updated_after`. Cambia la fuente del
    sync, no la capa de filtrado.

- [ ] **P2.10 — Caché de detalle solo por demanda**
  - `property_details/{id}.json` se escribe **únicamente al abrir esa
    propiedad**, TTL 24 h, revalidación en background. Nada de descarga masiva
    de galerías.
  - Tope LRU de 100 entradas + purga de las de más de 30 días.

---

## P3 — Datos, batería y subidas

- [ ] **P3.11 — Delta sync de citas** *(depende de backend propio)*
  - Endpoint a implementar: `GET /appointments?updated_after=<ISO>&include_deleted=true`,
    con `updated_at` y borrado lógico. El cliente guarda `last_appointments_sync`.
  - El `after=hoy` actual queda como fallback hasta que el endpoint exista, así
    el cliente no se bloquea. Hoy se re-descarga toda la agenda futura cada
    5 min y las citas pasadas nunca se reconcilian.

- [ ] **P3.12 — Sync consciente del lifecycle**
  - `WidgetsBindingObserver`: pausar el timer en background, sincronizar al
    volver a foreground. Hoy `stopListening()` no se llama nunca.

- [ ] **P3.13 — Caché de notas CRM**
  - `latest-notes` con TTL corto y notas por cliente con
    stale-while-revalidate. Hoy ambas van a red en cada apertura.

- [ ] **P3.14 — Autosave del borrador**
  - Codificar base64 una sola vez por ciclo (hoy `_autoSave` y `_currentData`
    llaman ambos a `_buildPhotoTuples`, con hasta 30 fotos) y pasar de
    `Timer.periodic` cada 5 s a debounce por cambio real.
  - El borrador local guarda los bytes como archivos binarios. **El envío al
    webhook sigue siendo base64 dentro del JSON, sin cambios** — es como WASI
    lo exige; la codificación ocurre una sola vez, al enviar.
  - Lectura compatible con borradores viejos que ya guardan base64.

- [ ] **P3.15 — Cola offline para clientes y notas**
  - `client/add`, `client/update`, `add-property` y creación de notas, sobre una
    cola genérica por tipo de entidad que reutiliza la compactación existente.

- [ ] **P3.16 — Limpieza**
  - Un único `Dio` compartido para WASI (hoy se instancia en 5 sitios).
  - Límites explícitos en `cached_network_image` y `url_medium` en las tarjetas
    de lista en vez de `url_big`.

---

## Notas de ejecución

- Los puntos P0.1, P0.3 y P1.5 cambian firmas de `CacheService`, `SyncService` y
  `AppointmentRepository`: hay que correr
  `dart run build_runner build --delete-conflicting-outputs` y ajustar los stubs.
  Los mocks viejos compilan pero fallan en runtime con `MissingStubError`.
- Verificación por paquete: `flutter analyze` + `flutter test`.

## Contexto

Inventario de sincronizaciones al momento del análisis: 20 endpoints (8 WASI,
10 backend propio, 2 webhooks n8n). Un arranque en frío dispara ~11 peticiones,
de las cuales ~8 traen datos que casi nunca cambian, y 4 de ellas bloquean el
primer frame.
