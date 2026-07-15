import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

/// Tapping an animal flies in a cartoon parrot that says the word, then the
/// child holds the mic to copy it. Instead of trying to grade the child's
/// pronunciation (fragile for young kids), we just detect that *something*
/// was said (duration/volume) and play it straight back pitch-shifted up —
/// the "squirrel voice" reward that makes kids want to talk into the mic.
///
/// Uses `flutter_sound` for recording (already a project dependency) and
/// `just_audio` for pitch-shifted playback via setPitch().
///
/// PLATFORM NOTE: just_audio's setPitch() is well-supported on Android
/// (ExoPlayer). iOS support is present but less consistently pitched at
/// extreme values — test on a real iOS device before relying on it, and
/// clamp the pitch multiplier conservatively (this file uses 1.6x).
class VoiceMimicParrot extends StatefulWidget {
  final String word;
  final String imageAsset; // the animal's picture, shown alongside the parrot
  final VoidCallback onComplete;

  const VoiceMimicParrot({
    super.key,
    required this.word,
    required this.imageAsset,
    required this.onComplete,
  });

  @override
  State<VoiceMimicParrot> createState() => _VoiceMimicParrotState();
}

enum _Stage { parrotIntro, listening, recording, playback, done }

class _VoiceMimicParrotState extends State<VoiceMimicParrot> {
  final FlutterTts tts = FlutterTts();
  final FlutterSoundRecorder soundRecorder = FlutterSoundRecorder();
  final AudioPlayer player = AudioPlayer();

  _Stage stage = _Stage.parrotIntro;
  String? recordingPath;
  DateTime? recordStartedAt;
  int attemptCount = 0;
  bool recorderReady = false;

  @override
  void initState() {
    super.initState();
    tts.setLanguage('en-US');
    WidgetsBinding.instance.addPostFrameCallback((_) => _playParrotIntro());
  }

  @override
  void dispose() {
    tts.stop();
    if (recorderReady) soundRecorder.closeRecorder();
    player.dispose();
    super.dispose();
  }

  Future<void> _playParrotIntro() async {
    setState(() => stage = _Stage.parrotIntro);
    await tts.speak('Squawk! Say ${widget.word}!');
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) setState(() => stage = _Stage.listening);
  }

  Future<void> _startRecording() async {
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      // Mic permission denied — fall back gracefully instead of blocking progress.
      if (mounted) widget.onComplete();
      return;
    }

    if (!recorderReady) {
      await soundRecorder.openRecorder();
      recorderReady = true;
    }

    final dir = Directory.systemTemp;
    final path = '${dir.path}/mimic_${DateTime.now().millisecondsSinceEpoch}.aac';
    await soundRecorder.startRecorder(toFile: path, codec: Codec.aacADTS);
    setState(() {
      stage = _Stage.recording;
      recordingPath = path;
      recordStartedAt = DateTime.now();
    });
  }

  Future<void> _stopRecording() async {
    final path = await soundRecorder.stopRecorder();
    final heldMs = recordStartedAt == null
        ? 0
        : DateTime.now().difference(recordStartedAt!).inMilliseconds;

    // Minimum-effort check, mirroring the tracing screen's approach: reject
    // a near-instant tap/release (no real attempt), not the *content* of
    // what was said — we deliberately don't try to grade pronunciation.
    if (path == null || heldMs < 400) {
      attemptCount++;
      if (attemptCount >= 3) {
        // Don't trap a frustrated child in a retry loop forever.
        if (mounted) widget.onComplete();
        return;
      }
      setState(() => stage = _Stage.listening);
      return;
    }

    setState(() {
      recordingPath = path;
      stage = _Stage.playback;
    });
    await _playbackPitchShifted(path);
  }

  Future<void> _playbackPitchShifted(String path) async {
    try {
      await player.setFilePath(path);
      await player.setPitch(1.6); // squirrel-voice effect
      await player.play();
      await player.playerStateStream.firstWhere((s) => s.processingState == ProcessingState.completed);
    } catch (_) {
      // Pitch-shift playback failed on this platform/device — still let the
      // session continue rather than blocking the child's progress.
    }
    if (!mounted) return;
    setState(() => stage = _Stage.done);
    await Future.delayed(const Duration(milliseconds: 900));
    if (mounted) widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(24)),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🦜', style: TextStyle(fontSize: 64)),
              const SizedBox(width: 12),
              Image.asset(widget.imageAsset, width: 80, height: 80, fit: BoxFit.contain),
            ],
          ),
          const SizedBox(height: 24),
          Text(widget.word,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFFE07800), letterSpacing: 2)),
          const SizedBox(height: 32),
          if (stage == _Stage.listening || stage == _Stage.recording)
            GestureDetector(
              onLongPressStart: (_) => _startRecording(),
              onLongPressEnd: (_) => _stopRecording(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: stage == _Stage.recording ? 100 : 84,
                height: stage == _Stage.recording ? 100 : 84,
                decoration: BoxDecoration(
                  color: stage == _Stage.recording ? const Color(0xFFE85D5D) : const Color(0xFFFFAB40),
                  shape: BoxShape.circle,
                  boxShadow: stage == _Stage.recording
                      ? [BoxShadow(color: const Color(0xFFE85D5D).withOpacity(0.4), blurRadius: 20, spreadRadius: 4)]
                      : [],
                ),
                child: const Icon(Icons.mic_rounded, color: Colors.white, size: 40),
              ),
            ),
          if (stage == _Stage.listening)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text('Hold the mic and say it! 🎤', style: TextStyle(color: Color(0xFF888888), fontSize: 13)),
            ),
          if (stage == _Stage.playback)
            const Text('Listen to yourself! 🐿️', style: TextStyle(color: Color(0xFFE07800), fontWeight: FontWeight.bold)),
          if (stage == _Stage.done)
            const Text('Great job! 🎉', style: TextStyle(color: Color(0xFF4DD9C0), fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
    );
  }
}
