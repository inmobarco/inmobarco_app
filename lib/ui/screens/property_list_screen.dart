import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/property_provider.dart';
import '../widgets/property_card.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/cache_service.dart';
import 'property_detail_screen.dart';
import 'property_filter_screen.dart';
import 'add_apartment_screen.dart';

class PropertyListScreen extends StatefulWidget {
  const PropertyListScreen({super.key});

  @override
  State<PropertyListScreen> createState() => _PropertyListScreenState();
}

class _PropertyListScreenState extends State<PropertyListScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String? _userFirstName;
  String? _userLastName;
  String? _userPhone;
  bool _isPublicNavigation = true;
  
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadUserProfile();
    
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

  void _toggleNavigationVisibility() {
    setState(() {
      _isPublicNavigation = !_isPublicNavigation;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
      leadingWidth: 170,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12, top: 8, bottom: 8),
        child: Row(
          children: [
            Expanded(
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: _showUserDialog,
                child: Text(
                  _userFirstName != null && _userFirstName!.trim().isNotEmpty
                      ? _userFirstName!.trim()
                      : 'Entrar',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: IconButton(
                icon: Icon(
                  _isPublicNavigation ? Icons.visibility : Icons.visibility_off,
                  color: Colors.white,
                ),
                tooltip: _isPublicNavigation
                    ? 'Navegación pública'
                    : 'Navegación privada',
                onPressed: _toggleNavigationVisibility,
              ),
            ),
          ],
        ),
      ),
        title: const Text('Inmobarco'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nuevo Apartamento',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddApartmentScreen(),
                ),
              );
            },
          ),
          // Botón de información del caché
          Consumer<PropertyProvider>(
            builder: (context, provider, child) {
              return IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () => _showCacheInfo(context),
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
                        isPublicNavigation: _isPublicNavigation,
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

  Future<void> _loadUserProfile() async {
    final data = await CacheService.loadUserProfile();
    if (!mounted) return;
    if (data != null) {
      setState(() {
        _userFirstName = _normalizeProfileValue(data['first_name']);
        _userLastName = _normalizeProfileValue(data['last_name']);
        _userPhone = _normalizeProfileValue(data['phone']);
      });
    }
  }

  String? _normalizeProfileValue(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  Future<void> _showUserDialog() async {
    final formKey = GlobalKey<FormState>();
    String firstName = _userFirstName ?? '';
    String lastName = _userLastName ?? '';
    String phoneNumber = _userPhone ?? '';

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Identifícate'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: firstName,
                  onChanged: (value) => firstName = value,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  textCapitalization: TextCapitalization.words,
                  validator: (_) => null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: lastName,
                  onChanged: (value) => lastName = value,
                  decoration: const InputDecoration(labelText: 'Apellido'),
                  textCapitalization: TextCapitalization.words,
                  validator: (_) => null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: phoneNumber,
                  onChanged: (value) => phoneNumber = value,
                  decoration: const InputDecoration(labelText: 'Teléfono'),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) return null;
                    final digits = trimmed.replaceAll(RegExp(r'[^0-9+]'), '');
                    if (digits.replaceAll('+', '').length < 7) return 'Teléfono inválido';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final formState = formKey.currentState;
                if (formState != null && !formState.validate()) return;
                final profile = <String, String>{};

                final trimmedFirst = firstName.trim();
                if (trimmedFirst.isNotEmpty) {
                  profile['first_name'] = trimmedFirst;
                }

                final trimmedLast = lastName.trim();
                if (trimmedLast.isNotEmpty) {
                  profile['last_name'] = trimmedLast;
                }

                final trimmedPhone = phoneNumber.trim();
                if (trimmedPhone.isNotEmpty) {
                  profile['phone'] = trimmedPhone;
                }

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(profile);
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    if (result == null) {
      return;
    }

    if (result.isEmpty) {
      await CacheService.clearUserProfile();
      if (!mounted) return;
      setState(() {
        _userFirstName = null;
        _userLastName = null;
        _userPhone = null;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil eliminado')),
      );
      return;
    }

    await CacheService.saveUserProfile(result);
    if (!mounted) return;
    setState(() {
      _userFirstName = result['first_name'];
      _userLastName = result['last_name'];
      _userPhone = result['phone'];
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Perfil guardado correctamente')),
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
        builder: (context) => PropertyDetailScreen(
          propertyId: propertyId,
          isPublicNavigation: _isPublicNavigation,
        ),
      ),
    );
  }
}
