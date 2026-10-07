/// CPU / GPU load meters: a compact sparkline pill with a name tag, the current
/// percentage and an optional temperature.
///
/// These default to off. They poll host telemetry that the bar otherwise does
/// not need, so enabling them is an explicit choice.
library;

import 'package:denial_flutter_sdk/theme.dart';
import 'package:denial_sdk/system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/module.dart';
import '../core/module_defaults.dart';
import '../core/module_descriptor.dart';
import '../widgets/neo_card.dart';

class CpuModule implements NeoModule {
  const CpuModule();

  @override
  NeoModuleDescriptor get descriptor => cpuModule;

  @override
  bool isAvailable(NeoModuleContext context) => true;

  @override
  Widget build(BuildContext context, NeoModuleContext module) =>
      _CpuContent(module: module);
}

class GpuModule implements NeoModule {
  const GpuModule();

  @override
  NeoModuleDescriptor get descriptor => gpuModule;

  @override
  bool isAvailable(NeoModuleContext context) => true;

  @override
  Widget build(BuildContext context, NeoModuleContext module) =>
      _GpuContent(module: module);
}

class _CpuContent extends ConsumerWidget {
  const _CpuContent({required this.module});

  final NeoModuleContext module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final series = ref.watch(module.services.cpu);
    if (series.current == null) return const SizedBox.shrink();
    return NeoLoadMeter(module: module, label: 'CPU', series: series);
  }
}

class _GpuContent extends ConsumerWidget {
  const _GpuContent({required this.module});

  final NeoModuleContext module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gpus = ref.watch(module.services.gpus);
    if (gpus.isEmpty) return const SizedBox.shrink();
    final horizontal = module.horizontal;
    return Flex(
      direction: horizontal ? Axis.horizontal : Axis.vertical,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final gpu in gpus)
          Padding(
            padding: EdgeInsets.only(
              right: horizontal ? 8 * module.density : 0,
              bottom: horizontal ? 0 : 8 * module.density,
            ),
            child: NeoLoadMeter(
              module: module,
              label: gpu.label,
              series: gpu.series,
            ),
          ),
      ],
    );
  }
}

/// One load pill: name tag, sparkline, animated percentage and optional
/// temperature. Identity comes from the tag, never from the line colour alone.
class NeoLoadMeter extends StatelessWidget {
  const NeoLoadMeter({
    required this.module,
    required this.label,
    required this.series,
    super.key,
  });

  final NeoModuleContext module;
  final String label;
  final LoadSeries series;

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    final strings = module.services.strings(context);
    final caption = ShellText.systemBarCaption.copyWith(
      color: module.accent.captionColor(theme),
    );
    return NeoCard(
      accent: module.accent,
      density: module.density,
      horizontal: module.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: caption),
          const SizedBox(width: 6),
          RepaintBoundary(
            child: CustomPaint(
              size: const Size(38, 14),
              painter: _SparklinePainter(
                history: series.history,
                accent: theme.accent,
              ),
            ),
          ),
          const SizedBox(width: 7),
          SizedBox(
            width: 34,
            child: Text.rich(
              TextSpan(
                text: strings.numberValue(
                  ((series.current ?? 0.0) * 100).round(),
                ),
                style: ShellText.systemBarValue,
                children: [TextSpan(text: strings.percentSign, style: caption)],
              ),
              textAlign: TextAlign.right,
              maxLines: 1,
            ),
          ),
          if (series.temperatureC case final temperature?) ...[
            const SizedBox(width: 7),
            Text.rich(
              TextSpan(
                text: strings.numberValue(temperature.round()),
                style: ShellText.systemBarValue,
                children: [TextSpan(text: strings.celsiusUnit, style: caption)],
              ),
              maxLines: 1,
            ),
          ],
        ],
      ),
    );
  }
}

/// Paints a load history as an accent polyline over a fading gradient fill.
/// Plain path drawing only — no mask filters and no save layers.
class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({required this.history, required this.accent});

  final List<double> history;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final points = sparklinePoints(history, size);
    if (points.length < 2) return;
    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      line.lineTo(point.dx, point.dy);
    }
    final fill = Path.from(line)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accent.withValues(alpha: 0.35),
            accent.withValues(alpha: 0.0),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.history != history || oldDelegate.accent != accent;
}

/// Maps [history] (oldest first, 0-1 values) onto sparkline points inside
/// [size]. The newest sample sits on the trailing edge and a partial history
/// grows outward as samples arrive.
///
/// [LoadSeries.capacity] defines the full window, so the line's slope stays
/// meaningful instead of rescaling to whatever has arrived so far.
List<Offset> sparklinePoints(List<double> history, Size size) {
  if (history.isEmpty || size.isEmpty) return const <Offset>[];
  final step = size.width / (LoadSeries.capacity - 1);
  return List<Offset>.generate(history.length, (index) {
    final fromEnd = history.length - 1 - index;
    return Offset(
      size.width - fromEnd * step,
      size.height * (1.0 - history[index].clamp(0.0, 1.0)),
    );
  }, growable: false);
}
