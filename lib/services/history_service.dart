// File: services/history_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/analysis_entry.dart';

class HistoryService extends ChangeNotifier {
  static const String _storageKey = 'saved_analyses';
  
  // Private list to hold the data
  final List<AnalysisEntry> _savedAnalyses = [];

  // Public getter to access the list
  List<AnalysisEntry> get savedAnalyses => _savedAnalyses;

  // Initialize and load saved data
  Future<void> initialize() async {
    await _loadSavedAnalyses();
  }

  // Load saved analyses from SharedPreferences
  Future<void> _loadSavedAnalyses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? savedData = prefs.getString(_storageKey);
      
      if (savedData != null) {
        final List<dynamic> jsonList = jsonDecode(savedData);
        _savedAnalyses.clear();
        _savedAnalyses.addAll(
          jsonList.map((json) => AnalysisEntry.fromJson(json)).toList(),
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading saved analyses: $e');
    }
  }

  // Save analyses to SharedPreferences
  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> jsonList = 
          _savedAnalyses.map((entry) => entry.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error saving analyses: $e');
    }
  }

  // Method to add an entry and notify all listeners
  Future<void> addAnalysis(AnalysisEntry entry) async {
    _savedAnalyses.insert(0, entry); // Add to the top of the list
    notifyListeners();
    await _saveToStorage();
  }

  // Method to remove an entry and notify all listeners
  Future<void> removeAnalysis(AnalysisEntry entry) async {
    _savedAnalyses.remove(entry);
    notifyListeners();
    await _saveToStorage();
  }

  // Method to clear all analyses
  Future<void> clearAllAnalyses() async {
    _savedAnalyses.clear();
    notifyListeners();
    await _saveToStorage();
  }

  // Method to get analysis count
  int get analysisCount => _savedAnalyses.length;
}