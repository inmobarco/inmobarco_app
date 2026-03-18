import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/models/geo_location.dart';

/// Pantalla fullscreen para seleccionar una ubicación en el mapa.
///
/// Retorna un [GeoLocation] al confirmar, o `null` al cancelar.
/// Para migrar a Google Maps, reemplazar solo esta pantalla.
class MapPickerScreen extends StatefulWidget {
  /// Coordenada inicial (centro de la ciudad seleccionada o Medellín).
  final double initialLatitude;
  final double initialLongitude;

  /// Ubicación previamente seleccionada (si existe, centra allí).
  final GeoLocation? currentLocation;

  const MapPickerScreen({
    super.key,
    required this.initialLatitude,
    required this.initialLongitude,
    this.currentLocation,
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  late final MapController _mapController;
  LatLng? _centerPosition;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  LatLng get _initialCenter {
    if (widget.currentLocation != null) {
      return LatLng(
        widget.currentLocation!.latitude,
        widget.currentLocation!.longitude,
      );
    }
    return LatLng(widget.initialLatitude, widget.initialLongitude);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Mapa ──────────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: 16.0,
              minZoom: 10.0,
              maxZoom: 19.0,
              onPositionChanged: (position, hasGesture) {
                setState(() => _centerPosition = position.center);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.inmobarco.app',
              ),
            ],
          ),

          // ── Pin fijo en el centro ─────────────────────────────────────
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 36),
              child: Icon(
                Icons.location_pin,
                size: 48,
                color: AppColors.error,
              ),
            ),
          ),

          // ── Sombra del pin ────────────────────────────────────────────
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          // ── Botón volver ──────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: CircleAvatar(
              backgroundColor: AppColors.backgroundLevel1,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // ── Coordenadas en tiempo real ────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.backgroundLevel1.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _formatCoordinates(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textColor,
                ),
              ),
            ),
          ),

          // ── Botones confirmar / cancelar ──────────────────────────────
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 16,
            left: 16,
            right: 16,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: const Text('Cancelar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textColor,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppConstants.buttonBorderRadius,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _confirmLocation,
                    icon: const Icon(Icons.check),
                    label: const Text('Confirmar ubicación'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: AppColors.pureWhite,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppConstants.buttonBorderRadius,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatCoordinates() {
    final center = _centerPosition ?? _initialCenter;
    return '${center.latitude.toStringAsFixed(5)}, ${center.longitude.toStringAsFixed(5)}';
  }

  void _confirmLocation() {
    final center = _centerPosition ?? _initialCenter;
    Navigator.pop(
      context,
      GeoLocation(latitude: center.latitude, longitude: center.longitude),
    );
  }
}
