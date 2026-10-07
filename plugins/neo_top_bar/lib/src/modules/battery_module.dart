/// Battery gauge. Activating the card opens Denial's power settings.
library;

import 'dart:math' as math;

import 'package:denial_flutter_sdk/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/module.dart';
import '../core/module_defaults.dart';
import '../core/module_descriptor.dart';
import '../widgets/neo_card.dart';

class BatteryModule implements NeoModule {
  const BatteryModule();

  @override
  NeoModuleDescriptor get descriptor => batteryModule;

  @override
  bool isAvailable(NeoModuleContext context) => true;

  @override
  Widget build(BuildContext context, NeoModuleContext module) =>
      _BatteryContent(module: module);
}

class _BatteryContent extends ConsumerWidget {
  const _BatteryContent({required this.module});

  final NeoModuleContext module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = module.services;
    final status = ref.watch(services.battery);
    final capacity = status.capacity;
    // A machine without a battery shows nothing rather than a dead gauge.
    if (capacity == null) return const SizedBox.shrink();

    final theme = ShellTheme.of(context);
    final strings = services.strings(context);
    final state = status.charging ? 'charging' : 'discharging';
    final statusLabel = strings.batteryLine(state, capacity);
    final level = (capacity / 100).clamp(0.0, 1.0).toDouble();

    return NeoCardButton(
      accent: module.accent,
      density: module.density,
      horizontal: module.horizontal,
      tooltip: '打开电源设置',
      onPressed: services.openPowerSettings,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label: '${strings.batteryTitle}, $statusLabel',
            child: SizedBox(
              width: 24,
              height: 14,
              child: CustomPaint(
                painter: _BatteryLevelPainter(
                  level: level,
                  charging: status.charging,
                  accent: theme.accent,
                  outline: module.accent.captionColor(theme),
                  foreground: theme.colors.textPrimary,
                  cornerRadiusScale: theme.cornerRadiusScale,
                ),
              ),
            ),
          ),
          const SizedBox(width: 7),
          SizedBox(
            width: 34,
            child: Text.rich(
              TextSpan(
                text: strings.numberValue(capacity),
                style: ShellText.systemBarValue,
                children: [
                  TextSpan(
                    text: strings.percentSign,
                    style: ShellText.systemBarCaption.copyWith(
                      color: module.accent.captionColor(theme),
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.right,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Vector battery silhouette with an animated charge fill and an integrated
/// charging bolt, so the gauge stays crisp at fractional output scales.
class _BatteryLevelPainter extends CustomPainter {
  const _BatteryLevelPainter({
    required this.level,
    required this.charging,
    required this.accent,
    required this.outline,
    required this.foreground,
    required this.cornerRadiusScale,
  });

  final double level;
  final bool charging;
  final Color accent;
  final Color outline;
  final Color foreground;
  final double cornerRadiusScale;

  @override
  void paint(Canvas canvas, Size size) {
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.75, 1.25, size.width - 4.0, size.height - 2.5),
      Radius.circular(3.0 * cornerRadiusScale),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.35,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width - 2.55,
          size.height * 0.34,
          1.8,
          size.height * 0.32,
        ),
        Radius.circular(0.8 * cornerRadiusScale),
      ),
      Paint()..color = outline,
    );

    final fillWidth = math.max(0.0, (body.width - 4.0) * level);
    if (fillWidth > 0.0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            body.left + 2.0,
            body.top + 2.0,
            fillWidth,
            body.height - 4.0,
          ),
          Radius.circular(1.5 * cornerRadiusScale),
        ),
        Paint()..color = accent,
      );
    }

    if (charging) {
      final center = body.center;
      final bolt = Path()
        ..moveTo(center.dx + 0.6, body.top + 1.7)
        ..lineTo(center.dx - 3.0, center.dy + 0.4)
        ..lineTo(center.dx - 0.6, center.dy + 0.4)
        ..lineTo(center.dx - 1.5, body.bottom - 1.6)
        ..lineTo(center.dx + 3.0, center.dy - 0.8)
        ..lineTo(center.dx + 0.5, center.dy - 0.8)
        ..close();
      canvas.drawPath(bolt, Paint()..color = foreground);
    }
  }

  @override
  bool shouldRepaint(covariant _BatteryLevelPainter oldDelegate) =>
      oldDelegate.level != level ||
      oldDelegate.charging != charging ||
      oldDelegate.accent != accent ||
      oldDelegate.outline != outline ||
      oldDelegate.foreground != foreground ||
      oldDelegate.cornerRadiusScale != cornerRadiusScale;
}
