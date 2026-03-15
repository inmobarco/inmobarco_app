import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';

class BasicInfoSection extends StatelessWidget {
  final TextEditingController apartmentNumberController;
  final TextEditingController unitNameController;
  final TextEditingController buildingDateController;
  final String operation;
  final String statusOnPageId;
  final String propertyConditionId;
  final bool isManualUnitName;
  final bool fieldsLockedByComplex;
  final bool unitNameHasError;
  final int? selectedComplexId;
  final List<Map<String, dynamic>> residentialComplexes;
  final List<Map<String, String>> propertyConditions;
  final List<Map<String, String>> statusOptions;
  final bool isSubmitting;
  final ValueChanged<String> onOperationChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onPropertyConditionChanged;
  final ValueChanged<Map<String, dynamic>> onComplexSelected;
  final VoidCallback onEnableManualUnitName;

  const BasicInfoSection({
    super.key,
    required this.apartmentNumberController,
    required this.unitNameController,
    required this.buildingDateController,
    required this.operation,
    required this.statusOnPageId,
    required this.propertyConditionId,
    required this.isManualUnitName,
    required this.fieldsLockedByComplex,
    required this.unitNameHasError,
    required this.selectedComplexId,
    required this.residentialComplexes,
    required this.propertyConditions,
    required this.statusOptions,
    required this.isSubmitting,
    required this.onOperationChanged,
    required this.onStatusChanged,
    required this.onPropertyConditionChanged,
    required this.onComplexSelected,
    required this.onEnableManualUnitName,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Número de apartamento
        TextFormField(
          controller: apartmentNumberController,
          decoration: const InputDecoration(
            labelText: 'Número de apartamento',
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
        const SizedBox(height: 16),
        // Nombre de la unidad: dropdown o campo manual
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
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
                                onPressed: onEnableManualUnitName,
                              )
                            : null,
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) {
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
            if (!isManualUnitName && residentialComplexes.isNotEmpty)
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
        const SizedBox(height: 16),
        // Tipo de negocio + Disponibilidad
        Row(
          children: [
            Expanded(
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Tipo de negocio',
                  border: OutlineInputBorder(),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isDense: true,
                    value: operation,
                    items: const [
                      DropdownMenuItem(
                        value: 'alquiler',
                        child: Text('Alquiler'),
                      ),
                      DropdownMenuItem(
                        value: 'venta',
                        child: Text('Venta'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      onOperationChanged(value);
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Disponibilidad',
                  border: OutlineInputBorder(),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isDense: true,
                    value: statusOnPageId,
                    items: statusOptions
                        .map(
                          (option) => DropdownMenuItem<String>(
                            value: option['id'],
                            child: Text(option['label'] ?? ''),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      onStatusChanged(value);
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Condición + Año de construcción
        Row(
          children: [
            Expanded(
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Condición de la propiedad',
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
      ],
    );
  }
}
