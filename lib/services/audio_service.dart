import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import 'storage_service.dart';

enum MusicTrack { menu, tension }

/// Sound effects, looping background music and light haptics, all
/// respecting the mute / music / vibration settings.
class AudioService {
  final StorageService storage;
  final _sfx = <String, AudioPlayer>{};
  AudioPlayer? _musicPlayer;
  MusicTrack? _track;
  bool _suspended = false;

  AudioService(this.storage) {
    storage.addListener(_syncMusic);
  }

  // Created lazily so nothing touches the platform while muted.
  AudioPlayer get _music =>
      _musicPlayer ??= AudioPlayer()..setReleaseMode(ReleaseMode.loop);

  Future<void> play(String name) async {
    if (storage.muted) return;
    try {
      final player = _sfx.putIfAbsent(
        name,
        () => AudioPlayer()..setPlayerMode(PlayerMode.lowLatency),
      );
      await player.stop();
      await player.play(AssetSource('sounds/$name.wav'));
    } catch (_) {
      // Audio is non-critical.
    }
  }

  /// Switches the looping background track (menu calm / game tension).
  Future<void> playMusic(MusicTrack track) async {
    if (_track == track) return;
    _track = track;
    await _restartMusic();
  }

  Future<void> stopMusic() async {
    _track = null;
    try {
      await _musicPlayer?.stop();
    } catch (_) {}
  }

  /// App went to background.
  Future<void> suspend() async {
    _suspended = true;
    try {
      await _musicPlayer?.pause();
    } catch (_) {}
  }

  Future<void> resumeFromBackground() async {
    _suspended = false;
    await _restartMusic();
  }

  bool get _musicAllowed => !storage.muted && storage.music && !_suspended;

  Future<void> _restartMusic() async {
    try {
      final track = _track;
      if (track == null || !_musicAllowed) {
        await _musicPlayer?.pause();
        return;
      }
      await _music.stop();
      await _music.setVolume(track == MusicTrack.tension ? 0.55 : 0.35);
      await _music.play(AssetSource('sounds/${track.name}.wav'));
    } catch (_) {}
  }

  bool _lastAllowed = true;
  void _syncMusic() {
    final allowed = _musicAllowed;
    if (allowed == _lastAllowed) return;
    _lastAllowed = allowed;
    _restartMusic();
  }

  void tap() {
    if (storage.vibration) HapticFeedback.lightImpact();
  }

  void heavy() {
    if (storage.vibration) HapticFeedback.mediumImpact();
  }
}
