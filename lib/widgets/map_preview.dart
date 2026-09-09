import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../config/app_config.dart';

/// Shows the picked address on an OpenStreetMap tile layer. Tapping the map
/// moves the pin, which the parent reverse-geocodes back into an address.
class MapPreview extends StatefulWidget {
  const MapPreview({
    super.key,
    required this.attribution,
    this.latitude,
    this.longitude,
    this.onTap,
    this.busy = false,
  });

  final double? latitude;
  final double? longitude;
  final String attribution;

  /// Called when the user taps a new point on the map.
  final ValueChanged<LatLng>? onTap;

  /// Shows a progress overlay while the parent resolves the tapped point.
  final bool busy;

  @override
  State<MapPreview> createState() => _MapPreviewState();
}

class _MapPreviewState extends State<MapPreview> {
  final MapController _controller = MapController();
  bool _mapReady = false;

  static const double _zoom = 16;

  LatLng? get _point => widget.latitude != null && widget.longitude != null
      ? LatLng(widget.latitude!, widget.longitude!)
      : null;

  @override
  void didUpdateWidget(covariant MapPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    final point = _point;
    final moved =
        oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude;
    if (point != null && moved && _mapReady) {
      _controller.move(point, _zoom);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final point = _point;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 220,
        child: point == null
            ? _placeholder(theme)
            : Stack(
                children: [
                  FlutterMap(
                    mapController: _controller,
                    options: MapOptions(
                      initialCenter: point,
                      initialZoom: _zoom,
                      onMapReady: () => _mapReady = true,
                      onTap: (_, latLng) => widget.onTap?.call(latLng),
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: AppConfig.packageName,
                        maxZoom: 19,
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: point,
                            width: 44,
                            height: 44,
                            alignment: Alignment.topCenter,
                            child: Icon(
                              Icons.location_on,
                              size: 44,
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          color: Colors.white70,
                          child: Text(
                            widget.attribution,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (widget.busy)
                    const Positioned.fill(
                      child: ColoredBox(
                        color: Colors.black26,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                  Positioned(
                    left: 8,
                    top: 8,
                    child: _hint(theme, 'Tap the map to move the pin'),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _placeholder(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.map_outlined,
              size: 36,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              'Pick an address to see it on the map',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hint(ThemeData theme, String text) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(text, style: theme.textTheme.labelSmall),
      ),
    );
  }
}
