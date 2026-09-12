import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import '../services/audio_cache_service.dart';

class AudioBubble extends StatefulWidget {
  final String audioUrl;
  final Color bubbleColor;
  final Color textColor;
  final bool isMe;
  final bool isAnonymous;

  const AudioBubble({
    super.key,
    required this.audioUrl,
    required this.bubbleColor,
    required this.textColor,
    required this.isMe,
    this.isAnonymous = false,
  });

  @override
  State<AudioBubble> createState() => _AudioBubbleState();
}

class _AudioBubbleState extends State<AudioBubble> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isLoading = true;

  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerCompleteSubscription;
  StreamSubscription? _playerStateChangeSubscription;

  @override
  void initState() {
    super.initState();
    _initAudio();
  }

  @override
  void didUpdateWidget(AudioBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioUrl != widget.audioUrl) {
      _audioPlayer.stop();
      _isLoading = true;
      _initAudio();
    }
  }

  Future<void> _initAudio() async {
    try {
      if (widget.audioUrl.isNotEmpty) {
        final cachedFile = await AudioCacheService.getCachedAudio(widget.audioUrl);
        if (cachedFile != null) {
          await _audioPlayer.setSourceDeviceFile(cachedFile.path);
        } else {
          await _audioPlayer.setSourceUrl(widget.audioUrl);
          AudioCacheService.downloadAndCacheAudio(widget.audioUrl);
        }
        
        // Wait briefly for the player to initialize, then attempt to get duration directly
        await Future.delayed(const Duration(milliseconds: 200));
        final d = await _audioPlayer.getDuration();
        if (d != null && mounted) {
          setState(() => _duration = d);
        }
        
        if (widget.isAnonymous) {
          await _audioPlayer.setPlaybackRate(0.75);
        }
      }
    } catch (e) {
      // Ignore errors silently for now
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }

    _durationSubscription = _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) {
        setState(() {
          _duration = d;
          _isLoading = false;
        });
      }
    });

    _positionSubscription = _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) {
        setState(() => _position = p);
      }
    });

    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });

    _playerStateChangeSubscription = _audioPlayer.onPlayerStateChanged.listen(
      (state) {
        if (mounted) {
          setState(() {
            _isPlaying = state == PlayerState.playing;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _playerCompleteSubscription?.cancel();
    _playerStateChangeSubscription?.cancel();
    _audioPlayer.stop().then((_) {
      _audioPlayer.dispose();
    }).catchError((_) {
      _audioPlayer.dispose();
    });
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _isLoading
              ? SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    color: widget.textColor,
                    strokeWidth: 2,
                  ),
                )
              : IconButton(
                  icon: Icon(
                    _isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_fill,
                    color: widget.textColor,
                    size: 36,
                  ),
                  onPressed: () async {
                    if (_isPlaying) {
                      await _audioPlayer.pause();
                    } else {
                      if (_position == Duration.zero || _position >= _duration) {
                        await _audioPlayer.seek(Duration.zero);
                      }
                      await _audioPlayer.resume();
                    }
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderTheme(
                  data: SliderThemeData(
                    thumbColor: widget.textColor,
                    activeTrackColor: widget.textColor.withValues(alpha: 0.7),
                    inactiveTrackColor: widget.textColor.withValues(alpha: 0.3),
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14,
                    ),
                  ),
                  child: Slider(
                    min: 0,
                    max: _duration.inMilliseconds > 0
                        ? _duration.inMilliseconds.toDouble()
                        : 1.0,
                    value: _position.inMilliseconds.toDouble().clamp(
                      0.0,
                      _duration.inMilliseconds > 0
                          ? _duration.inMilliseconds.toDouble()
                          : 1.0,
                    ),
                    onChanged: (val) async {
                      final position = Duration(milliseconds: val.toInt());
                      await _audioPlayer.seek(position);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_position),
                        style: TextStyle(fontSize: 10, color: widget.textColor),
                      ),
                      Text(
                        _formatDuration(_duration),
                        style: TextStyle(fontSize: 10, color: widget.textColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
