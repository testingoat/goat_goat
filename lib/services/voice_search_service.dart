import 'package:flutter/foundation.dart';
// import 'package:speech_to_text/speech_to_text.dart'; // Will be enabled after package update
import 'package:permission_handler/permission_handler.dart';

/// Service for handling voice search functionality with proper permissions
///
/// Features:
/// - Microphone permission handling
/// - Speech-to-text conversion (temporarily disabled during package upgrade)
/// - Voice search state management
/// - Error handling and user feedback
class VoiceSearchService {
  static final VoiceSearchService _instance = VoiceSearchService._internal();
  factory VoiceSearchService() => _instance;
  VoiceSearchService._internal();

  // final SpeechToText _speechToText = SpeechToText(); // Will be enabled after package update
  bool _isInitialized = false;
  bool _isListening = false;
  String _lastWords = '';

  // Callbacks for UI updates
  Function(String)? onResult;
  Function(String)? onError;
  Function(bool)? onListeningStateChanged;
  Function(double)? onSoundLevelChanged;

  /// Initialize the speech-to-text service (temporarily disabled during package upgrade)
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Temporarily disabled during speech_to_text package upgrade from 6.6.x to 7.2.0
      _isInitialized = false;

      if (kDebugMode) {
        print(
          '🎤 VoiceSearchService: Speech-to-text temporarily disabled during package upgrade',
        );
      }

      return _isInitialized;
    } catch (e) {
      if (kDebugMode) {
        print('🎤 VoiceSearchService: Initialization error: $e');
      }
      return false;
    }
  }

  /// Request microphone permission (stub implementation)
  Future<bool> requestMicrophonePermission({Function(String)? onError}) async {
    try {
      final status = await Permission.microphone.request();

      switch (status) {
        case PermissionStatus.granted:
          if (kDebugMode) {
            print('🎤 VoiceSearchService: Microphone permission granted');
          }
          return true;
        case PermissionStatus.denied:
          onError?.call('Microphone permission denied');
          return false;
        case PermissionStatus.permanentlyDenied:
          onError?.call('Please enable microphone permission in app settings');
          return false;
        default:
          if (kDebugMode) {
            print(
              '🎤 VoiceSearchService: Microphone permission status: $status',
            );
          }
          onError?.call('Unable to access microphone');
          return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('🎤 VoiceSearchService: Permission request error: $e');
      }
      onError?.call('Error requesting microphone permission: $e');
      return false;
    }
  }

  /// Start listening for speech (stub implementation)
  Future<bool> startListening({
    String? localeId,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (!_isInitialized) {
      onError?.call('Voice search not available');
      return false;
    }

    // Stub implementation - always fails since speech_to_text is disabled
    onError?.call('Voice search temporarily unavailable');
    return false;
  }

  /// Stop listening for speech (stub implementation)
  Future<void> stopListening() async {
    if (!_isListening) return;

    try {
      if (kDebugMode) {
        print('🎤 VoiceSearchService: Stopping listening (stub)');
      }
      _isListening = false;
      onListeningStateChanged?.call(false);
    } catch (e) {
      if (kDebugMode) {
        print('🎤 VoiceSearchService: Stop listening error: $e');
      }
      onError?.call('Error stopping voice search: $e');
    }
  }

  /// Cancel listening for speech (stub implementation)
  Future<void> cancelListening() async {
    if (!_isListening) return;

    try {
      if (kDebugMode) {
        print('🎤 VoiceSearchService: Cancelling listening (stub)');
      }
      _isListening = false;
      onListeningStateChanged?.call(false);
    } catch (e) {
      if (kDebugMode) {
        print('🎤 VoiceSearchService: Cancel listening error: $e');
      }
      onError?.call('Error cancelling voice search: $e');
    }
  }

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  String get lastWords => _lastWords;

  /// Get available locales (stub implementation)
  Future<List<String>> getAvailableLocales() async {
    return []; // Empty list since speech_to_text is disabled
  }

  /// Check if speech recognition is available (stub implementation)
  Future<bool> isAvailable() async {
    return false; // Always false since speech_to_text is disabled
  }

  /// Dispose of resources
  void dispose() {
    _isInitialized = false;
    _isListening = false;
    _lastWords = '';
    onResult = null;
    onError = null;
    onListeningStateChanged = null;
    onSoundLevelChanged = null;
  }
}
