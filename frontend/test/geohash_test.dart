import 'package:flutter_test/flutter_test.dart';

import 'package:handover/services/geohash.dart';

void main() {
  group('Geohash.encode', () {
    test('encodes known coordinates', () {
      expect(Geohash.encode(0, 0, 1), 's');
      expect(Geohash.encode(37.7749, -122.4195, 5), '9q8yy');
      expect(Geohash.encode(37.7749, -122.4195, 6), '9q8yyk');
      expect(Geohash.encode(51.5074, -0.1278, 5), 'gcpvj');
    });

    test('uses lowercase base32 characters', () {
      final hash = Geohash.encode(37.7749, -122.4195, 12);
      expect(hash, matches(RegExp(r'^[0-9bcdefghjkmnpqrstuvwxyz]+$')));
      expect(hash.length, 12);
    });
  });

  group('Geohash.decodeBounds', () {
    test('contains the encoded point', () {
      for (final point in const [
        (lat: 37.7749, lng: -122.4195),
        (lat: 51.5074, lng: -0.1278),
        (lat: -33.8688, lng: 151.2093),
        (lat: 0.0, lng: 0.0),
      ]) {
        final bounds = Geohash.decodeBounds(
          Geohash.encode(point.lat, point.lng, 7),
        );
        expect(point.lat, inInclusiveRange(bounds.minLat, bounds.maxLat));
        expect(point.lng, inInclusiveRange(bounds.minLng, bounds.maxLng));
      }
    });

    test('higher precision produces smaller bounds', () {
      final coarse = Geohash.decodeBounds(
        Geohash.encode(37.7749, -122.4195, 4),
      );
      final fine = Geohash.decodeBounds(Geohash.encode(37.7749, -122.4195, 8));

      double area(GeoBounds b) => (b.maxLat - b.minLat) * (b.maxLng - b.minLng);

      expect(area(fine), lessThan(area(coarse)));
    });

    test('throws FormatException on an invalid character', () {
      expect(() => Geohash.decodeBounds('9q8yY!'), throwsFormatException);
      expect(
        () => Geohash.decodeBounds('aaaa'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('GeoBounds', () {
    test('computes the center', () {
      final bounds = GeoBounds(minLat: 10, maxLat: 20, minLng: 30, maxLng: 40);
      final center = bounds.center;

      expect(center.latitude, 15);
      expect(center.longitude, 35);
    });

    test('builds polygon points in clockwise order', () {
      final bounds = GeoBounds(minLat: 10, maxLat: 20, minLng: 30, maxLng: 40);
      final points = bounds.toPolygonPoints();

      expect(points, hasLength(4));
      expect(points.first.latitude, 10);
      expect(points.first.longitude, 30);
      expect(points.last.latitude, 10);
      expect(points.last.longitude, 40);
    });
  });
}
