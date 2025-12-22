import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../domain/models/apartment.dart';
import '../../core/theme/app_colors.dart';

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
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
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
                        // ignore: deprecated_member_use
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        apartment.reference,
                        style: const TextStyle(
                          color: Colors.white,
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
                  // Precio
                  Text(
                    apartment.priceFormatted,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
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
                  
                  // Características (cuartos, baños, área)
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
                        label: apartment.banos == 1 ? 'baño' : 'baños',
                      ),
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
          '$value $label',
          style: const TextStyle(
            color: AppColors.textColor2,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
