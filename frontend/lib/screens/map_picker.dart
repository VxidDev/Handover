import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/geohash.dart';

import '../theme/colors.dart';

class GridSelection {
  const GridSelection({
    required this.cellId,
    required this.precision,
    required this.centerLat,
    required this.centerLng,
  });

  final String cellId;
  final int precision;
  final double centerLat;
  final double centerLng;
}

class LocationGridPickerPage extends StatefulWidget {
  const LocationGridPickerPage({
    super.key,
    required this.initialLat,
    required this.initialLng,
  });

  final double initialLat;
  final double initialLng;

  @override
  State<LocationGridPickerPage> createState() => _LocationGridPickerPageState();
}

class _LocationGridPickerPageState extends State<LocationGridPickerPage> {
  static const int _gridPrecision = 6;

  String? _cellId;
  GeoBounds? _cellBounds;

  void _selectPoint(LatLng point) {
    final cellId = Geohash.encode(
      point.latitude,
      point.longitude,
      _gridPrecision,
    );

    final bounds = Geohash.decodeBounds(cellId);

    setState(() {
      _cellId = cellId;
      _cellBounds = bounds;
    });
  }

  void _confirm() {
    if (_cellId == null || _cellBounds == null) return;

    final center = _cellBounds!.center;

    Navigator.of(context).pop(
      GridSelection(
        cellId: _cellId!,
        precision: _gridPrecision,
        centerLat: center.latitude,
        centerLng: center.longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cellCenter = _cellBounds?.center;

    final infoCardBg = isDark
        ? AppColors.darkPaper.withValues(alpha: 0.9)
        : Colors.white.withValues(alpha: 0.82);

    final infoCardBorder = isDark
        ? AppColors.darkBorder.withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.9);

    final infoCardShadow = isDark
        ? Colors.black.withValues(alpha: 0.25)
        : AppColors.inkSoft.withValues(alpha: 0.06);

    final lockIconColor = isDark ? AppColors.terracotta : AppColors.terracottaDeep;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Choose your area'),
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(widget.initialLat, widget.initialLng),
              initialZoom: 14,
              onTap: (tapPosition, point) => _selectPoint(point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.handover',
              ),
              if (_cellBounds != null)
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: _cellBounds!.toPolygonPoints(),
                      color: AppColors.terracotta.withValues(alpha: 0.16),
                      borderColor: AppColors.terracotta.withValues(alpha: 0.55),
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
              if (cellCenter != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: cellCenter,
                      width: 44,
                      height: 44,
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.terracotta,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.terracotta.withValues(alpha: isDark ? 0.4 : 0.25),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.home_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: infoCardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: infoCardBorder, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: infoCardShadow,
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 18,
                    color: lockIconColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Tap the map. We'll turn this into a rough grid area instead of your exact location.",
                      style: TextStyle(
                        fontSize: 12.5,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_cellId != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Selected grid: $_cellId',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _cellId == null ? null : _confirm,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.terracotta,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  child: const Text(
                    'Use this area',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}