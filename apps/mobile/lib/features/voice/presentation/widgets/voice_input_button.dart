import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/voice_input_service.dart';

/// Voice input button widget
class VoiceInputButton extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final String? localeId;
  final String? hint;
  final ValueChanged<String>? onResult;
  final VoidCallback? onStart;
  final VoidCallback? onStop;
  final bool showLocaleSelector;
  final VoiceInputMode mode;
  
  const VoiceInputButton({
    super.key,
    required this.controller,
    this.localeId,
    this.hint,
    this.onResult,
    this.onStart,
    this.onStop,
    this.showLocaleSelector = false,
    this.mode = VoiceInputMode.text,
  });
  
  @override
  ConsumerState<VoiceInputButton> createState() => _VoiceInputButtonState();
}

class _VoiceInputButtonState extends ConsumerState<VoiceInputButton> {
  final VoiceInputService _voiceService = VoiceInputService();
  bool _isInitialized = false;
  String _selectedLocale = 'zh_CN';
  bool _showLocaleMenu = false;
  
  @override
  void initState() {
    super.initState();
    _initVoice();
    _selectedLocale = widget.localeId ?? 'zh_CN';
  }
  
  Future<void> _initVoice() async {
    _isInitialized = await _voiceService.initialize();
    if (mounted && _isInitialized) {
      setState(() {
        if (_voiceService.availableLocales.isNotEmpty) {
          _selectedLocale = _voiceService.availableLocales.first.localeId;
        }
      });
    }
  }
  
  void _toggleListening() async {
    if (!_isInitialized) {
      _showInitializationError();
      return;
    }
    
    if (_voiceService.isListening) {
      await _voiceService.stopListening();
      widget.onStop?.call();
    } else {
      // Clear previous text for new input
      if (widget.mode == VoiceInputMode.amount) {
        widget.controller.clear();
      }
      
      widget.onStart?.call();
      await _voiceService.startListening(
        localeId: _selectedLocale,
        onDevice: true,
        partialResults: true,
      );
    }
  }
  
  void _showInitializationError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('语音识别初始化失败，请检查权限设置'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<VoiceInputStatus>(
      stream: _voiceService.statusStream,
      initialData: VoiceInputStatus.idle,
      builder: (context, statusSnapshot) {
        final status = statusSnapshot.data ?? VoiceInputStatus.idle;
        final isListening = status == VoiceInputStatus.listening;
        
        return StreamBuilder<VoiceInputResult>(
          stream: _voiceService.resultStream,
          builder: (context, resultSnapshot) {
            final result = resultSnapshot.data;
            
            // Update controller with recognized words
            if (result != null && result.recognizedWords.isNotEmpty) {
              final processedText = _processResult(result.recognizedWords);
              
              if (widget.mode == VoiceInputMode.amount) {
                // For amount mode, only update if it's a valid number
                if (processedText.isNotEmpty) {
                  widget.controller.text = processedText;
                }
              } else {
                // For text mode, append or replace
                if (result.isFinal) {
                  widget.controller.text = processedText;
                  widget.onResult?.call(processedText);
                }
              }
            }
            
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.showLocaleSelector) _buildLocaleSelector(),
                _buildMicButton(isListening, status),
              ],
            );
          },
        );
      },
    );
  }
  
  Widget _buildMicButton(bool isListening, VoiceInputStatus status) {
    return GestureDetector(
      onLongPress: widget.showLocaleSelector ? () {
        setState(() => _showLocaleMenu = true);
      } : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: IconButton(
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: isListening
                ? const _PulsingMicIcon()
                : Icon(
                    Icons.mic,
                    color: _getIconColor(status),
                  ),
          ),
          onPressed: _toggleListening,
          tooltip: isListening ? '停止录音' : '开始语音输入',
        ),
      ),
    );
  }
  
  Widget _buildLocaleSelector() {
    if (!_isInitialized || _voiceService.availableLocales.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return PopupMenuButton<String>(
      icon: const Icon(Icons.language, size: 18),
      tooltip: '选择语言',
      initialValue: _selectedLocale,
      itemBuilder: (context) {
        return _voiceService.availableLocales.map((locale) {
          return PopupMenuItem(
            value: locale.localeId,
            child: Text(locale.name),
          );
        }).toList();
      },
      onSelected: (localeId) {
        setState(() => _selectedLocale = localeId);
        _voiceService.setLocale(localeId);
      },
    );
  }
  
  Color? _getIconColor(VoiceInputStatus status) {
    switch (status) {
      case VoiceInputStatus.listening:
        return Colors.red;
      case VoiceInputStatus.error:
        return Colors.orange;
      case VoiceInputStatus.completed:
        return Colors.green;
      default:
        return null;
    }
  }
  
  String _processResult(String recognizedWords) {
    if (widget.mode == VoiceInputMode.amount) {
      return _extractAmount(recognizedWords);
    }
    return recognizedWords;
  }
  
  String _extractAmount(String text) {
    // Chinese number words to digits
    final chineseNumbers = {
      '零': '0', '一': '1', '二': '2', '三': '3', '四': '4',
      '五': '5', '六': '6', '七': '7', '八': '8', '九': '9',
      '十': '10', '百': '00', '千': '000', '万': '0000',
      '点': '.', '块': '.', '元': '', '角': '', '分': '',
    };
    
    String processed = text;
    
    // Replace Chinese numbers with digits
    chineseNumbers.forEach((chinese, digit) {
      processed = processed.replaceAll(chinese, digit);
    });
    
    // Extract numbers
    final numberPattern = RegExp(r'[\d.]+');
    final match = numberPattern.firstMatch(processed);
    
    if (match != null) {
      String amount = match.group(0) ?? '';
      // Validate it's a proper number
      final parsed = double.tryParse(amount);
      if (parsed != null && parsed > 0) {
        return amount;
      }
    }
    
    return '';
  }
}

/// Pulsing microphone icon animation
class _PulsingMicIcon extends StatefulWidget {
  const _PulsingMicIcon();
  
  @override
  State<_PulsingMicIcon> createState() => _PulsingMicIconState();
}

class _PulsingMicIconState extends State<_PulsingMicIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    
    _animation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: const Icon(Icons.mic, color: Colors.red),
        );
      },
    );
  }
}

/// Voice input mode
enum VoiceInputMode {
  text,    // General text input
  amount,  // Amount/number input
  search,  // Search query
}
