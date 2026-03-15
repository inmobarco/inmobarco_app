import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/utils/formatters.dart';

class PricingSection extends StatelessWidget {
  final TextEditingController rentPriceController;
  final TextEditingController salePriceController;
  final TextEditingController areaController;
  final String operation;
  final String bedrooms;
  final String bathrooms;
  final String garages;
  final ValueChanged<String> onBedroomsChanged;
  final ValueChanged<String> onBathroomsChanged;
  final ValueChanged<String> onGaragesChanged;

  const PricingSection({
    super.key,
    required this.rentPriceController,
    required this.salePriceController,
    required this.areaController,
    required this.operation,
    required this.bedrooms,
    required this.bathrooms,
    required this.garages,
    required this.onBedroomsChanged,
    required this.onBathroomsChanged,
    required this.onGaragesChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Precios
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: rentPriceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Precio arriendo',
                  border: OutlineInputBorder(),
                ),
                inputFormatters: const [
                  ThousandsSeparatorFormatter(),
                ],
                validator: (v) {
                  final d = digitsOnly(v ?? '');
                  if (operation == 'alquiler' && d.isEmpty) {
                    return 'Ingrese el precio de arriendo';
                  }
                  if (d.isEmpty && (v ?? '').trim().isNotEmpty) {
                    return 'Solo números';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: salePriceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Precio venta',
                  border: OutlineInputBorder(),
                ),
                inputFormatters: const [
                  ThousandsSeparatorFormatter(),
                ],
                validator: (v) {
                  final d = digitsOnly(v ?? '');
                  if (operation == 'venta' && d.isEmpty) {
                    return 'Ingrese el precio de venta';
                  }
                  if (d.isEmpty && (v ?? '').trim().isNotEmpty) {
                    return 'Solo números';
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
      ],
    );
  }
}
