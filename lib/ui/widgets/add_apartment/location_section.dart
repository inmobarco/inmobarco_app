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
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ciudad
        InputDecorator(
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
                  height: 40,
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isDense: true,
                    value: selectedCityId,
                    isExpanded: true,
                    hint: const Text('Seleccione ciudad'),
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
        const SizedBox(height: 16),
        // Zona + Estrato
        Row(
          children: [
            Expanded(
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
                    ? const Text('Seleccione primero una ciudad')
                    : loadingZones
                    ? const SizedBox(
                        height: 40,
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isDense: true,
                          value: selectedZoneId,
                          isExpanded: true,
                          hint: const Text('Seleccione zona (opcional)'),
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
            const SizedBox(width: 12),
            Expanded(
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
          ],
        ),
        const SizedBox(height: 16),
        // Dirección
        TextFormField(
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
      ],
    );
  }
}
