import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/purchase.dart';
import '../services/analytics_service.dart';
import '../services/backup_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  PeriodFilter _period = PeriodFilter.all;

  String _periodLabel(PeriodFilter f) {
    switch (f) {
      case PeriodFilter.month1:
        return '1 мес';
      case PeriodFilter.month3:
        return '3 мес';
      case PeriodFilter.month6:
        return '6 мес';
      case PeriodFilter.year1:
        return '1 год';
      case PeriodFilter.all:
        return 'Всё время';
    }
  }

  String _assetTypeLabel(AssetType t) {
    switch (t) {
      case AssetType.stock:
        return 'Акции';
      case AssetType.bond:
        return 'Облигации';
      case AssetType.etf:
        return 'Фонды';
      case AssetType.currency:
        return 'Валюта';
      case AssetType.other:
        return 'Другое';
    }
  }

  final _pieColors = [
    Colors.teal,
    Colors.indigo,
    Colors.orange,
    Colors.purple,
    Colors.red,
    Colors.blueGrey,
    Colors.green,
    Colors.brown,
  ];

  @override
  Widget build(BuildContext context) {
    final deposited = AnalyticsService.totalDeposited(f: _period);
    final invested = AnalyticsService.totalInvested(f: _period);
    final income = AnalyticsService.totalIncome(f: _period);
    final byType = AnalyticsService.investedByType(f: _period);
    final bySector = AnalyticsService.investedBySector(f: _period);
    final incomeByMonth = AnalyticsService.incomeByMonth(f: _period == PeriodFilter.all ? PeriodFilter.year1 : _period);
    final cumulative = AnalyticsService.cumulativeInvested();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Статистика'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Экспорт бэкапа',
            onPressed: () async {
              await BackupService.exportToJson();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Фильтр периода
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: PeriodFilter.values
                  .map((f) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(_periodLabel(f)),
                          selected: _period == f,
                          onSelected: (_) => setState(() => _period = f),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Сводные карточки
          Row(
            children: [
              Expanded(child: _summaryCard('Внесено', deposited, Colors.blue)),
              const SizedBox(width: 8),
              Expanded(child: _summaryCard('Вложено', invested, Colors.teal)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _summaryCard('Доход', income, Colors.green)),
              const SizedBox(width: 8),
              Expanded(
                child: _summaryCard(
                  'Свободно',
                  deposited - invested,
                  Colors.orange,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Рост капитала — линейный график
          if (cumulative.length > 1) ...[
            const Text('Рост внесённого капитала', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                  titlesData: const FlTitlesData(
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (int i = 0; i < cumulative.length; i++)
                          FlSpot(i.toDouble(), cumulative[i].value),
                      ],
                      isCurved: true,
                      color: Theme.of(context).colorScheme.primary,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Распределение по типу актива — пирог
          if (byType.isNotEmpty) ...[
            const Text('Распределение по типу актива', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: Row(
                children: [
                  Expanded(
                    child: PieChart(
                      PieChartData(
                        sections: [
                          for (int i = 0; i < byType.length; i++)
                            PieChartSectionData(
                              value: byType.values.elementAt(i),
                              color: _pieColors[i % _pieColors.length],
                              title: '',
                              radius: 60,
                            ),
                        ],
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (int i = 0; i < byType.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                Container(width: 10, height: 10, color: _pieColors[i % _pieColors.length]),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${_assetTypeLabel(byType.keys.elementAt(i))}: ${byType.values.elementAt(i).toStringAsFixed(0)}',
                                    style: const TextStyle(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Распределение по секторам
          if (bySector.isNotEmpty) ...[
            const Text('Распределение по секторам', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: Row(
                children: [
                  Expanded(
                    child: PieChart(
                      PieChartData(
                        sections: [
                          for (int i = 0; i < bySector.length; i++)
                            PieChartSectionData(
                              value: bySector.values.elementAt(i),
                              color: _pieColors[(i + 3) % _pieColors.length],
                              title: '',
                              radius: 60,
                            ),
                        ],
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (int i = 0; i < bySector.length; i++)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  Container(width: 10, height: 10, color: _pieColors[(i + 3) % _pieColors.length]),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '${bySector.keys.elementAt(i)}: ${bySector.values.elementAt(i).toStringAsFixed(0)}',
                                      style: const TextStyle(fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Доход по месяцам — столбцы
          if (incomeByMonth.isNotEmpty) ...[
            const Text('Дивиденды и купоны по месяцам', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final keys = incomeByMonth.keys.toList();
                          final idx = value.toInt();
                          if (idx < 0 || idx >= keys.length) return const SizedBox.shrink();
                          final parts = keys[idx].split('-');
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(parts[1], style: const TextStyle(fontSize: 10)),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (int i = 0; i < incomeByMonth.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: incomeByMonth.values.elementAt(i),
                            color: Colors.green,
                            width: 14,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          if (deposited == 0 && invested == 0 && income == 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'Добавь первое пополнение, покупку или выплату,\nчтобы увидеть статистику',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _summaryCard(String title, double value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            const SizedBox(height: 4),
            Text(
              value.toStringAsFixed(0),
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
