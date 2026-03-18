import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/utils/formatters.dart';

class FeaturesSection extends StatelessWidget {
  final TextEditingController areaController;
  final TextEditingController buildingDateController;
  final TextEditingController promptsController;
  final String propertyConditionId;
  final List<Map<String, String>> propertyConditions;
  final ValueChanged<String> onPropertyConditionChanged;
  final String bedrooms;
  final String bathrooms;
  final String garages;
  final ValueChanged<String> onBedroomsChanged;
  final ValueChanged<String> onBathroomsChanged;
  final ValueChanged<String> onGaragesChanged;
  final Set<String> selectedFeatureIds;
  final String featureSummaryText;
  final bool loadingFeatures;
  final VoidCallback onOpenFeatureSelector;
  final VoidCallback onClearSelection;

  const FeaturesSection({
    super.key,
    required this.areaController,
    required this.buildingDateController,
    required this.promptsController,
    required this.propertyConditionId,
    required this.propertyConditions,
    required this.onPropertyConditionChanged,
    required this.bedrooms,
    required this.bathrooms,
    required this.garages,
    required this.onBedroomsChanged,
    required this.onBathroomsChanged,
    required this.onGaragesChanged,
    required this.selectedFeatureIds,
    required this.featureSummaryText,
    required this.loadingFeatures,
    required this.onOpenFeatureSelector,
    required this.onClearSelection,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Condición + Año de construcción
        Row(
          children: [
            Expanded(
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Condición',
                  border: OutlineInputBorder(),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isDense: true,
                    value: propertyConditionId,
                    isExpanded: true,
                    items: propertyConditions
                        .map(
                          (c) => DropdownMenuItem(
                            value: c['id'],
                            child: Text(
                              '${c['id']}. ${c['label']}',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      onPropertyConditionChanged(value);
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: buildingDateController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Año de construcción',
                  border: OutlineInputBorder(),
                  hintText: 'Ej: 2015',
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                validator: (v) {
                  final raw = (v ?? '').trim();
                  if (raw.isEmpty) {
                    return 'Ingrese el año de construcción';
                  }
                  final d = digitsOnly(raw, maxLength: 4);
                  if (d.length != 4) {
                    return 'Ingrese un año válido (4 dígitos)';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Habitaciones + Baños
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: bedrooms,
                decoration: const InputDecoration(
                  labelText: 'Habitaciones',
                  border: OutlineInputBorder(),
                ),
                isExpanded: true,
                items: List.generate(10, (index) {
                  final value = (index + 1).toString();
                  return DropdownMenuItem(
                    value: value,
                    child: Text(value),
                  );
                }),
                onChanged: (value) {
                  if (value == null) return;
                  onBedroomsChanged(value);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: bathrooms,
                decoration: const InputDecoration(
                  labelText: 'Baños',
                  border: OutlineInputBorder(),
                ),
                isExpanded: true,
                items: List.generate(10, (index) {
                  final value = (index + 1).toString();
                  return DropdownMenuItem(
                    value: value,
                    child: Text(value),
                  );
                }),
                onChanged: (value) {
                  if (value == null) return;
                  onBathroomsChanged(value);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Parqueaderos + Área
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: garages,
                decoration: const InputDecoration(
                  labelText: 'Parqueaderos',
                  border: OutlineInputBorder(),
                ),
                isExpanded: true,
                items: List.generate(10, (index) {
                  final value = index.toString();
                  return DropdownMenuItem(
                    value: value,
                    child: Text(value),
                  );
                }),
                onChanged: (value) {
                  if (value == null) return;
                  onGaragesChanged(value);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: areaController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Área (m²)',
                  border: OutlineInputBorder(),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[0-9.,]'),
                  ),
                ],
                validator: (v) {
                  final numeric = numericString(v ?? '');
                  if (numeric.isEmpty) return 'Ingrese el área';
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Características
        if (loadingFeatures)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else ...[
          OutlinedButton.icon(
            icon: const Icon(Icons.list_alt),
            label: const Text('Seleccionar características'),
            onPressed: onOpenFeatureSelector,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              featureSummaryText,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (selectedFeatureIds.isNotEmpty)
            TextButton(
              onPressed: onClearSelection,
              child: const Text('Limpiar selección'),
            ),
        ],
        const SizedBox(height: 16),
        TextFormField(
          controller: promptsController,
          decoration: const InputDecoration(
            labelText: 'Prompts / Descripciones adicionales para IA',
            border: OutlineInputBorder(),
          ),
          maxLines: 4,
        ),
      ],
    );
  }
}
