import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/property_provider.dart';
import '../../domain/models/apartment.dart';
import '../../core/theme/app_colors.dart';
import '../../core/encription.dart';

class PropertyDetailScreen extends StatefulWidget {
  final String propertyId;

  const PropertyDetailScreen({
    super.key,
    required this.propertyId,
  });

  @override
  State<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends State<PropertyDetailScreen> {
  Apartment? apartment;
  bool isLoading = true;
  String? error;
  PageController? _pageController;
  bool _showApartmentInfo = false;

  @override
  void initState() {
    super.initState();
    _loadPropertyDetail();
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  Future<void> _loadPropertyDetail() async {
    try {
      final provider = context.read<PropertyProvider>();
      final property = await provider.getPropertyById(widget.propertyId);
      
      if (mounted) {
        setState(() {
          apartment = property;
          isLoading = false;
          if (apartment != null && apartment!.imagenes.isNotEmpty) {
            _pageController = PageController();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Propiedad'),
        actions: apartment != null
            ? [
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: _shareProperty,
                ),
              ]
            : null,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primaryColor,
        ),
      );
    }

    if (error != null) {
      return _buildErrorWidget();
    }

    if (apartment == null) {
      return _buildNotFoundWidget();
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Galería de imágenes
          _buildImageGallery(),

          // Información principal
          _buildMainInfo(),

          // Características
          _buildFeatures(),

          // Descripción
          if (apartment!.descripcion.isNotEmpty) _buildDescription(),

          // Botón de compartir
          _buildShareButton(),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildImageGallery() {
    if (apartment!.imagenes.isEmpty) {
      return Container(
        height: 250,
        color: AppColors.backgroundLevel2,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.home,
                size: 64,
                color: AppColors.textColor2,
              ),
              SizedBox(height: 8),
              Text(
                'Sin imágenes',
                style: TextStyle(
                  color: AppColors.textColor2,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 300,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: apartment!.imagenes.length,
            itemBuilder: (context, index) {
              return CachedNetworkImage(
                imageUrl: apartment!.imagenes[index],
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: AppColors.backgroundLevel2,
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryColor,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: AppColors.backgroundLevel2,
                  child: const Center(
                    child: Icon(
                      Icons.error_outline,
                      size: 48,
                      color: AppColors.textColor2,
                    ),
                  ),
                ),
              );
            },
          ),
          
          // Indicador de página
          if (apartment!.imagenes.length > 1)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: apartment!.imagenes.asMap().entries.map((entry) {
                  return Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.white.withValues(alpha: 0.8),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMainInfo() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Precio
          Text(
            apartment!.priceFormatted,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: AppColors.primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          // Título
          if (apartment!.titulo.isNotEmpty)
            GestureDetector(
              onTap: () {
                setState(() {
                  _showApartmentInfo = !_showApartmentInfo;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primaryColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _showApartmentInfo
                          ? Text(
                              '${apartment!.titulo} - ID: ${apartment!.id}',
                              style: Theme.of(context).textTheme.headlineMedium,
                            )
                          : Text(
                              'Mostrar apto',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: AppColors.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                    Icon(
                      _showApartmentInfo ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.primaryColor,
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 12),

          // Ubicación
          Row(
            children: [
              const Icon(
                Icons.location_on,
                color: AppColors.textColor2,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      apartment!.ubicacion,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (apartment!.direccion.isNotEmpty)
                      Visibility(
                        visible: _showApartmentInfo,
                        child: Text(
                          apartment!.direccion,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textColor2,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatures() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Características',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildFeatureItem(
                      icon: Icons.bed,
                      label: 'Cuartos',
                      value: apartment!.cuartos.toString(),
                    ),
                  ),
                  Expanded(
                    child: _buildFeatureItem(
                      icon: Icons.bathtub,
                      label: 'Baños',
                      value: apartment!.banos.toString(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (apartment!.area > 0)
                    Expanded(
                      child: _buildFeatureItem(
                        icon: Icons.square_foot,
                        label: 'Área',
                        value: '${apartment!.area.toStringAsFixed(0)} m²',
                      ),
                    ),
                  if (apartment!.estrato.isNotEmpty)
                    Expanded(
                      child: _buildFeatureItem(
                        icon: Icons.apartment,
                        label: 'Estrato',
                        value: apartment!.estratoTexto,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          size: 32,
          color: AppColors.primaryColor,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textColor2,
          ),
        ),
      ],
    );
  }

  Widget _buildDescription() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Descripción',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                apartment!.descripcion,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShareButton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _shareProperty,
          icon: const Icon(Icons.share),
          label: const Text('Compartir Propiedad'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
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
              'Error al cargar la propiedad',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textColor2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPropertyDetail,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotFoundWidget() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: AppColors.textColor2,
            ),
            SizedBox(height: 16),
            Text(
              'Propiedad no encontrada',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _shareProperty() {
    if (apartment == null) return;

    // Encriptar el ID del apartamento
    final String? encryptedId = propertyEncryption.encrypt(apartment!.codigo);
    final String propertyUrl = encryptedId != null 
        ? 'https://ficha.inmobarco.com/?id=$encryptedId'
        : 'https://ficha.inmobarco.com/?id=${apartment!.codigo}'; // Fallback si falla la encriptación

    final shareText = '''
🏠 ${apartment!.titulo.isNotEmpty ? apartment!.titulo : 'Propiedad Disponible'}

💰 Precio: ${apartment!.priceFormatted}
🛏️ Cuartos: ${apartment!.cuartos}
🛁 Baños: ${apartment!.banos}
📍 Ubicación: ${apartment!.ubicacion}

Ver más detalles: $propertyUrl

#Inmobarco #PropiedadesEnArriendo
    ''';
    ShareParams shareParams = ShareParams(
          text: shareText,
          subject: 'Propiedad en Inmobarco',
          sharePositionOrigin: Rect.fromLTWH(0, 0, 100, 100),
    );
    SharePlus.instance.share(shareParams);
  }
}
