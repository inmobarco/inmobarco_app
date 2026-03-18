class GeoLocation {
  final double latitude;
  final double longitude;

  const GeoLocation({required this.latitude, required this.longitude});

  @override
  String toString() => '$latitude,$longitude';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeoLocation &&
          other.latitude == latitude &&
          other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}
