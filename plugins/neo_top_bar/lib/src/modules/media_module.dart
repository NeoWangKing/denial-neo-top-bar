/// Media playback state, with transport controls.
///
/// Optional: hidden unless a player is publishing MPRIS, so a machine with no
/// active playback never reserves a pill.
library;

import 'package:denial_flutter_sdk/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n_context.dart';
import '../core/module.dart';
import '../core/module_defaults.dart';
import '../core/module_descriptor.dart';
import '../widgets/neo_card.dart';

class MediaModule implements NeoModule {
  const MediaModule();

  @override
  NeoModuleDescriptor get descriptor => mediaModule;

  @override
  bool isAvailable(NeoModuleContext context) => true;

  @override
  Widget build(BuildContext context, NeoModuleContext module) =>
      _MediaContent(module: module);
}

class _MediaContent extends ConsumerWidget {
  const _MediaContent({required this.module});

  final NeoModuleContext module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.neoStrings;
    final services = module.services;
    final playback = ref.watch(services.media);
    final current = playback.value;
    if (current == null || !current.available) return const SizedBox.shrink();
    final commands = ref.watch(services.mediaCommands);
    final theme = ShellTheme.of(context);
    final label = current.title.isEmpty ? current.artistLabel : current.title;

    Widget iconButton(IconData icon, String tooltip, VoidCallback onPressed) =>
        Tooltip(
          message: tooltip,
          child: Semantics(
            button: true,
            label: tooltip,
            onTap: onPressed,
            child: ExcludeSemantics(
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onPressed,
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: Center(
                      child: Icon(
                        icon,
                        size: 16,
                        color: theme.colors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

    final transport = <Widget>[
      if (current.canGoPrevious)
        iconButton(Icons.skip_previous, s.previousTrack, commands.previous),
      if (current.playing ? current.canPause : current.canPlay)
        iconButton(
          current.playing ? Icons.pause : Icons.play_arrow,
          current.playing ? s.pause : s.play,
          commands.playPause,
        ),
      if (current.canGoNext)
        iconButton(Icons.skip_next, s.nextTrack, commands.next),
    ];

    return NeoCard(
      accent: module.accent,
      density: module.density,
      horizontal: module.horizontal,
      child: module.horizontal
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Text(
                    label,
                    style: ShellText.systemBarValue,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                ...transport,
              ],
            )
          // Vertical: the buttons only. A track title cannot be read in a pill as
          // wide as the strip — it would be an ellipsis with three letters — so
          // the transport is what a vertical bar keeps, and the title stays in
          // the media panel.
          : Column(mainAxisSize: MainAxisSize.min, children: transport),
    );
  }
}
