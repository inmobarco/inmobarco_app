import 'dart:convert';
import 'dart:typed_data';

class ApartmentPhoto {
  ApartmentPhoto({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;

  String? _base64;

  /// Base64 de la foto, calculado una sola vez.
  ///
  /// El borrador se guarda muchas veces mientras se llena el formulario y el
  /// envío al webhook exige base64 dentro del JSON: sin memorizar, cada
  /// guardado recodificaba hasta 30 fotos.
  String get base64 => _base64 ??= base64Encode(bytes);
}
