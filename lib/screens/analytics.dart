import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/analytics_models.dart';
import '../models/dashboard_model.dart';
import '../state/app_state.dart';
import '../widgets/cache_notice.dart';
import '../widgets/empty_state.dart';
import '../widgets/panel.dart';
import '../widgets/stat_card.dart';
import 'day_detail.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 7,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '백엔드 확장 분석 모듈',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '웹 콘솔과 같은 분석 API 를 직접 사용합니다. 기간별 리포트와 비교 모듈을 모바일에서 확인할 수 있습니다.',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                const TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    Tab(text: '월간'),
                    Tab(text: '품목'),
                    Tab(text: '시간대'),
                    Tab(text: '요일'),
                    Tab(text: '결제'),
                    Tab(text: '비교'),
                    Tab(text: '트렌드'),
                  ],
                ),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _MonthlyTab(),
                _ItemsTab(),
                _HoursTab(),
                _WeekdayTab(),
                _PaymentsTab(),
                _CompareTab(),
                _TrendsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlyTab extends StatefulWidget {
  const _MonthlyTab();

  @override
  State<_MonthlyTab> createState() => _MonthlyTabState();
}

class _MonthlyTabState extends State<_MonthlyTab> {
  late DateTime _selectedMonth;
  MonthlyReportData? _data;
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
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _selectedMonth = DateTime(picked.year, picked.month);
    });
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
        '/api/monthly',
        params: {
          'year': _selectedMonth.year,
          'month': _selectedMonth.month,
        },
        parser: MonthlyReportData.fromJson,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _data = response.data;
        _fromCache = response.fromCache;
        _cachedAt = response.cachedAt;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error.isNotEmpty) {
      return EmptyState(
        title: '월간 리포트를 불러오지 못했습니다.',
        message: _error,
        action: FilledButton(onPressed: _load, child: const Text('다시 시도')),
      );
    }

    final data = _data;
    if (data == null || data.error.isNotEmpty) {
      return EmptyState(
        title: '월간 데이터가 없습니다.',
        message: data?.error,
        action: FilledButton(onPressed: _load, child: const Text('새로고침')),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _AnalyticsHeaderRow(
            title: '${data.year}년 ${data.month}월',
            subtitle: '월간 합계와 일자별 흐름을 확인합니다.',
            actionLabel: '월 선택',
            onAction: _pickMonth,
          ),
          if (_fromCache && _cachedAt != null) ...[
            const SizedBox(height: 8),
            CacheNotice(cachedAt: _cachedAt),
          ],
          const SizedBox(height: 16),
          _AnalyticsMetricGrid(
            cards: [
              StatCard(label: '총매출', value: UiFormat.won(data.totals.gross), accent: true),
              StatCard(label: '평균 객단가', value: UiFormat.won(data.totals.avgTicket)),
              StatCard(
                label: '영수 / 고객',
                value: '${UiFormat.number(data.totals.receipts)} / ${UiFormat.number(data.totals.customers)}',
              ),
              StatCard(
                label: '카드 / 현금',
                value: '${UiFormat.won(data.totals.card)} / ${UiFormat.won(data.totals.cash)}',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Panel(
            title: '일별 흐름',
            subtitle: '일자를 누르면 일별 상세로 이동합니다.',
            child: Column(
              children: data.days.map((day) {
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(UiFormat.weekday(day.businessDate)),
                  subtitle: Text(
                    '영수 ${UiFormat.number(day.receiptCount)}건 · 고객 ${UiFormat.number(day.customerCount)}명',
                  ),
                  trailing: Text(
                    UiFormat.won(day.grossAmount),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DayDetailScreen(date: day.businessDate),
                    ),
                  ),
                );
              }).toList(growable: false),
            ),
          ),
          Panel(
            title: '상위 판매 품목',
            subtitle: '월간 누적 매출 기준',
            child: _TopItemList(items: data.topItems),
          ),
        ],
      ),
    );
  }
}

class _ItemsTab extends StatefulWidget {
  const _ItemsTab();

  @override
  State<_ItemsTab> createState() => _ItemsTabState();
}

class _ItemsTabState extends State<_ItemsTab> {
  late DateTimeRange _range;
  ItemAnalysisData? _data;
  bool _isLoading = true;
  String _error = '';
  bool _fromCache = false;
  DateTime? _cachedAt;

  @override
  void initState() {
    super.initState();
    _range = _defaultRange(days: 13);
    _load();
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _range,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked == null) {
      return;
    }
    setState(() => _range = picked);
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
        '/api/items',
        params: _rangeParams(_range),
        parser: ItemAnalysisData.fromJson,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _data = response.data;
        _fromCache = response.fromCache;
        _cachedAt = response.cachedAt;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error.isNotEmpty) {
      return EmptyState(
        title: '품목 분석을 불러오지 못했습니다.',
        message: _error,
        action: FilledButton(onPressed: _load, child: const Text('다시 시도')),
      );
    }

    final data = _data;
    if (data == null || data.error.isNotEmpty) {
      return EmptyState(
        title: '품목 데이터가 없습니다.',
        message: data?.error,
        action: FilledButton(onPressed: _load, child: const Text('새로고침')),
      );
    }

    final abcA = data.itemList.where((item) => item.abc == 'A').length;
    final abcB = data.itemList.where((item) => item.abc == 'B').length;
    final abcC = data.itemList.where((item) => item.abc == 'C').length;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _AnalyticsHeaderRow(
            title: '품목 분석',
            subtitle: _rangeLabel(_range),
            actionLabel: '기간 변경',
            onAction: _pickRange,
          ),
          if (_fromCache && _cachedAt != null) ...[
            const SizedBox(height: 8),
            CacheNotice(cachedAt: _cachedAt),
          ],
          const SizedBox(height: 16),
          _AnalyticsMetricGrid(
            cards: [
              StatCard(label: '총 품목수', value: UiFormat.number(data.itemList.length), accent: true),
              StatCard(label: '누적 매출', value: UiFormat.won(data.grandTotal)),
              StatCard(label: 'ABC A/B/C', value: '$abcA / $abcB / $abcC'),
              StatCard(
                label: '최상위 품목',
                value: data.itemList.isEmpty ? '-' : data.itemList.first.itemName,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Panel(
            title: '품목 랭킹',
            subtitle: '매출 기준 상위 품목과 ABC 등급',
            child: Column(
              children: data.itemList.take(15).map((item) {
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.itemName),
                  subtitle: Text(
                    '수량 ${UiFormat.number(item.totalQty)}개 · 비중 ${item.pct.toStringAsFixed(1)}% · 등급 ${item.abc.isEmpty ? '-' : item.abc}',
                  ),
                  trailing: Text(
                    UiFormat.won(item.totalAmount),
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

class _HoursTab extends StatefulWidget {
  const _HoursTab();

  @override
  State<_HoursTab> createState() => _HoursTabState();
}

class _HoursTabState extends State<_HoursTab> {
  late DateTimeRange _range;
  HourlyAnalysisData? _data;
  bool _isLoading = true;
  String _error = '';
  bool _fromCache = false;
  DateTime? _cachedAt;

  @override
  void initState() {
    super.initState();
    _range = _defaultRange(days: 13);
    _load();
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _range,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked == null) {
      return;
    }
    setState(() => _range = picked);
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
        '/api/hours',
        params: _rangeParams(_range),
        parser: HourlyAnalysisData.fromJson,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _data = response.data;
        _fromCache = response.fromCache;
        _cachedAt = response.cachedAt;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error.isNotEmpty) {
      return EmptyState(
        title: '시간대 분석을 불러오지 못했습니다.',
        message: _error,
        action: FilledButton(onPressed: _load, child: const Text('다시 시도')),
      );
    }

    final data = _data;
    if (data == null || data.error.isNotEmpty) {
      return EmptyState(
        title: '시간대 데이터가 없습니다.',
        message: data?.error,
        action: FilledButton(onPressed: _load, child: const Text('새로고침')),
      );
    }

    final peakHour = data.hourlyTotals.isEmpty
        ? null
        : (data.hourlyTotals.toList()..sort((a, b) => b.totalAmount.compareTo(a.totalAmount))).first;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _AnalyticsHeaderRow(
            title: '시간대 분석',
            subtitle: _rangeLabel(_range),
            actionLabel: '기간 변경',
            onAction: _pickRange,
          ),
          if (_fromCache && _cachedAt != null) ...[
            const SizedBox(height: 8),
            CacheNotice(cachedAt: _cachedAt),
          ],
          const SizedBox(height: 16),
          _AnalyticsMetricGrid(
            cards: [
              StatCard(label: '시간대 슬롯', value: UiFormat.number(data.hourlyTotals.length), accent: true),
              StatCard(label: '평균 매출', value: UiFormat.won(data.avgAmount)),
              StatCard(label: '변동폭', value: UiFormat.won(data.stdAmount)),
              StatCard(
                label: '피크 시간',
                value: peakHour == null ? '-' : '${peakHour.hour}:00',
                sub: peakHour == null ? null : UiFormat.won(peakHour.totalAmount),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Panel(
            title: '시간대 합계',
            subtitle: '전체 기간 누적 시간대 분포',
            child: Column(
              children: data.hourlyTotals.map((row) {
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('${row.hour}:00'),
                  subtitle: Text(
                    '영수 ${UiFormat.number(row.billCount)}건 · 고객 ${UiFormat.number(row.totalCustomers)}명',
                  ),
                  trailing: Text(
                    UiFormat.won(row.totalAmount),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                );
              }).toList(growable: false),
            ),
          ),
          Panel(
            title: '핫스팟',
            subtitle: '요일 × 시간 조합 중 매출 상위 구간',
            child: Column(
              children: (data.heatmap.toList()
                    ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount)))
                  .take(8)
                  .map((cell) {
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('${_dowLabel(cell.dow)} ${cell.hour}:00'),
                  subtitle: Text(
                    '영수 ${UiFormat.number(cell.billCount)}건 · 고객 ${UiFormat.number(cell.totalCustomers)}명',
                  ),
                  trailing: Text(
                    UiFormat.won(cell.totalAmount),
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

class _WeekdayTab extends StatefulWidget {
  const _WeekdayTab();

  @override
  State<_WeekdayTab> createState() => _WeekdayTabState();
}

class _WeekdayTabState extends State<_WeekdayTab> {
  late DateTimeRange _range;
  WeekdayAnalysisData? _data;
  bool _isLoading = true;
  String _error = '';
  bool _fromCache = false;
  DateTime? _cachedAt;

  @override
  void initState() {
    super.initState();
    _range = _defaultRange(days: 29);
    _load();
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _range,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked == null) {
      return;
    }
    setState(() => _range = picked);
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
        '/api/weekday',
        params: _rangeParams(_range),
        parser: WeekdayAnalysisData.fromJson,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _data = response.data;
        _fromCache = response.fromCache;
        _cachedAt = response.cachedAt;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error.isNotEmpty) {
      return EmptyState(
        title: '요일 분석을 불러오지 못했습니다.',
        message: _error,
        action: FilledButton(onPressed: _load, child: const Text('다시 시도')),
      );
    }

    final data = _data;
    if (data == null || data.error.isNotEmpty) {
      return EmptyState(
        title: '요일 데이터가 없습니다.',
        message: data?.error,
        action: FilledButton(onPressed: _load, child: const Text('새로고침')),
      );
    }

    final bestRow = data.rows.isEmpty
        ? null
        : (data.rows.toList()..sort((a, b) => b.avgAmount.compareTo(a.avgAmount))).first;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _AnalyticsHeaderRow(
            title: '요일 분석',
            subtitle: _rangeLabel(_range),
            actionLabel: '기간 변경',
            onAction: _pickRange,
          ),
          if (_fromCache && _cachedAt != null) ...[
            const SizedBox(height: 8),
            CacheNotice(cachedAt: _cachedAt),
          ],
          const SizedBox(height: 16),
          _AnalyticsMetricGrid(
            cards: [
              StatCard(label: '평일 평균', value: UiFormat.won(data.weekdayAvg), accent: true),
              StatCard(label: '주말 평균', value: UiFormat.won(data.weekendAvg)),
              StatCard(
                label: '최강 요일',
                value: bestRow?.name ?? '-',
                sub: bestRow == null ? null : UiFormat.won(bestRow.avgAmount),
              ),
              StatCard(
                label: '분석 일수',
                value: UiFormat.number(data.rows.fold<int>(0, (sum, row) => sum + row.dayCount)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Panel(
            title: '요일별 평균',
            subtitle: '요일별 평균 매출과 객단가',
            child: Column(
              children: data.rows.map((row) {
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(row.name),
                  subtitle: Text(
                    '평균 객단가 ${UiFormat.won(row.avgTicket)} · 평균 영수 ${UiFormat.number(row.avgReceipts)}건',
                  ),
                  trailing: Text(
                    UiFormat.won(row.avgAmount),
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

class _PaymentsTab extends StatefulWidget {
  const _PaymentsTab();

  @override
  State<_PaymentsTab> createState() => _PaymentsTabState();
}

class _PaymentsTabState extends State<_PaymentsTab> {
  late DateTimeRange _range;
  PaymentAnalysisData? _data;
  bool _isLoading = true;
  String _error = '';
  bool _fromCache = false;
  DateTime? _cachedAt;

  @override
  void initState() {
    super.initState();
    _range = _defaultRange(days: 13);
    _load();
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _range,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked == null) {
      return;
    }
    setState(() => _range = picked);
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
        '/api/payments',
        params: _rangeParams(_range),
        parser: PaymentAnalysisData.fromJson,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _data = response.data;
        _fromCache = response.fromCache;
        _cachedAt = response.cachedAt;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error.isNotEmpty) {
      return EmptyState(
        title: '결제수단 분석을 불러오지 못했습니다.',
        message: _error,
        action: FilledButton(onPressed: _load, child: const Text('다시 시도')),
      );
    }

    final data = _data;
    if (data == null || data.error.isNotEmpty) {
      return EmptyState(
        title: '결제수단 데이터가 없습니다.',
        message: data?.error,
        action: FilledButton(onPressed: _load, child: const Text('새로고침')),
      );
    }

    final cardShare = data.totals.gross == 0
        ? 0.0
        : data.totals.card / data.totals.gross * 100;
    final cashShare = data.totals.gross == 0
        ? 0.0
        : data.totals.cash / data.totals.gross * 100;
    final avgReceipt = data.totals.receipts == 0
        ? 0
        : data.totals.gross ~/ data.totals.receipts;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _AnalyticsHeaderRow(
            title: '결제수단 분석',
            subtitle: _rangeLabel(_range),
            actionLabel: '기간 변경',
            onAction: _pickRange,
          ),
          if (_fromCache && _cachedAt != null) ...[
            const SizedBox(height: 8),
            CacheNotice(cachedAt: _cachedAt),
          ],
          const SizedBox(height: 16),
          _AnalyticsMetricGrid(
            cards: [
              StatCard(label: '총매출', value: UiFormat.won(data.totals.gross), accent: true),
              StatCard(label: '카드 비중', value: '${cardShare.toStringAsFixed(1)}%'),
              StatCard(label: '현금 비중', value: '${cashShare.toStringAsFixed(1)}%'),
              StatCard(label: '평균 영수액', value: UiFormat.won(avgReceipt)),
            ],
          ),
          const SizedBox(height: 16),
          Panel(
            title: '수단별 평균 영수액',
            subtitle: '영수증 단위 결제 방식 분포',
            child: Column(
              children: data.methodTickets.map((item) {
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.method),
                  subtitle: Text('건수 ${UiFormat.number(item.count)}건'),
                  trailing: Text(
                    UiFormat.won(item.avgTicket),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                );
              }).toList(growable: false),
            ),
          ),
          Panel(
            title: '일별 결제 구성',
            subtitle: '일자별 카드/현금 흐름',
            child: Column(
              children: data.days.map((day) {
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(UiFormat.weekday(day.businessDate)),
                  subtitle: Text(
                    '카드 ${UiFormat.won(day.cardAmount)} · 현금 ${UiFormat.won(day.cashAmount)}',
                  ),
                  trailing: Text(
                    UiFormat.won(day.grossAmount),
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

class _CompareTab extends StatefulWidget {
  const _CompareTab();

  @override
  State<_CompareTab> createState() => _CompareTabState();
}

class _CompareTabState extends State<_CompareTab> {
  late DateTimeRange _range;
  CompareAnalysisData? _data;
  bool _isLoading = true;
  String _error = '';
  bool _fromCache = false;
  DateTime? _cachedAt;

  @override
  void initState() {
    super.initState();
    _range = _defaultRange(days: 6);
    _load();
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _range,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked == null) {
      return;
    }
    setState(() => _range = picked);
    await _load();
  }

  Future<void> _load() async {
    final previous = _previousRange(_range);
    final appState = context.read<AppState>();
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final response = await appState.fetchMapParsed(
        '/api/compare',
        params: {
          'a_from': _formatDate(_range.start),
          'a_to': _formatDate(_range.end),
          'b_from': _formatDate(previous.start),
          'b_to': _formatDate(previous.end),
        },
        parser: CompareAnalysisData.fromJson,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _data = response.data;
        _fromCache = response.fromCache;
        _cachedAt = response.cachedAt;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error.isNotEmpty) {
      return EmptyState(
        title: '기간 비교를 불러오지 못했습니다.',
        message: _error,
        action: FilledButton(onPressed: _load, child: const Text('다시 시도')),
      );
    }

    final data = _data;
    if (data == null || data.error.isNotEmpty) {
      return EmptyState(
        title: '비교 데이터가 없습니다.',
        message: data?.error,
        action: FilledButton(onPressed: _load, child: const Text('새로고침')),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _AnalyticsHeaderRow(
            title: '기간 비교',
            subtitle: '${_rangeLabel(_range)} vs ${_rangeLabel(_previousRange(_range))}',
            actionLabel: '기준 기간',
            onAction: _pickRange,
          ),
          if (_fromCache && _cachedAt != null) ...[
            const SizedBox(height: 8),
            CacheNotice(cachedAt: _cachedAt),
          ],
          const SizedBox(height: 16),
          _AnalyticsMetricGrid(
            cards: [
              StatCard(label: '매출 증감', value: _percentText(data.deltas.gross), accent: true),
              StatCard(label: '영수 증감', value: _percentText(data.deltas.receipts)),
              StatCard(label: '고객 증감', value: _percentText(data.deltas.customers)),
              StatCard(label: '객단가 증감', value: _percentText(data.deltas.avgTicket)),
            ],
          ),
          const SizedBox(height: 16),
          Panel(
            title: '기간 요약',
            subtitle: '현재 구간과 직전 동일 길이 구간 비교',
            child: Column(
              children: [
                _CompareSummaryTile(label: '현재 구간', stats: data.current),
                const Divider(height: 24),
                _CompareSummaryTile(label: '비교 구간', stats: data.previous),
              ],
            ),
          ),
          Panel(
            title: '상위 판매 품목',
            subtitle: '현재 구간과 비교 구간의 주요 품목',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '현재 구간',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                _TopItemList(items: data.current.topItems.take(5).toList(growable: false)),
                const SizedBox(height: 16),
                const Text(
                  '비교 구간',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                _TopItemList(items: data.previous.topItems.take(5).toList(growable: false)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendsTab extends StatefulWidget {
  const _TrendsTab();

  @override
  State<_TrendsTab> createState() => _TrendsTabState();
}

class _TrendsTabState extends State<_TrendsTab> {
  late DateTimeRange _range;
  TrendsAnalysisData? _data;
  bool _isLoading = true;
  String _error = '';
  bool _fromCache = false;
  DateTime? _cachedAt;

  @override
  void initState() {
    super.initState();
    _range = _defaultRange(days: 29);
    _load();
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _range,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked == null) {
      return;
    }
    setState(() => _range = picked);
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
        '/api/trends',
        params: _rangeParams(_range),
        parser: TrendsAnalysisData.fromJson,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _data = response.data;
        _fromCache = response.fromCache;
        _cachedAt = response.cachedAt;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error.isNotEmpty) {
      return EmptyState(
        title: '트렌드 분석을 불러오지 못했습니다.',
        message: _error,
        action: FilledButton(onPressed: _load, child: const Text('다시 시도')),
      );
    }

    final data = _data;
    if (data == null || data.error.isNotEmpty) {
      return EmptyState(
        title: '트렌드 데이터가 없습니다.',
        message: data?.error,
        action: FilledButton(onPressed: _load, child: const Text('새로고침')),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _AnalyticsHeaderRow(
            title: '매출 트렌드',
            subtitle: _rangeLabel(_range),
            actionLabel: '기간 변경',
            onAction: _pickRange,
          ),
          if (_fromCache && _cachedAt != null) ...[
            const SizedBox(height: 8),
            CacheNotice(cachedAt: _cachedAt),
          ],
          const SizedBox(height: 16),
          _AnalyticsMetricGrid(
            cards: [
              StatCard(label: '총매출', value: UiFormat.won(data.summary.totalGross), accent: true),
              StatCard(label: '평균 객단가', value: UiFormat.won(data.summary.avgTicket)),
              StatCard(label: '고객당 매출', value: UiFormat.won(data.summary.perCustomer)),
              StatCard(label: '7일 예측 기준', value: UiFormat.won(data.forecastAvg)),
            ],
          ),
          const SizedBox(height: 16),
          Panel(
            title: '일별 추세',
            subtitle: '일자별 매출, 객단가, 고객당 매출',
            child: Column(
              children: data.days.reversed.take(12).map((day) {
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(UiFormat.weekday(day.businessDate)),
                  subtitle: Text(
                    '객단가 ${UiFormat.won(day.avgTicket)} · 고객당 ${UiFormat.won(day.perCustomer)}',
                  ),
                  trailing: Text(
                    UiFormat.won(day.grossAmount),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                );
              }).toList(growable: false),
            ),
          ),
          Panel(
            title: '28일 이동 평균',
            subtitle: '백엔드 계산 MA28 시계열',
            child: Column(
              children: data.maSeries.reversed.take(12).map((point) {
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(UiFormat.weekday(point.businessDate)),
                  trailing: Text(
                    UiFormat.won(point.ma28),
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

class _AnalyticsHeaderRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  const _AnalyticsHeaderRow({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: onAction,
          icon: const Icon(Icons.tune_outlined),
          label: Text(actionLabel),
        ),
      ],
    );
  }
}

class _AnalyticsMetricGrid extends StatelessWidget {
  final List<Widget> cards;

  const _AnalyticsMetricGrid({required this.cards});

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
          children: cards
              .map((card) => SizedBox(width: width, child: card))
              .toList(growable: false),
        );
      },
    );
  }
}

class _TopItemList extends StatelessWidget {
  final List<AnalyticsTopItem> items;

  const _TopItemList({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Text(
        '표시할 품목이 없습니다.',
        style: TextStyle(color: Color(0xFF64748B)),
      );
    }

    return Column(
      children: items.map((item) {
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(item.itemName),
          subtitle: Text(
            '수량 ${UiFormat.number(item.totalQty)}개${item.abc.isNotEmpty ? ' · 등급 ${item.abc}' : ''}',
          ),
          trailing: Text(
            UiFormat.won(item.totalAmount),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        );
      }).toList(growable: false),
    );
  }
}

class _CompareSummaryTile extends StatelessWidget {
  final String label;
  final CompareRangeStats stats;

  const _CompareSummaryTile({
    required this.label,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label · ${stats.from} ~ ${stats.to}',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        _CompareInfoRow(label: '총매출', value: UiFormat.won(stats.gross)),
        _CompareInfoRow(label: '영수건수', value: '${UiFormat.number(stats.receipts)}건'),
        _CompareInfoRow(label: '고객수', value: '${UiFormat.number(stats.customers)}명'),
        _CompareInfoRow(label: '평균 객단가', value: UiFormat.won(stats.avgTicket)),
      ],
    );
  }
}

class _CompareInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _CompareInfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

DateTimeRange _defaultRange({required int days}) {
  final end = DateTime.now();
  final start = end.subtract(Duration(days: days));
  return DateTimeRange(start: start, end: end);
}

Map<String, Object?> _rangeParams(DateTimeRange range) {
  return {
    'from_date': _formatDate(range.start),
    'to_date': _formatDate(range.end),
  };
}

DateTimeRange _previousRange(DateTimeRange range) {
  final length = range.duration.inDays + 1;
  final end = range.start.subtract(const Duration(days: 1));
  final start = end.subtract(Duration(days: length - 1));
  return DateTimeRange(start: start, end: end);
}

String _rangeLabel(DateTimeRange range) {
  return '${_formatDate(range.start)} ~ ${_formatDate(range.end)}';
}

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

String _dowLabel(int dow) {
  const names = ['월', '화', '수', '목', '금', '토', '일'];
  if (dow < 1 || dow > 7) {
    return '-';
  }
  return names[dow - 1];
}

String _percentText(double value) {
  final sign = value >= 0 ? '+' : '';
  return '$sign${value.toStringAsFixed(1)}%';
}
