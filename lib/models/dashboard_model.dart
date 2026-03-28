import 'package:intl/intl.dart';

class UiFormat {
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'ko_KR',
    symbol: '',
    decimalDigits: 0,
  );
  static final NumberFormat _numberFormat =
      NumberFormat.decimalPattern('ko_KR');
  static final DateFormat _dateTimeFormat = DateFormat('MM-dd HH:mm');
  static const List<String> _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  static String won(num? amount) {
    return '${_currencyFormat.format(amount ?? 0)}원';
  }

  static String number(num? value) {
    return _numberFormat.format(value ?? 0);
  }

  static String weekday(String date) {
    final parsed = DateTime.tryParse(date);
    if (parsed == null) {
      return date;
    }
    return '$date (${_weekdays[parsed.weekday - 1]})';
  }

  static String delta(num? current, num? previous) {
    final currentValue = (current ?? 0).toDouble();
    final previousValue = (previous ?? 0).toDouble();
    if (previousValue == 0) {
      return '비교 불가';
    }

    final pct = ((currentValue / previousValue) - 1) * 100;
    final sign = pct >= 0 ? '▲' : '▼';
    return '$sign ${pct.abs().toStringAsFixed(1)}%';
  }

  static String compactDateTime(String? value) {
    if (value == null || value.isEmpty) {
      return '-';
    }

    final parsed = DateTime.tryParse(value.replaceFirst(' ', 'T'));
    if (parsed == null) {
      return value;
    }
    return _dateTimeFormat.format(parsed);
  }
}

class DashboardSnapshot {
  final Map<String, dynamic> raw;

  DashboardSnapshot(this.raw);

  bool get dbAvailable => raw['db_available'] == true;

  String get error => (raw['error'] ?? '').toString();

  String? get latestDay => raw['latest_day']?.toString();

  Map<String, dynamic> get latestMetrics =>
      Map<String, dynamic>.from(raw['latest_metrics'] ?? const {});

  List<Map<String, dynamic>> get recentDays => _listOfMaps(raw['recent_days']);

  List<Map<String, dynamic>> get topItems => _listOfMaps(raw['top_items']);

  List<Map<String, dynamic>> get paymentMix => _listOfMaps(raw['payment_mix']);

  List<Map<String, dynamic>> get growers => _listOfMaps(raw['growers']);

  List<Map<String, dynamic>> get decliners => _listOfMaps(raw['decliners']);

  int get weekThis => _asInt(raw['week_this']);

  int get weekPrev => _asInt(raw['week_prev']);

  int get avgTicket => _asInt(raw['avg_ticket']);

  int get prevAvgTicket => _asInt(raw['prev_avg_ticket']);
}

class DayDetailData {
  final Map<String, dynamic> raw;

  DayDetailData(this.raw);

  String get error => (raw['error'] ?? '').toString();

  String get date => (raw['date'] ?? '').toString();

  Map<String, dynamic> get summary =>
      Map<String, dynamic>.from(raw['summary'] ?? const {});

  List<Map<String, dynamic>> get topItems => _listOfMaps(raw['top_items']);

  List<Map<String, dynamic>> get paymentMix => _listOfMaps(raw['payment_mix']);

  List<Map<String, dynamic>> get bills => _listOfMaps(raw['bills']);

  String? get prevDate => raw['prev_date']?.toString();

  String? get nextDate => raw['next_date']?.toString();
}

class SyncRunsData {
  final Map<String, dynamic> raw;

  SyncRunsData(this.raw);

  String get error => (raw['error'] ?? '').toString();

  List<Map<String, dynamic>> get runs => _listOfMaps(raw['runs']);
}

class SyncTaskStatusData {
  final Map<String, dynamic> raw;

  SyncTaskStatusData(this.raw);

  Map<String, dynamic> get task =>
      Map<String, dynamic>.from(raw['task'] ?? const {});

  String get status => (task['status'] ?? '').toString();
}

List<Map<String, dynamic>> _listOfMaps(Object? source) {
  if (source is! List) {
    return const [];
  }

  return source
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

int _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is double) {
    return value.round();
  }
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  return 0;
}
