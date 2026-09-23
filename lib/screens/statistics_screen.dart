import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ataraxy/l10n/strings.dart';
import 'package:ataraxy/models/dream_signs.dart';
import 'package:ataraxy/models/entry.dart';
import 'package:ataraxy/providers/settings_provider.dart';
import 'package:ataraxy/services/steps_service.dart';
import 'package:ataraxy/services/storage_service.dart';
import 'package:ataraxy/theme/app_theme.dart';
import 'package:ataraxy/widgets/pressable_icon_button.dart';
import 'package:ataraxy/widgets/animated_snack.dart';
import 'package:ataraxy/widgets/skeleton.dart';
import 'package:ataraxy/widgets/premium_header.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  List<JournalEntry> _entries = [];
  bool _loading = true;
  late DateTime _focusedMonth;

  @override
  void initState() {
    super.initState();
    _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
    _load();
  }

  Future<void> _load() async {
    final entries = await StorageService().loadEntries();
    if (mounted) {
      setState(() {
        _entries = entries;
        _loading = false;
      });
    }
  }

  Map<DateTime, int> _monthCounts() {
    final map = <DateTime, int>{};
    for (final e in _entries) {
      final d = DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day);
      map[d] = (map[d] ?? 0) + 1;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_loading) {
      // Skeleton: summary cards + chart placeholders shimmer while the
      // entries are read, so the screen feels alive instead of blank.
      return Scaffold(
        appBar: _buildAppBar(scheme, context),
        body: Skeleton(
          child: ListView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: const [
                  Expanded(child: SkeletonBox(height: 84, radius: 18)),
                  SizedBox(width: 12),
                  Expanded(child: SkeletonBox(height: 84, radius: 18)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: const [
                  Expanded(child: SkeletonBox(height: 84, radius: 18)),
                  SizedBox(width: 12),
                  Expanded(child: SkeletonBox(height: 84, radius: 18)),
                ],
              ),
              const SizedBox(height: 24),
              const SkeletonBox(height: 200, radius: 20),
              const SizedBox(height: 24),
              const SkeletonBox(height: 140, radius: 20),
            ],
          ),
        ),
      );
    }

    final dreams = _entries.where((e) => e.type == EntryType.dream).toList();
    final life = _entries.where((e) => e.type == EntryType.life).toList();
    final tulpas = _entries.where((e) => e.type == EntryType.tulpa).toList();

    final sortedByDate = List<JournalEntry>.from(_entries)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final moodSpots = <FlSpot>[];
    for (var i = 0; i < sortedByDate.length; i++) {
      moodSpots.add(FlSpot(i.toDouble(), sortedByDate[i].mood.toDouble()));
    }

    final signCounts = <String, int>{};
    for (final e in dreams) {
      for (final s in e.dreamSigns) {
        signCounts[s] = (signCounts[s] ?? 0) + 1;
      }
    }
    final sortedSigns = signCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final counts = _monthCounts();
    final maxMonthCount = counts.values.fold(0, (a, b) => b > a ? b : a);

    return Scaffold(
      appBar: _buildAppBar(scheme, context),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              _SummaryCard(
                icon: Icons.book_rounded,
                color: scheme.primary,
                value: _entries.length,
                label: L.tr(context, 'statsTotal'),
              ),
              const SizedBox(width: 12),
              _SummaryCard(
                icon: Icons.nightlight_round_rounded,
                color: AppAccents.lilac,
                value: dreams.length,
                label: L.tr(context, 'tabDreams'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _SummaryCard(
                icon: Icons.favorite_rounded,
                color: AppAccents.teal,
                value: life.length,
                label: L.tr(context, 'tabLife'),
              ),
              const SizedBox(width: 12),
              _SummaryCard(
                icon: Icons.psychology_rounded,
                color: AppAccents.slate,
                value: tulpas.length,
                label: L.tr(context, 'tabTulpa'),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            L.tr(context, 'statsByType'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: _BarChartWithTooltip(
              values: [dreams.length, life.length, tulpas.length],
              colors: const [
                AppAccents.lilac,
                AppAccents.teal,
                AppAccents.slate,
              ],
              labels: [
                L.tr(context, 'tabDreams'),
                L.tr(context, 'tabLife'),
                L.tr(context, 'tabTulpa'),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text(
            L.tr(context, 'statsMood'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: moodSpots.length < 2
                ? _emptyChart(context)
                : LineChart(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    LineChartData(
                      minY: 1,
                      maxY: 5,
                      lineBarsData: [
                        LineChartBarData(
                          spots: moodSpots,
                          isCurved: true,
                          color: scheme.primary,
                          barWidth: 3,
                          dotData: FlDotData(
                            show: moodSpots.length <= 30,
                            getDotPainter: (spot, xPercentage, barSpot, index) =>
                                FlDotCirclePainter(
                              radius: 3,
                              color: scheme.primary,
                              strokeWidth: 0,
                            ),
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            color: scheme.primary.withValues(alpha: 0.12),
                          ),
                        ),
                      ],
                      titlesData: FlTitlesData(
                        show: true,
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            getTitlesWidget: (v, _) => Text(
                              v.toInt().toString(),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        horizontalInterval: 1,
                        getDrawingHorizontalLine: (v) => FlLine(
                          color: scheme.outline.withValues(alpha: 0.2),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      // Smooth touch scrubbing: the dot follows the finger
                      // with an animated tooltip in the theme palette.
                      lineTouchData: LineTouchData(
                        enabled: true,
                        handleBuiltInTouches: true,
                        // The whole chart is a touch target, so a finger
                        // drag picks the nearest spot — no dead zones.
                        touchSpotThreshold: 30,
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (_) => scheme.inverseSurface,
                          fitInsideHorizontally: true,
                          fitInsideVertically: true,
                          getTooltipItems: (spots) => spots
                              .map(
                                (s) => LineTooltipItem(
                                  '${s.y.toInt()}',
                                  TextStyle(
                                    color: scheme.onInverseSurface,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        getTouchedSpotIndicator:
                            (barData, spotIndexes) => spotIndexes
                                .map(
                                  (i) => TouchedSpotIndicatorData(
                                    FlLine(
                                      color: scheme.primary,
                                      strokeWidth: 2,
                                    ),
                                    FlDotData(
                                      show: true,
                                      getDotPainter:
                                          (spot, x, barSpot, index) =>
                                              FlDotCirclePainter(
                                        radius: 5,
                                        color: scheme.primary,
                                        strokeWidth: 2,
                                        strokeColor: scheme.surface,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 22),
          Text(
            L.tr(context, 'statsCalendar'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          _CalendarHeatmap(
            focusedMonth: _focusedMonth,
            counts: counts,
            maxCount: maxMonthCount,
            onMonthChanged: (m) {
              // Calendar is clamped to 2026-01 .. 2032-12 — months outside
              // the range simply don't navigate.
              if (m.isBefore(DateTime(2026, 1)) ||
                  m.isAfter(DateTime(2032, 12))) {
                return;
              }
              setState(() => _focusedMonth = m);
            },
          ),
          const SizedBox(height: 22),
          Text(
            L.tr(context, 'statsDreamSigns'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          if (sortedSigns.isEmpty)
            _emptyChart(context)
          else
            ...sortedSigns.take(8).map((e) {
              final pct = maxMonthCount > 0
                  ? e.value / sortedSigns.first.value
                  : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(DreamSigns.iconOf(e.key), size: 20, color: scheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(DreamSigns.label(context, e.key)),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: pct,
                            backgroundColor:
                                scheme.primary.withValues(alpha: 0.15),
                            color: scheme.primary,
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                     Text(
                       e.value.toString(),
                       style: Theme.of(context).textTheme.labelMedium,
                     ),
                   ],
                 ),
               );
             }),
          const SizedBox(height: 22),
          _TrackingSection(entries: _entries),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ColorScheme scheme, BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 72,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      flexibleSpace: PremiumHeader(colors: AppTheme.headerColors(scheme)),
      title: Text(L.tr(context, 'statistics')),
    );
  }

  Widget _emptyChart(BuildContext context) {
    return Container(
      height: 200,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        L.tr(context, 'statsNoData'),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
            ),
      ),
    );
  }
}

/// Bar chart with a custom animated tooltip that fades+scales in/out
/// smoothly instead of the default fl_chart tooltip which pops abruptly.
class _BarChartWithTooltip extends StatefulWidget {
  final List<int> values;
  final List<Color> colors;
  final List<String> labels;

  const _BarChartWithTooltip({
    required this.values,
    required this.colors,
    required this.labels,
  });

  @override
  State<_BarChartWithTooltip> createState() => _BarChartWithTooltipState();
}

class _BarChartWithTooltipState extends State<_BarChartWithTooltip> {
  int? _touched;
  int? _previousTouched;

  void _onTouch(FlTouchEvent event, BarTouchResponse? response) {
    if (!event.isInterestedForInteractions ||
        response?.spot == null ||
        event is FlPanEndEvent ||
        event is FlPanCancelEvent) {
      if (_touched != null) {
        setState(() {
          _previousTouched = _touched;
          _touched = null;
        });
        Future.delayed(const Duration(milliseconds: 240), () {
          if (mounted && _touched == null) {
            setState(() => _previousTouched = null);
          }
        });
      }
      return;
    }
    final group = response!.spot!.touchedBarGroupIndex;
    if (group != _touched) {
      setState(() {
        _touched = group;
        _previousTouched = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxV = (List.from(widget.values)..add(1))
            .reduce((a, b) => a > b ? a : b) +
        1;
    final n = widget.values.length;

    return LayoutBuilder(
      builder: (ctx, cons) {
        final w = cons.maxWidth;
        final cellW = w / n;
        return Stack(
          children: [
            BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxV.toDouble(),
                barGroups: List.generate(n,
                    (i) => _buildBar(i, widget.values[i], widget.colors[i])),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= n) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(widget.labels[i],
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall),
                        );
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(
                  handleBuiltInTouches: false,
                  touchCallback: _onTouch,
                ),
              ),
            ),
            // Animated tooltip
            if (_touched != null || _previousTouched != null)
              Positioned(
                left: ((_touched ?? _previousTouched!) + 0.5) * cellW - 32,
                top: 8,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  opacity: _touched != null ? 1.0 : 0.0,
                  child: AnimatedScale(
                    scale: _touched != null ? 1.0 : 0.7,
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutBack,
                    child: Container(
                      width: 64,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: scheme.inverseSurface,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: scheme.shadow.withValues(alpha: 0.15),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '${widget.values[_touched ?? _previousTouched!]}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: scheme.onInverseSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  BarChartGroupData _buildBar(int x, int value, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: value.toDouble(),
          color: color,
          width: 26,
          borderRadius: BorderRadius.circular(8),
        ),
      ],
    );
  }
}

int? _parseMin(String? v) {
  if (v == null) return null;
  final parts = v.split(':');
  if (parts.length < 2) return null;
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

class _TrackingSection extends StatefulWidget {
  final List<JournalEntry> entries;

  const _TrackingSection({required this.entries});

  @override
  State<_TrackingSection> createState() => _TrackingSectionState();
}

class _TrackingSectionState extends State<_TrackingSection> {
  int? _steps;
  bool _stepsError = false;
  StreamSubscription<int>? _sub;
  bool _stepsEnabled = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final enabled = SettingsProvider.of(context).settings.stepsEnabled;
    if (enabled && !_stepsEnabled) {
      _stepsEnabled = true;
      _initSteps();
    } else if (!enabled && _stepsEnabled) {
      _stepsEnabled = false;
      _sub?.cancel();
      _sub = null;
      setState(() {
        _steps = null;
        _stepsError = false;
      });
    }
  }

  void _initSteps() {
    try {
      _sub = StepsService.stream.listen(
        (s) => setState(() => _steps = s),
        onError: (_) => setState(() => _stepsError = true),
      );
    } catch (_) {
      setState(() => _stepsError = true);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final water =
        widget.entries.where((e) => e.waterLiters != null).toList();
    final fasting = widget.entries
        .where((e) => e.fastingStart != null && e.fastingEnd != null)
        .toList();
    final stepsEnabled =
        SettingsProvider.of(context).settings.stepsEnabled;

    final children = <Widget>[];

    if (water.isNotEmpty) {
      final total = water.fold<double>(
        0,
        (a, e) => a + (e.waterLiters ?? 0),
      );
      final avg = total / water.length;
      children.addAll([
        Text(
          L.tr(context, 'waterStats'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _SummaryCard(
              icon: Icons.water_drop_rounded,
              color: AppAccents.sky,
              value: total.toInt(),
              label: '${L.tr(context, 'water')} ∑',
            ),
            const SizedBox(width: 12),
            _SummaryCard(
              icon: Icons.show_chart_rounded,
              color: AppAccents.teal,
              value: avg.toInt(),
              label: '${L.tr(context, 'water')} / ${L.tr(context, 'catAll').toLowerCase()}',
            ),
          ],
        ),
      ]);
    }

    if (fasting.isNotEmpty) {
      final durations = fasting.map((e) {
        final a = _parseMin(e.fastingStart) ?? 0;
        final b = _parseMin(e.fastingEnd) ?? 0;
        var d = b - a;
        if (d < 0) d += 24 * 60;
        return d;
      }).toList();
      final avgF = durations.fold(0, (a, b) => a + b) / durations.length;
      children.addAll([
        if (children.isNotEmpty) const SizedBox(height: 22),
        Text(
          L.tr(context, 'expFasting'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _SummaryCard(
              icon: Icons.timer_rounded,
              color: AppAccents.clay,
              value: fasting.length,
              label: L.tr(context, 'fastingWindow'),
            ),
            const SizedBox(width: 12),
            _SummaryCard(
              icon: Icons.schedule_rounded,
              color: AppAccents.amber,
              value: avgF ~/ 60,
              label: '${L.tr(context, 'fasting')} ч',
            ),
          ],
        ),
      ]);
    }

    if (stepsEnabled) {
      children.addAll([
        if (children.isNotEmpty) const SizedBox(height: 22),
        Text(
          L.tr(context, 'expSteps'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () {
            AnimatedSnack.show(
              context,
              '${L.tr(context, 'comingSoon')} 💖',
              type: SnackType.info,
            );
          },
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppAccents.sage.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.directions_walk_rounded,
                    color: AppAccents.sage,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _stepsError
                      ? Text(L.tr(context, 'stepsNotSupported'))
                      : Text(
                          _steps == null
                              ? L.tr(context, 'stepsToday')
                              : '${L.tr(context, 'stepsToday')}: $_steps',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                ),
                const Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: AppAccents.sage,
                ),
              ],
            ),
          ),
        ),
      ]);
    }

    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int value;
  final String label;

  const _SummaryCard({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.2),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value.toString(),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      // Tabular figures: the digits never jitter as the
                      // counters change between months.
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarHeatmap extends StatefulWidget {
  final DateTime focusedMonth;
  final Map<DateTime, int> counts;
  final int maxCount;
  final ValueChanged<DateTime> onMonthChanged;

  const _CalendarHeatmap({
    required this.focusedMonth,
    required this.counts,
    required this.maxCount,
    required this.onMonthChanged,
  });

  @override
  State<_CalendarHeatmap> createState() => _CalendarHeatmapState();
}

class _CalendarHeatmapState extends State<_CalendarHeatmap> {
  // Direction of the month switch: +1 forward, -1 back. Used to slide the
  // grid in from the correct side when paging months.
  int _direction = 0;

  @override
  void didUpdateWidget(_CalendarHeatmap old) {
    super.didUpdateWidget(old);
    if (old.focusedMonth != widget.focusedMonth) {
      final delta = widget.focusedMonth.difference(old.focusedMonth);
      _direction = delta.inDays >= 28 ? 1 : -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final code = Localizations.localeOf(context).languageCode;
    final monthLabel = DateFormat('LLLL y', code).format(widget.focusedMonth);
    final f = widget.focusedMonth;
    final daysInMonth = DateTime(f.year, f.month + 1, 0).day;
    final firstWeekday = DateTime(f.year, f.month, 1).weekday; // 1=Mon

    // Fixed grid height: during the month switch the AnimatedSwitcher stacks
    // the old and new grids briefly — without a clamped height the ListView
    // re-lays out mid-transition and the top of the page visibly "sticks".
    final innerW = MediaQuery.of(context).size.width - 60 - 36;
    final cell = innerW / 7;
    final rows = ((firstWeekday - 1 + daysInMonth) / 7).ceil();
    final gridH = rows * cell + (rows - 1) * 6;

    final cells = <Widget>[];
    for (var i = 1; i < firstWeekday; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var d = 1; d <= daysInMonth; d++) {
      final day = DateTime(f.year, f.month, d);
      final count = widget.counts[day] ?? 0;
      final intensity =
          widget.maxCount > 0 ? count / widget.maxCount : 0.0;
      final bg = count == 0
          ? scheme.surfaceContainerHighest
          : scheme.primary.withValues(
              alpha: 0.2 + 0.8 * intensity,
            );
      cells.add(
        Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              d.toString(),
              style: TextStyle(
                fontSize: 12,
                color: count == 0
                    ? scheme.onSurface.withValues(alpha: 0.5)
                    : scheme.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    // Localised weekday headers (Пн/Вт/…, Mon/Tue/…, Lun/Mar/…).
    final weekDays = List.generate(7, (i) {
      final wd = DateTime(2024, 1, 1 + i); // 2024-01-01 is a Monday
      return DateFormat('E', code).format(wd);
    });

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              PressableIconButton(
                size: 36,
                // Back is limited to January 2026.
                onPressed: f.isBefore(DateTime(2026, 2))
                    ? null
                    : () => widget.onMonthChanged(
                          DateTime(f.year, f.month - 1),
                        ),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              // Animated month title: fades/slides on page.
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) =>
                    FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: Offset(0.25 * _direction, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: Text(
                  monthLabel[0].toUpperCase() +
                      monthLabel.substring(1),
                  key: ValueKey(f),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              PressableIconButton(
                size: 36,
                // Forward is limited to December 2032.
                onPressed: f.isAfter(DateTime(2032, 11))
                    ? null
                    : () => widget.onMonthChanged(
                          DateTime(f.year, f.month + 1),
                        ),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Animated grid: the whole month slides+fades in the direction of
          // paging, instead of hard-swapping. Clamped to [gridH] so the
          // page never jumps during the transition.
          SizedBox(
            height: gridH,
            child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) =>
                FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: Offset(0.3 * _direction, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: GridView.count(
              key: ValueKey(f),
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1,
              children: [
                ...weekDays.map((w) => Center(
                      child: Text(
                        w,
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(
                              color: scheme.onSurface
                                  .withValues(alpha: 0.5),
                            ),
                      ),
                    )),
                ...cells,
              ],
            ),
            ),
          ),
        ],
      ),
    );
  }
}
