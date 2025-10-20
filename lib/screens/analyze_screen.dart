import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../services/history_service.dart';
import '../services/gemini_service.dart';
import '../models/analysis_entry.dart';

class AnalyzeScreen extends StatefulWidget {
  const AnalyzeScreen({super.key});

  @override
  State<AnalyzeScreen> createState() => _AnalyzeScreenState();
}

class _AnalyzeScreenState extends State<AnalyzeScreen> {
  bool _isLoading = false;
  bool _hasAnalyzed = false;
  String _address = "";
  String _aiResponse = "";
  String? _errorMessage;
  AnalysisEntry? _preloadedAnalysis;
  DateTime? _lastRequestTime;
  static const Duration _requestCooldown = Duration(seconds: 2);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is String) {
      _address = args;
      _isLoading = false;
      _hasAnalyzed = false;
    } else if (args is AnalysisEntry) {
      _preloadedAnalysis = args;
      _address = _preloadedAnalysis!.address;
      _aiResponse = _preloadedAnalysis!.analysisData;
      _isLoading = false;
      _hasAnalyzed = true;
    }
  }

  @override
  void dispose() {
    // Cancel any active requests when the screen is disposed
    GeminiService.cancelActiveRequests();
    super.dispose();
  }

  Future<void> _fetchAiAnalysis() async {
    // Prevent multiple simultaneous requests
    if (_isLoading) return;
    
    // Implement request cooldown to prevent rapid button presses
    final now = DateTime.now();
    if (_lastRequestTime != null && 
        now.difference(_lastRequestTime!) < _requestCooldown) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Please wait before making another request."),
          backgroundColor: Theme.of(context).colorScheme.tertiary,
          duration: const Duration(seconds: 1),
        ),
      );
      return;
    }
    
    // Check if we already have analysis for this exact address
    if (_hasAnalyzed && _aiResponse.isNotEmpty && _errorMessage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Analysis already available for this location."),
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    
    _lastRequestTime = now;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await GeminiService.analyzeLocation(_address);
      if (!mounted) return;

      setState(() {
        _aiResponse = response;
        _isLoading = false;
        _hasAnalyzed = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
        _hasAnalyzed = false;
      });
    }
  }

  void _saveAnalysis() async {
    final theme = Theme.of(context);

    if (_aiResponse.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "No analysis to save. Please analyze the location first.",
            style: TextStyle(color: theme.colorScheme.onTertiaryContainer),
          ),
          backgroundColor: theme.colorScheme.tertiaryContainer,
        ),
      );
      return;
    }

    if (_isAlreadySaved()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "This analysis is already saved in your history.",
            style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
          ),
          backgroundColor: theme.colorScheme.primaryContainer,
        ),
      );
      return;
    }

    final entry = AnalysisEntry(
      address: _address,
      analysisData: _aiResponse,
      dateSaved: DateTime.now(),
    );

    try {
      await Provider.of<HistoryService>(context, listen: false).addAnalysis(entry);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text("Analysis saved! View in History tab."),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: "VIEW",
            textColor: Colors.white,
            onPressed: () {
              Navigator.of(context).pushNamed('/history');
            },
          ),
        ),
      );

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/map');
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to save analysis: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }

  bool _isAlreadySaved() {
    final historyService = Provider.of<HistoryService>(context, listen: false);
    return historyService.savedAnalyses.any(
      (entry) => entry.address == _address && entry.analysisData == _aiResponse,
    );
  }

  bool _canMakeRequest() {
    // Don't allow requests if already loading
    if (_isLoading) return false;
    
    // Don't allow requests if we're in cooldown period
    if (_lastRequestTime != null) {
      final timeSinceLastRequest = DateTime.now().difference(_lastRequestTime!);
      if (timeSinceLastRequest < _requestCooldown) return false;
    }
    
    // Don't allow requests if we already have a successful analysis
    if (_hasAnalyzed && _aiResponse.isNotEmpty && _errorMessage == null) {
      return false;
    }
    
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Location Analysis"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_preloadedAnalysis != null) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacementNamed('/map');
            }
          },
        ),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Analyzing location with AI..."),
                ],
              ),
            )
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _address,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (!_hasAnalyzed && _errorMessage == null)
            _buildAnalyzeButton()
          else if (_errorMessage != null)
            _buildErrorCard()
          else
            _buildAnalysisResults(),

          const SizedBox(height: 24),

          if (_hasAnalyzed && _preloadedAnalysis == null)
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _saveAnalysis,
                    icon: const Icon(Icons.bookmark_add),
                    label: const Text(
                      "Save Analysis",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      foregroundColor: Theme.of(context).colorScheme.onSecondary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Save this analysis to view it later in your history",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          
          if (_preloadedAnalysis != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.history,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "This is a saved analysis from ${_formatDate(_preloadedAnalysis!.dateSaved)}",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAnalyzeButton() {
    return Column(
      children: [
        const SizedBox(height: 32),
        Icon(
          Icons.analytics_outlined,
          size: 64,
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
        ),
        const SizedBox(height: 16),
        Text(
          "Ready to analyze this location?",
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          "Get AI-powered insights about the area including safety, amenities, demographics, and more.",
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _canMakeRequest() ? _fetchAiAnalysis : null,
            icon: _isLoading 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.psychology),
            label: Text(
              _isLoading ? "Analyzing..." : "Analyze with AI",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _canMakeRequest() 
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).disabledColor,
              foregroundColor: _canMakeRequest()
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorCard() {
    return Card(
      elevation: 2,
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              "Analysis Failed",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _fetchAiAnalysis,
              icon: _isLoading 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.refresh),
              label: Text(_isLoading ? "Retrying..." : "Try Again"),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isLoading 
                    ? Theme.of(context).disabledColor
                    : Theme.of(context).colorScheme.error,
                foregroundColor: _isLoading
                    ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)
                    : Theme.of(context).colorScheme.onError,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisResults() {
    return Card(
      elevation: 2, 
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.psychology,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  "AI Analysis Results",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            MarkdownBody(
              data: _aiResponse,
              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                p: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
                strong: const TextStyle(fontWeight: FontWeight.bold),
                listBullet: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}