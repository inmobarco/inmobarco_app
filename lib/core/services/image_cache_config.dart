import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Límites del caché de imágenes.
///
/// `cached_network_image` traía los valores por defecto (200 archivos y 30
/// días en disco, y un caché en memoria sin tope de bytes explícito). Con el
/// inventario completo en local, el usuario puede recorrer cientos de fichas y
/// varias galerías en una sesión, así que conviene acotarlo a mano.
class ImageCacheConfig {
  /// Archivos en disco y cuánto viven.
  static const int maxDiskEntries = 400;
  static const Duration diskMaxAge = Duration(days: 15);

  /// Imágenes decodificadas en memoria.
  static const int maxLiveImages = 150;
  static const int maxLiveBytes = 120 << 20; // 120 MB

  static void apply() {
    PaintingBinding.instance.imageCache
      ..maximumSize = maxLiveImages
      ..maximumSizeBytes = maxLiveBytes;
  }

  /// Gestor de disco para `CachedNetworkImage`.
  static final CacheManager manager = CacheManager(
    Config(
      'inmobarco_images',
      maxNrOfCacheObjects: maxDiskEntries,
      stalePeriod: diskMaxAge,
    ),
  );

  /// Proveedor listo para usar con los límites aplicados.
  static CachedNetworkImageProvider provider(String url) =>
      CachedNetworkImageProvider(url, cacheManager: manager);
}
