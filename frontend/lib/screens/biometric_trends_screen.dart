import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/theme.dart';
import '../data/database_service.dart';
import '../models/biometric_record.dart';

class BiometricTrendsScreen extends StatelessWidget {
  const BiometricTrendsScreen({super.key});

  static const _metrics = [
    _Metric('Peso', 'kg', Colors.cyanAccent, _w),
    _Metric('Fianchi', 'cm', AppTheme.vividPurple, _h),
    _Metric('Petto', 'cm', AppTheme.pullAccent, _c),
    _Metric('Bicipite', 'cm', AppTheme.pushAccent, _b),
    _Metric('Vita', 'cm', Colors.orangeAccent, _wa),
    _Metric('Coscia', 'cm', AppTheme.legsAccent, _t),
    _Metric('Polpaccio', 'cm', Colors.greenAccent, _ca),
    _Metric('Collo', 'cm', Colors.pinkAccent, _n),
    _Metric('Polso', 'cm', Colors.amberAccent, _wr),
  ];

  static double? _w(BiometricRecord r)  => r.weight;
  static double? _h(BiometricRecord r)  => r.hips;
  static double? _c(BiometricRecord r)  => r.chest;
  static double? _b(BiometricRecord r)  => r.biceps;
  static double? _wa(BiometricRecord r) => r.waist;
  static double? _t(BiometricRecord r)  => r.thigh;
  static double? _ca(BiometricRecord r) => r.calf;
  static double? _n(BiometricRecord r)  => r.neck;
  static double? _wr(BiometricRecord r) => r.wrist;

  List<BiometricRecord> _sortedRecords() {
    final records = DatabaseService.getAllBiometricRecords();
    records.sort((a, b) => a.date.compareTo(b.date));
    return records;
  }

  @override
  Widget build(BuildContext context) {
    final records = _sortedRecords();

    return AppTheme.buildBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Trend Misure Corporee', style: TextStyle(color: AppTheme.textPrimary)),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: records.isEmpty
            ? const Center(
                child: Text(
                  'Nessuna misurazione registrata.\nAggiungi le tue misure dalla schermata Analisi.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _metrics.length,
                separatorBuilder: (_, __) => const SizedBox(height: 20),
                itemBuilder: (context, i) {
                  final m = _metrics[i];
                  final spots = _buildSpots(records, m.extractor);
                  if (spots.length < 2) return const SizedBox.shrink();
                  return _MetricCard(metric: m, spots: spots, records: records)
                      .animate()
                      .fadeIn(delay: Duration(milliseconds: i * 80))
                      .slideY(begin: 0.1);
                },
              ),
      ),
    );
  }

  List<FlSpot> _buildSpots(List<BiometricRecord> records, double? Function(BiometricRecord) fn) {
    final spots = <FlSpot>[];
    for (int i = 0; i < records.length; i++) {
      final v = fn(records[i]);
      if (v != null && v > 0) spots.add(FlSpot(i.toDouble(), v));
    }
    return spots;
  }
}

class _Metric {
  final String label;
  final String unit;
  final Color color;
  final double? Function(BiometricRecord) extractor;
  const _Metric(this.label, this.unit, this.color, this.extractor);
}

class _MetricCard extends StatelessWidget {
  final _Metric metric;
  final List<FlSpot> spots;
  final List<BiometricRecord> records;

  const _MetricCard({required this.metric, required this.spots, required this.records});

  String _dateLabel(int index) {
    if (index < 0 || index >= records.length) return '';
    final d = records[index].date;
    return '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}';
  }

  @override
  Widget build(BuildContext context) {
    final first = spots.first.y;
    final last  = spots.last.y;
    final delta = last - first;
    final deltaStr = delta >= 0 ? '+${delta.toStringAsFixed(1)}' : delta.toStringAsFixed(1);
    final deltaColor = delta < 0 ? Colors.greenAccent : (delta > 0 ? Colors.redAccent : Colors.white54);

    return AppTheme.glassContainer(
      padding: const EdgeInsets.all(16),
      borderColor: metric.color.withOpacity(0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(metric.label,
                  style: TextStyle(color: metric.color, fontWeight: FontWeight.bold, fontSize: 16)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${last.toStringAsFixed(1)} ${metric.unit}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  Text('$deltaStr ${metric.unit}',
                      style: TextStyle(color: deltaColor, fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: Colors.white10, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (v, _) => Text(
                        v.toStringAsFixed(1),
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (v, _) {
                        final idx = v.toInt();
                        if (idx == spots.first.x.toInt() || idx == spots.last.x.toInt()) {
                          return Text(_dateLabel(idx),
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9));
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                      '${s.y.toStringAsFixed(1)} ${metric.unit}\n${_dateLabel(s.x.toInt())}',
                      TextStyle(color: metric.color, fontSize: 11),
                    )).toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: metric.color,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                        radius: 3,
                        color: metric.color,
                        strokeWidth: 0,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [metric.color.withOpacity(0.25), metric.color.withOpacity(0.0)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
