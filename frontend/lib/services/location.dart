import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationService {
  const LocationService._();

  /// Play Policy prominent disclosure — must be shown *before* system prompt.
  /// Returns true if user accepted and permission granted.
  static Future<bool> showProminentDisclosure(BuildContext context) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD96C4A).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.location_on_rounded, color: Color(0xFFD96C4A), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Allow location access?',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Handover uses your location to:',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
              ),
              const SizedBox(height: 8),
              _bullet(theme, 'Find nearby neighbors and skills (distance sort & radius filter).'),
              _bullet(theme, 'Create a rough privacy area (grid) instead of sharing your exact address.'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Location is optional. You can also pick an area manually on the map. Granting “Precise” will be downgraded to coarse for privacy.',
                        style: TextStyle(fontSize: 11.5, color: theme.colorScheme.onSurface.withValues(alpha: 0.65), height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Not now'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD96C4A)),
                      child: const Text('Continue'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  'You can change this anytime in Settings',
                  style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.45)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return result == true;
  }

  static Widget _bullet(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 6), child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFFD96C4A), shape: BoxShape.circle))),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(fontSize: 12.5, color: theme.colorScheme.onSurface.withValues(alpha: 0.75), height: 1.4))),
        ],
      ),
    );
  }

  static Future<LatLng?> getCurrentPosition({BuildContext? context}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return null;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // Play requires prominent disclosure before requestPermission
      if (context != null && context.mounted) {
        final accepted = await showProminentDisclosure(context);
        if (!accepted) return null;
      }
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 10),
      ),
    );

    return LatLng(position.latitude, position.longitude);
  }

  static Future<bool> openSettings() => Geolocator.openAppSettings();
}
