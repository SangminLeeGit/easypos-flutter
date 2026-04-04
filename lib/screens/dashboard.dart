import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/dashboard_model.dart';
import '../widgets/cache_notice.dart';
import '../state/app_state.dart';
import '../widgets/empty_state.dart';
import '../widgets/panel.dart';
import '../widgets/stat_card.dart';
import 'day_detail.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardSnapshot? _data;
  bool _isLoading = true;
  String _error = '';
  bool _fromCache = false;
  DateTime? _cachedAt;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final appState = context.read<AppState>();
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final response = await appState.fetchMapParsed(
        '/api/dashboard',
        parser: DashboardSnapshot.fromJson,
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
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF0D9488)),
      );
    }

    if (_error.isNotEmpty) {
      return EmptyState(
        title: '대시보드를 불러오지 못했습니다.',
        message: _error,
        action: FilledButton(
          onPressed: _fetchData,
          child: const Text('다시 시도'),
        ),
      );
    }

    if (_data == null || !_data!.dbAvailable) {
      return EmptyState(
        title: '데이터베이스에 연결되지 않았습니다.',
        message:
            _data?.error.isNotEmpty == true ? _data!.error : '백엔드 상태를 확인하세요.',
        action: FilledButton(
          onPressed: _fetchData,
          child: const Text('새로고침'),
        ),
      );
    }

    final data = _data!;
    final latest = data.latestMetrics;
    final previousDayAmount = data.recentDays.length > 1
        ? data.recentDays[1].grossAmount
        : 0;

    return RefreshIndicator(
      onRefresh: _fetchData,
      color: const Color(0xFF0D9488),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '실시간 요약',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
          ),
          const SizedBox(height: 6),
          Text(
            data.latestDay != null
                ? '기준일 ${UiFormat.weekday(data.latestDay!)}'
                : '기준일 정보 없음',
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 14,
            ),
          ),
          if (_fromCache && _cachedAt != null) ...[
            const SizedBox(height: 8),
            CacheNotice(cachedAt: _cachedAt),
          ],
          const SizedBox(height: 16),
          _buildCardGrid([
            StatCard(
              label: '오늘 매출',
              value: UiFormat.won(latest.grossAmount),
              sub: '전일 대비 ${UiFormat.delta(latest.grossAmount, previousDayAmount)}',
              accent: true,
            ),
            StatCard(
              label: '주간 누적',
              value: UiFormat.won(data.weekThis),
              sub:
                  '전주 ${UiFormat.won(data.weekPrev)} · ${UiFormat.delta(data.weekThis, data.weekPrev)}',
            ),
            StatCard(
              label: '평균 객단가',
              value: UiFormat.won(data.avgTicket),
              sub: '전주 ${UiFormat.won(data.prevAvgTicket)}',
            ),
            StatCard(
              label: '영수건수 / 고객',
              value:
                  '${UiFormat.number(latest.receiptCount)} / ${UiFormat.number(latest.customerCount)}',
              sub:
                  '카드 ${UiFormat.won(latest.cardAmount)} · 현금 ${UiFormat.won(latest.cashAmount)}',
            ),
          ]),
          const SizedBox(height: 16),
          Panel(
            title: '최근 7일 매출',
            subtitle: '탭하면 일별 상세로 이동합니다.',
            child: _buildRecentDays(context, data),
          ),
          Panel(
            title: '상위 판매 품목',
            subtitle: '최신 영업일 매출 상위 품목',
            child: _buildTopItems(data.topItems),
          ),
          Panel(
            title: '결제수단 구성',
            subtitle: '최신 영업일 결제 비중',
            child: _buildPaymentMix(data.paymentMix),
          ),
          Panel(
            title: '최근 적재 이력',
            subtitle: '백엔드 동기화 상태를 함께 확인합니다.',
            child: _buildRecentRuns(data.recentRuns),
          ),
          Panel(
            title: '성장 / 주의 품목',
            subtitle: '최근 주간 비교',
            child: _buildTrendItems(data),
          ),
        ],
      ),
    );
  }

  Widget _buildCardGrid(List<Widget> cards) {
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

  Widget _buildRecentDays(BuildContext context, DashboardSnapshot data) {
    final rows = data.recentDays;
    if (rows.isEmpty) {
      return const Text(
        '표시할 최근 매출이 없습니다.',
        style: TextStyle(color: Color(0xFF64748B)),
      );
    }

    return Column(
      children: rows.map((day) {
        final date = day.businessDate;
        return ListTile(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DayDetailScreen(date: date),
            ),
          ),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.calendar_today_outlined, size: 20),
          title: Text(UiFormat.weekday(date)),
          subtitle: Text(
            '영수 ${UiFormat.number(day.receiptCount)}건 · 고객 ${UiFormat.number(day.customerCount)}명',
          ),
          trailing: Text(
            UiFormat.won(day.grossAmount),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        );
      }).toList(growable: false),
    );
  }

  Widget _buildTopItems(List<TopItemSummary> items) {
    if (items.isEmpty) {
      return const Text(
        '품목 데이터가 없습니다.',
        style: TextStyle(color: Color(0xFF64748B)),
      );
    }

    return Column(
      children: items.take(5).map((item) {
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(
            item.itemName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text('수량 ${UiFormat.number(item.totalQty)}개'),
          trailing: Text(
            UiFormat.won(item.totalAmount),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        );
      }).toList(growable: false),
    );
  }

  Widget _buildPaymentMix(List<PaymentMixItem> items) {
    if (items.isEmpty) {
      return const Text(
        '결제수단 데이터가 없습니다.',
        style: TextStyle(color: Color(0xFF64748B)),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        return Chip(
          label: Text(
            '${item.method} ${item.pct.toStringAsFixed(1)}%',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          avatar: const CircleAvatar(
            backgroundColor: Color(0xFF0D9488),
            child: Icon(Icons.payments_outlined, size: 14, color: Colors.white),
          ),
          backgroundColor: const Color(0xFFF0FDFA),
          side: const BorderSide(color: Color(0xFF99F6E4)),
        );
      }).toList(growable: false),
    );
  }

  Widget _buildTrendItems(DashboardSnapshot data) {
    final growers = data.growers.take(3).toList(growable: false);
    final decliners = data.decliners.take(3).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '성장 품목',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        ..._buildTrendRows(growers, isPositive: true),
        const SizedBox(height: 16),
        const Text(
          '주의 품목',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        ..._buildTrendRows(decliners, isPositive: false),
      ],
    );
  }

  List<Widget> _buildTrendRows(
    List<TrendItem> items, {
    required bool isPositive,
  }) {
    if (items.isEmpty) {
      return const [
        Text(
          '데이터 없음',
          style: TextStyle(color: Color(0xFF64748B)),
        ),
      ];
    }

    return items.map((item) {
      final delta = item.delta;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                item.itemName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              UiFormat.won(delta),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isPositive
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFDC2626),
              ),
            ),
          ],
        ),
      );
    }).toList(growable: false);
  }
  Widget _buildRecentRuns(List<SyncRun> runs) {
    if (runs.isEmpty) {
      return const Text(
        '최근 적재 이력이 없습니다.',
        style: TextStyle(color: Color(0xFF64748B)),
      );
    }

    return Column(
      children: runs.take(6).map((run) {
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(
            run.targetDate,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            '시작 ${UiFormat.compactDateTime(run.startedAt)} · 완료 ${UiFormat.compactDateTime(run.finishedAt)}',
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                run.status,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: switch (run.status) {
                    'succeeded' => const Color(0xFF16A34A),
                    'failed' => const Color(0xFFDC2626),
                    'running' || 'pending' => const Color(0xFFB45309),
                    _ => const Color(0xFF64748B),
                  },
                ),
              ),
              Text(
                '${UiFormat.number(run.loadedCount)} / ${UiFormat.number(run.sourceCount)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        );
      }).toList(growable: false),
    );
  }
}
