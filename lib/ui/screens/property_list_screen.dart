import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/property_provider.dart';
import '../widgets/property_card.dart';
import '../../core/theme/app_colors.dart';
import 'property_detail_screen.dart';
import 'property_filter_screen.dart';

class PropertyListScreen extends StatefulWidget {
  const PropertyListScreen({super.key});

  @override
  State<PropertyListScreen> createState() => _PropertyListScreenState();
}

class _PropertyListScreenState extends State<PropertyListScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    
    // Cargar datos iniciales
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<PropertyProvider>();
      // Solo hacer refresh si no hay propiedades cargadas desde caché
      if (provider.properties.isEmpty) {
        provider.refresh();
      }
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
        _scrollController.position.maxScrollExtent - 200) {
      context.read<PropertyProvider>().loadMoreProperties();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inmobarco'),
        actions: [
          // Botón de información del caché
          Consumer<PropertyProvider>(
            builder: (context, provider, child) {
              return IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () => _showCacheInfo(context),
              );
            },
          ),
          Consumer<PropertyProvider>(
            builder: (context, provider, child) {
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.filter_list),
                    onPressed: () => _showFilterDialog(context),
                  ),
                  if (provider.hasActiveFilters)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.secondaryColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
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
                      return PropertyCard(
                        apartment: apartment,
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
          return TextField(
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

  void _showCacheInfo(BuildContext context) async {
    final provider = context.read<PropertyProvider>();
    final cacheInfo = await provider.getCacheInfo();
    if (!mounted) return;

    showDialog(
      // ignore: use_build_context_synchronously
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Información del Caché'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Propiedades en caché: ${cacheInfo['propertiesCount']}'),
            const SizedBox(height: 8),
            if (cacheInfo['hasCache'])
              Text('Última actualización: ${_formatDate(cacheInfo['lastUpdate'])}')
            else
              const Text('Sin caché disponible'),
            const SizedBox(height: 8),
            if (cacheInfo['hasCache'])
              Text('Antigüedad: ${cacheInfo['cacheAgeHours'].toStringAsFixed(1)} horas'),
          ],
        ),
        actions: [
          if (cacheInfo['hasCache'])
            TextButton(
              onPressed: () async {
                // Capturar referencias antes del async
                final navigator = Navigator.of(dialogContext);
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                
                await provider.clearCache();
                navigator.pop();
                
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(content: Text('Caché limpiado')),
                  );
                }
              },
              child: const Text('Limpiar Caché'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Desconocida';
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _navigateToDetail(String propertyId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PropertyDetailScreen(propertyId: propertyId),
      ),
    );
  }
}
