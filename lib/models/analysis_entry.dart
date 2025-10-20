// File: models/analysis_entry.dart

import 'dart:convert';

class AnalysisEntry {
  final String address;
  final String analysisData;
  final DateTime dateSaved;

  AnalysisEntry({
    required this.address,
    required this.analysisData,
    required this.dateSaved,
  });

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'address': address,
      'analysisData': analysisData,
      'dateSaved': dateSaved.toIso8601String(),
    };
  }

  // Create from JSON
  factory AnalysisEntry.fromJson(Map<String, dynamic> json) {
    return AnalysisEntry(
      address: json['address'] as String,
      analysisData: json['analysisData'] as String,
      dateSaved: DateTime.parse(json['dateSaved'] as String),
    );
  }

  // Convert to JSON string
  String toJsonString() {
    return jsonEncode(toJson());
  }

  // Create from JSON string
  factory AnalysisEntry.fromJsonString(String jsonString) {
    return AnalysisEntry.fromJson(jsonDecode(jsonString));
  }
}