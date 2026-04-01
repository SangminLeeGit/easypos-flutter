import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/dashboard_model.dart';
import '../state/app_state.dart';
import '../widgets/empty_state.dart';
import 'day_detail.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  static const List<Map<String, dynamic>> _plannedModules = [
    {
      'title': '월간 보고서',
      'sub': '월 단위 KPI와 일별 매출 흐름을 모바일에 맞게 구성',
      'icon': Icons.calendar_month_outlined,
      'ready': true,
    },
    {
      'title': '품목 분석',
      'sub': '품목별 매출, 수량, 비중 중심으로 요약',
      'icon': Icons.inventory_2_outlined,
      'ready': true,
    },
    {
      'title': '시간대 분석',
      'sub': '시간대별 매출 패턴과 피크타임 시각화',
      'icon': Icons.schedule_outlined,
      'ready': true,
    },
    {
      'title': '결제수단 분석',
      'sub': '카드, 현금, 포인트 비중 비교',
      'icon': Icons.payments_outlined,
      'ready': true,
    },
    {
      'title': '피크타임 히트맵',
      'sub': '요일 × 시간 매출 밀도 화면 예정',
      'icon': Icons.grid_view_outlined,
      'ready': false,
    },
    {
      'title': '특이일 탐지',
      'sub': '평균 대비 급등락 날짜 탐지 화면 예정',
      'icon': Icons.warning_amber_outlined,
      'ready': false,
    },
  ];

  List<Map<String, dynamic>> _recentDays = const [];
  bool _isLoading = true;
  String _error = '';
  bool _fromCache = false;
  DateTime? _cachedAt;

  @override
  void initState() {
    super.initState();
    _loadSidebar();
  }

  Future<void> _loadSidebar() async {
    final appState = context.read<AppState>();
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final response = await appState.fetchJsonList('/api/sidebar');
      if (!mounted) {
        return;
      }
      setState(() {
        _recentDays = response.data
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false);
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
        title: '분석 허브를 불러오지 못했습니다.',
        message: _error,
        action: FilledButton(
          onPressed: _loadSidebar,
          child: const Text('다시 시도'),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSidebar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '분석 허브',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
          ),
          const SizedBox(height: 6),
          const Text(
            '웹 콘솔 기준 분석 메뉴를 모바일 화면으로 단계적으로 옮기는 중입니다.',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 14,
            ),
          ),
          if (_fromCache && _cachedAt != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: Text(
                '오프라인 캐시 · ${UiFormat.compactDateTime(_cachedAt?.toIso8601String())}',
                style: const TextStyle(
                  color: Color(0xFF9A3412),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          const Text(
            '최근 영업일',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 12),
          ..._recentDays.take(10).map((day) {
            final date = day['business_date']?.toString() ?? '-';
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              color: Colors.white,
              child: ListTile(
                leading: const Icon(Icons.event_available_outlined),
                title: Text(UiFormat.weekday(date)),
                subtitle: Text(
                  "매출 ${UiFormat.won(day['gross_amount'] as num?)}",
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DayDetailScreen(date: date),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          const Text(
            '모바일 분석 로드맵',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 12),
          ..._plannedModules.map((item) {
            final isReady = item['ready'] == true;
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              color: Colors.white,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isReady
                      ? const Color.fromRGBO(13, 148, 136, 0.12)
                      : const Color(0xFFF1F5F9),
                  child: Icon(
                    item['icon'] as IconData,
                    color: isReady
                        ? const Color(0xFF0D9488)
                        : const Color(0xFF64748B),
                  ),
                ),
                title: Text(item['title'] as String),
                subtitle: Text(item['sub'] as String),
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isReady
                        ? const Color(0xFFE6FFFA)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    isReady ? '다음 단계' : '후속 구현',
                    style: TextStyle(
                      color: isReady
                          ? const Color(0xFF0F766E)
                          : const Color(0xFF64748B),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
