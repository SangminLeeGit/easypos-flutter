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

class DashboardMetric {
  final String businessDate;
  final String shopNo;
  final int grossAmount;
  final int receiptCount;
  final int customerCount;
  final int cardAmount;
  final int cashAmount;

  const DashboardMetric({
    required this.businessDate,
    required this.shopNo,
    required this.grossAmount,
    required this.receiptCount,
    required this.customerCount,
    required this.cardAmount,
    required this.cashAmount,
  });

  factory DashboardMetric.fromJson(Map<String, dynamic> json) {
    return DashboardMetric(
      businessDate: _asString(json['business_date']),
      shopNo: _asString(json['shop_no']),
      grossAmount: _asInt(json['gross_amount']),
      receiptCount: _asInt(json['receipt_count']),
      customerCount: _asInt(json['customer_count']),
      cardAmount: _asInt(json['card_amount']),
      cashAmount: _asInt(json['cash_amount']),
    );
  }
}

class SalesDaySummary {
  final String businessDate;
  final int grossAmount;
  final int pureSalesAmount;
  final int netAmount;
  final int vatAmount;
  final int discountAmount;
  final int receiptCount;
  final int customerCount;
  final int cardAmount;
  final int cashAmount;
  final int pointAmount;
  final int giftAmount;
  final int prepaidAmount;

  const SalesDaySummary({
    required this.businessDate,
    required this.grossAmount,
    required this.pureSalesAmount,
    required this.netAmount,
    required this.vatAmount,
    required this.discountAmount,
    required this.receiptCount,
    required this.customerCount,
    required this.cardAmount,
    required this.cashAmount,
    required this.pointAmount,
    required this.giftAmount,
    required this.prepaidAmount,
  });

  factory SalesDaySummary.fromJson(Map<String, dynamic> json) {
    return SalesDaySummary(
      businessDate: _asString(json['business_date']),
      grossAmount: _asInt(json['gross_amount']),
      pureSalesAmount: _asInt(json['pure_sales_amount']),
      netAmount: _asInt(json['net_amount']),
      vatAmount: _asInt(json['vat_amount']),
      discountAmount: _asInt(json['discount_amount']),
      receiptCount: _asInt(json['receipt_count']),
      customerCount: _asInt(json['customer_count']),
      cardAmount: _asInt(json['card_amount']),
      cashAmount: _asInt(json['cash_amount']),
      pointAmount: _asInt(json['point_amount']),
      giftAmount: _asInt(json['gift_amount']),
      prepaidAmount: _asInt(json['prepaid_amount']),
    );
  }
}

class TopItemSummary {
  final String itemName;
  final String itemCode;
  final int totalQty;
  final int totalAmount;
  final int lineCount;
  final int totalDiscount;

  const TopItemSummary({
    required this.itemName,
    required this.itemCode,
    required this.totalQty,
    required this.totalAmount,
    required this.lineCount,
    this.totalDiscount = 0,
  });

  factory TopItemSummary.fromJson(Map<String, dynamic> json) {
    return TopItemSummary(
      itemName: _asString(json['item_name']),
      itemCode: _asString(json['item_code']),
      totalQty: _asInt(json['total_qty']),
      totalAmount: _asInt(json['total_amount']),
      lineCount: _asInt(json['line_count']),
      totalDiscount: _asInt(json['total_discount']),
    );
  }
}

class PaymentMixItem {
  final String method;
  final int amount;
  final double pct;

  const PaymentMixItem({
    required this.method,
    required this.amount,
    required this.pct,
  });

  factory PaymentMixItem.fromJson(Map<String, dynamic> json) {
    return PaymentMixItem(
      method: _asString(json['method']),
      amount: _asInt(json['amount']),
      pct: _asDouble(json['pct']),
    );
  }
}

class TrendItem {
  final String itemName;
  final int currentAmount;
  final int previousAmount;
  final int delta;

  const TrendItem({
    required this.itemName,
    required this.currentAmount,
    required this.previousAmount,
    required this.delta,
  });

  factory TrendItem.fromJson(Map<String, dynamic> json) {
    return TrendItem(
      itemName: _asString(json['item_name']),
      currentAmount: _asInt(json['cur_amt']),
      previousAmount: _asInt(json['prev_amt']),
      delta: _asInt(json['delta']),
    );
  }
}

class SyncRun {
  final String targetDate;
  final String status;
  final int sourceCount;
  final int loadedCount;
  final String startedAt;
  final String finishedAt;

  const SyncRun({
    required this.targetDate,
    required this.status,
    required this.sourceCount,
    required this.loadedCount,
    required this.startedAt,
    required this.finishedAt,
  });

  factory SyncRun.fromJson(Map<String, dynamic> json) {
    return SyncRun(
      targetDate: _asString(json['target_date']),
      status: _asString(json['status']),
      sourceCount: _asInt(json['source_count']),
      loadedCount: _asInt(json['loaded_count']),
      startedAt: _asString(json['started_at']),
      finishedAt: _asString(json['finished_at']),
    );
  }
}

class DashboardSnapshot {
  final bool dbAvailable;
  final String error;
  final String? latestDay;
  final DashboardMetric latestMetrics;
  final List<SalesDaySummary> recentDays;
  final List<SyncRun> recentRuns;
  final List<TopItemSummary> topItems;
  final List<PaymentMixItem> paymentMix;
  final List<TrendItem> growers;
  final List<TrendItem> decliners;
  final int weekThis;
  final int weekPrev;
  final int avgTicket;
  final int prevAvgTicket;

  const DashboardSnapshot({
    required this.dbAvailable,
    required this.error,
    required this.latestDay,
    required this.latestMetrics,
    required this.recentDays,
    required this.recentRuns,
    required this.topItems,
    required this.paymentMix,
    required this.growers,
    required this.decliners,
    required this.weekThis,
    required this.weekPrev,
    required this.avgTicket,
    required this.prevAvgTicket,
  });

  factory DashboardSnapshot.fromJson(Map<String, dynamic> json) {
    return DashboardSnapshot(
      dbAvailable: json['db_available'] == true,
      error: _asString(json['error']),
      latestDay: _nullableString(json['latest_day']),
      latestMetrics: DashboardMetric.fromJson(_asMap(json['latest_metrics'])),
      recentDays: _asListOfMaps(json['recent_days'])
          .map(SalesDaySummary.fromJson)
          .toList(growable: false),
      recentRuns: _asListOfMaps(json['recent_runs'])
          .map(SyncRun.fromJson)
          .toList(growable: false),
      topItems: _asListOfMaps(json['top_items'])
          .map(TopItemSummary.fromJson)
          .toList(growable: false),
      paymentMix: _asListOfMaps(json['payment_mix'])
          .map(PaymentMixItem.fromJson)
          .toList(growable: false),
      growers: _asListOfMaps(json['growers'])
          .map(TrendItem.fromJson)
          .toList(growable: false),
      decliners: _asListOfMaps(json['decliners'])
          .map(TrendItem.fromJson)
          .toList(growable: false),
      weekThis: _asInt(json['week_this']),
      weekPrev: _asInt(json['week_prev']),
      avgTicket: _asInt(json['avg_ticket']),
      prevAvgTicket: _asInt(json['prev_avg_ticket']),
    );
  }
}

class DaySummary {
  final int grossAmount;
  final int pureSalesAmount;
  final int netAmount;
  final int vatAmount;
  final int discountAmount;
  final int receiptCount;
  final int customerCount;
  final int cashAmount;
  final int cardAmount;
  final int pointAmount;
  final int giftAmount;
  final int prepaidAmount;

  const DaySummary({
    required this.grossAmount,
    required this.pureSalesAmount,
    required this.netAmount,
    required this.vatAmount,
    required this.discountAmount,
    required this.receiptCount,
    required this.customerCount,
    required this.cashAmount,
    required this.cardAmount,
    required this.pointAmount,
    required this.giftAmount,
    required this.prepaidAmount,
  });

  factory DaySummary.fromJson(Map<String, dynamic> json) {
    return DaySummary(
      grossAmount: _asInt(json['gross_amount']),
      pureSalesAmount: _asInt(json['pure_sales_amount']),
      netAmount: _asInt(json['net_amount']),
      vatAmount: _asInt(json['vat_amount']),
      discountAmount: _asInt(json['discount_amount']),
      receiptCount: _asInt(json['receipt_count']),
      customerCount: _asInt(json['customer_count']),
      cashAmount: _asInt(json['cash_amount']),
      cardAmount: _asInt(json['card_amount']),
      pointAmount: _asInt(json['point_amount']),
      giftAmount: _asInt(json['gift_amount']),
      prepaidAmount: _asInt(json['prepaid_amount']),
    );
  }
}

class HourlySalesPoint {
  final String hour;
  final int billCount;
  final int totalAmount;
  final int totalCustomers;

  const HourlySalesPoint({
    required this.hour,
    required this.billCount,
    required this.totalAmount,
    required this.totalCustomers,
  });

  factory HourlySalesPoint.fromJson(Map<String, dynamic> json) {
    return HourlySalesPoint(
      hour: _asString(json['hour']),
      billCount: _asInt(json['bill_count']),
      totalAmount: _asInt(json['total_amount']),
      totalCustomers: _asInt(json['total_customers']),
    );
  }
}

class PosBreakdown {
  final String posNo;
  final int billCount;
  final int totalAmount;
  final int totalCustomers;

  const PosBreakdown({
    required this.posNo,
    required this.billCount,
    required this.totalAmount,
    required this.totalCustomers,
  });

  factory PosBreakdown.fromJson(Map<String, dynamic> json) {
    return PosBreakdown(
      posNo: _asString(json['pos_no']),
      billCount: _asInt(json['bill_count']),
      totalAmount: _asInt(json['total_amount']),
      totalCustomers: _asInt(json['total_customers']),
    );
  }
}

class BillRecord {
  final String posNo;
  final String billNo;
  final String payTime;
  final String saleFlag;
  final String saleType;
  final int grossAmount;
  final int pureSalesAmount;
  final int discountAmount;
  final int customerCount;
  final int itemCount;

  const BillRecord({
    required this.posNo,
    required this.billNo,
    required this.payTime,
    required this.saleFlag,
    required this.saleType,
    required this.grossAmount,
    required this.pureSalesAmount,
    required this.discountAmount,
    required this.customerCount,
    required this.itemCount,
  });

  String get formattedPayTime {
    if (payTime.length < 4) {
      return payTime;
    }
    return '${payTime.substring(0, 2)}:${payTime.substring(2, 4)}';
  }

  factory BillRecord.fromJson(Map<String, dynamic> json) {
    return BillRecord(
      posNo: _asString(json['pos_no']),
      billNo: _asString(json['bill_no']),
      payTime: _asString(json['pay_time']),
      saleFlag: _asString(json['sale_flag']),
      saleType: _asString(json['sale_type']),
      grossAmount: _asInt(json['gross_amount']),
      pureSalesAmount: _asInt(json['pure_sales_amount']),
      discountAmount: _asInt(json['discount_amount']),
      customerCount: _asInt(json['customer_count']),
      itemCount: _asInt(json['item_count']),
    );
  }
}

class DayDetailData {
  final String error;
  final String date;
  final DaySummary summary;
  final List<TopItemSummary> topItems;
  final List<PaymentMixItem> paymentMix;
  final List<HourlySalesPoint> hourlySales;
  final List<PosBreakdown> posBreakdown;
  final List<BillRecord> bills;
  final String? prevDate;
  final String? nextDate;

  const DayDetailData({
    required this.error,
    required this.date,
    required this.summary,
    required this.topItems,
    required this.paymentMix,
    required this.hourlySales,
    required this.posBreakdown,
    required this.bills,
    required this.prevDate,
    required this.nextDate,
  });

  factory DayDetailData.fromJson(Map<String, dynamic> json) {
    return DayDetailData(
      error: _asString(json['error']),
      date: _asString(json['date']),
      summary: DaySummary.fromJson(_asMap(json['summary'])),
      topItems: _asListOfMaps(json['top_items'])
          .map(TopItemSummary.fromJson)
          .toList(growable: false),
      paymentMix: _asListOfMaps(json['payment_mix'])
          .map(PaymentMixItem.fromJson)
          .toList(growable: false),
      hourlySales: _asListOfMaps(json['hourly_sales'])
          .map(HourlySalesPoint.fromJson)
          .toList(growable: false),
      posBreakdown: _asListOfMaps(json['pos_breakdown'])
          .map(PosBreakdown.fromJson)
          .toList(growable: false),
      bills: _asListOfMaps(json['bills'])
          .map(BillRecord.fromJson)
          .toList(growable: false),
      prevDate: _nullableString(json['prev_date']),
      nextDate: _nullableString(json['next_date']),
    );
  }
}

class SyncRunsData {
  final List<SyncRun> runs;
  final String today;
  final String error;

  const SyncRunsData({
    required this.runs,
    required this.today,
    required this.error,
  });

  factory SyncRunsData.fromJson(Map<String, dynamic> json) {
    return SyncRunsData(
      runs: _asListOfMaps(json['runs'])
          .map(SyncRun.fromJson)
          .toList(growable: false),
      today: _asString(json['today']),
      error: _asString(json['error']),
    );
  }
}

class SyncTaskStatusData {
  final String taskId;
  final String targetDate;
  final String status;
  final String errorMessage;
  final int headerCount;
  final int itemCount;
  final int summaryCount;
  final int loadedCount;
  final String startedAt;
  final String finishedAt;

  const SyncTaskStatusData({
    required this.taskId,
    required this.targetDate,
    required this.status,
    required this.errorMessage,
    required this.headerCount,
    required this.itemCount,
    required this.summaryCount,
    required this.loadedCount,
    required this.startedAt,
    required this.finishedAt,
  });

  bool get isRunning => status == 'pending' || status == 'running';
  bool get isFinished => status == 'succeeded' || status == 'failed';
  bool get isSuccessful => status == 'succeeded';

  factory SyncTaskStatusData.fromJson(Map<String, dynamic> json) {
    final task = _asMap(json['task']);
    return SyncTaskStatusData(
      taskId: _asString(task['task_id']),
      targetDate: _asString(task['target_date']),
      status: _asString(task['status']),
      errorMessage: _asString(task['error_message']),
      headerCount: _asInt(task['header_count']),
      itemCount: _asInt(task['item_count']),
      summaryCount: _asInt(task['summary_count']),
      loadedCount: _asInt(task['loaded_count']),
      startedAt: _asString(task['started_at']),
      finishedAt: _asString(task['finished_at']),
    );
  }
}

class SidebarDay {
  final String businessDate;
  final int grossAmount;

  const SidebarDay({
    required this.businessDate,
    required this.grossAmount,
  });

  factory SidebarDay.fromJson(Map<String, dynamic> json) {
    return SidebarDay(
      businessDate: _asString(json['business_date']),
      grossAmount: _asInt(json['gross_amount']),
    );
  }
}

List<Map<String, dynamic>> _asListOfMaps(Object? source) {
  if (source is! List) {
    return const [];
  }

  return source
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

Map<String, dynamic> _asMap(Object? source) {
  if (source is Map) {
    return Map<String, dynamic>.from(source);
  }
  return const {};
}

String _asString(Object? value) {
  return value?.toString() ?? '';
}

String? _nullableString(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) {
    return null;
  }
  return text;
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

double _asDouble(Object? value) {
  if (value is double) {
    return value;
  }
  if (value is int) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value) ?? 0;
  }
  return 0;
}
