class Faskes {
  final int? id;
  final String nama;
  final String jenis;
  final String alamat;
  final String alamatLengkap;
  final String telepon;
  final String jamBuka;
  final double latitude;
  final double longitude;
  double? distance; // Distance from user in km, computed at runtime
  bool isRouteDistance; // True if distance is the real route distance from OSRM table

  Faskes({
    this.id,
    required this.nama,
    required this.jenis,
    required this.alamat,
    required this.alamatLengkap,
    required this.telepon,
    required this.jamBuka,
    required this.latitude,
    required this.longitude,
    this.distance,
    this.isRouteDistance = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nama': nama,
      'jenis': jenis,
      'alamat': alamat,
      'alamat_lengkap': alamatLengkap,
      'telepon': telepon,
      'jam_buka': jamBuka,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  factory Faskes.fromMap(Map<String, dynamic> map) {
    return Faskes(
      id: map['id'] as int?,
      nama: map['nama'] as String? ?? '',
      jenis: map['jenis'] as String? ?? '',
      alamat: map['alamat'] as String? ?? '',
      alamatLengkap: map['alamat_lengkap'] as String? ?? '',
      telepon: map['telepon'] as String? ?? '',
      jamBuka: map['jam_buka'] as String? ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }

  factory Faskes.fromJson(Map<String, dynamic> json) {
    return Faskes(
      nama: json['nama'] as String? ?? '',
      jenis: json['jenis'] as String? ?? '',
      alamat: json['alamat'] as String? ?? '',
      alamatLengkap: json['alamat_lengkap'] as String? ?? '',
      telepon: json['telepon'] as String? ?? '',
      jamBuka: json['jam_buka'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
