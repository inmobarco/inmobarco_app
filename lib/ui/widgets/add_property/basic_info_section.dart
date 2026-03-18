import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';

class BasicInfoSection extends StatelessWidget {
  final TextEditingController apartmentNumberController;
  final TextEditingController unitNameController;
  final bool isResidentialComplex;
  final bool isManualUnitName;
  final bool fieldsLockedByComplex;
  final bool unitNameHasError;
  final int? selectedComplexId;
  final List<Map<String, dynamic>> residentialComplexes;
  final bool isSubmitting;
  final String propertyTypeId;
  final List<Map<String, String>> propertyTypes;
  final Set<String> enabledPropertyTypeIds;
  final ValueChanged<String> onPropertyTypeChanged;
  final ValueChanged<bool> onIsResidentialComplexChanged;
  final ValueChanged<Map<String, dynamic>> onComplexSelected;
  final VoidCallback onEnableManualUnitName;
  final VoidCallback onDisableManualUnitName;

  const BasicInfoSection({
    super.key,
    required this.apartmentNumberController,
    required this.unitNameController,
    required this.isResidentialComplex,
    required this.isManualUnitName,
    required this.fieldsLockedByComplex,
    required this.unitNameHasError,
    required this.selectedComplexId,
    required this.residentialComplexes,
    required this.isSubmitting,
    required this.propertyTypeId,
    required this.propertyTypes,
    required this.enabledPropertyTypeIds,
    required this.onPropertyTypeChanged,
    required this.onIsResidentialComplexChanged,
    required this.onComplexSelected,
    required this.onEnableManualUnitName,
    required this.onDisableManualUnitName,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Número de apartamento + Tipo de inmueble
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: TextFormField(
                controller: apartmentNumberController,
                decoration: const InputDecoration(
                  labelText: 'Núm de apartamento',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                validator: (v) {
                  final d = digitsOnly(v ?? '');
                  if (d.isEmpty) {
                    return 'Ingrese el número de apartamento';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 4,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Inmueble',
                  border: OutlineInputBorder(),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isDense: true,
                    value: propertyTypeId,
                    isExpanded: true,
                    items: propertyTypes
                        .where((t) => enabledPropertyTypeIds.contains(t['id']))
                        .map(
                          (t) => DropdownMenuItem<String>(
                            value: t['id'],
                            child: Text(
                              t['label'] ?? '',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      onPropertyTypeChanged(value);
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Unidad Residencial
        Text(
          'Unidad Residencial',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 40,
              child: Checkbox(
                value: isResidentialComplex,
                onChanged: (v) => onIsResidentialComplexChanged(v ?? false),
              ),
            ),
            Expanded(
              child: IgnorePointer(
                ignoring: !isResidentialComplex,
                child: Opacity(
                  opacity: isResidentialComplex ? 1.0 : 0.4,
                  child: isManualUnitName || residentialComplexes.isEmpty
                      ? TextFormField(
                          controller: unitNameController,
                          decoration: InputDecoration(
                            labelText: 'Nombre de la unidad',
                            border: const OutlineInputBorder(),
                            hintText: 'Ingrese el nombre manualmente',
                            suffixIcon: residentialComplexes.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.list, size: 20),
                                    tooltip: 'Seleccionar de lista',
                                    onPressed: onDisableManualUnitName,
                                  )
                                : null,
                          ),
                          textCapitalization: TextCapitalization.words,
                          validator: (v) {
                            if (!isResidentialComplex) return null;
                            if (v == null || v.trim().isEmpty) {
                              return 'Ingrese el nombre de la unidad';
                            }
                            return null;
                          },
                        )
                      : InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Nombre de la unidad',
                            border: OutlineInputBorder(
                              borderSide: unitNameHasError
                                  ? const BorderSide(color: AppColors.error, width: 2)
                                  : const BorderSide(),
                            ),
                            enabledBorder: unitNameHasError
                                ? const OutlineInputBorder(
                                    borderSide: BorderSide(color: AppColors.error, width: 2),
                                  )
                                : null,
                            errorText: unitNameHasError
                                ? 'Seleccione una unidad residencial'
                                : null,
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              isDense: true,
                              value: selectedComplexId,
                              isExpanded: true,
                              hint: const Text('Seleccione una unidad'),
                              items: residentialComplexes.map((complex) {
                                return DropdownMenuItem<int>(
                                  value: complex['id'] as int,
                                  child: Text(
                                    complex['name']?.toString() ?? '',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                final complex = residentialComplexes.firstWhere(
                                  (c) => c['id'] == value,
                                );
                                onComplexSelected(complex);
                              },
                            ),
                          ),
                        ),
                ),
              ),
            ),
            if (isResidentialComplex && !isManualUnitName && residentialComplexes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  tooltip: 'Ingresar nueva unidad',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.gray,
                  ),
                  onPressed: onEnableManualUnitName,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
