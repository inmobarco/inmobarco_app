import 'dart:typed_data';

class ApartmentPhoto {
  final Uint8List bytes;
  final String fileName;

  const ApartmentPhoto({required this.bytes, required this.fileName});
}
