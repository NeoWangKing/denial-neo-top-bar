/// Live output volume for the control centre.
///
/// Denial's audio bridge exposes a level and nothing else — there is no mute
/// call — so this provider owns the two things the panel needs on top of it:
/// the level it is showing while the user drags the slider, and the level to
/// restore when the speaker button unmutes.
///
/// The level is applied through [`AudioService.apply`], which echoes every
/// change back as an [`AudioLevelState`] tagged with the request serial. The
/// echo is what makes the slider safe to drag: the host's own volume keys and
/// other clients mutate the same sink, so the panel cannot simply trust what it
/// last sent. While a drag is in progress the local value wins, and the echo is
/// accepted again as soon as the drag ends.
library;

import 'dart:async';

import 'package:denial_flutter_sdk/system_services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One request in flight, so its echo can be recognised.
class _PendingVolume {
  const _PendingVolume(this.serial, this.percent);

  final int serial;
  final int percent;
}

class NeoVolumeState {
  const NeoVolumeState({
    required this.level,
    required this.muted,
    this.ready = false,
  });

  /// Output level in `[0, 1]`, which is how the bridge reports it.
  final double level;

  /// True when the host reports the sink as muted, or the level is zero.
  final bool muted;

  /// False until the first reading arrives, so the slider can render a disabled
  /// track instead of jumping from zero.
  final bool ready;

  NeoVolumeState copyWith({double? level, bool? muted, bool? ready}) =>
      NeoVolumeState(
        level: level ?? this.level,
        muted: muted ?? this.muted,
        ready: ready ?? this.ready,
      );
}

/// How long after a drag ends an echo is still treated as its acknowledgement.
///
/// The bridge answers quickly, but a request can also be superseded by the
/// user's own volume keys; after this long the next echo is trusted again.
const Duration neoVolumeEchoWindow = Duration(milliseconds: 250);

/// Interval between level commits while the slider is being dragged.
///
/// One apply per frame would flood the bridge; one at the end would leave the
/// sink silent until the user let go.
const Duration neoVolumeCommitInterval = Duration(milliseconds: 90);

final neoVolumeProvider = NotifierProvider<NeoVolumeController, NeoVolumeState>(
  NeoVolumeController.new,
);

class NeoVolumeController extends Notifier<NeoVolumeState> {
  AudioService? _audio;
  StreamSubscription<AudioLevelState>? _subscription;
  Timer? _commitTimer;
  Timer? _echoTimer;
  _PendingVolume? _pending;
  int _nextSerial = 1;
  double _remembered = 0.5;
  bool _dragging = false;

  @override
  NeoVolumeState build() {
    final audio = ref.watch(audioServiceProvider);
    _audio = audio;
    _subscription = audio.states.listen(_handleState);
    ref.onDispose(() {
      _commitTimer?.cancel();
      _echoTimer?.cancel();
      unawaited(_subscription?.cancel());
      _subscription = null;
    });
    // The stream only pushes on change, so the initial level has to be read.
    unawaited(_readInitial());
    return const NeoVolumeState(level: 0, muted: false);
  }

  Future<void> _readInitial() async {
    final level = await _audio?.readLevel();
    if (level == null || !ref.mounted) return;
    if (_dragging) return;
    if (level > 0) _remembered = level;
    state = NeoVolumeState(level: level, muted: level <= 0, ready: true);
  }

  void _handleState(AudioLevelState update) {
    final pending = _pending;
    if (pending != null && update.requestSerial != pending.serial) {
      // Someone else moved the sink in between — the hardware keys, most likely.
      // Their value wins, because it is the truth; the pending request is
      // dropped so it cannot overwrite a later echo.
      _pending = null;
      _echoTimer?.cancel();
    }
    final level = update.level.clamp(0.0, 1.0).toDouble();
    if (level > 0) _remembered = level;
    if (_dragging) {
      // The slider is the user's hand right now; showing the echoed value would
      // pull the knob back under it.
      state = state.copyWith(muted: update.muted, ready: true);
      return;
    }
    state = NeoVolumeState(
      level: level,
      muted: update.muted || level <= 0,
      ready: true,
    );
  }

  /// Called when a drag starts, so echoes stop moving the knob.
  void beginDrag() => _dragging = true;

  /// Called continuously while dragging: moves the knob and applies the level.
  void setLevel(double level) {
    final clamped = level.clamp(0.0, 1.0).toDouble();
    if (clamped > 0) _remembered = clamped;
    state = state.copyWith(level: clamped, muted: clamped <= 0, ready: true);
    _commitTimer?.cancel();
    _commitTimer = Timer(neoVolumeCommitInterval, () => _apply(clamped));
  }

  /// Called when the drag ends: applies immediately and stops deferring echoes.
  void commitLevel(double level) {
    final clamped = level.clamp(0.0, 1.0).toDouble();
    _dragging = false;
    _commitTimer?.cancel();
    state = state.copyWith(level: clamped, muted: clamped <= 0, ready: true);
    _apply(clamped);
  }

  /// Speaker button: mute to zero, or put the remembered level back.
  void toggleMute() {
    final silenced = state.muted || state.level <= 0;
    final target = silenced ? _remembered.clamp(0.05, 1.0) : 0.0;
    _dragging = false;
    _commitTimer?.cancel();
    state = state.copyWith(level: target, muted: target <= 0, ready: true);
    _apply(target);
  }

  void _apply(double level) {
    final audio = _audio;
    if (audio == null) return;
    final percent = (level * 100).round().clamp(0, 100);
    final serial = _nextSerial;
    _nextSerial = serial >= 0xffffffff ? 1 : serial + 1;
    _pending = _PendingVolume(serial, percent);
    _echoTimer?.cancel();
    _echoTimer = Timer(neoVolumeEchoWindow, () {
      _pending = null;
    });
    audio.apply(percent, requestSerial: serial);
  }
}
