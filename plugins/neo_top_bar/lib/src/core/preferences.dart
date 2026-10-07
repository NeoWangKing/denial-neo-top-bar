/// Plugin-owned configuration storage.
///
/// Denial's SDK has no plugin settings API: a plugin keeps its own preferences.
/// This follows the pattern Denial's own taskbar uses — a JSON file under
/// `~/.config/denial/plugins/`, written atomically and merged rather than
/// replaced, so keys written by a newer build are never destroyed by an older
/// one.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'config.dart';

class NeoTopBarPreferencesStore {
  NeoTopBarPreferencesStore(this.file);

  final File file;

  int _tempSequence = 0;
  Future<void>? _inFlight;
  NeoTopBarConfig? _pending;

  /// `$XDG_CONFIG_HOME/denial/plugins/neo_top_bar.json`, falling back to
  /// `$HOME/.config`.
  static File defaultFile() {
    final env = Platform.environment;
    final configured = env['XDG_CONFIG_HOME'];
    final home = env['HOME'];
    final root = configured != null && configured.startsWith('/')
        ? configured
        : home != null && home.startsWith('/')
        ? '$home/.config'
        : null;
    if (root == null) {
      throw const FileSystemException('No configuration directory');
    }
    return File('$root/denial/plugins/neo_top_bar.json');
  }

  /// Reads the raw JSON object, treating a missing file as empty.
  ///
  /// A malformed file throws: the caller decides whether to surface it or fall
  /// back to defaults. Silently overwriting a file the user hand-edited is the
  /// one outcome worth avoiding.
  Future<Map<String, Object?>> readRaw() async {
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) {
        throw const FormatException('Expected a JSON object');
      }
      return decoded.cast<String, Object?>();
    } on FileSystemException catch (error) {
      if (error.osError?.errorCode == 2) return <String, Object?>{};
      rethrow;
    }
  }

  Future<NeoTopBarConfig> read() async =>
      NeoTopBarConfig.fromJson(await readRaw());

  /// Persists [config], preserving every key this plugin does not own.
  ///
  /// Calls are serialized. A request made while a write is running replaces the
  /// pending one, so rapid toggling costs at most one extra write and two
  /// renames can never interleave.
  Future<void> save(NeoTopBarConfig config) {
    _pending = config;
    final running = _inFlight;
    if (running != null) return running;
    final future = _drain();
    _inFlight = future;
    return future;
  }

  Future<void> _drain() async {
    try {
      while (_pending != null) {
        final next = _pending!;
        _pending = null;
        await _writeOnce(next);
      }
    } finally {
      _inFlight = null;
    }
  }

  Future<void> _writeOnce(NeoTopBarConfig config) async {
    Map<String, Object?> json;
    try {
      json = await readRaw();
    } on FormatException {
      // A malformed file must not block saving the user's new choice; keep the
      // unreadable content aside so it can still be recovered by hand.
      try {
        await file.copy('${file.path}.broken');
      } on FileSystemException {
        // Best effort only: failing to back up must not fail the write.
      }
      json = <String, Object?>{};
    }
    final encoded = config.toJson();
    json['schema'] = config.schema;
    json['instances'] = encoded['instances'];
    json['order'] = encoded['order'];
    // A file written by an older build stored one entry per *module* under
    // `modules`. It is read as the instances of the same name and rewritten
    // here, so leaving it behind would put a second, stale copy of every
    // decision in the file.
    json.remove('modules');
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.$pid.${_tempSequence++}.tmp');
    try {
      await temp.writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(json)}\n',
        flush: true,
      );
      await temp.rename(file.path);
    } finally {
      if (await temp.exists()) {
        try {
          await temp.delete();
        } on FileSystemException {
          // Leftover temp files are harmless and cleaned up on the next write.
        }
      }
    }
  }
}
