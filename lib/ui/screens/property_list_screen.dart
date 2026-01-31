import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/property_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/property_card.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import 'property_detail_screen.dart';
import 'property_filter_screen.dart';
import 'add_apartment_screen.dart';

/// Widget que muestra la lista de propiedades con búsqueda y filtros.
/// 
/// Incluye botones flotantes para:
/// - Cambiar entre navegación pública/privada
/// - Crear nuevo apartamento
class PropertyListScreen extends StatefulWidget {
  const PropertyListScreen({super.key});

  @override
  State<PropertyListScreen> createState() => _PropertyListScreenState();
}

class _PropertyListScreenState extends State<PropertyListScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  bool _isPublicNavigation = true;
  
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _toggleNavigationVisibility() {
    setState(() {
      _isPublicNavigation = !_isPublicNavigation;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - AppConstants.loadMoreThreshold) {
      context.read<PropertyProvider>().loadMoreProperties();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = context.watch<AuthProvider>().isLoggedIn;
    
    return Scaffold(
      floatingActionButton: isLoggedIn ? Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Botón del ojo (navegación pública/privada) - solo si está logueado
          FloatingActionButton.small(
            heroTag: 'visibility_fab',
            backgroundColor: _isPublicNavigation 
                ? AppColors.primaryColor.withValues(alpha: 0.8)
                : Colors.grey.shade600,
            onPressed: _toggleNavigationVisibility,
            tooltip: _isPublicNavigation
                ? 'Navegación pública'
                : 'Navegación privada',
            child: Icon(
              _isPublicNavigation ? Icons.visibility : Icons.visibility_off,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          // Botón de nuevo apartamento - solo si está logueado
          FloatingActionButton(
            heroTag: 'add_apartment_fab',
            backgroundColor: AppColors.primaryColor,
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddApartmentScreen(),
                ),
              );
            },
            tooltip: 'Nuevo Apartamento',
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ],
      ) : null,
      body: Column(
        children: [
          // Indicador de carga desde caché
          Consumer<PropertyProvider>(
            builder: (context, provider, child) {
              if (provider.isLoadingFromCache) {
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                color: AppColors.primaryColor.withValues(alpha: 0.1),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryColor,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Cargando desde caché...',
                      style: TextStyle(
                        color: AppColors.primaryColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),

        // Barra de búsqueda
        _buildSearchBar(),
        
        // Lista de propiedades
        Expanded(
          child: Consumer<PropertyProvider>(
            builder: (context, provider, child) {
              final visibleList = provider.filteredProperties;
              final isFiltering = _searchController.text.trim().isNotEmpty;

              if (provider.isLoading && provider.properties.isEmpty && !provider.isLoadingFromCache) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryColor,
                  ),
                );
              }

              if (provider.error != null && provider.properties.isEmpty) {
                return _buildErrorWidget(provider.error!);
              }

              if (provider.properties.isEmpty && !provider.isLoadingFromCache) {
                return _buildEmptyWidget();
              }

              return RefreshIndicator(
                onRefresh: () => provider.refresh(),
                color: AppColors.primaryColor,
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: isFiltering
                      ? visibleList.length
                      : provider.properties.length + (provider.hasMoreData ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (!isFiltering && index == provider.properties.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryColor,
                          ),
                        ),
                      );
                    }

                    final apartment = isFiltering ? visibleList[index] : provider.properties[index];
                    // Forzar navegación pública si no está logueado
                    final effectivePublicNav = !isLoggedIn || _isPublicNavigation;
                    return PropertyCard(
                      apartment: apartment,
                      isPublicNavigation: effectivePublicNav,
                      onTap: () => _navigateToDetail(apartment.id),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.backgroundLevel1,
      child: Consumer<PropertyProvider>(
        builder: (context, provider, _) {
          final hasActiveFilters = provider.hasActiveFilters;
          return Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar por número de registro...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.textColor2),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: AppColors.textColor2),
                            onPressed: () {
                              _searchController.clear();
                              provider.clearSearchQuery();
                              setState(() {}); // Actualiza visibilidad del botón
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.backgroundLevel2,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (value) {
                    provider.updateSearchQuery(value);
                    setState(() {}); // solo para refrescar suffixIcon
                  },
                ),
              ),
              const SizedBox(width: 12),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Material(
                    color: AppColors.primaryColor,
                    shape: const CircleBorder(),
                    child: IconButton(
                      icon: const Icon(Icons.filter_list, color: Colors.white),
                      tooltip: 'Filtros',
                      onPressed: () => _showFilterDialog(context),
                    ),
                  ),
                  if (hasActiveFilters)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppColors.secondaryColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.textColor2,
            ),
            const SizedBox(height: 16),
            Text(
              'Error al cargar propiedades',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textColor2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.read<PropertyProvider>().refresh(),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.home_outlined,
              size: 64,
              color: AppColors.textColor2,
            ),
            const SizedBox(height: 16),
            Text(
              'No hay propiedades disponibles',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'No se encontraron propiedades que coincidan con los filtros aplicados.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textColor2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.read<PropertyProvider>().clearFilters(),
              child: const Text('Limpiar filtros'),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PropertyFilterScreen(),
    );
  }

  void _navigateToDetail(String propertyId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PropertyDetailScreen(
          propertyId: propertyId,
          isPublicNavigation: _isPublicNavigation,
        ),
      ),
    );
  }
}
