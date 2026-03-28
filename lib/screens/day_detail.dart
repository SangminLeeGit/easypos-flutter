import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/dashboard_model.dart';
import '../services/api.dart';
import '../state/app_state.dart';
import '../widgets/empty_state.dart';
import '../widgets/panel.dart';
import '../widgets/stat_card.dart';

class DayDetailScreen extends StatefulWidget {
  final String date;

  const DayDetailScreen({
    super.key,
    required this.date,
  });

  @override
  State<DayDetailScreen> createState() => _DayDetailScreenState();
}

class _DayDetailScreenState extends State<DayDetailScreen> {
  DayDetailData? _data;
  bool _isLoading = true;
  String _error = '';
  late String _targetDate;

  @override
  void initState() {
    super.initState();
    _targetDate = widget.date;
    _fetchData();
  }

  Future<void> _fetchData() async {
    final baseUrl = context.read<AppState>().apiBaseUrl;
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final raw = await ApiService.fetchJson(baseUrl, '/api/days/$_targetDate');
      if (!mounted) {
        return;
      }
      setState(() {
        _data = DayDetailData(raw);
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

  Future<void> _moveTo(String? targetDate) async {
    if (targetDate == null || targetDate.isEmpty) {
      return;
    }
    setState(() {
      _targetDate = targetDate;
    });
    await _fetchData();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;

    return Scaffold(
      appBar: AppBar(
        title: Text(_targetDate),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error.isNotEmpty
                ? EmptyState(
                    title: '일별 상세를 불러오지 못했습니다.',
                    message: _error,
                    action: FilledButton(
                      onPressed: _fetchData,
                      child: const Text('다시 시도'),
                    ),
                  )
                : data == null || data.error.isNotEmpty
                    ? EmptyState(
                        title: '일별 데이터가 없습니다.',
                        message: data?.error,
                        action: FilledButton(
                          onPressed: _fetchData,
                          child: const Text('새로고침'),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchData,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: data.prevDate == null
                                        ? null
                                        : () => _moveTo(data.prevDate),
                                    icon: const Icon(Icons.chevron_left),
                                    label: const Text('이전 영업일'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: data.nextDate == null
                                        ? null
                                        : () => _moveTo(data.nextDate),
                                    icon: const Icon(Icons.chevron_right),
                                    label: const Text('다음 영업일'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildSummaryGrid(data),
                            const SizedBox(height: 16),
                            Panel(
                              title: '결제수단 구성',
                              subtitle: '당일 매출 기준 비중',
                              child: _buildPaymentMix(data.paymentMix),
                            ),
                            Panel(
                              title: '상위 판매 품목',
                              subtitle: '매출 상위 10개 품목',
                              child: _buildTopItems(data.topItems),
                            ),
                            Panel(
                              title: '영수증 목록',
                              subtitle: 'POS / 결제시간 / 금액',
                              child: _buildBills(data.bills),
                            ),
                          ],
                        ),
                      ),
      ),
    );
  }

  Widget _buildSummaryGrid(DayDetailData data) {
    final summary = data.summary;
    final cards = [
      StatCard(
        label: '총매출',
        value: UiFormat.won(summary['gross_amount'] as num?),
        sub: "순매출 ${UiFormat.won(summary['pure_sales_amount'] as num?)}",
        accent: true,
      ),
      StatCard(
        label: '영수건수',
        value: "${UiFormat.number(summary['receipt_count'] as num?)}건",
        sub: "고객 ${UiFormat.number(summary['customer_count'] as num?)}명",
      ),
      StatCard(
        label: '할인금액',
        value: UiFormat.won(summary['discount_amount'] as num?),
        sub: "부가세 ${UiFormat.won(summary['vat_amount'] as num?)}",
      ),
      StatCard(
        label: '카드 / 현금',
        value:
            "${UiFormat.won(summary['card_amount'] as num?)} / ${UiFormat.won(summary['cash_amount'] as num?)}",
      ),
    ];

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

  Widget _buildPaymentMix(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return const Text(
        '결제수단 데이터가 없습니다.',
        style: TextStyle(color: Color(0xFF64748B)),
      );
    }

    return Column(
      children: items.map((item) {
        final pct = (item['pct'] as num?)?.toDouble() ?? 0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item['method']?.toString() ?? '-',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  Text(
                    "${UiFormat.won(item['amount'] as num?)} · ${pct.toStringAsFixed(1)}%",
                    style: const TextStyle(color: Color(0xFF64748B)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: (pct / 100).clamp(0, 1),
                  backgroundColor: const Color(0xFFE2E8F0),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Color(0xFF0D9488)),
                ),
              ),
            ],
          ),
        );
      }).toList(growable: false),
    );
  }

  Widget _buildTopItems(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return const Text(
        '품목 데이터가 없습니다.',
        style: TextStyle(color: Color(0xFF64748B)),
      );
    }

    final visibleItems = items.take(10).toList(growable: false);
    return Column(
      children: visibleItems.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            radius: 14,
            backgroundColor: const Color.fromRGBO(13, 148, 136, 0.12),
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0D9488),
              ),
            ),
          ),
          title: Text(
            item['item_name']?.toString() ?? '-',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            "수량 ${UiFormat.number(item['total_qty'] as num?)}개",
          ),
          trailing: Text(
            UiFormat.won(item['total_amount'] as num?),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        );
      }).toList(growable: false),
    );
  }

  Widget _buildBills(List<Map<String, dynamic>> bills) {
    if (bills.isEmpty) {
      return const Text(
        '영수증 데이터가 없습니다.',
        style: TextStyle(color: Color(0xFF64748B)),
      );
    }

    final visibleBills = bills.take(12).toList(growable: false);
    return Column(
      children: visibleBills.map((bill) {
        final payTime = (bill['pay_time'] ?? '').toString();
        final hour = payTime.length >= 4
            ? '${payTime.substring(0, 2)}:${payTime.substring(2, 4)}'
            : payTime;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "POS ${bill['pos_no'] ?? '-'} · ${bill['bill_no'] ?? '-'}",
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "$hour · 품목 ${UiFormat.number(bill['item_count'] as num?)}개 · 고객 ${UiFormat.number(bill['customer_count'] as num?)}명",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                UiFormat.won(bill['gross_amount'] as num?),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        );
      }).toList(growable: false),
    );
  }
}
