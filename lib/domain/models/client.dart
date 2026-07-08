/// Cliente del CRM: datos personales de WASI (`/client/search` filtrado por
/// la propiedad dummy del asesor).
class Client {
  final int idClientWasi;
  final String firstName;
  final String lastName;
  final String? email;
  final String? phone;
  final String? cellPhone;
  final String? cityLabel;
  final String? address;
  final String? identification;
  final int? idClientStatus;
  final String? query;
  final String? createdAt;

  Client({
    required this.idClientWasi,
    required this.firstName,
    required this.lastName,
    this.email,
    this.phone,
    this.cellPhone,
    this.cityLabel,
    this.address,
    this.identification,
    this.idClientStatus,
    this.query,
    this.createdAt,
  });

  String get fullName => '$firstName $lastName'.trim();

  /// Etiqueta del estado del cliente en el pipeline CRM.
  String get statusLabel {
    switch (idClientStatus) {
      case 1:
        return 'Nuevo';
      case 2:
        return 'En Proceso';
      case 3:
        return 'Convertido';
      case 4:
        return 'Recuperado';
      case 5:
        return 'Perdido';
      default:
        return '—';
    }
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static String? _parseString(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    return s.isEmpty ? null : s;
  }

  /// Construye el cliente desde el JSON crudo de WASI.
  factory Client.fromWasi(Map<String, dynamic> wasi) {
    return Client(
      idClientWasi: _parseInt(wasi['id_client']) ?? 0,
      firstName: _parseString(wasi['first_name']) ?? '',
      lastName: _parseString(wasi['last_name']) ?? '',
      email: _parseString(wasi['email']),
      phone: _parseString(wasi['phone']),
      cellPhone: _parseString(wasi['cell_phone']),
      cityLabel: _parseString(wasi['city_label']),
      address: _parseString(wasi['address']),
      identification: _parseString(wasi['identification']),
      idClientStatus: _parseInt(wasi['id_client_status']),
      query: _parseString(wasi['query']),
      createdAt: _parseString(wasi['created_at']),
    );
  }

  /// Serialización camelCase para el caché local.
  Map<String, dynamic> toJson() => {
        'idClientWasi': idClientWasi,
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phone': phone,
        'cellPhone': cellPhone,
        'cityLabel': cityLabel,
        'address': address,
        'identification': identification,
        'idClientStatus': idClientStatus,
        'query': query,
        'createdAt': createdAt,
      };

  factory Client.fromJson(Map<String, dynamic> json) {
    return Client(
      idClientWasi: _parseInt(json['idClientWasi']) ?? 0,
      firstName: _parseString(json['firstName']) ?? '',
      lastName: _parseString(json['lastName']) ?? '',
      email: _parseString(json['email']),
      phone: _parseString(json['phone']),
      cellPhone: _parseString(json['cellPhone']),
      cityLabel: _parseString(json['cityLabel']),
      address: _parseString(json['address']),
      identification: _parseString(json['identification']),
      idClientStatus: _parseInt(json['idClientStatus']),
      query: _parseString(json['query']),
      createdAt: _parseString(json['createdAt']),
    );
  }
}
