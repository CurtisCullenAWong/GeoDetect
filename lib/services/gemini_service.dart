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

      final response = await model.generateContent([Content.text(prompt)]);
      final result = response.text ?? 'No analysis could be generated for this location.';
      
      // Cache the result
      _cachedResponses[normalizedAddress] = result;
      _cacheTimestamps[normalizedAddress] = DateTime.now();
      
      // Complete the request
      completer.complete(result);
      return result;
      
    } catch (e) {
      final error = e.toString();
      Exception exception;

      if (error.contains('Quota exceeded')) {
        exception = Exception('AI usage limit reached. Please wait a minute and try again.');
      } else if (error.contains('not found') || error.contains('not supported')) {
        exception = Exception('Invalid or unsupported Gemini model or API key.');
      } else {
        exception = Exception('Failed to analyze location: $error');
      }
      
      // Complete the request with error
      completer.completeError(exception);
      throw exception;
      
    } finally {
      // Clean up the active request
      _activeRequests.remove(normalizedAddress);
    }
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
