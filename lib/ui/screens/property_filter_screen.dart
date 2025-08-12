import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/property_provider.dart';
import '../../domain/models/property_filter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';

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
  final _ciudadController = TextEditingController(); // Agregado para controlar el campo de ciudad
  
  int? _selectedMinCuartos;
  int? _selectedMinBanos;
  int? _selectedMinGarages;
  String? _selectedCiudad;
  bool? _forRent;
  bool? _forSale;


  @override
  void initState() {
    super.initState();
    _currentFilter = context.read<PropertyProvider>().currentFilter;
    _initializeValues();
    
    // Verificar si las ciudades están cargadas, si no, inicializar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!AppConstants.globalData.isInitialized || AppConstants.cities.isEmpty) {
        AppConstants.globalData.initialize().then((_) {
          if (mounted) setState(() {});
        });
      }
    });
  }

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    _minAreaController.dispose();
    _ciudadController.dispose(); // Agregar dispose del controlador de ciudad
    super.dispose();
  }

  void _initializeValues() {
    _selectedMinCuartos = _currentFilter.minCuartos;
    _selectedMinBanos = _currentFilter.minBanos;
    _selectedCiudad = _currentFilter.municipio;
    _selectedMinGarages = _currentFilter.minGarages;
    _forRent = _currentFilter.forRent;
    _forSale = _currentFilter.forSale;

    if (_currentFilter.minPrecio != null) {
      _minPriceController.text = _currentFilter.minPrecio!.toStringAsFixed(0);
    }

    if (_currentFilter.maxPrecio != null) {
      _maxPriceController.text = _currentFilter.maxPrecio!.toStringAsFixed(0);
    }

    if (_currentFilter.minArea != null) {
      _minAreaController.text = _currentFilter.minArea!.toStringAsFixed(0);
    }

    // Inicializar el controlador de ciudad
    if (_currentFilter.municipio != null) {
      _ciudadController.text = _currentFilter.municipio!;
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
        maxChildSize: 0.95,
        minChildSize: 0.3,
        expand: false,
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
                      _buildSectionTitleWithClear(
                        'Número de cuartos',
                        _selectedMinCuartos != null,
                        () => setState(() {
                          _selectedMinCuartos = null;
                        }),
                      ),
                      _buildNumberSelector(
                        _selectedMinCuartos,
                        (value) => setState(() => _selectedMinCuartos = value),
                        6, // Máximo 6 cuartos
                      ),
                      const SizedBox(height: 8),
                      const SizedBox(height: 24),
                      
                      // Baños
                      _buildSectionTitleWithClear(
                        'Número de baños',
                        _selectedMinBanos != null,
                        () => setState(() {
                          _selectedMinBanos = null;
                        }),
                      ),
                      _buildNumberSelector(
                        _selectedMinBanos,
                        (value) => setState(() => _selectedMinBanos = value),
                        4, // Máximo 4 baños
                      ),
                      const SizedBox(height: 24),

                      // Garajes
                      _buildSectionTitleWithClear(
                        'Garajes',
                        _selectedMinGarages != null,
                        () => setState(() => _selectedMinGarages = null),
                      ),
                      _buildNumberSelector(
                        _selectedMinGarages,
                        (value) => setState(() => _selectedMinGarages = value),
                        4, // Máximo 4 garajes
                      ),
                      const SizedBox(height: 24),
                      
                      // Tipo de transacción
                      _buildSectionTitleWithClear(
                        'Tipo de transacción',
                        _forRent != null || _forSale != null,
                        () => setState(() {
                          _forRent = null;
                          _forSale = null;
                        }),
                      ),
                      _buildTransactionTypeSelector(),
                      
                      const SizedBox(height: 24),
                      
                      // Precio
                      _buildSectionTitleWithClear(
                        'Precio',
                        _minPriceController.text.isNotEmpty || _maxPriceController.text.isNotEmpty,
                        () => setState(() {
                          _minPriceController.clear();
                          _maxPriceController.clear();
                        }),
                      ),
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
                      
                      // Ciudad
                      _buildSectionTitleWithClear(
                        'Ciudad',
                        _selectedCiudad != null,
                        () => setState(() {
                          _selectedCiudad = null;
                          _ciudadController.clear(); // Limpiar también el controlador
                        }),
                      ),
                      _buildCiudadDropdown(),
                      
                      const SizedBox(height: 24),
                      
                      // Área
                      _buildSectionTitleWithClear(
                        'Área (m²)',
                        _minAreaController.text.isNotEmpty,
                        () => setState(() {
                          _minAreaController.clear();
                        }),
                      ),
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
                        ],
                      ),
                      
                      SizedBox(height: MediaQuery.of(context).size.height * 0.4),
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

  // Nuevo widget para título de sección con botón de limpiar
  Widget _buildSectionTitleWithClear(String title, bool hasValue, VoidCallback onClear) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (hasValue)
            TextButton(
              onPressed: onClear,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Limpiar filtro',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.primaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNumberSelector(int? selected, Function(int?) onChanged, int maxCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: List.generate(maxCount, (index) {
            final value = index + 1;
            return _buildSelectableChip(
              '$value+',
              selected == value,
              () => onChanged(value),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildTransactionTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildTransactionChip(
                'En Venta',
                _forSale ?? false,
                () => setState(() {
                  _forSale = _forSale == true ? null : true;
                }),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTransactionChip(
                'En Renta',
                _forRent ?? false,
                () => setState(() {
                  _forRent = _forRent == true ? null : true;
                }),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTransactionChip(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryColor : AppColors.backgroundLevel2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primaryColor : AppColors.textColor2,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: AppColors.white,
                size: 20,
              ),
            if (isSelected) const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.white : AppColors.textColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
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

  Widget _buildCiudadDropdown() {
    // Usar datos globales directamente con manejo defensivo
    final globalCities = AppConstants.cities;
    
    // Verificar si las ciudades están disponibles
    if (globalCities.isEmpty || !AppConstants.globalData.isInitialized) {
      return Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.textColor2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primaryColor,
              ),
            ),
            SizedBox(width: 12),
            Text('Cargando ciudades...'),
          ],
        ),
      );
    }

    // Extraer solo los nombres de las ciudades para el autocompletado
    final cityNames = globalCities
        .where((city) => city['name'] != null)
        .map((city) => city['name'] as String)
        .toList();

    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return cityNames; // Mostrar todas las ciudades si no hay texto
        }
        return cityNames.where((String option) {
          return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
        });
      },
      displayStringForOption: (String option) => option,
      fieldViewBuilder: (BuildContext context, TextEditingController textEditingController, 
                        FocusNode focusNode, VoidCallback onFieldSubmitted) {
        // Sincronizar con nuestro controlador personalizado
        if (_ciudadController.text != textEditingController.text) {
          textEditingController.text = _ciudadController.text;
          textEditingController.selection = TextSelection.fromPosition(
            TextPosition(offset: textEditingController.text.length),
          );
        }
        
        return TextFormField(
          controller: textEditingController,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: 'Escribir ciudad',
            hintText: 'Ej: Medellín, Bello, Envigado...',
            suffixIcon: _selectedCiudad != null
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      textEditingController.clear();
                      _ciudadController.clear();
                      setState(() {
                        _selectedCiudad = null;
                      });
                    },
                  )
                : const Icon(Icons.location_city),
          ),
          onChanged: (value) {
            // Sincronizar con nuestro controlador
            _ciudadController.text = value;
            
            // Actualizar la selección mientras escribe
            if (cityNames.contains(value)) {
              setState(() {
                _selectedCiudad = value;
              });
            } else if (value.isEmpty) {
              setState(() {
                _selectedCiudad = null;
              });
            }
          },
        );
      },
      optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<String> onSelected, 
                          Iterable<String> options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4.0,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 200),
              width: MediaQuery.of(context).size.width - 32, // Ancho ajustado al contenedor padre
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final String option = options.elementAt(index);
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: AppColors.textColor2.withValues(alpha: 0.1),
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_city,
                            size: 16,
                            color: AppColors.textColor2,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              option,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
      onSelected: (String selection) {
        _ciudadController.text = selection; // Sincronizar con nuestro controlador
        setState(() {
          _selectedCiudad = selection;
        });
      },
    );
  }

  void _clearFilters() {
    setState(() {
      _selectedMinCuartos = null;
      _selectedMinBanos = null;
      _selectedMinGarages = null;
      _selectedCiudad = null;
      _forRent = null;
      _forSale = null;
      _minPriceController.clear();
      _maxPriceController.clear();
      _minAreaController.clear();
      _ciudadController.clear(); // Limpiar también el campo de ciudad
    });
  }

  void _applyFilters() {
    final newFilter = PropertyFilter(
      minCuartos: _selectedMinCuartos,
      minBanos: _selectedMinBanos,
      minGarages: _selectedMinGarages,
      minPrecio: _minPriceController.text.isNotEmpty
          ? double.tryParse(_minPriceController.text.replaceAll(',', ''))
          : null,
      maxPrecio: _maxPriceController.text.isNotEmpty
          ? double.tryParse(_maxPriceController.text.replaceAll(',', ''))
          : null,
      municipio: _selectedCiudad,
      minArea: _minAreaController.text.isNotEmpty
          ? double.tryParse(_minAreaController.text)
          : null,
      forRent: _forRent,
      forSale: _forSale,
    );
    context.read<PropertyProvider>().updateFilter(newFilter);
    Navigator.pop(context);
  }
}
