import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';

class PrivateDataSection extends StatelessWidget {
  final TextEditingController observationsController;
  final TextEditingController landlordNameController;
  final TextEditingController landlordPhoneController;
  final TextEditingController keysController;
  final TextEditingController adminMailController;
  final TextEditingController adminPhoneController;
  final TextEditingController lodgePhoneController;
  final TextEditingController porterNameController;
  final TextEditingController porterPhoneController;
  final bool hasVeredalWater;
  final bool hasGasInstallation;
  final bool hasLegalizacionEpm;
  final bool hasInternetOperators;
  final bool isSubmitting;
  final bool cooldownActive;
  final bool fieldsLockedByComplex;
  final Map<String, dynamic>? selectedComplex;
  final DateTime? lastSaved;
  final ValueChanged<bool> onVeredalWaterChanged;
  final ValueChanged<bool> onGasInstallationChanged;
  final ValueChanged<bool> onLegalizacionEpmChanged;
  final ValueChanged<bool> onInternetOperatorsChanged;
  final VoidCallback onSavePressed;

  const PrivateDataSection({
    super.key,
    required this.observationsController,
    required this.landlordNameController,
    required this.landlordPhoneController,
    required this.keysController,
    required this.adminMailController,
    required this.adminPhoneController,
    required this.lodgePhoneController,
    required this.porterNameController,
    required this.porterPhoneController,
    required this.hasVeredalWater,
    required this.hasGasInstallation,
    required this.hasLegalizacionEpm,
    required this.hasInternetOperators,
    required this.isSubmitting,
    required this.cooldownActive,
    required this.fieldsLockedByComplex,
    required this.selectedComplex,
    required this.lastSaved,
    required this.onVeredalWaterChanged,
    required this.onGasInstallationChanged,
    required this.onLegalizacionEpmChanged,
    required this.onInternetOperatorsChanged,
    required this.onSavePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Observaciones
        TextFormField(
          controller: observationsController,
          decoration: const InputDecoration(
            labelText: 'Observaciones / Comentarios internos',
            border: OutlineInputBorder(),
          ),
          maxLines: 4,
        ),
        const SizedBox(height: 16),
        // Checkboxes
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: CheckboxListTile(
                value: hasVeredalWater,
                onChanged: isSubmitting
                    ? null
                    : (checked) => onVeredalWaterChanged(checked ?? false),
                title: const Text('Agua veredal'),
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CheckboxListTile(
                value: hasGasInstallation,
                onChanged: isSubmitting
                    ? null
                    : (checked) => onGasInstallationChanged(checked ?? false),
                title: const Text('Instalación gas cubierta'),
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: CheckboxListTile(
                value: hasLegalizacionEpm,
                onChanged: isSubmitting
                    ? null
                    : (checked) => onLegalizacionEpmChanged(checked ?? false),
                title: const Text('Legalización EPM'),
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CheckboxListTile(
                value: hasInternetOperators,
                onChanged: isSubmitting
                    ? null
                    : (checked) => onInternetOperatorsChanged(checked ?? false),
                title: const Text('Operadores de internet'),
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Propietario
        TextFormField(
          controller: landlordNameController,
          decoration: const InputDecoration(
            labelText: 'Nombre propietario *',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'El nombre del propietario es obligatorio';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: landlordPhoneController,
          decoration: const InputDecoration(
            labelText: 'Celular propietario *',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'El celular del propietario es obligatorio';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        // Llaves
        TextFormField(
          controller: keysController,
          decoration: const InputDecoration(
            labelText: 'Llaves',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: 16),
        // Admin
        TextFormField(
          controller: adminMailController,
          decoration: InputDecoration(
            labelText: 'Correo Admin',
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: (fieldsLockedByComplex && selectedComplex?['admin_email'] != null)
                ? AppColors.gray
                : AppColors.backgroundLevel1,
          ),
          readOnly: fieldsLockedByComplex && selectedComplex?['admin_email'] != null,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: adminPhoneController,
          decoration: InputDecoration(
            labelText: 'Celular Admin',
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: (fieldsLockedByComplex && selectedComplex?['admin_phone'] != null)
                ? AppColors.gray
                : AppColors.backgroundLevel1,
          ),
          readOnly: fieldsLockedByComplex && selectedComplex?['admin_phone'] != null,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
        ),
        const SizedBox(height: 16),
        // Portería
        TextFormField(
          controller: lodgePhoneController,
          decoration: InputDecoration(
            labelText: 'Celular Porteria',
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: (fieldsLockedByComplex && selectedComplex?['front_desk_phone'] != null)
                ? AppColors.gray
                : AppColors.backgroundLevel1,
          ),
          readOnly: fieldsLockedByComplex && selectedComplex?['front_desk_phone'] != null,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
        ),
        const SizedBox(height: 16),
        // Portero
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: porterNameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre portero',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: porterPhoneController,
                decoration: const InputDecoration(
                  labelText: 'Numero portero',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Botón Captar
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Captar!'),
            onPressed: (isSubmitting || cooldownActive) ? null : onSavePressed,
          ),
        ),
        if (lastSaved != null) ...[
          const SizedBox(height: 12),
          Text(
            'Último guardado automático: ${lastSaved!.hour.toString().padLeft(2, '0')}:${lastSaved!.minute.toString().padLeft(2, '0')}:${lastSaved!.second.toString().padLeft(2, '0')}',
            style: const TextStyle(
              color: AppColors.textColor2,
            ),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}
