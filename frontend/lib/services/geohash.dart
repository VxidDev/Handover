import 'package:latlong2/latlong.dart';

class GeoBounds {
  const GeoBounds({
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
  });

  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  LatLng get center => LatLng(
        (minLat + maxLat) / 2,
        (minLng + maxLng) / 2,
      );

  List<LatLng> toPolygonPoints() => [
        LatLng(minLat, minLng),
        LatLng(maxLat, minLng),
        LatLng(maxLat, maxLng),
        LatLng(minLat, maxLng),
      ];
}

class Geohash {
  static const String _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

  static String encode(double lat, double lng, int precision) {
    double minLat = -90;
    double maxLat = 90;
    double minLng = -180;
    double maxLng = 180;

    bool isLng = true;
    int bit = 0;
    int charIndex = 0;

    final buffer = StringBuffer();

    while (buffer.length < precision) {
      if (isLng) {
        final mid = (minLng + maxLng) / 2;
        if (lng >= mid) {
          charIndex = (charIndex << 1) | 1;
          minLng = mid;
        } else {
          charIndex <<= 1;
          maxLng = mid;
        }
      } else {
        final mid = (minLat + maxLat) / 2;
        if (lat >= mid) {
          charIndex = (charIndex << 1) | 1;
          minLat = mid;
        } else {
          charIndex <<= 1;
          maxLat = mid;
        }
      }

      isLng = !isLng;
      bit++;

      if (bit == 5) {
        buffer.write(_base32[charIndex]);
        bit = 0;
        charIndex = 0;
      }
    }

    return buffer.toString();
  }

  static GeoBounds decodeBounds(String geohash) {
    double minLat = -90;
    double maxLat = 90;
    double minLng = -180;
    double maxLng = 180;

    bool isLng = true;

    for (final c in geohash.toLowerCase().split('')) {
      final idx = _base32.indexOf(c);
      if (idx == -1) {
        throw FormatException('Invalid geohash character: $c');
      }

      for (int bit = 4; bit >= 0; bit--) {
        final mask = 1 << bit;

        if (isLng) {
          final mid = (minLng + maxLng) / 2;
          if ((idx & mask) != 0) {
            minLng = mid;
          } else {
            maxLng = mid;
          }
        } else {
          final mid = (minLat + maxLat) / 2;
          if ((idx & mask) != 0) {
            minLat = mid;
          } else {
            maxLat = mid;
          }
        }

        isLng = !isLng;
      }
    }

    return GeoBounds(
      minLat: minLat,
      maxLat: maxLat,
      minLng: minLng,
      maxLng: maxLng,
    );
  }
}