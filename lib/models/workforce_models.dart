// Models for the workforce (인력 관리) feature.

class WorkforceDashboardWorkplace {
  final int id;
  final String name;
  final String payCycle;
  final String nextPayday;
  final int daysUntilPayday;
  final int grossPay;
  final int netPay;
  final double workedHours;

  const WorkforceDashboardWorkplace({
    required this.id,
    required this.name,
    required this.payCycle,
    required this.nextPayday,
    required this.daysUntilPayday,
    required this.grossPay,
    required this.netPay,
    required this.workedHours,
  });

  factory WorkforceDashboardWorkplace.fromJson(Map<String, dynamic> json) {
    return WorkforceDashboardWorkplace(
      id: _asInt(json['id']),
      name: _asString(json['name']),
      payCycle: _asString(json['pay_cycle']),
      nextPayday: _asString(json['next_payday']),
      daysUntilPayday: _asInt(json['days_until_payday']),
      grossPay: _asInt(json['gross_pay']),
      netPay: _asInt(json['net_pay']),
      workedHours: _asDouble(json['worked_hours']),
    );
  }
}

class WorkforceSummary {
  final int totalGrossPay;
  final int totalNetPay;
  final double totalWorkedHours;
  final int shiftCount;
  final int employeeCount;

  const WorkforceSummary({
    required this.totalGrossPay,
    required this.totalNetPay,
    required this.totalWorkedHours,
    required this.shiftCount,
    required this.employeeCount,
  });

  factory WorkforceSummary.fromJson(Map<String, dynamic> json) {
    return WorkforceSummary(
      totalGrossPay: _asInt(json['total_gross_pay']),
      totalNetPay: _asInt(json['total_net_pay']),
      totalWorkedHours: _asDouble(json['total_worked_hours']),
      shiftCount: _asInt(json['shift_count']),
      employeeCount: _asInt(json['employee_count']),
    );
  }
}

class WorkforceDashboardData {
  final Map<String, String> period;
  final WorkforceSummary summary;
  final List<WorkforceDashboardWorkplace> workplaces;
  final int minimumWage;

  const WorkforceDashboardData({
    required this.period,
    required this.summary,
    required this.workplaces,
    required this.minimumWage,
  });

  factory WorkforceDashboardData.fromJson(Map<String, dynamic> json) {
    final rawPeriod = json['period'];
    final period = <String, String>{};
    if (rawPeriod is Map) {
      rawPeriod.forEach((k, v) => period[k.toString()] = v?.toString() ?? '');
    }
    return WorkforceDashboardData(
      period: period,
      summary: WorkforceSummary.fromJson(_asMap(json['summary'])),
      workplaces: _asListOfMaps(json['workplaces'])
          .map(WorkforceDashboardWorkplace.fromJson)
          .toList(growable: false),
      minimumWage: _asInt(json['minimum_wage']),
    );
  }
}

class CalendarDay {
  final String date;
  final int shiftCount;
  final int workedMinutes;
  final double workedHours;
  final int grossPay;

  const CalendarDay({
    required this.date,
    required this.shiftCount,
    required this.workedMinutes,
    required this.workedHours,
    required this.grossPay,
  });

  factory CalendarDay.fromJson(Map<String, dynamic> json) {
    return CalendarDay(
      date: _asString(json['date']),
      shiftCount: _asInt(json['shift_count']),
      workedMinutes: _asInt(json['worked_minutes']),
      workedHours: _asDouble(json['worked_hours']),
      grossPay: _asInt(json['gross_pay']),
    );
  }
}

class WorkloadCalendarData {
  final int year;
  final int month;
  final String fromDate;
  final String toDate;
  final List<CalendarDay> days;
  final WorkforceSummary summary;

  const WorkloadCalendarData({
    required this.year,
    required this.month,
    required this.fromDate,
    required this.toDate,
    required this.days,
    required this.summary,
  });

  factory WorkloadCalendarData.fromJson(Map<String, dynamic> json) {
    return WorkloadCalendarData(
      year: _asInt(json['year']),
      month: _asInt(json['month']),
      fromDate: _asString(json['from_date']),
      toDate: _asString(json['to_date']),
      days: _asListOfMaps(json['days'])
          .map(CalendarDay.fromJson)
          .toList(growable: false),
      summary: WorkforceSummary.fromJson(_asMap(json['summary'])),
    );
  }
}

class Employee {
  final int id;
  final int workplaceId;
  final String workplaceName;
  final String name;
  final String role;
  final int hourlyWage;
  final String taxPreset;
  final bool isActive;

  const Employee({
    required this.id,
    required this.workplaceId,
    required this.workplaceName,
    required this.name,
    required this.role,
    required this.hourlyWage,
    required this.taxPreset,
    required this.isActive,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: _asInt(json['id']),
      workplaceId: _asInt(json['workplace_id']),
      workplaceName: _asString(json['workplace_name']),
      name: _asString(json['name']),
      role: _asString(json['role']),
      hourlyWage: _asInt(json['hourly_wage']),
      taxPreset: _asString(json['tax_preset']),
      isActive: json['is_active'] == true,
    );
  }
}

class Workplace {
  final int id;
  final String name;
  final String payCycle;
  final int payday;
  final bool isActive;

  const Workplace({
    required this.id,
    required this.name,
    required this.payCycle,
    required this.payday,
    required this.isActive,
  });

  factory Workplace.fromJson(Map<String, dynamic> json) {
    return Workplace(
      id: _asInt(json['id']),
      name: _asString(json['name']),
      payCycle: _asString(json['pay_cycle']),
      payday: _asInt(json['payday']),
      isActive: json['is_active'] == true,
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

List<Map<String, dynamic>> _asListOfMaps(Object? source) {
  if (source is! List) return const [];
  return source
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

Map<String, dynamic> _asMap(Object? source) {
  if (source is Map) return Map<String, dynamic>.from(source);
  return const {};
}

String _asString(Object? value) => value?.toString() ?? '';

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

double _asDouble(Object? value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}
