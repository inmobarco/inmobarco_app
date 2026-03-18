import 'package:flutter/material.dart';
import '../../../core/utils/formatters.dart';

class PricingSection extends StatelessWidget {
  final TextEditingController rentPriceController;
  final TextEditingController salePriceController;
  final bool forRent;
  final bool forSale;
  final String statusOnPageId;
  final List<Map<String, String>> statusOptions;
  final ValueChanged<bool> onForRentChanged;
  final ValueChanged<bool> onForSaleChanged;
  final ValueChanged<String> onStatusChanged;

  const PricingSection({
    super.key,
    required this.rentPriceController,
    required this.salePriceController,
    required this.forRent,
    required this.forSale,
    required this.statusOnPageId,
    required this.statusOptions,
    required this.onForRentChanged,
    required this.onForSaleChanged,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tipo de negocio + Disponibilidad
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tipo de negocio',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('Alquiler'),
                        selected: forRent,
                        onSelected: (selected) {
                          if (!selected && !forSale) return;
                          onForRentChanged(selected);
                        },
                      ),
                      FilterChip(
                        label: const Text('Venta'),
                        selected: forSale,
                        onSelected: (selected) {
                          if (!selected && !forRent) return;
                          onForSaleChanged(selected);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Disponibilidad',
                  border: OutlineInputBorder(),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isDense: true,
                    value: statusOnPageId,
                    isExpanded: true,
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
        // Precios
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: rentPriceController,
                enabled: forRent,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Precio arriendo',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: forRent ? Colors.white : Colors.grey.shade100,
                ),
                inputFormatters: const [
                  ThousandsSeparatorFormatter(),
                ],
                validator: (v) {
                  if (!forRent) return null;
                  final d = digitsOnly(v ?? '');
                  if (d.isEmpty) return 'Ingrese el precio de arriendo';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: salePriceController,
                enabled: forSale,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Precio venta',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: forSale ? Colors.white : Colors.grey.shade100,
                ),
                inputFormatters: const [
                  ThousandsSeparatorFormatter(),
                ],
                validator: (v) {
                  if (!forSale) return null;
                  final d = digitsOnly(v ?? '');
                  if (d.isEmpty) return 'Ingrese el precio de venta';
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
