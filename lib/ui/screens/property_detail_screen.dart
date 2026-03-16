import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import '../providers/property_provider.dart';
import '../providers/auth_provider.dart';
import '../../domain/models/apartment.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/encription.dart';
import '../../data/services/webhook_service.dart';
import '../widgets/photo_gallery.dart';

class PropertyDetailScreen extends StatefulWidget {
  final String propertyId;
  final bool isPublicNavigation;

  const PropertyDetailScreen({
    super.key,
    required this.propertyId,
    this.isPublicNavigation = true,
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
  int _currentImageIndex = 0;
  bool _isDownloadingImages = false;

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

      // Mostrar datos locales de inmediato (versión short) si existen.
      final localProperty = provider.properties.where((p) => p.id == widget.propertyId).firstOrNull;
      if (localProperty != null && mounted) {
        setState(() {
          apartment = localProperty;
          isLoading = false;
          if (apartment!.imagenes.isNotEmpty) {
            _pageController = PageController();
          }
        });
      }

      // Obtener detalle completo con galerías desde la API.
      final fullProperty = await provider.getPropertyById(widget.propertyId);

      if (mounted && fullProperty != null) {
        setState(() {
          apartment = fullProperty;
          isLoading = false;
          if (apartment!.imagenes.isNotEmpty) {
            _pageController?.dispose();
            _pageController = PageController();
            _currentImageIndex = 0;
            _preloadImages();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        // Si ya teníamos datos locales, no mostramos error.
        if (apartment != null) return;
        setState(() {
          error = e.toString();
          isLoading = false;
        });
      }
    }
  }

  // Precargar todas las imágenes en segundo plano
  void _preloadImages() {
    if (apartment == null || apartment!.imagenes.isEmpty) return;
    const int maxPreloadCount = 3;
    final imagesToPreload = apartment!.imagenes.take(maxPreloadCount);

    for (String imageUrl in imagesToPreload) {
      precacheImage(
        CachedNetworkImageProvider(imageUrl),
        context,
      ).catchError((error) {
        debugPrint('Error precargando imagen: $error');
      });
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

          // Botón de eliminar propiedad (solo si está logueado)
          if (context.watch<AuthProvider>().isLoggedIn)
            _buildDeleteButton(),

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
            onPageChanged: (index) {
              setState(() {
                _currentImageIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return Hero(
                tag: 'property-image-$index',
                child: GestureDetector(
                  onTap: () => _showFullScreenImage(index),
                  child: CachedNetworkImage(
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
                    // Configuración de caché mejorada
                    cacheKey: apartment!.imagenes[index],
                    memCacheWidth: 800, // Limitar el ancho en memoria
                    memCacheHeight: 600, // Limitar la altura en memoria
                  ),
                ),
              );
            },
          ),
          
          // Indicadores de página mejorados
          if (apartment!.imagenes.length > 1)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.overlayDark,
                      borderRadius: AppTheme.pillBorderRadius,
                    ),
                    child: Text(
                      '${_currentImageIndex + 1} / ${apartment!.imagenes.length}',
                      style: const TextStyle(
                        color: AppColors.pureWhite,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Controles de navegación
          if (apartment!.imagenes.length > 1) ...[
            // Botón anterior
            if (_currentImageIndex > 0)
              Positioned(
                left: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.overlayLight,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.chevron_left, color: AppColors.pureWhite),
                      onPressed: () {
                        _pageController?.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                    ),
                  ),
                ),
              ),
            
            // Botón siguiente
            if (_currentImageIndex < apartment!.imagenes.length - 1)
              Positioned(
                right: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.overlayLight,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.chevron_right, color: AppColors.pureWhite),
                      onPressed: () {
                        _pageController?.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  // Mostrar imagen en pantalla completa
  void _showFullScreenImage(int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenImageGallery(
          images: apartment!.imagenes,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  Widget _buildMainInfo() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Precio y botón de descarga
          Row(
            children: [
              Expanded(
                child: Text(
                  apartment!.priceFormatted,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: AppColors.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (apartment!.imagenes.isNotEmpty)
                IconButton(
                  icon: _isDownloadingImages
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primaryColor,
                          ),
                        )
                      : const Icon(Icons.download, color: AppColors.primaryColor),
                  tooltip: 'Descargar imágenes',
                  onPressed: _isDownloadingImages ? null : _downloadAllImages,
                ),
            ],
          ),

          const SizedBox(height: 8),

          // Título - Solo visible si está logueado
          if (apartment!.reference.isNotEmpty && context.watch<AuthProvider>().isLoggedIn)
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
                  borderRadius: AppTheme.buttonBorderRadius,
                  border: Border.all(color: AppColors.primaryColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _showApartmentInfo
                          ? Text(
                              '${apartment!.reference} - ID: ${apartment!.id}',
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
                  if (apartment!.garages > 0)
                    Expanded(
                      child: _buildFeatureItem(
                        icon: Icons.directions_car,
                        label: 'Parqueos',
                        value: apartment!.garages.toString(),
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
                  if (apartment!.estrato > 0)
                    Expanded(
                      child: _buildFeatureItem(
                        icon: Icons.apartment,
                        label: 'Estrato',
                        value: apartment!.estrato.toString(),
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

  Widget _buildDeleteButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _showDeleteConfirmationDialog,
          icon: const Icon(Icons.delete_outline, color: AppColors.pureWhite),
          label: const Text(
            'Eliminar Propiedad',
            style: TextStyle(color: AppColors.pureWhite),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmationDialog() {
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Eliminar Propiedad'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '¿Estás seguro de que deseas eliminar esta propiedad?',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Text(
                'Referencia: ${apartment!.reference}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'ID: ${apartment!.id}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Razón (opcional)',
                  hintText: 'Ingrese una razón...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _sendDeleteWebhook(reasonController.text.trim());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
              ),
              child: const Text(
                'Eliminar',
                style: TextStyle(color: AppColors.pureWhite),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendDeleteWebhook(String comment) async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;

    if (user == null || apartment == null) return;

    final body = {
      'username': user.username,
      'user_first_name': user.firstName,
      'user_last_name': user.lastName,
      'apartment_reference': apartment!.reference,
      'apartment_id': apartment!.id,
      'comment': comment,
    };

    final result = await WebhookService.sendDelete(body);

    if (mounted) {
      if (result.success) {
        context.read<PropertyProvider>().loadProperties(refresh: true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Solicitud de eliminación enviada correctamente.'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.userFriendlyMessage),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
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
    final String? encryptedId = propertyEncryption.encrypt(apartment!.id);
    final String propertyUrl = encryptedId != null 
        ? 'https://ficha.inmobarco.com/?id=$encryptedId'
        : 'https://ficha.inmobarco.com/?id=${apartment!.id}'; // Fallback si falla la encriptación

    final shareText = '''
🏠 ${apartment!.titulo.isNotEmpty ? apartment!.titulo : 'Propiedad Disponible'}

💰 Precio: ${apartment!.priceFormatted}
🛏️ Cuartos: ${apartment!.cuartos}
🛁 Baños: ${apartment!.banos}
📍 Ubicación: ${apartment!.ubicacion}

Ver más detalles: $propertyUrl''';
    ShareParams shareParams = ShareParams(
          text: shareText,
          subject: 'Propiedad en Inmobarco',
          sharePositionOrigin: Rect.fromLTWH(0, 0, 100, 100),
    );
    SharePlus.instance.share(shareParams);
  }

  Future<void> _downloadAllImages() async {
    if (apartment == null || apartment!.imagenes.isEmpty) return;

    setState(() {
      _isDownloadingImages = true;
    });

    try {
      final dio = Dio();
      
      // Obtener directorio de descargas
      Directory? downloadsDir;
      if (Platform.isAndroid) {
        // Usar el directorio público de Pictures para que aparezca en la galería
        downloadsDir = Directory('/storage/emulated/0/Pictures/Inmobarco');
      } else if (Platform.isIOS) {
        downloadsDir = await getApplicationDocumentsDirectory();
      } else {
        downloadsDir = await getDownloadsDirectory();
      }

      if (downloadsDir == null) {
        throw Exception('No se pudo acceder al directorio de descargas');
      }

      // Crear carpeta si no existe
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      int successCount = 0;
      int failCount = 0;

      // Canal para comunicación con código nativo Android
      const platform = MethodChannel('com.inmobarco.app/media_scanner');

      for (int i = 0; i < apartment!.imagenes.length; i++) {
        try {
          final imageUrl = apartment!.imagenes[i];
          final fileName = '${apartment!.reference.replaceAll(' ', '_')}_${i + 1}.jpg';
          final filePath = '${downloadsDir.path}/$fileName';

          await dio.download(
            imageUrl,
            filePath,
            options: Options(
              headers: {
                'User-Agent': 'Mozilla/5.0',
              },
            ),
          );

          // Notificar al sistema Android sobre el nuevo archivo
          if (Platform.isAndroid) {
            try {
              await platform.invokeMethod('scanFile', {'path': filePath});
            } catch (e) {
              debugPrint('Error escaneando archivo: $e');
            }
          }

          successCount++;
        } catch (e) {
          debugPrint('Error descargando imagen ${i + 1}: $e');
          failCount++;
        }
      }

      if (mounted) {
        final downloadPath = Platform.isAndroid 
            ? 'Pictures/Inmobarco'
            : downloadsDir.path;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              failCount == 0
                  ? '✓ $successCount imágenes descargadas en:\n$downloadPath\n\nYa disponibles en tu galería'
                  : '$successCount descargadas, $failCount fallidas\nRuta: $downloadPath',
            ),
            backgroundColor: failCount == 0 ? AppColors.success : AppColors.warning,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al descargar imágenes: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloadingImages = false;
        });
      }
    }
  }
}
