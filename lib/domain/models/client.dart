/// Cliente del CRM: cruce entre la tabla interna (backend Inmobarco)
/// y los datos personales de WASI (`/client/search`).
class Client {
  // Backend CRM (tabla interna)
  final int id;
  final int idClientWasi;
  final String? operationType;
  final double? budgetMin;
  final double? budgetMax;
  final int? bedrooms;
  final String? zones;
  final String? propertyType;
  final String? needsNote;

  // WASI
  final String firstName;
  final String lastName;
  final String? email;
  final String? phone;
  final String? cellPhone;
  final String? cityLabel;
  final String? address;
  final String? identification;

  Client({
    required this.id,
    required this.idClientWasi,
    this.operationType,
    this.budgetMin,
    this.budgetMax,
    this.bedrooms,
    this.zones,
    this.propertyType,
    this.needsNote,
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

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
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

  /// Construye el cliente cruzando la fila del backend CRM con el JSON de WASI.
  factory Client.fromCrmAndWasi(Map<String, dynamic> crm, Map<String, dynamic> wasi) {
    return Client(
      id: _parseInt(crm['id']) ?? 0,
      idClientWasi: _parseInt(crm['id_client_wasi']) ?? 0,
      operationType: _parseString(crm['operation_type']),
      budgetMin: _parseDouble(crm['budget_min']),
      budgetMax: _parseDouble(crm['budget_max']),
      bedrooms: _parseInt(crm['bedrooms']),
      zones: _parseString(crm['zones']),
      propertyType: _parseString(crm['property_type']),
      needsNote: _parseString(crm['needs_note']),
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
        'id': id,
        'idClientWasi': idClientWasi,
        'operationType': operationType,
        'budgetMin': budgetMin,
        'budgetMax': budgetMax,
        'bedrooms': bedrooms,
        'zones': zones,
        'propertyType': propertyType,
        'needsNote': needsNote,
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
      id: _parseInt(json['id']) ?? 0,
      idClientWasi: _parseInt(json['idClientWasi']) ?? 0,
      operationType: _parseString(json['operationType']),
      budgetMin: _parseDouble(json['budgetMin']),
      budgetMax: _parseDouble(json['budgetMax']),
      bedrooms: _parseInt(json['bedrooms']),
      zones: _parseString(json['zones']),
      propertyType: _parseString(json['propertyType']),
      needsNote: _parseString(json['needsNote']),
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
