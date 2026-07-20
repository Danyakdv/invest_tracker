import '../models/deposit.dart';
import '../models/purchase.dart';
import '../models/income.dart';
import 'storage_service.dart';

/// Фильтр периода для статистики
enum PeriodFilter { month1, month3, month6, year1, all }

class AnalyticsService {
  static DateTime? _periodStart(PeriodFilter f) {
    final now = DateTime.now();
    switch (f) {
      case PeriodFilter.month1:
        return DateTime(now.year, now.month - 1, now.day);
      case PeriodFilter.month3:
        return DateTime(now.year, now.month - 3, now.day);
      case PeriodFilter.month6:
        return DateTime(now.year, now.month - 6, now.day);
      case PeriodFilter.year1:
        return DateTime(now.year - 1, now.month, now.day);
      case PeriodFilter.all:
        return null;
    }
  }

  static List<Deposit> filterDeposits(PeriodFilter f, {String? currency}) {
    final start = _periodStart(f);
    return StorageService.deposits.where((d) {
      final okDate = start == null || d.date.isAfter(start);
      final okCur = currency == null || d.currency == currency;
      return okDate && okCur;
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  static List<Purchase> filterPurchases(PeriodFilter f,
      {AssetType? type, String? sector}) {
    final start = _periodStart(f);
    return StorageService.purchases.where((p) {
      final okDate = start == null || p.date.isAfter(start);
      final okType = type == null || p.type == type;
      final okSector = sector == null || p.sector == sector;
      return okDate && okType && okSector;
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  static List<Income> filterIncomes(PeriodFilter f, {IncomeType? type}) {
    final start = _periodStart(f);
    return StorageService.incomes.where((i) {
      final okDate = start == null || i.date.isAfter(start);
      final okType = type == null || i.type == type;
      return okDate && okType;
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Суммарно вложено (пополнения)
  static double totalDeposited({PeriodFilter f = PeriodFilter.all}) =>
      filterDeposits(f).fold(0.0, (s, d) => s + d.amount);

  /// Суммарно потрачено на покупки
  static double totalInvested({PeriodFilter f = PeriodFilter.all}) =>
      filterPurchases(f).fold(0.0, (s, p) => s + p.total);

  /// Суммарный доход (дивиденды + купоны), net
  static double totalIncome({PeriodFilter f = PeriodFilter.all}) =>
      filterIncomes(f).fold(0.0, (s, i) => s + i.amountNet);

  /// Портфель: сколько чего куплено (агрегация по тикеру)
  static Map<String, double> holdingsByTicker() {
    final map = <String, double>{};
    for (final p in StorageService.purchases) {
      map[p.ticker] = (map[p.ticker] ?? 0) + p.quantity;
    }
    return map;
  }

  /// Распределение вложений по типу актива (для круговой диаграммы)
  static Map<AssetType, double> investedByType({PeriodFilter f = PeriodFilter.all}) {
    final map = <AssetType, double>{};
    for (final p in filterPurchases(f)) {
      map[p.type] = (map[p.type] ?? 0) + p.total;
    }
    return map;
  }

  /// Распределение по секторам
  static Map<String, double> investedBySector({PeriodFilter f = PeriodFilter.all}) {
    final map = <String, double>{};
    for (final p in filterPurchases(f)) {
      final key = p.sector?.isNotEmpty == true ? p.sector! : 'Без сектора';
      map[key] = (map[key] ?? 0) + p.total;
    }
    return map;
  }

  /// Доход по месяцам (для столбчатого графика динамики дивидендов/купонов)
  static Map<String, double> incomeByMonth({PeriodFilter f = PeriodFilter.year1}) {
    final map = <String, double>{};
    for (final i in filterIncomes(f)) {
      final key = '${i.date.year}-${i.date.month.toString().padLeft(2, '0')}';
      map[key] = (map[key] ?? 0) + i.amountNet;
    }
    return map;
  }

  /// Динамика пополнений по месяцам
  static Map<String, double> depositsByMonth({PeriodFilter f = PeriodFilter.year1}) {
    final map = <String, double>{};
    for (final d in filterDeposits(f)) {
      final key = '${d.date.year}-${d.date.month.toString().padLeft(2, '0')}';
      map[key] = (map[key] ?? 0) + d.amount;
    }
    return map;
  }

  /// Кумулятивная сумма вложенного капитала по времени (для линии роста портфеля)
  static List<MapEntry<DateTime, double>> cumulativeInvested() {
    final all = [...StorageService.deposits.map((d) => MapEntry(d.date, d.amount))];
    all.sort((a, b) => a.key.compareTo(b.key));
    double running = 0;
    return all.map((e) {
      running += e.value;
      return MapEntry(e.key, running);
    }).toList();
  }
}
