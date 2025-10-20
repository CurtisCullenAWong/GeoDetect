import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

class GetStartedScreen extends StatefulWidget {
  const GetStartedScreen({super.key});

  @override
  State<GetStartedScreen> createState() => _GetStartedScreenState();
}

class _GetStartedScreenState extends State<GetStartedScreen>
    with TickerProviderStateMixin {
  late AnimationController _primaryController;
  late AnimationController _buttonController;
  late AnimationController _pulseController;
  
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;
  late Animation<double> _logoScale;
  late Animation<double> _buttonScale;
  late Animation<double> _pulseAnimation;
  
  bool _isLoading = false;
  String _statusText = '';
  LocationPermission? _currentPermission;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _checkInitialPermissionStatus();
  }

  void _initializeAnimations() {
    _primaryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _buttonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _fadeIn = CurvedAnimation(
      parent: _primaryController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    );

    _slideUp = Tween(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _primaryController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
      ),
    );

    _logoScale = Tween(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _primaryController,
        curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
      ),
    );

    _buttonScale = Tween(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.easeOut),
    );

    _pulseAnimation = Tween(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _primaryController.forward();
    _pulseController.repeat(reverse: true);
  }

  Future<void> _checkInitialPermissionStatus() async {
    final permission = await Geolocator.checkPermission();
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    
    if (mounted) {
      setState(() {
        _currentPermission = permission;
        if (!serviceEnabled) {
          _statusText = 'Location services are disabled';
        } else if (permission == LocationPermission.denied) {
          _statusText = 'Location permission required';
        } else if (permission == LocationPermission.deniedForever) {
          _statusText = 'Location permission permanently denied';
        } else if (permission == LocationPermission.whileInUse || 
                   permission == LocationPermission.always) {
          _statusText = 'Location access granted';
        }
      });
    }
  }

  @override
  void dispose() {
    _primaryController.dispose();
    _buttonController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _requestPermissionAndNavigate(BuildContext context) async {
    setState(() {
      _isLoading = true;
      _statusText = 'Checking location services...';
    });

    _buttonController.forward();

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _statusText = 'Location services disabled';
          _isLoading = false;
        });
        
        if (!context.mounted) return;
        final result = await _showLocationServiceDialog(context);
        if (result == true) {
          // Try to open location settings
          await Geolocator.openLocationSettings();
          // Re-check after user potentially enabled services
          serviceEnabled = await Geolocator.isLocationServiceEnabled();
          if (!serviceEnabled) {
            setState(() {
              _statusText = 'Location services still disabled';
            });
            return;
          }
        } else {
          return;
        }
      }

      setState(() {
        _statusText = 'Checking permissions...';
      });

      // Check current permission status
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        setState(() {
          _statusText = 'Requesting location permission...';
        });
        
        permission = await Geolocator.requestPermission();
      }

      setState(() {
        _currentPermission = permission;
      });

      if (permission == LocationPermission.denied) {
        setState(() {
          _statusText = 'Location permission denied';
          _isLoading = false;
        });
        
        if (!context.mounted) return;
        _showPermissionDialog(context, "Permission Denied",
            "Location access was denied. Please try again and grant permission to use GeoDetect.");
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _statusText = 'Permission permanently denied';
          _isLoading = false;
        });
        
        if (!context.mounted) return;
        await _showPermissionDialog(context, "Permission Permanently Denied",
            "Location access has been permanently denied. Please enable it manually in your device settings.");
        await Geolocator.openAppSettings();
        return;
      }

      // Permission granted, test location access
      setState(() {
        _statusText = 'Testing location access...';
      });

      try {
        await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            timeLimit: Duration(seconds: 10),
          ),
        );
        
        setState(() {
          _statusText = 'Location access confirmed!';
        });
        
        // Small delay to show success message
        await Future.delayed(const Duration(milliseconds: 800));
        
        if (!context.mounted) return;
        Navigator.of(context).pushReplacementNamed('/map');
        
      } catch (e) {
        setState(() {
          _statusText = 'Failed to get location';
          _isLoading = false;
        });
        
        if (!context.mounted) return;
        _showPermissionDialog(context, "Location Error",
            "Unable to get your current location. Please check your GPS and try again.");
      }

    } catch (e) {
      setState(() {
        _statusText = 'An error occurred';
        _isLoading = false;
      });
      
      if (!context.mounted) return;
      _showPermissionDialog(context, "Error",
          "An unexpected error occurred: ${e.toString()}");
    } finally {
      _buttonController.reverse();
    }
  }

  Future<bool?> _showLocationServiceDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.location_disabled, color: Colors.orange),
            SizedBox(width: 8),
            Text("Location Services Disabled"),
          ],
        ),
        content: const Text(
          "Location services are disabled on your device. Would you like to open settings to enable them?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Open Settings"),
          ),
        ],
      ),
    );
  }

  Future<void> _showPermissionDialog(BuildContext context, String title, String content) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              title.contains("Error") ? Icons.error : Icons.location_off,
              color: title.contains("Error") ? Colors.red : Colors.orange,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionStatusCard() {
    if (_statusText.isEmpty && _currentPermission == null) return const SizedBox.shrink();
    
    Color statusColor = Colors.white70;
    IconData statusIcon = Icons.info_outline;
    
    if (_currentPermission != null) {
      switch (_currentPermission!) {
        case LocationPermission.always:
        case LocationPermission.whileInUse:
          statusColor = Colors.greenAccent;
          statusIcon = Icons.check_circle;
          break;
        case LocationPermission.denied:
          statusColor = Colors.orangeAccent;
          statusIcon = Icons.warning;
          break;
        case LocationPermission.deniedForever:
          statusColor = Colors.redAccent;
          statusIcon = Icons.error;
          break;
        case LocationPermission.unableToDetermine:
          statusColor = Colors.grey;
          statusIcon = Icons.help_outline;
          break;
      }
    }
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, color: statusColor, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _statusText,
              style: TextStyle(
                color: statusColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary,
              theme.colorScheme.primary.withBlue(180),
              theme.colorScheme.secondary,
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
              child: FadeTransition(
                opacity: _fadeIn,
                child: SlideTransition(
                  position: _slideUp,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated Logo
                      ScaleTransition(
                        scale: _logoScale,
                        child: AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _pulseAnimation.value,
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      blurRadius: 20,
                                      spreadRadius: _pulseAnimation.value * 2,
                                    ),
                                  ],
                                ),
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  width: size.width * 0.7,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 50),

                      // Main Title with animation
                      const Text(
                        "Smart Location. Real Insights.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 1.2,
                          height: 1.2,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Subtitle
                      const Text(
                        "Analyze the world around you effortlessly with GeoDetect — powered by precision geolocation technology.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                          height: 1.6,
                          fontWeight: FontWeight.w400,
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Permission Status Card
                      _buildPermissionStatusCard(),
                      
                      const SizedBox(height: 30),

                      // Animated Button
                      ScaleTransition(
                        scale: _buttonScale,
                        child: SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              shadowColor: Colors.black45,
                              elevation: _isLoading ? 2 : 8,
                              backgroundColor: _isLoading 
                                  ? Colors.grey.shade300 
                                  : null,
                            ),
                            onPressed: _isLoading 
                                ? null 
                                : () => _requestPermissionAndNavigate(context),
                            child: _isLoading
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation(
                                            theme.colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        "Processing...",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  )
                                : const Text(
                                    "Get Started",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Features list
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          children: [
                            _buildFeatureItem(
                              Icons.my_location,
                              "Precise GPS Location",
                              "High-accuracy positioning technology",
                            ),
                            const SizedBox(height: 12),
                            _buildFeatureItem(
                              Icons.analytics,
                              "Real-time Analysis",
                              "Instant insights about your surroundings",
                            ),
                            const SizedBox(height: 12),
                            _buildFeatureItem(
                              Icons.security,
                              "Privacy Protected",
                              "Your location data stays secure",
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      const Text(
                        "We require precise GPS access to determine your location and perform real-time analysis.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white54,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}