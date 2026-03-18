import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class LocationSection extends StatelessWidget {
  final TextEditingController addressController;
  final String? selectedCityId;
  final String? selectedZoneId;
  final String stratum;
  final List<Map<String, dynamic>> cities;
  final List<Map<String, dynamic>> zones;
  final bool loadingCities;
  final bool loadingZones;
  final bool fieldsLockedByComplex;
  final Map<String, dynamic>? selectedComplex;
  final ValueChanged<String?> onCityChanged;
  final ValueChanged<String?> onZoneChanged;
  final ValueChanged<String> onStratumChanged;
  final double? selectedLatitude;
  final double? selectedLongitude;
  final bool locationLockedByComplex;
  final VoidCallback onPickLocation;

  const LocationSection({
    super.key,
    required this.addressController,
    required this.selectedCityId,
    required this.selectedZoneId,
    required this.stratum,
    required this.cities,
    required this.zones,
    required this.loadingCities,
    required this.loadingZones,
    required this.fieldsLockedByComplex,
    required this.selectedComplex,
    required this.onCityChanged,
    required this.onZoneChanged,
    required this.onStratumChanged,
    required this.selectedLatitude,
    required this.selectedLongitude,
    required this.locationLockedByComplex,
    required this.onPickLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ciudad + Zona/Barrio
        Row(
          children: [
            Expanded(
              flex: 4,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Ciudad',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: (fieldsLockedByComplex && selectedCityId != null)
                      ? AppColors.gray
                      : AppColors.backgroundLevel1,
                ),
                child: loadingCities
                    ? const SizedBox(
                        height: 20,
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isDense: true,
                          value: selectedCityId,
                          isExpanded: true,
                          hint: const Text('Ciudad'),
                          items: cities
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c['id'] as String,
                                  child: Text(c['name'] as String),
                                ),
                              )
                              .toList(),
                          onChanged: (fieldsLockedByComplex && selectedCityId != null)
                              ? null
                              : onCityChanged,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 6,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Zona / Barrio',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: (fieldsLockedByComplex && selectedZoneId != null)
                      ? AppColors.gray
                      : AppColors.backgroundLevel1,
                ),
                child: (selectedCityId == null)
                    ? const Text(
                        'Seleccione ciudad',
                        style: TextStyle(fontSize: 12),
                      )
                    : loadingZones
                    ? const SizedBox(
                        height: 20,
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isDense: true,
                          value: selectedZoneId,
                          isExpanded: true,
                          hint: const Text('Barrio (Obligatorio)'),
                          items: zones
                              .map(
                                (z) => DropdownMenuItem(
                                  value: z['id'] as String,
                                  child: Text(z['name'] as String),
                                ),
                              )
                              .toList(),
                          onChanged: (fieldsLockedByComplex && selectedZoneId != null)
                              ? null
                              : onZoneChanged,
                        ),
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Estrato + Dirección
        Row(
          children: [
            SizedBox(
              width: 80,
              child: DropdownButtonFormField<String>(
                value: stratum,
                decoration: InputDecoration(
                  labelText: 'Estrato',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: (fieldsLockedByComplex && selectedComplex?['stratum'] != null)
                      ? AppColors.gray
                      : AppColors.backgroundLevel1,
                ),
                isExpanded: true,
                items: List.generate(6, (index) {
                  final value = (index + 1).toString();
                  return DropdownMenuItem(
                    value: value,
                    child: Text(value),
                  );
                }),
                onChanged: (fieldsLockedByComplex && selectedComplex?['stratum'] != null)
                    ? null
                    : (value) {
                        if (value == null) return;
                        onStratumChanged(value);
                      },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: addressController,
                decoration: InputDecoration(
                  labelText: 'Dirección',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: (fieldsLockedByComplex && addressController.text.isNotEmpty)
                      ? AppColors.gray
                      : AppColors.backgroundLevel1,
                ),
                readOnly: fieldsLockedByComplex && addressController.text.isNotEmpty,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Ingrese la dirección'
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Geolocalización
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(4),
                  color: locationLockedByComplex
                      ? AppColors.gray
                      : AppColors.backgroundLevel1,
                ),
                child: Row(
                  children: [
                    Icon(
                      selectedLatitude != null
                          ? Icons.location_on
                          : Icons.location_off_outlined,
                      size: 20,
                      color: selectedLatitude != null
                          ? AppColors.success
                          : AppColors.textColor2,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        selectedLatitude != null
                            ? '${selectedLatitude!.toStringAsFixed(5)}, ${selectedLongitude!.toStringAsFixed(5)}'
                            : 'Sin ubicación',
                        style: TextStyle(
                          fontSize: 13,
                          color: selectedLatitude != null
                              ? AppColors.textColor
                              : AppColors.textColor2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 42,
              child: ElevatedButton.icon(
                onPressed: locationLockedByComplex ? null : onPickLocation,
                icon: const Icon(Icons.map_outlined, size: 18),
                label: Text(
                  selectedLatitude != null ? 'Cambiar' : 'Seleccionar',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: AppColors.pureWhite,
                  textStyle: const TextStyle(fontSize: 13),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
