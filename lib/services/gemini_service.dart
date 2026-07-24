import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  static GenerativeModel? _model;
  static final Map<String, Completer<String>> _activeRequests = {};
  static final Map<String, String> _cachedResponses = {};
  static const int _cacheExpirationMinutes = 30;
  static final Map<String, DateTime> _cacheTimestamps = {};

  static GenerativeModel get model {
    if (_model == null) {
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('GEMINI_API_KEY not found or not loaded from .env file');
      }

      _model = GenerativeModel(
        model: 'gemini-2.0-flash-lite',
        apiKey: apiKey,
      );
    }
    return _model!;
  }

  static Future<String> analyzeLocation(String address) async {
    // Normalize address for consistent caching
    final normalizedAddress = address.trim().toLowerCase();
    
    // Check if there's already an active request for this address
    if (_activeRequests.containsKey(normalizedAddress)) {
      // Return the existing request to prevent duplicate API calls
      return await _activeRequests[normalizedAddress]!.future;
    }
    
    // Check cache first (with expiration)
    if (_cachedResponses.containsKey(normalizedAddress)) {
      final cacheTime = _cacheTimestamps[normalizedAddress];
      if (cacheTime != null && 
          DateTime.now().difference(cacheTime).inMinutes < _cacheExpirationMinutes) {
        return _cachedResponses[normalizedAddress]!;
      } else {
        // Remove expired cache
        _cachedResponses.remove(normalizedAddress);
        _cacheTimestamps.remove(normalizedAddress);
      }
    }
    
    // Create a completer for this request
    final completer = Completer<String>();
    _activeRequests[normalizedAddress] = completer;
    
    try {
      String? apiKey;
      try {
        if (dotenv.isInitialized) {
          apiKey = dotenv.env['GEMINI_API_KEY'];
        }
      } catch (_) {}

      String result;
      if (apiKey != null && apiKey.isNotEmpty) {
        try {
          final prompt = '''
Provide a detailed, factual, and organized analysis of the area around "$address".

Please include these sections:
1. Neighborhood Overview — describe the overall atmosphere, safety level (rate 1–5), and character of the community.
2. Local Amenities — mention nearby parks, schools, restaurants, transportation, and shopping options.
3. Historical Context — summarize the background or notable landmarks in the area.
4. Demographics — describe general population characteristics and lifestyle.
5. Real Estate Insights — note housing types, current market trends, and investment potential.
6. Key Takeaways — provide a concise summary of the area's main advantages and disadvantages, and who it may suit best.

Keep the tone informative and neutral. Avoid assumptions or opinions without context.
''';

          _model ??= GenerativeModel(
            model: 'gemini-2.0-flash-lite',
            apiKey: apiKey,
          );
          final response = await _model!.generateContent([Content.text(prompt)]);
          result = response.text ?? _generateDemoAnalysis(address);
        } catch (_) {
          result = _generateDemoAnalysis(address);
        }
      } else {
        await Future.delayed(const Duration(milliseconds: 600));
        result = _generateDemoAnalysis(address);
      }

      // Cache the result
      _cachedResponses[normalizedAddress] = result;
      _cacheTimestamps[normalizedAddress] = DateTime.now();
      
      completer.complete(result);
      return result;
    } catch (_) {
      final fallback = _generateDemoAnalysis(address);
      completer.complete(fallback);
      return fallback;
    } finally {
      // Clean up the active request
      _activeRequests.remove(normalizedAddress);
    }
  }

  static String _generateDemoAnalysis(String address) {
    final locationName = address.trim().isEmpty ? "Selected Location" : address.trim();
    return '''
# 📍 Location Analysis: $locationName

### 🏡 1. Neighborhood Overview
The neighborhood around **$locationName** is a well-balanced residential and commercial zone. It offers a safe (rated **4.5/5**), friendly community atmosphere with clean streets, accessible public spaces, and low crime rates.

### 🛍️ 2. Local Amenities
* **Parks & Recreation:** Beautiful public parks and sports facilities within walking distance.
* **Education:** Top-rated primary and secondary schools servicing the community.
* **Dining & Shopping:** Rich mix of local dining spots, cafes, supermarkets, and boutique shops.
* **Transit:** Excellent connection to public transit nodes and major highway connections.

### 🏛️ 3. Historical Context
Established as a pivotal community hub, this area seamlessly blends historic architecture with modern sustainable infrastructure.

### 👥 4. Demographics
A welcoming demographic profile consisting of young professionals, active families, and retirees, creating a strong sense of community engagement.

### 🏠 5. Real Estate Insights
* **Property Types:** Single-family homes, townhouses, and luxury apartments.
* **Market Trends:** Steady property value appreciation with high rental demand and long-term investment growth.

### ✨ 6. Key Takeaways
* **Pros:** Excellent walkability, strong safety record, high-quality amenities, and great transport links.
* **Cons:** High housing demand leading to competitive real estate pricing.
* **Best Suited For:** Families, young professionals, and property investors.

*(Operating in Offline Demo Mode)*
''';
  }

  /// Clear cached responses (useful for testing or memory management)
  static void clearCache() {
    _cachedResponses.clear();
    _cacheTimestamps.clear();
  }

  /// Cancel any active requests (useful when user navigates away)
  static void cancelActiveRequests() {
    for (final completer in _activeRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(Exception('Request cancelled'));
      }
    }
    _activeRequests.clear();
  }
}
