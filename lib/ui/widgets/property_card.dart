import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../domain/models/apartment.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

class PropertyCard extends StatelessWidget {
  final Apartment apartment;
  final VoidCallback onTap;
  final bool isPublicNavigation;

  const PropertyCard({
    super.key,
    required this.apartment,
    required this.onTap,
    this.isPublicNavigation = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: AppTheme.cardBorderRadius,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTheme.cardBorderRadius,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen principal
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  child: _buildPropertyImage(),
                ),
                // Reference badge en esquina inferior izquierda si navegación es privada
                if (!isPublicNavigation && apartment.reference.isNotEmpty)
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.overlayDark,
                        borderRadius: AppTheme.badgeBorderRadius,
                      ),
                      child: Text(
                        apartment.reference,
                        style: const TextStyle(
                          color: AppColors.pureWhite,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            
            // Información del apartamento
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Precio y tipo de negocio
                  _buildPriceSection(context),
                  
                  const SizedBox(height: 8),
                  
                  // Título/Descripción
                  if (apartment.titulo.isNotEmpty)
                    Text(
                      apartment.titulo,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  
                  const SizedBox(height: 8),
                  
                  // Ubicación
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 16,
                        color: AppColors.textColor2,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          apartment.ubicacion,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textColor2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Características (cuartos, baños, parqueos, cuarto útil, área)
                  Row(
                    children: [
                      _buildFeature(
                        icon: Icons.bed,
                        value: apartment.cuartos.toString(),
                        label: apartment.cuartos == 1 ? 'cuarto' : 'cuartos',
                      ),
                      const SizedBox(width: 16),
                      _buildFeature(
                        icon: Icons.bathtub,
                        value: apartment.banos.toString(),
                        label: (apartment.hasStoreroom == true && apartment.garages > 0) ? '' : (apartment.banos == 1 ? 'baño' : 'baños'),
                      ),
                      if (apartment.garages > 0) ...[
                        const SizedBox(width: 16),
                        _buildFeature(
                          icon: Icons.directions_car,
                          value: apartment.garages.toString(),
                          // Compactar label si también tiene cuarto útil
                          label: apartment.hasStoreroom == true ? '' : (apartment.garages == 1 ? 'parqueo' : 'parqueos'),
                        ),
                      ],
                      if (apartment.hasStoreroom == true) ...[
                        const SizedBox(width: 16),
                        _buildFeature(
                          icon: Icons.warehouse,
                          value: '',
                          label: 'C. útil',
                        ),
                      ],
                      if (apartment.area > 0) ...[
                        const SizedBox(width: 16),
                        _buildFeature(
                          icon: Icons.square_foot,
                          value: apartment.area.toStringAsFixed(0),
                          label: 'm²',
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyImage() {
    if (apartment.primaryImage.isEmpty) {
      return Container(
        height: 200,
        width: double.infinity,
        color: AppColors.backgroundLevel2,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.home,
              size: 48,
              color: AppColors.textColor2,
            ),
            SizedBox(height: 8),
            Text(
              'Sin imagen',
              style: TextStyle(
                color: AppColors.textColor2,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: apartment.primaryImage,
      height: 200,
      width: double.infinity,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        height: 200,
        color: AppColors.backgroundLevel2,
        child: const Center(
          child: CircularProgressIndicator(
            color: AppColors.primaryColor,
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        height: 200,
        color: AppColors.backgroundLevel2,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: AppColors.textColor2,
            ),
            SizedBox(height: 8),
            Text(
              'Error al cargar imagen',
              style: TextStyle(
                color: AppColors.textColor2,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceSection(BuildContext context) {
    final priceStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
      color: AppColors.primaryColor,
      fontWeight: FontWeight.bold,
    );

    String formatPrice(double price) {
      return '\$${price.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      )}';
    }

    final showRent = apartment.forRent && apartment.rentPrice > 0;
    final showSale = apartment.forSale && apartment.salePrice > 0;

    if (showRent && showSale) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(formatPrice(apartment.rentPrice), style: priceStyle),
              const SizedBox(width: 8),
              _buildBusinessTag('Alquiler'),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(formatPrice(apartment.salePrice), style: priceStyle),
              const SizedBox(width: 8),
              _buildBusinessTag('Venta'),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Text(apartment.priceFormatted, style: priceStyle),
        if (showRent || showSale) ...[
          const SizedBox(width: 8),
          _buildBusinessTag(showRent ? 'Alquiler' : 'Venta'),
        ],
      ],
    );
  }

  Widget _buildBusinessTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primaryColor.withValues(alpha: 0.1),
        borderRadius: AppTheme.badgeBorderRadius,
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primaryColor,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildFeature({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: AppColors.textColor2,
        ),
        const SizedBox(width: 4),
        Text(
          value.isEmpty ? label : (label.isEmpty ? value : '$value $label'),
          style: const TextStyle(
            color: AppColors.textColor2,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
