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
  });

  String get fullName => '$firstName $lastName'.trim();

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
    );
  }
}
