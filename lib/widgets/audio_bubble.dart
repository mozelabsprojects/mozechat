import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'dart:math';
import '../services/audio_cache_service.dart';

class AudioBubble extends StatefulWidget {
  final String audioUrl;
  final Color bubbleColor;
  final Color textColor;
  final bool isMe;

  const AudioBubble({
    super.key,
    required this.audioUrl,
    required this.bubbleColor,
    required this.textColor,
    required this.isMe,
  });

  @override
  State<AudioBubble> createState() => _AudioBubbleState();
}

class _AudioBubbleState extends State<AudioBubble> with AutomaticKeepAliveClientMixin {
  static AudioPlayer? _activePlayer;
  static double _globalPlaybackSpeed = 1.0;

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isLoading = true;
  bool _isDragging = false;

  late final List<double> _waveformBars;

  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerCompleteSubscription;
  StreamSubscription? _playerStateChangeSubscription;

  @override
  bool get wantKeepAlive => false;

  @override
  void initState() {
    super.initState();
    _waveformBars = _generateWaveformBars(widget.audioUrl, 28);
    _audioPlayer.setReleaseMode(ReleaseMode.stop);
    _initAudio();
  }

  static List<double> _generateWaveformBars(String seed, int count) {
    // Deterministic pseudo-random bars for each unique audioUrl
    int hash = seed.hashCode;
    if (hash == 0) hash = 1337;
    final rand = Random(hash.abs());
    return List.generate(count, (index) {
      // Natural voice speech waveform distribution: center slightly higher, varied peaks
      final base = 0.25 + (rand.nextDouble() * 0.70);
      final centerFactor = 1.0 - (pow((index - (count / 2)) / (count / 2), 2) * 0.35);
      return (base * centerFactor).clamp(0.2, 1.0);
    });
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

  Future<Source?> _getAudioSource() async {
    if (widget.audioUrl.isEmpty) return null;
    if (widget.audioUrl.startsWith('/') || widget.audioUrl.startsWith('file://')) {
      final path = widget.audioUrl.replaceFirst('file://', '');
      return DeviceFileSource(path);
    }
    final cached = await AudioCacheService.getCachedAudio(widget.audioUrl);
    if (cached != null) {
      return DeviceFileSource(cached.path);
    }
    final downloaded = await AudioCacheService.downloadAndCacheAudio(widget.audioUrl);
    if (downloaded != null) {
      return DeviceFileSource(downloaded.path);
    }
    return UrlSource(widget.audioUrl);
  }

  Future<void> _initAudio() async {
    try {
      if (widget.audioUrl.isNotEmpty) {
        final src = await _getAudioSource();
        if (src != null) {
          await _audioPlayer.setSource(src);
        }

        await Future.delayed(const Duration(milliseconds: 200));
        final d = await _audioPlayer.getDuration();
        if (d != null && mounted) {
          setState(() => _duration = d);
        }

        await _audioPlayer.setPlaybackRate(_globalPlaybackSpeed);
      }
    } catch (e) {
      // Ignore errors silently
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
      if (mounted && !_isDragging) {
        setState(() => _position = p);
      }
    });

    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((event) async {
      try {
        await _audioPlayer.seek(Duration.zero);
      } catch (_) {}
      if (_activePlayer == _audioPlayer) _activePlayer = null;
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

  Future<void> _togglePlay() async {
    if (_isLoading) return;

    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
        if (_activePlayer == _audioPlayer) _activePlayer = null;
        if (mounted) setState(() => _isPlaying = false);
      } else {
        if (_activePlayer != null && _activePlayer != _audioPlayer) {
          try {
            await _activePlayer!.pause();
          } catch (_) {}
        }
        _activePlayer = _audioPlayer;

        final isAtEnd = _position >= _duration && _duration > Duration.zero;
        final isCompleted = _audioPlayer.state == PlayerState.completed ||
            _audioPlayer.state == PlayerState.stopped;

        if (isAtEnd || isCompleted || _position == Duration.zero) {
          final src = await _getAudioSource();
          if (src != null) {
            try {
              await _audioPlayer.stop();
            } catch (_) {}
            await _audioPlayer.play(src);
          } else {
            await _audioPlayer.seek(Duration.zero);
            await _audioPlayer.resume();
          }
        } else {
          await _audioPlayer.resume();
        }

        await _audioPlayer.setPlaybackRate(_globalPlaybackSpeed);

        if (mounted) setState(() => _isPlaying = true);
      }
    } catch (e) {
      debugPrint("Audio play error: $e");
    }
  }

  Future<void> _cyclePlaybackSpeed() async {
    if (_globalPlaybackSpeed == 1.0) {
      _globalPlaybackSpeed = 1.5;
    } else if (_globalPlaybackSpeed == 1.5) {
      _globalPlaybackSpeed = 2.0;
    } else {
      _globalPlaybackSpeed = 1.0;
    }

    try {
      await _audioPlayer.setPlaybackRate(_globalPlaybackSpeed);
    } catch (_) {}

    if (mounted) {
      setState(() {});
    }
  }

  void _handleSeek(double localX, double totalWidth) {
    if (totalWidth <= 0 || _duration.inMilliseconds <= 0) return;
    final progress = (localX / totalWidth).clamp(0.0, 1.0);
    final targetMs = (progress * _duration.inMilliseconds).round();
    final newPos = Duration(milliseconds: targetMs);
    setState(() => _position = newPos);
    _audioPlayer.seek(newPos);
  }

  @override
  void dispose() {
    if (_activePlayer == _audioPlayer) {
      _activePlayer = null;
    }
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

  Widget _buildSpeedButton() {
    final speedText = _globalPlaybackSpeed == 1.0
        ? '1x'
        : (_globalPlaybackSpeed == 1.5 ? '1.5x' : '2x');

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _cyclePlaybackSpeed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: _globalPlaybackSpeed > 1.0
              ? widget.textColor.withValues(alpha: 0.22)
              : widget.textColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _globalPlaybackSpeed > 1.0
                ? widget.textColor.withValues(alpha: 0.55)
                : widget.textColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Text(
          speedText,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
            color: widget.textColor,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final double progress = (_duration.inMilliseconds > 0)
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      width: 250,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _isLoading
              ? SizedBox(
                  width: 38,
                  height: 38,
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: CircularProgressIndicator(
                      color: widget.textColor,
                      strokeWidth: 2,
                    ),
                  ),
                )
              : IconButton(
                  icon: Icon(
                    _isPlaying
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_fill_rounded,
                    color: widget.textColor,
                    size: 38,
                  ),
                  onPressed: _togglePlay,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Waveform bar visualizer with scrubbing
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) =>
                          _handleSeek(details.localPosition.dx, width),
                      onHorizontalDragStart: (details) {
                        _isDragging = true;
                        _handleSeek(details.localPosition.dx, width);
                      },
                      onHorizontalDragUpdate: (details) =>
                          _handleSeek(details.localPosition.dx, width),
                      onHorizontalDragEnd: (_) => _isDragging = false,
                      onHorizontalDragCancel: () => _isDragging = false,
                      child: Container(
                        height: 26,
                        color: Colors.transparent, // expand hit area
                        child: CustomPaint(
                          size: Size(width, 26),
                          painter: _WaveformPainter(
                            bars: _waveformBars,
                            progress: progress,
                            activeColor: widget.textColor,
                            inactiveColor: widget.textColor.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 6),
                // Time & Speed Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(_position),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: widget.textColor.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatDuration(_duration),
                          style: TextStyle(
                            fontSize: 10,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: widget.textColor.withValues(alpha: 0.55),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildSpeedButton(),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> bars;
  final double progress;
  final Color activeColor;
  final Color inactiveColor;

  _WaveformPainter({
    required this.bars,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty || size.width <= 0 || size.height <= 0) return;

    final int count = bars.length;
    // Calculate bar width and spacing to fill width evenly
    final double spacing = 2.0;
    final double totalSpacing = spacing * (count - 1);
    final double barWidth = ((size.width - totalSpacing) / count).clamp(1.5, 6.0);
    final double effectiveStep = barWidth + spacing;

    final activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.fill;

    final inactivePaint = Paint()
      ..color = inactiveColor
      ..style = PaintingStyle.fill;

    final centerY = size.height / 2;

    for (int i = 0; i < count; i++) {
      final double x = i * effectiveStep;
      final double barFraction = (i / (count - 1)).clamp(0.0, 1.0);
      final bool isPlayed = barFraction <= progress;

      final double barHeight = (bars[i] * size.height).clamp(4.0, size.height);
      final double top = centerY - (barHeight / 2);

      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, top, barWidth, barHeight),
        Radius.circular(barWidth / 2),
      );

      canvas.drawRRect(rrect, isPlayed ? activePaint : inactivePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor;
  }
}
