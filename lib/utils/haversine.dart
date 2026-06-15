import 'dart:math';

class Haversine {
  static const double _earthRadiusKm = 6371.0;

  /// Hitung jarak antara dua koordinat (lat/lon) menggunakan rumus Haversine.
  /// Hasilnya dalam satuan kilometer.
  static double distanceKm({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return _earthRadiusKm * c;
  }

  static double _toRadians(double degrees) {
    return degrees * (pi / 180.0);
  }

  /// Estimasi waktu tempuh berdasarkan jarak (asumsi kecepatan rata-rata 40 km/h)
  static String estimasiWaktu(double distanceKm) {
    const double avgSpeedKmPerHour = 40.0;
    final double timeHours = distanceKm / avgSpeedKmPerHour;
    final int minutes = (timeHours * 60).round();

    if (minutes < 60) {
      return '$minutes menit';
    } else {
      final int hours = minutes ~/ 60;
      final int remainingMinutes = minutes % 60;
      if (remainingMinutes == 0) {
        return '$hours jam';
      }
      return '$hours jam $remainingMinutes menit';
    }
  }

  static String formatDistance(double km) {
    if (km < 1.0) {
      return '${(km * 1000).round()} m';
    }
    return '${km.toStringAsFixed(2)} km';
  }
}
