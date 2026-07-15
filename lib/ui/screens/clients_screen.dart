import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/api_service.dart';
import '../../domain/models/client.dart';
import '../../domain/models/client_note.dart';
import '../providers/client_provider.dart';
import 'add_client_screen.dart';

Color _statusColor(int? status) {
  switch (status) {
    case 1: // Nuevo
      return AppColors.info;
    case 2: // En Proceso
      return AppColors.warning;
    case 3: // Convertido
      return AppColors.success;
    case 4: // Recuperado
      return Colors.teal;
    case 5: // Perdido
      return AppColors.error;
    default:
      return AppColors.textColor2;
  }
}

Widget _statusChip(Client client) {
  final color = _statusColor(client.idClientStatus);
  return Container(
    margin: const EdgeInsets.only(left: 8),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      client.statusLabel,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
    ),
  );
}

String _formatNoteDate(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  final date = DateTime.tryParse(raw);
  if (date == null) return raw;
  // El backend envía UTC; mostrar en hora local (America/Bogota)
  return DateFormat('d MMM, HH:mm', 'es_ES').format(date.toLocal());
}

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClientProvider>().ensureLoaded();
    });
  }

  Future<void> _createNew() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddClientScreen()),
    );
    if (created == true && mounted) {
      // La lista ya se refrescó dentro de createClient
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cliente creado'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clientes')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add_client_fab',
        backgroundColor: AppColors.primaryColor,
        onPressed: _createNew,
        tooltip: 'Nuevo cliente',
        child: const Icon(Icons.add, color: AppColors.pureWhite),
      ),
      body: Consumer<ClientProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Text(
                      'Referencia de asesor: ${provider.advisorPropertyId ?? ''}',
                      style: const TextStyle(color: AppColors.textColor2),
                    ),
                  ],
                ),
              ),
              Expanded(child: _buildBody(provider)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody(ClientProvider provider) {
    if (provider.isLoading && provider.clients.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryColor),
      );
    }
    if (provider.error != null && provider.clients.isEmpty) {
      return _buildErrorWidget(provider);
    }
    return RefreshIndicator(
      onRefresh: provider.refresh,
      color: AppColors.primaryColor,
      child: provider.clients.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 120),
                Center(
                  child: Text(
                    'No hay clientes',
                    style: TextStyle(color: AppColors.textColor2),
                  ),
                ),
              ],
            )
          : ListView.separated(
              itemCount: provider.clients.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) =>
                  _buildClientTile(provider, provider.clients[index]),
            ),
    );
  }

  Widget _buildClientTile(ClientProvider provider, Client client) {
    final statusColor = _statusColor(client.idClientStatus);
    final latestNote = provider.latestNoteFor(client.idClientWasi);
    return ListTile(
      isThreeLine: true,
      leading: CircleAvatar(
        backgroundColor: statusColor.withValues(alpha: 0.15),
        child: Icon(Icons.person, color: statusColor),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(client.fullName, overflow: TextOverflow.ellipsis),
          ),
          _statusChip(client),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            client.query ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textColor2),
          ),
          Text(
            latestNote != null
                ? '${_formatNoteDate(latestNote.createdAt)} · ${latestNote.note}'
                : 'Sin entradas en la bitácora',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textColor2,
              fontStyle: FontStyle.italic,
              fontSize: 12,
            ),
          ),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.info_outline, color: AppColors.textColor2),
        tooltip: 'Ver información',
        onPressed: () => _showDetails(client),
      ),
    );
  }

  void _showDetails(Client client) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ClientDetailSheet(client: client),
    );
  }

  Widget _buildErrorWidget(ClientProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.textColor2),
            const SizedBox(height: 16),
            const Text(
              'No se pudieron cargar los clientes',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: AppColors.textColor),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: provider.refresh,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet de detalle: datos del cliente + bitácora completa.
/// El historial se carga solo al abrir el sheet (lazy).
class _ClientDetailSheet extends StatefulWidget {
  final Client client;

  const _ClientDetailSheet({required this.client});

  @override
  State<_ClientDetailSheet> createState() => _ClientDetailSheetState();
}

class _ClientDetailSheetState extends State<_ClientDetailSheet> {
  static const _noteTypes = ['nota', 'visita', 'llamada', 'cambio_estado'];

  List<ClientNote>? _notes; // null = cargando
  String? _notesError;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    setState(() {
      _notes = null;
      _notesError = null;
    });
    try {
      final rows = await ApiService.getClientNotes(widget.client.idClientWasi);
      if (mounted) {
        setState(() => _notes = rows.map(ClientNote.fromJson).toList());
      }
    } catch (e) {
      debugPrint('❌ Error cargando bitácora: $e');
      if (mounted) {
        setState(() => _notesError = 'No se pudo cargar la bitácora');
      }
    }
  }

  Future<void> _addEntry() async {
    final controller = TextEditingController();
    String noteType = _noteTypes.first;
    bool saving = false;

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Nueva entrada'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: noteType,
                decoration: const InputDecoration(
                  labelText: 'Tipo',
                  border: OutlineInputBorder(),
                ),
                items: _noteTypes
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(t.replaceAll('_', ' ')),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) noteType = v;
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 3,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nota *',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed:
                  saving ? null : () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final text = controller.text.trim();
                      if (text.isEmpty) return;
                      setDialogState(() => saving = true);
                      try {
                        await dialogContext.read<ClientProvider>().addNote(
                            widget.client.idClientWasi, text, noteType);
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      } catch (e) {
                        debugPrint('❌ Error creando entrada: $e');
                        if (dialogContext.mounted) {
                          setDialogState(() => saving = false);
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('No se pudo guardar la entrada'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.pureWhite),
                    )
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (created == true && mounted) {
      _loadNotes();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entrada creada'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = widget.client;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.backgroundLevel1,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              client.fullName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textColor,
                              ),
                            ),
                          ),
                          _statusChip(client),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Cliente #${client.idClientWasi}',
                        style: const TextStyle(
                            color: AppColors.textColor2, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      if (client.cellPhone != null)
                        _detailRow(Icons.phone_android, 'Celular', client.cellPhone!),
                      if (client.phone != null)
                        _detailRow(Icons.phone, 'Teléfono', client.phone!),
                      if (client.email != null)
                        _detailRow(Icons.email, 'Correo', client.email!),
                      if (client.cityLabel != null)
                        _detailRow(Icons.location_city, 'Ciudad', client.cityLabel!),
                      if (client.address != null)
                        _detailRow(Icons.location_on, 'Dirección', client.address!),
                      if (client.identification != null)
                        _detailRow(Icons.badge, 'Identificación', client.identification!),
                      if (client.query != null)
                        _detailRow(Icons.search, 'Consulta', client.query!),
                      if (client.createdAt != null)
                        _detailRow(Icons.calendar_today, 'Creado',
                            _formatNoteDate(client.createdAt)),
                      const SizedBox(height: 12),
                      const Divider(),
                      Row(
                        children: [
                          const Text(
                            'Bitácora',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textColor,
                            ),
                          ),
                          const Spacer(),
                          OutlinedButton.icon(
                            onPressed: _addEntry,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Nueva entrada'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildNotesSection(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    if (_notesError != null) {
      return Row(
        children: [
          Expanded(
            child: Text(
              _notesError!,
              style: const TextStyle(color: AppColors.textColor2),
            ),
          ),
          TextButton(onPressed: _loadNotes, child: const Text('Reintentar')),
        ],
      );
    }
    if (_notes == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(color: AppColors.primaryColor),
        ),
      );
    }
    if (_notes!.isEmpty) {
      return const Text(
        'Sin entradas en la bitácora.',
        style: TextStyle(
          color: AppColors.textColor2,
          fontStyle: FontStyle.italic,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _notes!.map(_noteTile).toList(),
    );
  }

  Widget _noteTile(ClientNote note) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (note.noteType != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    note.noteType!.replaceAll('_', ' '),
                    style: const TextStyle(
                      color: AppColors.primaryColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  [
                    _formatNoteDate(note.createdAt),
                    if (note.advisorName != null) note.advisorName!,
                  ].join(' · '),
                  style: const TextStyle(
                      color: AppColors.textColor2, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            note.note,
            style: const TextStyle(color: AppColors.textColor, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textColor2),
          const SizedBox(width: 12),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textColor2, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppColors.textColor, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
