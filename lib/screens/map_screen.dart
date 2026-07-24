import 'package:flutter/material.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class DemoLocation {
  final String name;
  final String address;
  final Offset relativePoint;
  final IconData icon;

  const DemoLocation({
    required this.name,
    required this.address,
    required this.relativePoint,
    required this.icon,
  });
}

class _MapScreenState extends State<MapScreen> {
  static const List<DemoLocation> _presetLocations = [
    DemoLocation(
      name: "San Francisco",
      address: "Market St & 4th St, San Francisco, CA 94103, USA",
      relativePoint: Offset(0.35, 0.45),
      icon: Icons.location_city,
    ),
    DemoLocation(
      name: "New York",
      address: "7th Ave & W 42nd St, Times Square, New York, NY 10036, USA",
      relativePoint: Offset(0.65, 0.30),
      icon: Icons.apartment,
    ),
    DemoLocation(
      name: "London",
      address: "Parliament Square, Westminster, London SW1A 0AA, UK",
      relativePoint: Offset(0.50, 0.55),
      icon: Icons.account_balance,
    ),
    DemoLocation(
      name: "Tokyo",
      address: "Shibuya Crossing, Shibuya City, Tokyo 150-0042, Japan",
      relativePoint: Offset(0.75, 0.65),
      icon: Icons.storefront,
    ),
    DemoLocation(
      name: "Miami",
      address: "Ocean Drive & 8th St, Miami Beach, FL 33139, USA",
      relativePoint: Offset(0.25, 0.70),
      icon: Icons.beach_access,
    ),
  ];

  late DemoLocation _selectedPreset;
  late String _currentAddress;
  Offset _pinOffset = const Offset(0.5, 0.5);
  bool _isCustomPin = false;
  bool _initializedFromArgs = false;

  @override
  void initState() {
    super.initState();
    _selectedPreset = _presetLocations[0];
    _currentAddress = _selectedPreset.address;
    _pinOffset = _selectedPreset.relativePoint;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedFromArgs) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args != null) {
        String targetAddress = "";
        if (args is String) {
          targetAddress = args;
        } else if (args.runtimeType.toString() == "AnalysisEntry") {
          try {
            targetAddress = (args as dynamic).address ?? "";
          } catch (_) {}
        } else {
          targetAddress = args.toString();
        }

        if (targetAddress.isNotEmpty) {
          DemoLocation? matchedPreset;
          for (final loc in _presetLocations) {
            if (targetAddress.toLowerCase().contains(loc.name.toLowerCase()) ||
                loc.address.toLowerCase().contains(targetAddress.toLowerCase())) {
              matchedPreset = loc;
              break;
            }
          }

          if (matchedPreset != null) {
            _selectedPreset = matchedPreset;
            _currentAddress = matchedPreset.address;
            _pinOffset = matchedPreset.relativePoint;
            _isCustomPin = false;
          } else {
            _selectedPreset = DemoLocation(
              name: "Target Location",
              address: targetAddress,
              relativePoint: const Offset(0.5, 0.45),
              icon: Icons.pin_drop,
            );
            _currentAddress = targetAddress;
            _pinOffset = const Offset(0.5, 0.45);
            _isCustomPin = true;
          }
        }
      }
      _initializedFromArgs = true;
    }
  }

  void _selectPreset(DemoLocation location) {
    setState(() {
      _selectedPreset = location;
      _currentAddress = location.address;
      _pinOffset = location.relativePoint;
      _isCustomPin = false;
    });
  }

  void _handleMapTap(TapDownDetails details, BoxConstraints constraints) {
    final x = (details.localPosition.dx / constraints.maxWidth).clamp(0.05, 0.95);
    final y = (details.localPosition.dy / constraints.maxHeight).clamp(0.05, 0.95);

    final lat = (37.77 + (0.5 - y) * 0.1).toStringAsFixed(4);
    final lng = (-122.41 + (x - 0.5) * 0.1).toStringAsFixed(4);

    setState(() {
      _pinOffset = Offset(x, y);
      _isCustomPin = true;
      _currentAddress = "Custom Pinned Location (Lat: $lat, Lng: $lng)";
    });
  }

  void _confirmLocation() {
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/analyze', arguments: _currentAddress);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Pin a Location"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.pop(context);
            } else {
              Navigator.of(context).pushReplacementNamed('/');
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.of(context).pushNamed('/history');
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              // Header Section: Presets & Target Address Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: theme.colorScheme.surface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Presets horizontal list
                    SizedBox(
                      height: 40,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _presetLocations.length,
                        itemBuilder: (context, index) {
                          final loc = _presetLocations[index];
                          final isSelected = !_isCustomPin && _selectedPreset.name == loc.name;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: FilterChip(
                              avatar: Icon(
                                loc.icon,
                                size: 16,
                                color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.primary,
                              ),
                              label: Text(loc.name),
                              selected: isSelected,
                              onSelected: (_) => _selectPreset(loc),
                              selectedColor: theme.colorScheme.primary,
                              labelStyle: TextStyle(
                                color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 13,
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Target Location Address Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.pin_drop,
                            color: theme.colorScheme.primary,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "SELECTED LOCATION",
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _currentAddress,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Interactive Map Canvas Area
              Expanded(
                child: Stack(
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return GestureDetector(
                          onTapDown: (details) => _handleMapTap(details, constraints),
                          child: CustomPaint(
                            size: Size(constraints.maxWidth, constraints.maxHeight),
                            painter: DummyMapPainter(theme: theme),
                            child: Stack(
                              children: [
                                // Marker Pin
                                AnimatedPositioned(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOutCubic,
                                  left: _pinOffset.dx * constraints.maxWidth - 24,
                                  top: _pinOffset.dy * constraints.maxHeight - 48,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primaryContainer,
                                          borderRadius: BorderRadius.circular(10),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Colors.black26,
                                              blurRadius: 4,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          _isCustomPin ? "Pinned" : _selectedPreset.name,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.onPrimaryContainer,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Icon(
                                        Icons.location_on,
                                        size: 42,
                                        color: theme.colorScheme.error,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    // Tap Hint Badge
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.touch_app, color: Colors.white, size: 14),
                              SizedBox(width: 6),
                              Text(
                                "Tap canvas to place custom pin",
                                style: TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Action Button Container
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _confirmLocation,
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(
                      "Confirm Location & Analyze",
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
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

class DummyMapPainter extends CustomPainter {
  final ThemeData theme;

  DummyMapPainter({required this.theme});

  @override
  void paint(Canvas canvas, Size size) {
    // Background fill (Map background)
    final bgPaint = Paint()..color = const Color(0xFFE8ECEF);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Draw stylized river
    final riverPaint = Paint()
      ..color = const Color(0xFFA5C9EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 28.0;

    final riverPath = Path()
      ..moveTo(0, size.height * 0.3)
      ..cubicTo(
        size.width * 0.3, size.height * 0.2,
        size.width * 0.6, size.height * 0.6,
        size.width, size.height * 0.45,
      );
    canvas.drawPath(riverPath, riverPaint);

    // Draw Parks (Green areas)
    final parkPaint = Paint()..color = const Color(0xFFC8E6C9);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.1, size.height * 0.1, size.width * 0.25, size.height * 0.2),
        const Radius.circular(16),
      ),
      parkPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.65, size.height * 0.6, size.width * 0.25, size.height * 0.25),
        const Radius.circular(20),
      ),
      parkPaint,
    );

    // Draw Major Roads (White grid lines)
    final majorRoadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 8.0
      ..style = PaintingStyle.stroke;

    final minorRoadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;

    // Horizontal roads
    canvas.drawLine(Offset(0, size.height * 0.25), Offset(size.width, size.height * 0.25), majorRoadPaint);
    canvas.drawLine(Offset(0, size.height * 0.5), Offset(size.width, size.height * 0.5), majorRoadPaint);
    canvas.drawLine(Offset(0, size.height * 0.75), Offset(size.width, size.height * 0.75), majorRoadPaint);

    // Vertical roads
    canvas.drawLine(Offset(size.width * 0.3, 0), Offset(size.width * 0.3, size.height), majorRoadPaint);
    canvas.drawLine(Offset(size.width * 0.6, 0), Offset(size.width * 0.6, size.height), majorRoadPaint);

    // Diagonal/minor roads
    canvas.drawLine(Offset(0, 0), Offset(size.width, size.height), minorRoadPaint);
    canvas.drawLine(Offset(size.width * 0.1, size.height * 0.8), Offset(size.width * 0.8, size.height * 0.1), minorRoadPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}