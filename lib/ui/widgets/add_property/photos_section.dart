import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/apartment_photo.dart';

class PhotosSection extends StatelessWidget {
  final List<ApartmentPhoto> photos;
  final int maxPhotoCount;
  final bool isSubmitting;
  final TextEditingController serviceRoomController;
  final TextEditingController parkingLotController;
  final Uint8List? serviceRoomPhotoBytes;
  final String? serviceRoomPhotoFileName;
  final Uint8List? parkingLotPhotoBytes;
  final String? parkingLotPhotoFileName;
  final VoidCallback onOpenPhotosManager;
  final VoidCallback onPickServiceRoomPhoto;
  final VoidCallback onPickParkingLotPhoto;
  final VoidCallback onClearServiceRoomPhoto;
  final VoidCallback onClearParkingLotPhoto;

  const PhotosSection({
    super.key,
    required this.photos,
    required this.maxPhotoCount,
    required this.isSubmitting,
    required this.serviceRoomController,
    required this.parkingLotController,
    required this.serviceRoomPhotoBytes,
    required this.serviceRoomPhotoFileName,
    required this.parkingLotPhotoBytes,
    required this.parkingLotPhotoFileName,
    required this.onOpenPhotosManager,
    required this.onPickServiceRoomPhoto,
    required this.onPickParkingLotPhoto,
    required this.onClearServiceRoomPhoto,
    required this.onClearParkingLotPhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Vista previa de la primera foto
        if (photos.isNotEmpty) ...[
          ClipRRect(
            borderRadius: AppTheme.buttonBorderRadius,
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.memory(
                photos.first.bytes,
                fit: BoxFit.cover,
              ),
            ),
          ),
          if (photos.first.fileName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                photos.first.fileName,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 16),
        ] else ...[
          const Text(
            'Añade al menos una foto desde el gestor para continuar.',
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 16),
        ],
        // Botón gestor de fotos
        OutlinedButton.icon(
          icon: const Icon(Icons.photo_library),
          label: const Text('Fotos del apartamento'),
          onPressed: isSubmitting ? null : onOpenPhotosManager,
        ),
        const SizedBox(height: 8),
        Text(
          'Fotos cargadas: ${photos.length} de $maxPhotoCount',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 24),
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Datos privados de la compañía',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 8),
        // Cuarto útil + Parqueo
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: serviceRoomController,
                    decoration: const InputDecoration(
                      labelText: 'Cuarto útil',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: Icon(
                      serviceRoomPhotoBytes == null
                          ? Icons.add_a_photo
                          : Icons.check_circle,
                    ),
                    label: Text(
                      serviceRoomPhotoBytes == null
                          ? 'Agregar foto cuarto útil'
                          : 'Cambiar foto cuarto útil',
                    ),
                    onPressed: isSubmitting ? null : onPickServiceRoomPhoto,
                  ),
                  if (serviceRoomPhotoBytes != null) ...[
                    const SizedBox(height: 4),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline, color: AppColors.error),
                      label: const Text('Limpiar foto', style: TextStyle(color: AppColors.error)),
                      onPressed: isSubmitting ? null : onClearServiceRoomPhoto,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.error),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    serviceRoomPhotoBytes == null
                        ? 'Sin foto cargada'
                        : 'Foto cargada: ${serviceRoomPhotoFileName ?? 'cuarto_util.jpg'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: parkingLotController,
                    decoration: const InputDecoration(
                      labelText: 'Número parqueo',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: Icon(
                      parkingLotPhotoBytes == null
                          ? Icons.add_a_photo
                          : Icons.check_circle,
                    ),
                    label: Text(
                      parkingLotPhotoBytes == null
                          ? 'Agregar foto parqueo'
                          : 'Cambiar foto parqueo',
                    ),
                    onPressed: isSubmitting ? null : onPickParkingLotPhoto,
                  ),
                  if (parkingLotPhotoBytes != null) ...[
                    const SizedBox(height: 4),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline, color: AppColors.error),
                      label: const Text('Limpiar foto', style: TextStyle(color: AppColors.error)),
                      onPressed: isSubmitting ? null : onClearParkingLotPhoto,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.error),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    parkingLotPhotoBytes == null
                        ? 'Sin foto cargada'
                        : 'Foto cargada: ${parkingLotPhotoFileName ?? 'parqueo.jpg'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Bottom sheet para gestionar las fotos del apartamento.
class PhotosManagerSheet extends StatelessWidget {
  final List<ApartmentPhoto> photos;
  final int maxPhotoCount;
  final int remainingPhotoSlots;
  final Future<void> Function() onAddPhotos;
  final Future<void> Function(int index) onRemovePhoto;

  const PhotosManagerSheet({
    super.key,
    required this.photos,
    required this.maxPhotoCount,
    required this.remainingPhotoSlots,
    required this.onAddPhotos,
    required this.onRemovePhoto,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Fotos del apartamento',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Agregar fotos'),
                onPressed: remainingPhotoSlots <= 0 ? null : onAddPhotos,
              ),
              const SizedBox(height: 8),
              Text(
                'Fotos cargadas: ${photos.length} de $maxPhotoCount',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: photos.isEmpty
                    ? const Center(
                        child: Text('No se han agregado fotos.'),
                      )
                    : GridView.builder(
                        itemCount: photos.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                        itemBuilder: (gridContext, index) {
                          final photo = photos[index];
                          return Stack(
                            children: [
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    photo.bytes,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: InkWell(
                                  onTap: () => onRemovePhoto(index),
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: AppColors.overlayDark,
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(4),
                                    child: const Icon(
                                      Icons.close,
                                      size: 16,
                                      color: AppColors.pureWhite,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 4,
                                right: 4,
                                bottom: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.overlayDark,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    photo.fileName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.pureWhite,
                                      fontSize: 10,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
