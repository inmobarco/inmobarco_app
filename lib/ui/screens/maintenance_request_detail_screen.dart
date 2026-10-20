import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../data/services/api_service.dart';
import '../../domain/models/maintenance_request.dart';
import '../widgets/maintenance_badges.dart';

/// Detalle de una solicitud de mantenimiento, de solo lectura: datos
/// completos, adjuntos y bitácora.
///
/// Se pinta de inmediato con el resumen del listado y se completa con las tres
/// consultas, que van en paralelo y fallan por separado: sin bitácora el
/// detalle sigue siendo útil.
class MaintenanceRequestDetailScreen extends StatefulWidget {
  const MaintenanceRequestDetailScreen({super.key, required this.summary});

  final MaintenanceRequest summary;

  @override
  State<MaintenanceRequestDetailScreen> createState() =>
      _MaintenanceRequestDetailScreenState();
}

class _MaintenanceRequestDetailScreenState
    extends State<MaintenanceRequestDetailScreen> {
  late MaintenanceRequest _request = widget.summary;
  bool _detailLoaded = false;
  String? _detailError;

  List<MaintenanceAttachment>? _attachments;
  String? _attachmentsError;

  List<MaintenanceEvent>? _events;
  String? _eventsError;

  /// Evita abrir dos veces un adjunto mientras se renuevan las URLs.
  bool _openingAttachment = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() =>
      Future.wait([_loadDetail(), _loadAttachments(), _loadEvents()]);

  Future<void> _loadDetail() async {
    try {
      final data = await ApiService.getMaintenanceRequest(_request.id);
      if (!mounted) return;
      setState(() {
        _request = MaintenanceRequest.fromJson(data);
        _detailLoaded = true;
        _detailError = null;
      });
    } catch (e) {
      debugPrint('⚠️ Error cargando la solicitud ${_request.id}: $e');
      if (!mounted) return;
      setState(() => _detailError = _errorMessage(e, 'la solicitud'));
    }
  }

  Future<void> _loadAttachments() async {
    try {
      final data = await ApiService.getMaintenanceAttachments(_request.id);
      if (!mounted) return;
      setState(() {
        _attachments = MaintenanceAttachment.listFromJson(data);
        _attachmentsError = null;
      });
    } catch (e) {
      debugPrint('⚠️ Error cargando adjuntos de ${_request.id}: $e');
      if (!mounted) return;
      setState(() => _attachmentsError = _errorMessage(e, 'los archivos'));
    }
  }

  Future<void> _loadEvents() async {
    try {
      final data = await ApiService.getMaintenanceEvents(_request.id);
      if (!mounted) return;
      setState(() {
        _events = MaintenanceEvent.listFromJson(data);
        _eventsError = null;
      });
    } catch (e) {
      debugPrint('⚠️ Error cargando la bitácora de ${_request.id}: $e');
      if (!mounted) return;
      setState(() => _eventsError = _errorMessage(e, 'la bitácora'));
    }
  }

  String _errorMessage(Object e, String what) {
    if (e is DioException) {
      switch (e.response?.statusCode) {
        case 401:
          return 'Tu sesión expiró. Vuelve a iniciar sesión.';
        case 403:
          return 'Tu usuario no tiene acceso a los mantenimientos.';
        case 404:
          return 'Solicitud no encontrada.';
      }
    }
    return 'No se pudo cargar $what. Revisa tu conexión.';
  }

  // ---------------------------------------------------------------------------
  // Acciones (solo abrir, nada se modifica)
  // ---------------------------------------------------------------------------

  Future<void> _openAttachment(MaintenanceAttachment attachment) async {
    if (_openingAttachment) return;
    _openingAttachment = true;
    try {
      var current = attachment;
      // Las URLs firmadas duran 15 min: si vencieron se piden de nuevo.
      if (current.isUrlExpired()) {
        await _loadAttachments();
        if (!mounted) return;
        final fresh = _attachments?.where((a) => a.id == attachment.id);
        if (fresh == null || fresh.isEmpty || fresh.first.isUrlExpired()) {
          _showSnack('No se pudo abrir el archivo. Intenta de nuevo.');
          return;
        }
        current = fresh.first;
      }

      if (current.isImage) {
        final images = _attachments!
            .where((a) => a.isImage && a.url != null)
            .toList();
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _AttachmentImageViewer(
              images: images,
              initialIndex: images.indexWhere((a) => a.id == current.id),
            ),
          ),
        );
        return;
      }

      // `url` abre PDF y video en línea; el resto la API lo fuerza a descarga.
      // isUrlExpired() ya garantizó que no es null.
      final opened = await launchUrl(
        Uri.parse(current.url!),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) _showSnack('No hay una app para abrir este archivo.');
    } finally {
      _openingAttachment = false;
    }
  }

  Future<void> _callReporter(String phone) async {
    final opened = await launchUrl(Uri(scheme: 'tel', path: phone));
    if (!opened) _showSnack('No se pudo abrir el marcador.');
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final r = _request;

    return Scaffold(
      appBar: AppBar(title: Text(r.ticket)),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            if (!_detailLoaded && _detailError == null)
              const LinearProgressIndicator(minHeight: 2),
            if (_detailError != null) _buildBanner(_detailError!),
            if (!r.isActive)
              _buildBanner(
                'Esta solicitud fue eliminada.',
                color: AppColors.warning,
              ),
            _buildHeader(r),
            _section('Descripción', [
              Text(
                r.description ?? 'Sin descripción.',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textColor,
                ),
              ),
            ]),
            _section('Inmueble', [
              _infoRow('Dirección', r.propertyAddress),
              _infoRow('Unidad', r.unit),
              _infoRow('Apartamento', r.aptNum),
              _infoRow('Municipio', r.city),
              _infoRow(
                'Contrato',
                r.contractNumber == null
                    ? null
                    : '${r.contractNumber}'
                          '${r.contractVerified ? '' : ' (sin verificar)'}',
                trailing: r.contractNumber != null && r.contractVerified
                    ? const Icon(
                        Icons.verified,
                        size: 16,
                        color: AppColors.success,
                      )
                    : null,
              ),
              _infoRow('Autorización de ingreso', r.entryAuthorization),
            ]),
            _section('Reportante', [
              _infoRow('Nombre', r.reporterName),
              _infoRow('Tipo de cliente', r.clientType),
              _infoRow('Documento', r.reporterDocument),
              _infoRow(
                'Teléfono',
                r.reporterPhone,
                trailing: r.reporterPhone == null
                    ? null
                    : IconButton(
                        icon: const Icon(
                          Icons.phone,
                          size: 20,
                          color: AppColors.primaryColor,
                        ),
                        tooltip: 'Llamar',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _callReporter(r.reporterPhone!),
                      ),
              ),
              _infoRow('Correo', r.reporterEmail),
            ]),
            if (_detailLoaded)
              _section('Disponibilidad', [
                _infoRow('Días', r.availableDays),
                _infoRow('Franja', r.timeSlot),
                _infoRow('Notas', r.availabilityNotes),
              ], emptyText: 'Sin disponibilidad registrada.'),
            _section('Gestión', [
              _infoRow('Responsable', r.assignedUserName ?? 'Sin responsable'),
              _infoRow('Asume el costo', r.responsiblePartyLabel),
              _infoRow('Requiere revisión', r.needsReview ? 'Sí' : 'No'),
              if (r.needsReview) _infoRow('Motivo', r.reviewReason),
              _infoRow('Enviada', _dateOrNull(r.submittedAt)),
              _infoRow('Creada', _dateOrNull(r.createdAt)),
              _infoRow('Actualizada', _dateOrNull(r.updatedAt)),
              _infoRow('Cerrada', _dateOrNull(r.closedAt)),
            ]),
            if (_detailLoaded && r.consentAccepted != null)
              _section('Consentimiento de datos', [
                _infoRow('Aceptado', r.consentAccepted! ? 'Sí' : 'No'),
                _infoRow('Versión de la política', r.consentPolicyVersion),
                _infoRow('Fecha', _dateOrNull(r.consentAcceptedAt)),
              ]),
            _buildAttachmentsSection(),
            _buildEventsSection(),
          ],
        ),
      ),
    );
  }

  String? _dateOrNull(DateTime? date) =>
      date == null ? null : formatMaintenanceDate(date, withYear: true);

  Widget _buildHeader(MaintenanceRequest r) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              MaintenanceBadge.status(r.status),
              MaintenanceBadge.priority(r.priority),
              if (r.isHappeningNow)
                const MaintenanceBadge(
                  label: 'Ocurriendo ahora',
                  color: AppColors.error,
                  icon: Icons.warning_amber,
                ),
              if (r.needsReview)
                const MaintenanceBadge(
                  label: 'Requiere revisión',
                  color: AppColors.warning,
                  icon: Icons.flag_outlined,
                ),
            ],
          ),
          if (r.categoryText.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              r.categoryText,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBanner(String text, {Color color = AppColors.error}) {
    return Container(
      width: double.infinity,
      color: color.withValues(alpha: 0.1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(text, style: TextStyle(fontSize: 12, color: color)),
    );
  }

  /// Tarjeta con título. Las filas sin valor se omiten; si no queda ninguna,
  /// se muestra [emptyText] o se omite la sección.
  Widget _section(String title, List<Widget?> children, {String? emptyText}) {
    final visible = children.whereType<Widget>().toList();
    if (visible.isEmpty && emptyText == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Card(
        margin: EdgeInsets.zero,
        color: AppColors.backgroundLevel1,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.borderLight),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              if (visible.isEmpty)
                Text(
                  emptyText!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textColor2,
                  ),
                )
              else
                ...visible,
            ],
          ),
        ),
      ),
    );
  }

  Widget? _infoRow(String label, String? value, {Widget? trailing}) {
    if (value == null) return null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.textColor2),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontSize: 14, color: AppColors.textColor),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  Widget _buildAttachmentsSection() {
    final attachments = _attachments;
    if (attachments == null) {
      return _section('Archivos', [
        _attachmentsError == null
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            : Text(
                _attachmentsError!,
                style: const TextStyle(fontSize: 13, color: AppColors.error),
              ),
      ]);
    }

    // La API ya los entrega ordenados por fase y posición.
    final byPhase = <String, List<MaintenanceAttachment>>{};
    for (final a in attachments) {
      byPhase.putIfAbsent(a.phase, () => []).add(a);
    }

    return _section('Archivos (${attachments.length})', [
      for (final entry in byPhase.entries) ...[
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 6),
          child: Text(
            entry.value.first.phaseLabel,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textColor2,
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: entry.value.map(_buildAttachmentTile).toList(),
        ),
        const SizedBox(height: 6),
      ],
    ], emptyText: 'Sin archivos adjuntos.');
  }

  Widget _buildAttachmentTile(MaintenanceAttachment a) {
    const size = 88.0;
    final Widget content;
    if (a.isImage && a.url != null) {
      content = Image.network(
        a.url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: 264,
        errorBuilder: (_, _, _) => const Center(
          child: Icon(Icons.broken_image_outlined, color: AppColors.textColor2),
        ),
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
      );
    } else {
      content = Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_fileIcon(a), color: AppColors.primaryColor),
            const SizedBox(height: 4),
            Text(
              a.displayName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: AppColors.textColor),
            ),
            if (a.sizeText != null)
              Text(
                a.sizeText!,
                style: const TextStyle(
                  fontSize: 9,
                  color: AppColors.textColor2,
                ),
              ),
          ],
        ),
      );
    }

    return Tooltip(
      message: a.displayName,
      child: Material(
        color: AppColors.backgroundLevel2,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openAttachment(a),
          child: SizedBox(width: size, height: size, child: content),
        ),
      ),
    );
  }

  IconData _fileIcon(MaintenanceAttachment a) {
    final type = a.contentType ?? '';
    if (type == 'application/pdf') return Icons.picture_as_pdf_outlined;
    if (type.startsWith('video/')) return Icons.videocam_outlined;
    if (type.startsWith('image/')) return Icons.image_outlined;
    return Icons.insert_drive_file_outlined;
  }

  Widget _buildEventsSection() {
    final events = _events;
    if (events == null) {
      return _section('Bitácora', [
        _eventsError == null
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            : Text(
                _eventsError!,
                style: const TextStyle(fontSize: 13, color: AppColors.error),
              ),
      ]);
    }

    return _section(
      'Bitácora',
      events.map(_buildEventTile).toList(),
      emptyText: 'Sin movimientos registrados.',
    );
  }

  Widget _buildEventTile(MaintenanceEvent event) {
    final detail = event.detail;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.primaryColor.withValues(alpha: 0.12),
            child: Icon(
              _eventIcon(event.eventType),
              size: 16,
              color: AppColors.primaryColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textColor,
                  ),
                ),
                if (detail != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textColor,
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  '${event.actorText} · '
                  '${formatMaintenanceDate(event.createdAt, withYear: true)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textColor2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _eventIcon(String type) {
    switch (type) {
      case 'cambio_estado':
        return Icons.swap_horiz;
      case 'nota':
        return Icons.sticky_note_2_outlined;
      case 'asignacion':
        return Icons.engineering_outlined;
      case 'actualizacion':
        return Icons.edit_note;
      default:
        return Icons.history;
    }
  }
}

/// Visor a pantalla completa de las imágenes adjuntas, con zoom.
class _AttachmentImageViewer extends StatefulWidget {
  const _AttachmentImageViewer({
    required this.images,
    required this.initialIndex,
  });

  final List<MaintenanceAttachment> images;
  final int initialIndex;

  @override
  State<_AttachmentImageViewer> createState() => _AttachmentImageViewerState();
}

class _AttachmentImageViewerState extends State<_AttachmentImageViewer> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex.clamp(0, widget.images.length - 1),
  );
  late int _index = widget.initialIndex.clamp(0, widget.images.length - 1);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.images[_index];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: AppColors.pureWhite,
        title: Text(
          '${current.phaseLabel} · ${_index + 1}/${widget.images.length}',
          style: const TextStyle(fontSize: 16),
        ),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.images.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) => InteractiveViewer(
          maxScale: 5,
          child: Center(
            child: Image.network(
              widget.images[i].url!,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : const CircularProgressIndicator(color: AppColors.pureWhite),
              errorBuilder: (_, _, _) => const Text(
                'No se pudo cargar la imagen.\nCierra y vuelve a abrirla.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.pureWhite),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
