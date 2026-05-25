import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

/// Voice input service for speech recognition
class VoiceInputService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  String _lastRecognizedWords = '';
  String _selectedLocaleId = 'zh_CN';
  
  // Available locales
  List<stt.LocaleName> _availableLocales = [];
  
  // Stream controllers for state updates
  final _statusController = StreamController<VoiceInputStatus>.broadcast();
  final _resultController = StreamController<VoiceInputResult>.broadcast();
  final _errorController = StreamController<VoiceInputError>.broadcast();
  
  // Streams
  Stream<VoiceInputStatus> get statusStream => _statusController.stream;
  Stream<VoiceInputResult> get resultStream => _resultController.stream;
  Stream<VoiceInputError> get errorStream => _errorController.stream;
  
  // Current state
  bool get isListening => _isListening;
  bool get isInitialized => _isInitialized;
  String get lastRecognizedWords => _lastRecognizedWords;
  String get currentLocale => _selectedLocaleId;
  List<stt.LocaleName> get availableLocales => _availableLocales;
  
  /// Initialize speech recognition
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      _isInitialized = await _speech.initialize(
        onError: _handleError,
        onStatus: _handleStatus,
        debugLogging: kDebugMode,
      );
      
      if (_isInitialized) {
        _availableLocales = await _speech.locales();
        
        // Try to find Chinese locale, fallback to first available
        final chineseLocale = _availableLocales.firstWhere(
          (locale) => locale.localeId.startsWith('zh'),
          orElse: () => _availableLocales.isNotEmpty 
              ? _availableLocales.first 
              : const stt.LocaleName('zh_CN', '中文'),
        );
        _selectedLocaleId = chineseLocale.localeId;
      }
      
      return _isInitialized;
    } catch (e) {
      _errorController.add(VoiceInputError(
        type: VoiceInputErrorType.initializationFailed,
        message: 'Failed to initialize speech recognition: $e',
      ));
      return false;
    }
  }
  
  /// Start listening for speech
  Future<void> startListening({
    String? localeId,
    Duration listenFor = const Duration(seconds: 30),
    Duration pauseFor = const Duration(seconds: 3),
    bool partialResults = true,
    bool onDevice = true,
  }) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return;
    }
    
    if (_isListening) return;
    
    _lastRecognizedWords = '';
    _selectedLocaleId = localeId ?? _selectedLocaleId;
    
    try {
      await _speech.listen(
        onResult: _handleResult,
        listenFor: listenFor,
        pauseFor: pauseFor,
        partialResults: partialResults,
        onDevice: onDevice,
        localeId: _selectedLocaleId,
      );
      
      _isListening = true;
      _statusController.add(VoiceInputStatus.listening);
    } catch (e) {
      _errorController.add(VoiceInputError(
        type: VoiceInputErrorType.startFailed,
        message: 'Failed to start listening: $e',
      ));
    }
  }
  
  /// Stop listening
  Future<void> stopListening() async {
    if (!_isListening) return;
    
    try {
      await _speech.stop();
      _isListening = false;
      _statusController.add(VoiceInputStatus.stopped);
    } catch (e) {
      _errorController.add(VoiceInputError(
        type: VoiceInputErrorType.stopFailed,
        message: 'Failed to stop listening: $e',
      ));
    }
  }
  
  /// Cancel current recognition
  Future<void> cancel() async {
    try {
      await _speech.cancel();
      _isListening = false;
      _statusController.add(VoiceInputStatus.cancelled);
    } catch (e) {
      // Ignore cancel errors
    }
  }
  
  /// Change locale
  void setLocale(String localeId) {
    if (_availableLocales.any((l) => l.localeId == localeId)) {
      _selectedLocaleId = localeId;
    }
  }
  
  /// Get locale display name
  String getLocaleDisplayName(String localeId) {
    final locale = _availableLocales.firstWhere(
      (l) => l.localeId == localeId,
      orElse: () => stt.LocaleName(localeId, localeId),
    );
    return locale.name;
  }
  
  void _handleResult(SpeechRecognitionResult result) {
    _lastRecognizedWords = result.recognizedWords;
    
    _resultController.add(VoiceInputResult(
      recognizedWords: result.recognizedWords,
      isFinal: result.finalResult,
      confidence: result.recognizedWords.isNotEmpty ? 1.0 : 0.0,
    ));
    
    if (result.finalResult) {
      _isListening = false;
      _statusController.add(VoiceInputStatus.completed);
    }
  }
  
  void _handleStatus(String status) {
    switch (status) {
      case 'listening':
        _isListening = true;
        _statusController.add(VoiceInputStatus.listening);
        break;
      case 'notListening':
        _isListening = false;
        _statusController.add(VoiceInputStatus.stopped);
        break;
      case 'done':
        _isListening = false;
        _statusController.add(VoiceInputStatus.completed);
        break;
      default:
        break;
    }
  }
  
  void _handleError(SpeechRecognitionError error) {
    _isListening = false;
    
    VoiceInputErrorType errorType;
    switch (error.errorMsg) {
      case 'error_no_match':
        errorType = VoiceInputErrorType.noMatch;
        break;
      case 'error_speech_timeout':
        errorType = VoiceInputErrorType.timeout;
        break;
      case 'error_audio':
        errorType = VoiceInputErrorType.audioError;
        break;
      case 'error_network':
        errorType = VoiceInputErrorType.networkError;
        break;
      default:
        errorType = VoiceInputErrorType.unknown;
    }
    
    _errorController.add(VoiceInputError(
      type: errorType,
      message: error.errorMsg,
      permanent: error.permanent,
    ));
    
    _statusController.add(VoiceInputStatus.error);
  }
  
  void dispose() {
    _statusController.close();
    _resultController.close();
    _errorController.close();
  }
}

/// Voice input status
enum VoiceInputStatus {
  idle,
  listening,
  stopped,
  completed,
  cancelled,
  error,
}

/// Voice input result
class VoiceInputResult {
  final String recognizedWords;
  final bool isFinal;
  final double confidence;
  
  const VoiceInputResult({
    required this.recognizedWords,
    required this.isFinal,
    required this.confidence,
  });
}

/// Voice input error
class VoiceInputError {
  final VoiceInputErrorType type;
  final String message;
  final bool permanent;
  
  const VoiceInputError({
    required this.type,
    required this.message,
    this.permanent = false,
  });
}

/// Voice input error type
enum VoiceInputErrorType {
  initializationFailed,
  startFailed,
  stopFailed,
  noMatch,
  timeout,
  audioError,
  networkError,
  permissionDenied,
  unknown,
}

/// Provider for voice input service
final voiceInputServiceProvider = Provider<VoiceInputService>((ref) {
  final service = VoiceInputService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider for voice input status
final voiceInputStatusProvider = StreamProvider<VoiceInputStatus>((ref) {
  final service = ref.watch(voiceInputServiceProvider);
  return service.statusStream;
});

/// Provider for voice input results
final voiceInputResultProvider = StreamProvider<VoiceInputResult>((ref) {
  final service = ref.watch(voiceInputServiceProvider);
  return service.resultStream;
});

/// Provider for voice input errors
final voiceInputErrorProvider = StreamProvider<VoiceInputError>((ref) {
  final service = ref.watch(voiceInputServiceProvider);
  return service.errorStream;
});
