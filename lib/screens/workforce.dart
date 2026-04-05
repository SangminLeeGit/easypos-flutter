import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/workforce_models.dart';
import '../state/app_state.dart';
import '../widgets/cache_notice.dart';
import '../widgets/empty_state.dart';
import '../widgets/panel.dart';
import '../widgets/stat_card.dart';

class WorkforceScreen extends StatelessWidget {
  const WorkforceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '인력 관리',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '근무 일정, 직원, 급여를 관리합니다.',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                ),
                const SizedBox(height: 12),
                const TabBar(
                  tabs: [
                    Tab(text: '대시보드'),
                    Tab(text: '캘린더'),
                    Tab(text: '직원'),
                  ],
                ),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _WorkforceDashboardTab(),
                _CalendarTab(),
                _EmployeesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Dashboard Tab ────────────────────────────────────────────────────────────

class _WorkforceDashboardTab extends StatefulWidget {
  const _WorkforceDashboardTab();

  @override
  State<_WorkforceDashboardTab> createState() => _WorkforceDashboardTabState();
}

class _WorkforceDashboardTabState extends State<_WorkforceDashboardTab> {
  WorkforceDashboardData? _data;
  bool _isLoading = true;
  String _error = '';
  bool _fromCache = false;
  DateTime? _cachedAt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final appState = context.read<AppState>();
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final response = await appState.fetchMapParsed(
        '/api/workforce/dashboard',
        parser: WorkforceDashboardData.fromJson,
        cacheTtl: const Duration(minutes: 10),
      );
      if (!mounted) return;
      setState(() {
        _data = response.data;
        _fromCache = response.fromCache;
        _cachedAt = response.cachedAt;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error.isNotEmpty) {
      return EmptyState(
        title: '인력 대시보드를 불러오지 못했습니다.',
        message: _error,
        action: FilledButton(onPressed: _load, child: const Text('다시 시도')),
      );
    }
    final data = _data;
    if (data == null) {
      return EmptyState(
        title: '데이터 없음',
        action: FilledButton(onPressed: _load, child: const Text('새로고침')),
      );
    }

    final s = data.summary;
    final period = '${data.period['from_date'] ?? ''} ~ ${data.period['to_date'] ?? ''}';

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (_fromCache && _cachedAt != null) ...[
            CacheNotice(cachedAt: _cachedAt),
            const SizedBox(height: 12),
          ],
          Text(
            '이번 달 ($period)',
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
          const SizedBox(height: 8),
          _MetricGrid(
            cards: [
              StatCard(
                label: '총 급여 (세전)',
                value: _won(s.totalGrossPay),
                accent: true,
              ),
              StatCard(
                label: '총 근무시간',
                value: '${s.totalWorkedHours.toStringAsFixed(1)}h',
              ),
              StatCard(
                label: '시프트 수',
                value: '${s.shiftCount}건',
              ),
              StatCard(
                label: '직원 수',
                value: '${s.employeeCount}명',
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (data.workplaces.isNotEmpty)
            Panel(
              title: '근무지별 현황',
              subtitle: '다음 지급일 기준',
              child: Column(
                children: data.workplaces.map((wp) {
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                wp.name,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                            Text(
                              '${wp.daysUntilPayday}일 후 지급일',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '근무 ${wp.workedHours.toStringAsFixed(1)}h',
                                style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                              ),
                            ),
                            Text(
                              _won(wp.grossPay),
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(growable: false),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            '최저임금 ${_won(data.minimumWage)}원/시간',
            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }
}

// ─── Calendar Tab ─────────────────────────────────────────────────────────────

class _CalendarTab extends StatefulWidget {
  const _CalendarTab();

  @override
  State<_CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<_CalendarTab> {
  late DateTime _selectedMonth;
  WorkloadCalendarData? _data;
  bool _isLoading = true;
  String _error = '';
  bool _fromCache = false;
  DateTime? _cachedAt;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
    _load();
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked == null) return;
    setState(() => _selectedMonth = DateTime(picked.year, picked.month));
    await _load();
  }

  Future<void> _load() async {
    final appState = context.read<AppState>();
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final response = await appState.fetchMapParsed(
        '/api/workforce/calendar',
        params: {
          'year': _selectedMonth.year,
          'month': _selectedMonth.month,
        },
        parser: WorkloadCalendarData.fromJson,
        cacheTtl: const Duration(minutes: 10),
      );
      if (!mounted) return;
      setState(() {
        _data = response.data;
        _fromCache = response.fromCache;
        _cachedAt = response.cachedAt;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error.isNotEmpty) {
      return EmptyState(
        title: '근무 캘린더를 불러오지 못했습니다.',
        message: _error,
        action: FilledButton(onPressed: _load, child: const Text('다시 시도')),
      );
    }
    final data = _data;
    if (data == null) {
      return EmptyState(
        title: '캘린더 데이터가 없습니다.',
        action: FilledButton(onPressed: _load, child: const Text('새로고침')),
      );
    }

    final s = data.summary;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${data.year}년 ${data.month}월 근무',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _pickMonth,
                icon: const Icon(Icons.tune_outlined, size: 16),
                label: const Text('월 선택'),
              ),
            ],
          ),
          if (_fromCache && _cachedAt != null) ...[
            const SizedBox(height: 8),
            CacheNotice(cachedAt: _cachedAt),
          ],
          const SizedBox(height: 12),
          _MetricGrid(
            cards: [
              StatCard(label: '총 급여', value: _won(s.totalGrossPay), accent: true),
              StatCard(label: '총 근무', value: '${s.totalWorkedHours.toStringAsFixed(1)}h'),
              StatCard(label: '시프트', value: '${s.shiftCount}건'),
            ],
          ),
          const SizedBox(height: 16),
          Panel(
            title: '일자별 근무 현황',
            subtitle: '근무가 있는 날만 표시',
            child: data.days.isEmpty
                ? const Text(
                    '이 기간에 등록된 시프트가 없습니다.',
                    style: TextStyle(color: Color(0xFF64748B)),
                  )
                : Column(
                    children: data.days.map((day) {
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(_formatWeekday(day.date)),
                        subtitle: Text(
                          '${day.shiftCount}명 · ${day.workedHours.toStringAsFixed(1)}h',
                        ),
                        trailing: Text(
                          _won(day.grossPay),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      );
                    }).toList(growable: false),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Employees Tab ────────────────────────────────────────────────────────────

class _EmployeesTab extends StatefulWidget {
  const _EmployeesTab();

  @override
  State<_EmployeesTab> createState() => _EmployeesTabState();
}

class _EmployeesTabState extends State<_EmployeesTab> {
  List<Employee>? _list;
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final appState = context.read<AppState>();
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final response = await appState.fetchMapParsed(
        '/api/workforce/employees',
        parser: (json) {
          final raw = json['employees'];
          if (raw is! List) return const <Employee>[];
          return raw
              .whereType<Map>()
              .map((e) => Employee.fromJson(Map<String, dynamic>.from(e)))
              .toList(growable: false);
        },
        cacheTtl: const Duration(minutes: 10),
      );
      if (!mounted) return;
      setState(() {
        _list = response.data;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error.isNotEmpty) {
      return EmptyState(
        title: '직원 목록을 불러오지 못했습니다.',
        message: _error,
        action: FilledButton(onPressed: _load, child: const Text('다시 시도')),
      );
    }
    final list = _list ?? const <Employee>[];
    if (list.isEmpty) {
      return EmptyState(
        title: '등록된 직원이 없습니다.',
        action: FilledButton(onPressed: _load, child: const Text('새로고침')),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final emp = list[index];
          return Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color.fromRGBO(13, 148, 136, 0.12),
                child: Text(
                  emp.name.isNotEmpty ? emp.name[0] : '?',
                  style: const TextStyle(
                    color: Color(0xFF0D9488),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(emp.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  if (!emp.isActive)
                    const Text(
                      '비활성',
                      style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                ],
              ),
              subtitle: Text(
                '${emp.workplaceName} · ${emp.role.isEmpty ? '직원' : emp.role}',
              ),
              trailing: Text(
                '${_won(emp.hourlyWage)}원/h',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

class _MetricGrid extends StatelessWidget {
  final List<Widget> cards;
  const _MetricGrid({required this.cards});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth >= 720
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards.map((c) => SizedBox(width: width, child: c)).toList(growable: false),
        );
      },
    );
  }
}

String _won(num value) {
  final abs = value.abs().round();
  final str = abs.toString();
  final buffer = StringBuffer();
  for (int i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) buffer.write(',');
    buffer.write(str[i]);
  }
  return value < 0 ? '-${buffer.toString()}' : buffer.toString();
}

String _formatWeekday(String date) {
  try {
    final dt = DateTime.parse(date);
    const days = ['월', '화', '수', '목', '금', '토', '일'];
    return '$date (${days[dt.weekday - 1]})';
  } catch (_) {
    return date;
  }
}
