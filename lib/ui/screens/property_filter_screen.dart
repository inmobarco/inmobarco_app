import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/property_provider.dart';
import '../../domain/models/property_filter.dart';
import '../../core/theme/app_colors.dart';

class PropertyFilterScreen extends StatefulWidget {
  const PropertyFilterScreen({super.key});

  @override
  State<PropertyFilterScreen> createState() => _PropertyFilterScreenState();
}

class _PropertyFilterScreenState extends State<PropertyFilterScreen> {
  late PropertyFilter _currentFilter;
  final _minPriceController = TextEditingController();
  final _maxPriceController = TextEditingController();
  final _minAreaController = TextEditingController();
  final _maxAreaController = TextEditingController();
  
  int? _selectedMinCuartos;
  int? _selectedMaxCuartos;
  int? _selectedMinBanos;
  int? _selectedMaxBanos;
  String? _selectedMunicipio;
  String? _selectedEstrato;

  @override
  void initState() {
    super.initState();
    _currentFilter = context.read<PropertyProvider>().currentFilter;
    _initializeValues();
  }

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    _minAreaController.dispose();
    _maxAreaController.dispose();
    super.dispose();
  }

  void _initializeValues() {
    _selectedMinCuartos = _currentFilter.minCuartos;
    _selectedMaxCuartos = _currentFilter.maxCuartos;
    _selectedMinBanos = _currentFilter.minBanos;
    _selectedMaxBanos = _currentFilter.maxBanos;
    _selectedMunicipio = _currentFilter.municipio;
    _selectedEstrato = _currentFilter.estrato;
    
    if (_currentFilter.minPrecio != null) {
      _minPriceController.text = _currentFilter.minPrecio!.toStringAsFixed(0);
    }
    if (_currentFilter.maxPrecio != null) {
      _maxPriceController.text = _currentFilter.maxPrecio!.toStringAsFixed(0);
    }
    if (_currentFilter.minArea != null) {
      _minAreaController.text = _currentFilter.minArea!.toStringAsFixed(0);
    }
    if (_currentFilter.maxArea != null) {
      _maxAreaController.text = _currentFilter.maxArea!.toStringAsFixed(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.backgroundLevel1,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) {
          return Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textColor2,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filtros',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    TextButton(
                      onPressed: _clearFilters,
                      child: const Text('Limpiar todo'),
                    ),
                  ],
                ),
              ),
              
              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cuartos
                      _buildSectionTitle('Número de cuartos'),
                      _buildRoomSelector(
                        'Mínimo',
                        _selectedMinCuartos,
                        (value) => setState(() => _selectedMinCuartos = value),
                      ),
                      const SizedBox(height: 8),
                      _buildRoomSelector(
                        'Máximo',
                        _selectedMaxCuartos,
                        (value) => setState(() => _selectedMaxCuartos = value),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Baños
                      _buildSectionTitle('Número de baños'),
                      _buildBathSelector(
                        'Mínimo',
                        _selectedMinBanos,
                        (value) => setState(() => _selectedMinBanos = value),
                      ),
                      const SizedBox(height: 8),
                      _buildBathSelector(
                        'Máximo',
                        _selectedMaxBanos,
                        (value) => setState(() => _selectedMaxBanos = value),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Precio
                      _buildSectionTitle('Rango de precio'),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _minPriceController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Precio mínimo',
                                prefixText: '\$ ',
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: _maxPriceController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Precio máximo',
                                prefixText: '\$ ',
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Municipio
                      _buildSectionTitle('Municipio'),
                      _buildMunicipioDropdown(),
                      
                      const SizedBox(height: 24),
                      
                      // Estrato
                      _buildSectionTitle('Estrato'),
                      _buildEstratoSelector(),
                      
                      const SizedBox(height: 24),
                      
                      // Área
                      _buildSectionTitle('Área (m²)'),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _minAreaController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Área mínima',
                                suffixText: 'm²',
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: _maxAreaController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Área máxima',
                                suffixText: 'm²',
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
              
              // Actions
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _applyFilters,
                        child: const Text('Aplicar filtros'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildRoomSelector(String label, int? selected, Function(int?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            _buildSelectableChip(
              'Cualquiera',
              selected == null,
              () => onChanged(null),
            ),
            ...List.generate(6, (index) {
              final value = index + 1;
              return _buildSelectableChip(
                value.toString(),
                selected == value,
                () => onChanged(value),
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildBathSelector(String label, int? selected, Function(int?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            _buildSelectableChip(
              'Cualquiera',
              selected == null,
              () => onChanged(null),
            ),
            ...List.generate(4, (index) {
              final value = index + 1;
              return _buildSelectableChip(
                value.toString(),
                selected == value,
                () => onChanged(value),
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildSelectableChip(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryColor : AppColors.backgroundLevel2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primaryColor : AppColors.textColor2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.white : AppColors.textColor,
            fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildMunicipioDropdown() {
    return Consumer<PropertyProvider>(
      builder: (context, provider, child) {
        return DropdownButtonFormField<String>(
          value: _selectedMunicipio,
          decoration: const InputDecoration(
            labelText: 'Seleccionar municipio',
          ),
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('Todos los municipios'),
            ),
            ...provider.municipios.map((municipio) {
              return DropdownMenuItem(
                value: municipio,
                child: Text(municipio),
              );
            }),
          ],
          onChanged: (value) {
            setState(() {
              _selectedMunicipio = value;
            });
          },
        );
      },
    );
  }

  Widget _buildEstratoSelector() {
    return Consumer<PropertyProvider>(
      builder: (context, provider, child) {
        return Wrap(
          spacing: 8,
          children: [
            _buildSelectableChip(
              'Cualquiera',
              _selectedEstrato == null,
              () => setState(() => _selectedEstrato = null),
            ),
            ...provider.estratos.map((estrato) {
              return _buildSelectableChip(
                'Estrato $estrato',
                _selectedEstrato == estrato,
                () => setState(() => _selectedEstrato = estrato),
              );
            }),
          ],
        );
      },
    );
  }

  void _clearFilters() {
    setState(() {
      _selectedMinCuartos = null;
      _selectedMaxCuartos = null;
      _selectedMinBanos = null;
      _selectedMaxBanos = null;
      _selectedMunicipio = null;
      _selectedEstrato = null;
      _minPriceController.clear();
      _maxPriceController.clear();
      _minAreaController.clear();
      _maxAreaController.clear();
    });
  }

  void _applyFilters() {
    final newFilter = PropertyFilter(
      minCuartos: _selectedMinCuartos,
      maxCuartos: _selectedMaxCuartos,
      minBanos: _selectedMinBanos,
      maxBanos: _selectedMaxBanos,
      minPrecio: _minPriceController.text.isNotEmpty
          ? double.tryParse(_minPriceController.text.replaceAll(',', ''))
          : null,
      maxPrecio: _maxPriceController.text.isNotEmpty
          ? double.tryParse(_maxPriceController.text.replaceAll(',', ''))
          : null,
      municipio: _selectedMunicipio,
      estrato: _selectedEstrato,
      minArea: _minAreaController.text.isNotEmpty
          ? double.tryParse(_minAreaController.text)
          : null,
      maxArea: _maxAreaController.text.isNotEmpty
          ? double.tryParse(_maxAreaController.text)
          : null,
    );

    context.read<PropertyProvider>().updateFilter(newFilter);
    Navigator.pop(context);
  }
}
