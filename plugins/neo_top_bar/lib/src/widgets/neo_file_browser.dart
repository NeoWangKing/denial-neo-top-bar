/// A small file browser for settings that need a path.
///
/// The plugin SDK has no file chooser and no portal client, so a setting like
/// "use this image as the launcher mark" cannot open a native dialog. What it can
/// do is list directories itself — `dart:io` is available to a plugin — which
/// gives the user the thing they actually need: a way to find the file by
/// looking rather than by typing an absolute path from memory.
///
/// Deliberately plain: directories and images only, hidden entries dropped, one
/// level at a time. It is a picker inside a settings card, not a file manager.
library;

import 'dart:io';

import 'package:denial_flutter_sdk/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/l10n.dart';
import '../core/l10n_context.dart';
import '../core/launcher_options.dart';
import 'neo_setting_controls.dart';

class NeoFileBrowser extends StatefulWidget {
  const NeoFileBrowser({
    required this.onSelected,
    this.startDirectory,
    this.title = '',
    super.key,
  });

  /// Receives the absolute path of the image the user picked.
  final ValueChanged<String> onSelected;

  /// Where to start; defaults to the home directory.
  final String? startDirectory;

  final String title;

  @override
  State<NeoFileBrowser> createState() => _NeoFileBrowserState();
}

class _NeoFileBrowserState extends State<NeoFileBrowser> {
  late String _directory;
  List<NeoBrowseEntry> _entries = const <NeoBrowseEntry>[];
  String? _error;

  @override
  void initState() {
    super.initState();
    _directory = widget.startDirectory ?? _homeDirectory();
    _read();
  }

  static String _homeDirectory() {
    for (final key in const <String>['HOME', 'XDG_PICTURES_DIR']) {
      final value = Platform.environment[key];
      if (value != null && value.isNotEmpty) return value;
    }
    return '/';
  }

  void _read() {
    try {
      final listed = <NeoBrowseEntry>[
        for (final entity in Directory(_directory).listSync(followLinks: false))
          NeoBrowseEntry(
            name: entity.path.split('/').last,
            isDirectory: entity is Directory,
          ),
      ];
      setState(() {
        _entries = neoBrowseEntries(listed);
        _error = null;
      });
    } on Object catch (error) {
      setState(() {
        _entries = const <NeoBrowseEntry>[];
        _error = '$error';
      });
    }
  }

  void _enter(String name) {
    final next = _directory.endsWith('/')
        ? '$_directory$name'
        : '$_directory/$name';
    setState(() => _directory = next);
    _read();
  }

  void _up() {
    final parent = neoParentDirectory(_directory);
    if (parent == null) return;
    setState(() => _directory = parent);
    _read();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    final s = context.neoStrings;
    final parent = neoParentDirectory(_directory);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colors.surfaceContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(theme.chipRadius),
        border: Border.all(color: theme.colors.hairlineSoft),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title.isEmpty ? s.chooseImage : widget.title,
                    style: theme.text.systemBarValue.copyWith(fontSize: 13),
                  ),
                ),
                if (parent != null)
                  _BrowserAction(
                    icon: Icons.arrow_upward,
                    label: s.parentDirectory,
                    onPressed: _up,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _directory,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.text.systemBarCaption.copyWith(
                fontSize: 11.5,
                color: theme.colors.textTertiary,
              ),
            ),
            const SizedBox(height: 8),
            if (_error case final error?)
              Text(
                s.openDirectoryFailed(error),
                style: theme.text.systemBarCaption.copyWith(
                  color: theme.colors.performanceWarning,
                ),
              )
            else if (_entries.isEmpty)
              Text(
                s.directoryEmpty,
                style: theme.text.systemBarCaption.copyWith(
                  color: theme.colors.textTertiary,
                ),
              )
            else
              ConstrainedBox(
                // Bounded so the card's own scroll view keeps working when a
                // directory has hundreds of entries.
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _entries.length,
                  itemBuilder: (context, index) {
                    final entry = _entries[index];
                    return _BrowserRow(
                      icon: entry.isDirectory
                          ? Icons.folder_outlined
                          : Icons.image_outlined,
                      label: entry.name,
                      onPressed: () => entry.isDirectory
                          ? _enter(entry.name)
                          : widget.onSelected(
                              _directory.endsWith('/')
                                  ? '$_directory${entry.name}'
                                  : '$_directory/${entry.name}',
                            ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BrowserRow extends StatelessWidget {
  const _BrowserRow({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(icon, size: 15, color: theme.colors.textSecondary),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.text.systemBarValue.copyWith(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrowserAction extends StatelessWidget {
  const _BrowserAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    return Tooltip(
      message: label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Icon(icon, size: 16, color: theme.colors.textSecondary),
          ),
        ),
      ),
    );
  }
}

/// The custom-mark field: what is chosen now, and the browser to change it.
class NeoImagePathField extends StatelessWidget {
  const NeoImagePathField({
    required this.path,
    required this.onChanged,
    this.browsing = false,
    this.onBrowse,
    this.hint = '',
    super.key,
  });

  final String path;
  final ValueChanged<String?> onChanged;

  /// Whether the browser is open underneath.
  final bool browsing;
  final VoidCallback? onBrowse;

  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    final s = context.neoStrings;
    final chosen = path.isNotEmpty;
    return NeoSettingRow(
      // The file's own name, with its directory underneath: an absolute path can
      // be longer than the row and reads worse than the name it ends with.
      label: chosen
          ? neoFileName(path)
          : (hint.isEmpty ? s.noImageSelected : hint),
      description: chosen
          ? '${neoParentDirectory(path) ?? ''} · ${_describe(path, s)}'
          : s.pickImageHint,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onBrowse != null)
            _BrowserAction(
              icon: browsing ? Icons.expand_less : Icons.folder_open,
              label: browsing ? s.collapse : s.browseFiles,
              onPressed: onBrowse!,
            ),
          if (chosen)
            _BrowserAction(
              icon: Icons.close,
              label: s.clear,
              onPressed: () => onChanged(null),
            ),
          if (chosen) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 28,
              height: 28,
              child: _Thumbnail(path: path, theme: theme),
            ),
          ],
        ],
      ),
    );
  }

  static String _describe(String path, NeoStrings s) {
    final dot = path.lastIndexOf('.');
    if (dot <= 0) return s.customImage;
    return path.substring(dot + 1).toUpperCase();
  }
}

/// Draws the chosen file, or says why it cannot be drawn.
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.path, required this.theme});

  final String path;
  final ShellThemeData theme;

  @override
  Widget build(BuildContext context) {
    final s = context.neoStrings;
    final file = File(path);
    if (!file.existsSync()) {
      return Tooltip(
        message: s.fileMissing,
        child: Icon(
          Icons.broken_image_outlined,
          size: 18,
          color: theme.colors.performanceWarning,
        ),
      );
    }
    // SVG is what distribution marks come as, and flutter_svg is already a
    // dependency of the launcher's own asset, so a chosen .svg previews too.
    if (path.toLowerCase().endsWith('.svg')) {
      return SvgPicture.file(file, fit: BoxFit.contain);
    }
    return Image.file(
      file,
      fit: BoxFit.contain,
      errorBuilder: (context, _, _) => Icon(
        Icons.broken_image_outlined,
        size: 18,
        color: theme.colors.performanceWarning,
      ),
    );
  }
}
