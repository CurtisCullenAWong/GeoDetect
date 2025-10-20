import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:location/location.dart' as location_pkg;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  final location_pkg.Location _locationService = location_pkg.Location();

  LatLng? _selectedCoordinates;
  String _currentAddress = "Fetching your current location...";
  bool _isAddressLoading = false;
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _initializeUserLocation();
  }

  Future<void> _initializeUserLocation() async {
    try {
      final hasService = await _locationService.serviceEnabled() ||
          await _locationService.requestService();

      if (!hasService) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Location service is disabled.")),
          );
        }
        return;
      }

      final permission = await _locationService.requestPermission();
      if (permission != location_pkg.PermissionStatus.granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Location permission denied.")),
          );
        }
        return;
      }

      final locationData = await _locationService.getLocation();
      final userCoords = LatLng(locationData.latitude!, locationData.longitude!);

      setState(() {
        _selectedCoordinates = userCoords;
      });

      _updateMarkerAndAddress(newCoords: userCoords);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to get location: $e")),
        );
      }
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_selectedCoordinates != null) {
      _updateMarkerAndAddress(newCoords: _selectedCoordinates!, fetchAddress: false);
    }
  }

  void _onCameraIdle() async {
    if (_mapController == null) return;

    final bounds = await _mapController!.getVisibleRegion();
    final center = LatLng(
      (bounds.northeast.latitude + bounds.southwest.latitude) / 2,
      (bounds.northeast.longitude + bounds.southwest.longitude) / 2,
    );

    if (_selectedCoordinates == null ||
        (_selectedCoordinates!.latitude - center.latitude).abs() > 0.0001 ||
        (_selectedCoordinates!.longitude - center.longitude).abs() > 0.0001) {
      _updateMarkerAndAddress(newCoords: center);
    }
  }

  void _onMarkerDragEnd(LatLng newPosition) {
    _updateMarkerAndAddress(newCoords: newPosition);
  }

  Future<void> _updateMarkerAndAddress({
    required LatLng newCoords,
    bool fetchAddress = true,
  }) async {
    setState(() {
      _selectedCoordinates = newCoords;
      _isAddressLoading = fetchAddress;
      if (fetchAddress) _currentAddress = "Getting address...";
      _markers = {
        Marker(
          markerId: const MarkerId('selectedLocation'),
          position: newCoords,
          draggable: true,
          onDragEnd: _onMarkerDragEnd,
        ),
      };
    });

    if (fetchAddress) {
      try {
        final placemarks = await placemarkFromCoordinates(
          newCoords.latitude,
          newCoords.longitude,
        );

        if (placemarks.isNotEmpty) {
          final address = placemarks.first;
          final formatted = [
            address.name,
            address.street,
            address.subLocality,
            address.locality,
            address.administrativeArea,
            address.postalCode,
            address.country,
          ].where((s) => s != null && s.isNotEmpty).join(', ');

          if (mounted) {
            setState(() {
              _currentAddress = formatted;
              _isAddressLoading = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _currentAddress = "No address found.";
              _isAddressLoading = false;
            });
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _currentAddress = "Failed to load address.";
            _isAddressLoading = false;
          });
        }
      }
    }
  }

  void _recenterToUserLocation() async {
    try {
      final locationData = await _locationService.getLocation();
      final userCoords = LatLng(locationData.latitude!, locationData.longitude!);

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(userCoords, 16.0),
      );
      _updateMarkerAndAddress(newCoords: userCoords);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Re-centered to your location.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error getting location: $e")),
        );
      }
    }
  }

  void _confirmLocation() {
    if (!_isAddressLoading && _selectedCoordinates != null && mounted) {
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
      body: _selectedCoordinates == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(
                    target: _selectedCoordinates!,
                    zoom: 16.0,
                  ),
                  markers: _markers,
                  mapType: MapType.normal,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  onCameraIdle: _onCameraIdle,
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: _isAddressLoading
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  _currentAddress,
                                  style: theme.textTheme.titleSmall,
                                ),
                              ],
                            )
                          : Text(
                              _currentAddress,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleSmall,
                            ),
                    ),
                  ),
                ),
                Positioned(
                  top: 100,
                  right: 16,
                  child: FloatingActionButton(
                    heroTag: 'myLocationFab',
                    onPressed: _recenterToUserLocation,
                    mini: true,
                    backgroundColor: theme.colorScheme.secondary,
                    foregroundColor: theme.colorScheme.onSecondary,
                    child: const Icon(Icons.my_location),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          height: 54,
          child: ElevatedButton.icon(
            onPressed: _isAddressLoading ? null : _confirmLocation,
            icon: Icon(_isAddressLoading
                ? Icons.location_searching
                : Icons.check),
            label: Text(
              _isAddressLoading
                  ? "Getting Address..."
                  : "Confirm Location",
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onPrimary,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}