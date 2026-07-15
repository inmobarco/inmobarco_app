/// Entrada de la bitácora de un cliente CRM (backend Inmobarco).
///
/// Tolera las dos formas del backend: `/crm/latest-notes` usa `note_id`
/// y no trae asesor; `/crm/clients/{id}/notes` usa `id` y trae
/// `first_name`/`last_name` del asesor.
class ClientNote {
  final int? id;
  final int? idClientWasi;
  final String note;
  final String? noteType;
  final String? createdAt;
  final String? advisorName;

  ClientNote({
    this.id,
    this.idClientWasi,
    required this.note,
    this.noteType,
    this.createdAt,
    this.advisorName,
  });

  factory ClientNote.fromJson(Map<String, dynamic> json) {
    final advisorName =
        '${json['first_name'] ?? ''} ${json['last_name'] ?? ''}'.trim();
    return ClientNote(
      id: int.tryParse((json['id'] ?? json['note_id'])?.toString() ?? ''),
      idClientWasi: int.tryParse(json['id_client_wasi']?.toString() ?? ''),
      note: json['note']?.toString() ?? '',
      noteType: json['note_type']?.toString(),
      createdAt: json['created_at']?.toString(),
      advisorName: advisorName.isEmpty ? null : advisorName,
    );
  }
}
