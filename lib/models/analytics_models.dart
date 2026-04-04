class MonthlyDayRecord {
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

  const MonthlyDayRecord({
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

  factory MonthlyDayRecord.fromJson(Map<String, dynamic> json) {
    return MonthlyDayRecord(
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

class MonthlyTotals {
  final int gross;
  final int pureSales;
  final int net;
  final int vat;
  final int discount;
  final int receipts;
  final int customers;
  final int card;
  final int cash;
  final int avgTicket;

  const MonthlyTotals({
    required this.gross,
    required this.pureSales,
    required this.net,
    required this.vat,
    required this.discount,
    required this.receipts,
    required this.customers,
    required this.card,
    required this.cash,
    required this.avgTicket,
  });

  factory MonthlyTotals.fromJson(Map<String, dynamic> json) {
    return MonthlyTotals(
      gross: _asInt(json['gross']),
      pureSales: _asInt(json['pure_sales']),
      net: _asInt(json['net']),
      vat: _asInt(json['vat']),
      discount: _asInt(json['discount']),
      receipts: _asInt(json['receipts']),
      customers: _asInt(json['customers']),
      card: _asInt(json['card']),
      cash: _asInt(json['cash']),
      avgTicket: _asInt(json['avg_ticket']),
    );
  }
}

class AnalyticsTopItem {
  final String itemName;
  final String itemCode;
  final int totalQty;
  final int totalAmount;
  final int lineCount;
  final int totalDiscount;
  final int daysSold;
  final double pct;
  final String abc;

  const AnalyticsTopItem({
    required this.itemName,
    required this.itemCode,
    required this.totalQty,
    required this.totalAmount,
    required this.lineCount,
    this.totalDiscount = 0,
    this.daysSold = 0,
    this.pct = 0,
    this.abc = '',
  });

  factory AnalyticsTopItem.fromJson(Map<String, dynamic> json) {
    return AnalyticsTopItem(
      itemName: _asString(json['item_name']),
      itemCode: _asString(json['item_code']),
      totalQty: _asInt(json['total_qty']),
      totalAmount: _asInt(json['total_amount']),
      lineCount: _asInt(json['line_count']),
      totalDiscount: _asInt(json['total_discount']),
      daysSold: _asInt(json['days_sold']),
      pct: _asDouble(json['pct']),
      abc: _asString(json['abc']),
    );
  }
}

class MonthlyReportData {
  final String error;
  final int year;
  final int month;
  final List<MonthlyDayRecord> days;
  final MonthlyTotals totals;
  final List<AnalyticsTopItem> topItems;

  const MonthlyReportData({
    required this.error,
    required this.year,
    required this.month,
    required this.days,
    required this.totals,
    required this.topItems,
  });

  factory MonthlyReportData.fromJson(Map<String, dynamic> json) {
    return MonthlyReportData(
      error: _asString(json['error']),
      year: _asInt(json['year']),
      month: _asInt(json['month']),
      days: _asListOfMaps(json['days'])
          .map(MonthlyDayRecord.fromJson)
          .toList(growable: false),
      totals: MonthlyTotals.fromJson(_asMap(json['totals'])),
      topItems: _asListOfMaps(json['top_items'])
          .map(AnalyticsTopItem.fromJson)
          .toList(growable: false),
    );
  }
}

class ItemAnalysisData {
  final String error;
  final String fromDate;
  final String toDate;
  final List<AnalyticsTopItem> itemList;
  final int grandTotal;

  const ItemAnalysisData({
    required this.error,
    required this.fromDate,
    required this.toDate,
    required this.itemList,
    required this.grandTotal,
  });

  factory ItemAnalysisData.fromJson(Map<String, dynamic> json) {
    return ItemAnalysisData(
      error: _asString(json['error']),
      fromDate: _asString(json['from_date']),
      toDate: _asString(json['to_date']),
      itemList: _asListOfMaps(json['item_list'])
          .map(AnalyticsTopItem.fromJson)
          .toList(growable: false),
      grandTotal: _asInt(json['grand_total']),
    );
  }
}

class HourlyHeatmapCell {
  final int dow;
  final String hour;
  final int billCount;
  final int totalAmount;
  final int totalCustomers;

  const HourlyHeatmapCell({
    required this.dow,
    required this.hour,
    required this.billCount,
    required this.totalAmount,
    required this.totalCustomers,
  });

  factory HourlyHeatmapCell.fromJson(Map<String, dynamic> json) {
    return HourlyHeatmapCell(
      dow: _asInt(json['dow']),
      hour: _asString(json['hour']),
      billCount: _asInt(json['bill_count']),
      totalAmount: _asInt(json['total_amount']),
      totalCustomers: _asInt(json['total_customers']),
    );
  }
}

class HourlyTotal {
  final String hour;
  final int billCount;
  final int totalAmount;
  final int totalCustomers;

  const HourlyTotal({
    required this.hour,
    required this.billCount,
    required this.totalAmount,
    required this.totalCustomers,
  });

  factory HourlyTotal.fromJson(Map<String, dynamic> json) {
    return HourlyTotal(
      hour: _asString(json['hour']),
      billCount: _asInt(json['bill_count']),
      totalAmount: _asInt(json['total_amount']),
      totalCustomers: _asInt(json['total_customers']),
    );
  }
}

class HourlyAnalysisData {
  final String error;
  final String fromDate;
  final String toDate;
  final List<HourlyHeatmapCell> heatmap;
  final List<HourlyTotal> hourlyTotals;
  final int avgAmount;
  final int stdAmount;

  const HourlyAnalysisData({
    required this.error,
    required this.fromDate,
    required this.toDate,
    required this.heatmap,
    required this.hourlyTotals,
    required this.avgAmount,
    required this.stdAmount,
  });

  factory HourlyAnalysisData.fromJson(Map<String, dynamic> json) {
    return HourlyAnalysisData(
      error: _asString(json['error']),
      fromDate: _asString(json['from_date']),
      toDate: _asString(json['to_date']),
      heatmap: _asListOfMaps(json['heatmap'])
          .map(HourlyHeatmapCell.fromJson)
          .toList(growable: false),
      hourlyTotals: _asListOfMaps(json['hourly_totals'])
          .map(HourlyTotal.fromJson)
          .toList(growable: false),
      avgAmount: _asInt(json['avg_amount']),
      stdAmount: _asInt(json['std_amount']),
    );
  }
}

class WeekdayAnalysisRow {
  final int dow;
  final String name;
  final int dayCount;
  final int totalAmount;
  final int avgAmount;
  final int totalReceipts;
  final int avgReceipts;
  final int totalCustomers;
  final int avgCustomers;
  final int avgTicket;

  const WeekdayAnalysisRow({
    required this.dow,
    required this.name,
    required this.dayCount,
    required this.totalAmount,
    required this.avgAmount,
    required this.totalReceipts,
    required this.avgReceipts,
    required this.totalCustomers,
    required this.avgCustomers,
    required this.avgTicket,
  });

  factory WeekdayAnalysisRow.fromJson(Map<String, dynamic> json) {
    return WeekdayAnalysisRow(
      dow: _asInt(json['dow']),
      name: _asString(json['name']),
      dayCount: _asInt(json['day_count']),
      totalAmount: _asInt(json['total_amount']),
      avgAmount: _asInt(json['avg_amount']),
      totalReceipts: _asInt(json['total_receipts']),
      avgReceipts: _asInt(json['avg_receipts']),
      totalCustomers: _asInt(json['total_customers']),
      avgCustomers: _asInt(json['avg_customers']),
      avgTicket: _asInt(json['avg_ticket']),
    );
  }
}

class WeekdayAnalysisData {
  final String error;
  final String fromDate;
  final String toDate;
  final List<WeekdayAnalysisRow> rows;
  final int weekdayAvg;
  final int weekendAvg;

  const WeekdayAnalysisData({
    required this.error,
    required this.fromDate,
    required this.toDate,
    required this.rows,
    required this.weekdayAvg,
    required this.weekendAvg,
  });

  factory WeekdayAnalysisData.fromJson(Map<String, dynamic> json) {
    return WeekdayAnalysisData(
      error: _asString(json['error']),
      fromDate: _asString(json['from_date']),
      toDate: _asString(json['to_date']),
      rows: _asListOfMaps(json['rows'])
          .map(WeekdayAnalysisRow.fromJson)
          .toList(growable: false),
      weekdayAvg: _asInt(json['weekday_avg']),
      weekendAvg: _asInt(json['weekend_avg']),
    );
  }
}

class PaymentDayRecord {
  final String businessDate;
  final int grossAmount;
  final int cardAmount;
  final int cashAmount;
  final int pointAmount;
  final int giftAmount;
  final int prepaidAmount;
  final int receiptCount;
  final int customerCount;

  const PaymentDayRecord({
    required this.businessDate,
    required this.grossAmount,
    required this.cardAmount,
    required this.cashAmount,
    required this.pointAmount,
    required this.giftAmount,
    required this.prepaidAmount,
    required this.receiptCount,
    required this.customerCount,
  });

  factory PaymentDayRecord.fromJson(Map<String, dynamic> json) {
    return PaymentDayRecord(
      businessDate: _asString(json['business_date']),
      grossAmount: _asInt(json['gross_amount']),
      cardAmount: _asInt(json['card_amount']),
      cashAmount: _asInt(json['cash_amount']),
      pointAmount: _asInt(json['point_amount']),
      giftAmount: _asInt(json['gift_amount']),
      prepaidAmount: _asInt(json['prepaid_amount']),
      receiptCount: _asInt(json['receipt_count']),
      customerCount: _asInt(json['customer_count']),
    );
  }
}

class PaymentTotals {
  final int gross;
  final int card;
  final int cash;
  final int point;
  final int gift;
  final int prepaid;
  final int receipts;

  const PaymentTotals({
    required this.gross,
    required this.card,
    required this.cash,
    required this.point,
    required this.gift,
    required this.prepaid,
    required this.receipts,
  });

  factory PaymentTotals.fromJson(Map<String, dynamic> json) {
    return PaymentTotals(
      gross: _asInt(json['gross']),
      card: _asInt(json['card']),
      cash: _asInt(json['cash']),
      point: _asInt(json['point']),
      gift: _asInt(json['gift']),
      prepaid: _asInt(json['prepaid']),
      receipts: _asInt(json['receipts']),
    );
  }
}

class MethodTicket {
  final String method;
  final int count;
  final int avgTicket;

  const MethodTicket({
    required this.method,
    required this.count,
    required this.avgTicket,
  });

  factory MethodTicket.fromJson(Map<String, dynamic> json) {
    return MethodTicket(
      method: _asString(json['method']),
      count: _asInt(json['cnt']),
      avgTicket: _asInt(json['avg_ticket']),
    );
  }
}

class PaymentAnalysisData {
  final String error;
  final String fromDate;
  final String toDate;
  final List<PaymentDayRecord> days;
  final PaymentTotals totals;
  final List<MethodTicket> methodTickets;

  const PaymentAnalysisData({
    required this.error,
    required this.fromDate,
    required this.toDate,
    required this.days,
    required this.totals,
    required this.methodTickets,
  });

  factory PaymentAnalysisData.fromJson(Map<String, dynamic> json) {
    return PaymentAnalysisData(
      error: _asString(json['error']),
      fromDate: _asString(json['from_date']),
      toDate: _asString(json['to_date']),
      days: _asListOfMaps(json['days'])
          .map(PaymentDayRecord.fromJson)
          .toList(growable: false),
      totals: PaymentTotals.fromJson(_asMap(json['totals'])),
      methodTickets: _asListOfMaps(json['method_tickets'])
          .map(MethodTicket.fromJson)
          .toList(growable: false),
    );
  }
}

class CompareRangeStats {
  final String from;
  final String to;
  final List<MonthlyDayRecord> days;
  final int gross;
  final int receipts;
  final int customers;
  final int avgTicket;
  final List<AnalyticsTopItem> topItems;

  const CompareRangeStats({
    required this.from,
    required this.to,
    required this.days,
    required this.gross,
    required this.receipts,
    required this.customers,
    required this.avgTicket,
    required this.topItems,
  });

  factory CompareRangeStats.fromJson(Map<String, dynamic> json) {
    return CompareRangeStats(
      from: _asString(json['from']),
      to: _asString(json['to']),
      days: _asListOfMaps(json['days'])
          .map(MonthlyDayRecord.fromJson)
          .toList(growable: false),
      gross: _asInt(json['gross']),
      receipts: _asInt(json['receipts']),
      customers: _asInt(json['customers']),
      avgTicket: _asInt(json['avg_ticket']),
      topItems: _asListOfMaps(json['top_items'])
          .map(AnalyticsTopItem.fromJson)
          .toList(growable: false),
    );
  }
}

class CompareDeltas {
  final double gross;
  final double receipts;
  final double customers;
  final double avgTicket;

  const CompareDeltas({
    required this.gross,
    required this.receipts,
    required this.customers,
    required this.avgTicket,
  });

  factory CompareDeltas.fromJson(Map<String, dynamic> json) {
    return CompareDeltas(
      gross: _asDouble(json['gross']),
      receipts: _asDouble(json['receipts']),
      customers: _asDouble(json['customers']),
      avgTicket: _asDouble(json['avg_ticket']),
    );
  }
}

class CompareAnalysisData {
  final String error;
  final CompareRangeStats current;
  final CompareRangeStats previous;
  final CompareDeltas deltas;

  const CompareAnalysisData({
    required this.error,
    required this.current,
    required this.previous,
    required this.deltas,
  });

  factory CompareAnalysisData.fromJson(Map<String, dynamic> json) {
    return CompareAnalysisData(
      error: _asString(json['error']),
      current: CompareRangeStats.fromJson(_asMap(json['a'])),
      previous: CompareRangeStats.fromJson(_asMap(json['b'])),
      deltas: CompareDeltas.fromJson(_asMap(json['deltas'])),
    );
  }
}

class TrendDayRecord {
  final String businessDate;
  final int grossAmount;
  final int receiptCount;
  final int customerCount;
  final int discountAmount;
  final int avgTicket;
  final int perCustomer;

  const TrendDayRecord({
    required this.businessDate,
    required this.grossAmount,
    required this.receiptCount,
    required this.customerCount,
    required this.discountAmount,
    required this.avgTicket,
    required this.perCustomer,
  });

  factory TrendDayRecord.fromJson(Map<String, dynamic> json) {
    return TrendDayRecord(
      businessDate: _asString(json['business_date']),
      grossAmount: _asInt(json['gross_amount']),
      receiptCount: _asInt(json['receipt_count']),
      customerCount: _asInt(json['customer_count']),
      discountAmount: _asInt(json['discount_amount']),
      avgTicket: _asInt(json['avg_ticket']),
      perCustomer: _asInt(json['per_customer']),
    );
  }
}

class MovingAveragePoint {
  final String businessDate;
  final int ma28;

  const MovingAveragePoint({
    required this.businessDate,
    required this.ma28,
  });

  factory MovingAveragePoint.fromJson(Map<String, dynamic> json) {
    return MovingAveragePoint(
      businessDate: _asString(json['business_date']),
      ma28: _asInt(json['ma28']),
    );
  }
}

class TrendsSummary {
  final int totalGross;
  final int totalReceipts;
  final int totalCustomers;
  final int avgTicket;
  final int perCustomer;
  final int dayCount;

  const TrendsSummary({
    required this.totalGross,
    required this.totalReceipts,
    required this.totalCustomers,
    required this.avgTicket,
    required this.perCustomer,
    required this.dayCount,
  });

  factory TrendsSummary.fromJson(Map<String, dynamic> json) {
    return TrendsSummary(
      totalGross: _asInt(json['total_gross']),
      totalReceipts: _asInt(json['total_receipts']),
      totalCustomers: _asInt(json['total_customers']),
      avgTicket: _asInt(json['avg_ticket']),
      perCustomer: _asInt(json['per_customer']),
      dayCount: _asInt(json['day_count']),
    );
  }
}

class TrendsAnalysisData {
  final String error;
  final String fromDate;
  final String toDate;
  final List<TrendDayRecord> days;
  final List<MovingAveragePoint> maSeries;
  final int forecastAvg;
  final TrendsSummary summary;

  const TrendsAnalysisData({
    required this.error,
    required this.fromDate,
    required this.toDate,
    required this.days,
    required this.maSeries,
    required this.forecastAvg,
    required this.summary,
  });

  factory TrendsAnalysisData.fromJson(Map<String, dynamic> json) {
    return TrendsAnalysisData(
      error: _asString(json['error']),
      fromDate: _asString(json['from_date']),
      toDate: _asString(json['to_date']),
      days: _asListOfMaps(json['days'])
          .map(TrendDayRecord.fromJson)
          .toList(growable: false),
      maSeries: _asListOfMaps(json['ma_series'])
          .map(MovingAveragePoint.fromJson)
          .toList(growable: false),
      forecastAvg: _asInt(json['forecast_avg']),
      summary: TrendsSummary.fromJson(_asMap(json['summary'])),
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
