# Inmobarco App

Aplicación móvil Android para la gestión de propiedades y citas de **Inmobarco**, empresa inmobiliaria con operaciones en el área metropolitana de Medellín (Colombia).

> Versión actual: **1.8.8** · Plataforma: **Android** · Idioma de la UI: **Español**

---

## Funcionalidades principales

- **Catálogo de propiedades** — Listado paginado (100/página) con búsqueda en tiempo real (debounce 350 ms) y filtros avanzados: ciudad, tipo, rango de precio, habitaciones, baños, área, zona.
- **Detalle de propiedad** — Galería de fotos con zoom, descripción completa, mapa de ubicación (OpenStreetMap) y enlace de compartir.
- **Creación de propiedades** — Formulario multi-sección: información básica, ubicación con selector de mapa, precios, características, fotos y datos privados del agente.
- **Agenda de citas** — CRUD local-first de citas (visita, reunión, firma, seguimiento); vista calendario por mes/semana.
- **Sincronización offline** — Cola de mutaciones local compactada antes de cada sync; re-sincroniza al recuperar conectividad.
- **Autenticación JWT** — Login/logout con sesión persistente en SharedPreferences.
- **Notificaciones locales** — Alertas para citas programadas.

---

## Stack tecnológico

| Categoría | Tecnología |
|---|---|
| Framework | Flutter (Dart 3.8.1+) |
| State management | `provider` 6 + `ChangeNotifier` |
| HTTP | `dio` 5 |
| Caché de propiedades | `path_provider` (JSON en disco, TTL 6 h) |
| Caché de sesión/citas | `shared_preferences` |
| Mapas | `flutter_map` 7 + `latlong2` (OpenStreetMap) |
| Imágenes de red | `cached_network_image` |
| Calendario | `table_calendar` |
| Fuente tipográfica | Quicksand (`google_fonts`) |
| Localización / fechas | `intl` (locale `es_ES`, TZ `America/Bogota`) |
| Notificaciones locales | `flutter_local_notifications` |
| Conectividad | `connectivity_plus` |
| Variables de entorno | `flutter_dotenv` |
| Permisos en runtime | `permission_handler` |
| Compartir contenido | `share_plus` |
| Selector de fotos | `image_picker` |
| Versión del build | `package_info_plus` |
| Tests | `mockito` 5 + `build_runner` |
| Linting | `flutter_lints` |

---

## Arquitectura

El proyecto sigue **Clean Architecture** con tres capas bien delimitadas:

```
lib/
├── core/               # Transversal: constantes, tema, servicios globales
│   ├── constants/      # AppConstants: URLs, timeouts, ciudades, tipos de propiedad
│   ├── services/       # GlobalDataService (singleton), NotificationService
│   ├── theme/          # AppTheme, AppColors
│   └── utils/          # Formateadores de fecha y número
│
├── data/               # Comunicación externa y persistencia
│   ├── services/       # ApiService, WasiApiService, AuthService,
│   │                   #   CacheService, SyncService, WebhookService
│   └── repositories/   # AppointmentRepository
│
├── domain/             # Modelos de negocio puros
│   └── models/         # Apartment, Appointment, PropertyFilter, User,
│                       #   ApartmentPhoto, GeoLocation
│
└── ui/
    ├── providers/      # AuthProvider, PropertyProvider, AppointmentProvider
    ├── screens/        # Pantallas navegadas vía Navigator.push()
    └── widgets/        # Componentes reutilizables
```

### Integración dual de APIs

| API | Uso | Base URL |
|---|---|---|
| **WASI** (`WasiApiService`) | Propiedades (solo lectura) | `https://api.wasi.co/v1` |
| **Backend propio** (`ApiService`) | Citas, auth, complejos residenciales | Configurado en `.env` |
| **Webhook n8n** (`WebhookService`) | Notificaciones de citas | Configurado en `.env` |

### Flujo de sincronización offline

```
App inicia ──► SyncService.syncAll()
                   │
Timer 5 min ──────►│
                   │
Offline→Online ───►│── Compactar cola ──► Push al servidor ──► Actualizar local
```

La compactación elimina operaciones redundantes antes de sincronizar (ej.: `CREATE + DELETE` de la misma cita → ninguna operación).

---

## Requisitos previos

- Flutter SDK (ver `pubspec.yaml` para la versión mínima de Dart)
- Android SDK con `minSdk 21`
- Java 17
- Archivo `assets/config/.env` con las credenciales (ver sección Configuración)

---

## Configuración del entorno

Crear el archivo `assets/config/.env` con las siguientes variables (no se incluye en el repositorio):

```env
INMOBARCO_WEB_BASE_URL=https://ficha.inmobarco.com
INMOBARCO_API_URL=http://<host>:<puerto>
WASI_API_URL=https://api.wasi.co/v1
WASI_API_TOKEN=<token>
WASI_API_ID=<id_empresa>
INMOBARCO_WEBHOOK_URL=https://<host_n8n>/webhook/...
```

---

## Comandos habituales

```bash
flutter pub get                      # Instalar dependencias
flutter run                          # Ejecutar en dispositivo/emulador
flutter analyze                      # Análisis estático
flutter test                         # Ejecutar todos los tests
flutter test test/widget_test.dart   # Test específico
flutter build apk                    # APK de release
```

```bash
# Generar mocks de Mockito (necesario después de cambiar interfaces)
flutter pub run build_runner build --delete-conflicting-outputs
```

El script `build_android.bat` automatiza la secuencia completa: `clean → pub get → analyze → build apk → build appbundle`.

**Salidas del build:**
- APK: `build/app/outputs/flutter-apk/app-release.apk`
- App Bundle: `build/app/outputs/bundle/release/app-release.aab`

---

## Tests

```
test/
├── domain/models/          # Serialización y lógica de modelos
├── data/repositories/      # AppointmentRepository con mocks
├── ui/providers/           # AuthProvider, AppointmentProvider
└── widget_test.dart
```

Los mocks se generan con Mockito + `build_runner`. Al añadir o modificar interfaces, regenerar con el comando indicado arriba.

---

## Ciudades habilitadas

| ID WASI | Ciudad |
|---|---|
| 291 | Envigado |
| 496 | Medellín |
| 698 | Sabaneta |
| 416 | La Estrella |
| 389 | Itagüí |
| 89 | Bello |

---

## Pendientes (TODO)

- [ ] **Refactorizar `getZonesByCity`** — Mover de `WasiApiService` a `GlobalDataService` (o un provider dedicado) para eliminar la instanciación directa de `WasiApiService` en `add_property_screen.dart` y `property_filter_screen.dart`.
- [ ] **Cambiar el package ID** — Actualizar `com.example.inmobarco_app` al identificador de producción en `android/app/build.gradle.kts`.
- [ ] **Notificaciones push remotas** — Integrar Firebase Cloud Messaging (FCM); actualmente solo hay notificaciones locales.
- [ ] **CI/CD** — Configurar GitHub Actions para análisis + build automático en cada push.
- [ ] **Firma del APK** — Configurar `keystore` y variables de entorno para builds de release firmados en el script `build_android.bat`.
- [ ] **Cobertura de tests** — Ampliar tests de widgets y tests de integración para los flujos principales (login, lista de propiedades, creación de citas).

---

## Estructura de pantallas

| Pantalla | Ruta | Auth |
|---|---|---|
| `HomeScreen` | Raíz (tabs) | No |
| `LoginScreen` | Tab o push | No |
| `PropertyListScreen` | Tab Propiedades | No |
| `PropertyDetailScreen` | Push desde lista | No |
| `PropertyFilterScreen` | Push desde lista | No |
| `AddPropertyScreen` | Push desde FAB | Sí |
| `CalendarScreen` | Tab Agenda | Sí |
| `AddAppointmentScreen` | Push desde agenda | Sí |
| `MapPickerScreen` | Push desde formulario | No |
| `PermissionsScreen` | Push on-demand | No |
