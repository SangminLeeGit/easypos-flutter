import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/menu_workspace_models.dart';
import '../state/app_state.dart';
import '../widgets/cache_notice.dart';
import '../widgets/empty_state.dart';
import '../widgets/panel.dart';
import '../widgets/stat_card.dart';

// ─── Models for product browser ──────────────────────────────────────────────

class _ProductRow {
  final String itemCode;
  final String itemName;
  final int? salePrice;
  final String category;

  const _ProductRow({
    required this.itemCode,
    required this.itemName,
    this.salePrice,
    this.category = '',
  });

  factory _ProductRow.fromRegistration(Map<String, dynamic> j) => _ProductRow(
        itemCode: (j['상품코드'] ?? j['item_code'] ?? '').toString(),
        itemName: (j['상품명'] ?? j['item_name'] ?? '').toString(),
        salePrice: _parseInt(j['판매가'] ?? j['target_price'] ?? j['sale_price']),
        category: [
          (j['대분류명'] ?? j['major_category'] ?? '').toString(),
          (j['중분류명'] ?? j['middle_category'] ?? '').toString(),
        ].where((s) => s.isNotEmpty).join(' > '),
      );

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString().replaceAll(',', ''));
  }
}

// ─── Main screen ─────────────────────────────────────────────────────────────

class MenuWorkspaceScreen extends StatefulWidget {
  const MenuWorkspaceScreen({super.key});

  @override
  State<MenuWorkspaceScreen> createState() => _MenuWorkspaceScreenState();
}

class _MenuWorkspaceScreenState extends State<MenuWorkspaceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _workspaceRefreshTick = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _workspaceRefreshTick.dispose();
    super.dispose();
  }

  void _onPriceChangeRegistered() {
    _workspaceRefreshTick.value++;
    _tabController.animateTo(1);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '메뉴 선택'),
            Tab(text: '작업 목록'),
          ],
          labelColor: const Color(0xFF0D9488),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFF0D9488),
        ),
        const Divider(height: 1),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _ProductBrowserTab(
                onPriceChangeRegistered: _onPriceChangeRegistered,
              ),
              _WorkspaceTab(
                refreshNotifier: _workspaceRefreshTick,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Tab 1: Workspace entries ─────────────────────────────────────────────────

class _WorkspaceTab extends StatefulWidget {
  final ValueNotifier<int>? refreshNotifier;
  const _WorkspaceTab({this.refreshNotifier});

  @override
  State<_WorkspaceTab> createState() => _WorkspaceTabState();
}

class _WorkspaceTabState extends State<_WorkspaceTab>
    with AutomaticKeepAliveClientMixin {
  WorkspaceSnapshot? _snapshot;
  bool _isLoading = true;
  String _error = '';
  bool _fromCache = false;
  DateTime? _cachedAt;
  String _filterStatus = 'all';
  String _filterKind = 'all';
  String _searchQuery = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    widget.refreshNotifier?.addListener(_onRefreshRequest);
    _load();
  }

  @override
  void dispose() {
    widget.refreshNotifier?.removeListener(_onRefreshRequest);
    super.dispose();
  }

  void _onRefreshRequest() {
    if (mounted && !_isLoading) _load(force: true);
  }

  Future<void> _load({bool force = false}) async {
    final appState = context.read<AppState>();
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final response = await appState.fetchMapParsed(
        '/api/menu-workspace',
        parser: WorkspaceSnapshot.fromJson,
        cacheTtl: force ? Duration.zero : const Duration(minutes: 5),
      );
      if (!mounted) return;
      setState(() {
        _snapshot = response.data;
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

  List<MenuEntry> get _filteredEntries {
    var entries = _snapshot?.entries ?? const <MenuEntry>[];
    if (_filterStatus != 'all') {
      entries = entries.where((e) => e.status == _filterStatus).toList();
    }
    if (_filterKind != 'all') {
      entries = entries.where((e) => e.kind == _filterKind).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      entries = entries
          .where((e) =>
              e.itemName.toLowerCase().contains(q) ||
              e.itemCode.toLowerCase().contains(q))
          .toList();
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error.isNotEmpty) {
      return EmptyState(
        title: '메뉴 워크스페이스를 불러오지 못했습니다.',
        message: _error,
        action: FilledButton(onPressed: _load, child: const Text('다시 시도')),
      );
    }

    final snapshot = _snapshot;
    if (snapshot == null) {
      return EmptyState(
        title: '데이터 없음',
        action: FilledButton(onPressed: _load, child: const Text('새로고침')),
      );
    }

    final entries = _filteredEntries;
    final s = snapshot.summary;
    final appState = context.watch<AppState>();
    final hasReady = (snapshot.statusCounts['ready'] ?? 0) > 0;

    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_fromCache && _cachedAt != null) ...[
                    CacheNotice(cachedAt: _cachedAt),
                    const SizedBox(height: 12),
                  ],
                  _MetricGrid(
                    cards: [
                      StatCard(
                          label: '전체 항목',
                          value: '${s.totalEntries}개',
                          accent: true),
                      StatCard(label: '적용 준비', value: '${s.readyCount}개'),
                      StatCard(label: '신규 등록', value: '${s.newItemCount}개'),
                      StatCard(
                          label: '가격 변동',
                          value: _wonSigned(s.priceDeltaTotal)),
                    ],
                  ),
                  if (hasReady && appState.hasOperatorAccess) ...[
                    const SizedBox(height: 12),
                    _ApplyReadyBanner(onApplied: _load),
                  ],
                  const SizedBox(height: 16),
                  _FilterBar(
                    filterStatus: _filterStatus,
                    filterKind: _filterKind,
                    onStatusChanged: (v) => setState(() => _filterStatus = v),
                    onKindChanged: (v) => setState(() => _filterKind = v),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: const InputDecoration(
                      hintText: '품목명 또는 코드 검색',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          if (entries.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Text(
                  '조건에 맞는 항목이 없습니다.',
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverList.separated(
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  return _MenuEntryCard(
                    entry: entries[index],
                    onTap: () => _showEntryDetail(context, entries[index]),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  void _showEntryDetail(BuildContext context, MenuEntry entry) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            MenuEntryDetailScreen(entry: entry, onUpdated: _load),
      ),
    );
  }
}

// ─── Tab 2: Product Browser ───────────────────────────────────────────────────

class _ProductBrowserTab extends StatefulWidget {
  final VoidCallback? onPriceChangeRegistered;
  const _ProductBrowserTab({this.onPriceChangeRegistered});

  @override
  State<_ProductBrowserTab> createState() => _ProductBrowserTabState();
}

class _ProductBrowserTabState extends State<_ProductBrowserTab>
    with AutomaticKeepAliveClientMixin {
  List<_ProductRow> _products = [];
  bool _isLoading = true;
  String _loadError = '';
  bool _hasSearched = false;

  final _searchController = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final appState = context.read<AppState>();
    setState(() {
      _isLoading = true;
      _loadError = '';
      _hasSearched = false;
    });
    try {
      final result = await appState.fetchMapParsed<Map<String, dynamic>>(
        '/api/menu-workspace/product-registration',
        params: {'query': '', 'refresh': 'false', 'cache_only': 'true'},
        parser: (j) => j,
        cacheTtl: const Duration(minutes: 10),
      );
      if (!mounted) return;
      final rows = (result.data['rows'] as List? ?? [])
          .map((e) =>
              _ProductRow.fromRegistration(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _products = rows;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _search(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      _searchController.clear();
      _loadAll();
      return;
    }
    final appState = context.read<AppState>();
    setState(() {
      _isLoading = true;
      _loadError = '';
      _hasSearched = true;
    });
    try {
      final result = await appState.fetchMapParsed<Map<String, dynamic>>(
        '/api/menu-workspace/product-registration',
        params: {'query': q, 'refresh': 'false', 'cache_only': 'true'},
        parser: (j) => j,
        cacheTtl: const Duration(minutes: 10),
      );
      if (!mounted) return;
      final rows = (result.data['rows'] as List? ?? [])
          .map((e) =>
              _ProductRow.fromRegistration(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _products = rows;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _isLoading = false;
      });
    }
  }

  void _openPriceChangeSheet(_ProductRow product) {
    final appState = context.read<AppState>();
    if (!appState.hasOperatorAccess) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _QuickPriceChangeSheet(
        product: product,
        appState: appState,
        onCreated: () {
          Navigator.of(context).pop();
          widget.onPriceChangeRegistered?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '${product.itemName} 가격변경이 준비완료로 등록됐습니다.'),
              action: SnackBarAction(
                label: '작업 목록 확인',
                onPressed: () {},
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final appState = context.watch<AppState>();
    final isOperator = appState.hasOperatorAccess;
    final list = _products;
    final isLoading = _isLoading;
    final error = _loadError;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'POS 상품명 또는 코드 검색',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _loadAll();
                      },
                    )
                  : null,
              isDense: true,
              border: const OutlineInputBorder(),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: _search,
            onChanged: (v) {
              setState(() {});
              if (v.isEmpty) _loadAll();
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Text(
                _hasSearched
                    ? 'POS 상품 검색 결과 (${_products.length}건)'
                    : '전체 메뉴 (${_products.length}건)',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Color(0xFF64748B),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _loadAll,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('새로고침',
                    style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : error.isNotEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(error,
                            style: const TextStyle(
                                color: Color(0xFFDC2626))),
                      ),
                    )
                  : list.isEmpty
                      ? Center(
                          child: Text(
                            _hasSearched
                                ? '검색 결과가 없습니다.'
                                : '상품 목록이 없습니다.',
                            style: const TextStyle(
                                color: Color(0xFF64748B)),
                          ),
                        )
                      : ListView.separated(
                          padding:
                              const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: list.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 6),
                          itemBuilder: (_, i) => _ProductCard(
                            product: list[i],
                            onTap: isOperator
                                ? () => _openPriceChangeSheet(list[i])
                                : null,
                          ),
                        ),
        ),
        if (!isOperator)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            color: const Color(0xFFFFF7ED),
            child: const Text(
              'operator 이상 권한이 있어야 가격변경을 등록할 수 있습니다.',
              style:
                  TextStyle(fontSize: 12, color: Color(0xFF92400E)),
            ),
          ),
      ],
    );
  }
}

// ─── Product Card ─────────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final _ProductRow product;
  final VoidCallback? onTap;

  const _ProductCard({
    required this.product,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        leading: const Icon(Icons.inventory_2_outlined,
            size: 20, color: Color(0xFF94A3B8)),
        title: Text(
          product.itemName,
          style: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          [
            if (product.itemCode.isNotEmpty) product.itemCode,
            if (product.category.isNotEmpty) product.category,
          ].join(' · '),
          style: const TextStyle(fontSize: 12),
        ),
        trailing: product.salePrice != null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${_won(product.salePrice!)}원',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  if (onTap != null)
                    const Text(
                      '탭하여 변경',
                      style: TextStyle(
                          fontSize: 10, color: Color(0xFF0D9488)),
                    ),
                ],
              )
            : onTap != null
                ? const Text('탭하여 변경',
                    style: TextStyle(
                        fontSize: 11, color: Color(0xFF0D9488)))
                : null,
      ),
    );
  }
}

// ─── Quick Price Change Sheet ─────────────────────────────────────────────────

class _QuickPriceChangeSheet extends StatefulWidget {
  final _ProductRow product;
  final AppState appState;
  final VoidCallback onCreated;

  const _QuickPriceChangeSheet({
    required this.product,
    required this.appState,
    required this.onCreated,
  });

  @override
  State<_QuickPriceChangeSheet> createState() =>
      _QuickPriceChangeSheetState();
}

class _QuickPriceChangeSheetState
    extends State<_QuickPriceChangeSheet> {
  final _targetController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isSubmitting = false;
  String _error = '';

  @override
  void dispose() {
    _targetController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final targetText =
        _targetController.text.replaceAll(',', '');
    final targetPrice = int.tryParse(targetText);

    if (targetPrice == null || targetPrice < 0) {
      setState(() => _error = '변경할 가격을 올바르게 입력하세요.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = '';
    });

    try {
      final body = <String, dynamic>{
        'item_name': widget.product.itemName,
        'target_price': targetPrice,
      };
      if (widget.product.itemCode.isNotEmpty) {
        body['item_code'] = widget.product.itemCode;
      }
      if (widget.product.salePrice != null) {
        body['current_price'] = widget.product.salePrice;
      }
      final notes = _notesController.text.trim();
      if (notes.isNotEmpty) body['notes'] = notes;

      final result = await widget.appState
          .postJson('/api/menu-workspace/price-change', body: body);
      // 자동으로 '준비완료(ready)' 상태로 승격 → apply-ready 배너 즉시 활성화
      final entryId = result['id'];
      if (entryId is int) {
        await widget.appState.postJson(
          '/api/menu-workspace/entries/$entryId',
          body: {'status': 'ready'},
          method: 'PATCH',
        );
      }
      if (!mounted) return;
      widget.onCreated();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16,
          20,
          16,
          MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.price_change_outlined,
                  color: Color(0xFF0D9488), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.itemName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16),
                    ),
                    if (p.itemCode.isNotEmpty)
                      Text(p.itemCode,
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B))),
                  ],
                ),
              ),
              if (p.salePrice != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('현재가',
                        style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B))),
                    Text(
                      '${_won(p.salePrice!)}원',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Divider(),
          // 상품코드 없음 경고
          if (p.itemCode.isEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                border: Border.all(color: const Color(0xFFF59E0B)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_outlined,
                      size: 16, color: Color(0xFF92400E)),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '이 상품은 POS 상품코드가 없어 등록은 되지만 POS에 자동 적용할 수 없습니다.',
                      style: TextStyle(
                          fontSize: 12, color: Color(0xFF92400E)),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _targetController,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              labelText: '변경할 가격 *',
              suffixText: '원',
              border: const OutlineInputBorder(),
              hintText:
                  p.salePrice != null ? '현재 ${_won(p.salePrice!)}원' : null,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: '메모 (선택)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(_error,
                style: const TextStyle(
                    color: Color(0xFFDC2626), fontSize: 13)),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isSubmitting ? null : _submit,
            icon: const Icon(Icons.check),
            label: Text(
                _isSubmitting ? '등록 중...' : '가격변경 항목 등록'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0D9488),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Entry Detail Screen ──────────────────────────────────────────────────────

class MenuEntryDetailScreen extends StatelessWidget {
  final MenuEntry entry;
  final VoidCallback? onUpdated;

  const MenuEntryDetailScreen(
      {super.key, required this.entry, this.onUpdated});

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final appState = context.read<AppState>();
    final canEdit = appState.hasOperatorAccess;

    return Scaffold(
      appBar: AppBar(
        title: Text(e.itemName),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
              height: 1, color: const Color(0xFFE2E8F0)),
        ),
        actions: [
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _showStatusSheet(context, e),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Panel(
              title: '기본 정보',
              child: Column(
                children: [
                  _InfoRow(label: '품목명', value: e.itemName),
                  _InfoRow(
                      label: '품목코드',
                      value: e.itemCode.isEmpty ? '-' : e.itemCode),
                  _InfoRow(
                      label: '분류',
                      value: e.categoryHint.isEmpty
                          ? '-'
                          : e.categoryHint),
                  _InfoRow(
                      label: '상태',
                      value: _statusLabel(e.status)),
                  _InfoRow(
                      label: '종류', value: _kindLabel(e.kind)),
                  _InfoRow(
                      label: '출처',
                      value: e.source.isEmpty ? '-' : e.source),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (e.kind == 'price_update') ...[
              Panel(
                title: '가격 정보',
                child: Column(
                  children: [
                    _InfoRow(
                      label: '현재 가격',
                      value: e.currentPrice == null
                          ? '-'
                          : '${_won(e.currentPrice!)}원',
                    ),
                    _InfoRow(
                      label: '목표 가격',
                      value: e.targetPrice == null
                          ? '-'
                          : '${_won(e.targetPrice!)}원',
                    ),
                    _InfoRow(
                      label: '변동',
                      value: e.targetPrice == null
                          ? '-'
                          : '${_wonSigned(e.priceDelta)}원',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (e.notes.isNotEmpty)
              Panel(
                title: '메모',
                child: Text(e.notes),
              ),
          ],
        ),
      ),
    );
  }

  void _showStatusSheet(BuildContext context, MenuEntry e) {
    final appState = context.read<AppState>();
    showModalBottomSheet(
      context: context,
      builder: (_) => _StatusUpdateSheet(
        entry: e,
        appState: appState,
        onUpdated: () {
          Navigator.of(context).pop();
          onUpdated?.call();
        },
      ),
    );
  }
}

// ─── Status Update Sheet ──────────────────────────────────────────────────────

class _StatusUpdateSheet extends StatefulWidget {
  final MenuEntry entry;
  final AppState appState;
  final VoidCallback onUpdated;

  const _StatusUpdateSheet({
    required this.entry,
    required this.appState,
    required this.onUpdated,
  });

  @override
  State<_StatusUpdateSheet> createState() => _StatusUpdateSheetState();
}

class _StatusUpdateSheetState extends State<_StatusUpdateSheet> {
  String _selectedStatus = '';
  int? _newTargetPrice;
  late final TextEditingController _targetPriceController;
  bool _isSubmitting = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.entry.status;
    _targetPriceController = TextEditingController(
      text: widget.entry.targetPrice?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _targetPriceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedStatus == widget.entry.status &&
        (_newTargetPrice == null ||
            _newTargetPrice == widget.entry.targetPrice)) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = '';
    });
    try {
      final body = <String, dynamic>{'status': _selectedStatus};
      if (_newTargetPrice != null) body['target_price'] = _newTargetPrice;
      await widget.appState.postJson(
        '/api/menu-workspace/entries/${widget.entry.id}',
        body: body,
        method: 'PATCH',
      );
      if (!mounted) return;
      widget.onUpdated();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const statuses = ['draft', 'reviewed', 'ready', 'done'];
    const labels = ['작성중', '검토됨', '준비완료', '완료'];

    return Padding(
      padding: EdgeInsets.fromLTRB(
          16,
          20,
          16,
          MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '편집: ${widget.entry.itemName}',
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 12),
          RadioGroup<String>(
            groupValue: _selectedStatus,
            onChanged: (v) =>
                setState(() => _selectedStatus = v ?? _selectedStatus),
            child: Column(
              children: List.generate(statuses.length, (i) {
                return RadioListTile<String>(
                  title: Text(labels[i]),
                  value: statuses[i],
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                );
              }),
            ),
          ),
          if (widget.entry.kind == 'price_update') ...[
            const SizedBox(height: 8),
            TextField(
              controller: _targetPriceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '목표 가격 (원)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) {
                final parsed =
                    int.tryParse(v.replaceAll(',', ''));
                setState(() => _newTargetPrice = parsed);
              },
            ),
          ],
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(_error,
                style: const TextStyle(
                    color: Color(0xFFDC2626), fontSize: 13)),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            child: Text(_isSubmitting ? '저장 중...' : '저장'),
          ),
        ],
      ),
    );
  }
}

// ─── Filter Bar ───────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final String filterStatus;
  final String filterKind;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onKindChanged;

  const _FilterBar({
    required this.filterStatus,
    required this.filterKind,
    required this.onStatusChanged,
    required this.onKindChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChipWidget(
              label: '전체',
              value: 'all',
              groupValue: filterStatus,
              onSelected: onStatusChanged),
          const SizedBox(width: 6),
          _FilterChipWidget(
              label: '작성중',
              value: 'draft',
              groupValue: filterStatus,
              onSelected: onStatusChanged),
          const SizedBox(width: 6),
          _FilterChipWidget(
              label: '검토됨',
              value: 'reviewed',
              groupValue: filterStatus,
              onSelected: onStatusChanged),
          const SizedBox(width: 6),
          _FilterChipWidget(
              label: '준비완료',
              value: 'ready',
              groupValue: filterStatus,
              onSelected: onStatusChanged),
          const SizedBox(width: 6),
          _FilterChipWidget(
              label: '완료',
              value: 'done',
              groupValue: filterStatus,
              onSelected: onStatusChanged),
          const SizedBox(width: 16),
          _FilterChipWidget(
              label: '전체 종류',
              value: 'all',
              groupValue: filterKind,
              onSelected: onKindChanged),
          const SizedBox(width: 6),
          _FilterChipWidget(
              label: '가격변경',
              value: 'price_update',
              groupValue: filterKind,
              onSelected: onKindChanged),
          const SizedBox(width: 6),
          _FilterChipWidget(
              label: '신규등록',
              value: 'new_item',
              groupValue: filterKind,
              onSelected: onKindChanged),
        ],
      ),
    );
  }
}

class _FilterChipWidget extends StatelessWidget {
  final String label;
  final String value;
  final String groupValue;
  final ValueChanged<String> onSelected;

  const _FilterChipWidget({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(value),
      selectedColor: const Color.fromRGBO(13, 148, 136, 0.15),
      checkmarkColor: const Color(0xFF0D9488),
    );
  }
}

// ─── Workspace Entry Cards ────────────────────────────────────────────────────

class _MenuEntryCard extends StatelessWidget {
  final MenuEntry entry;
  final VoidCallback onTap;

  const _MenuEntryCard({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final e = entry;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        leading: _StatusBadge(status: e.status),
        title: Row(
          children: [
            Expanded(
                child: Text(e.itemName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700))),
            _KindBadge(kind: e.kind),
          ],
        ),
        subtitle: Text(
          e.itemCode.isEmpty
              ? e.categoryHint
              : '${e.itemCode}${e.categoryHint.isNotEmpty ? ' · ${e.categoryHint}' : ''}',
        ),
        trailing: e.kind == 'price_update' && e.targetPrice != null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('→ ${_won(e.targetPrice!)}원',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700)),
                  if (e.currentPrice != null)
                    Text(
                      _wonSigned(e.priceDelta),
                      style: TextStyle(
                        fontSize: 11,
                        color: e.priceDelta >= 0
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFDC2626),
                      ),
                    ),
                ],
              )
            : null,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      'draft' => (const Color(0xFF64748B), '작성'),
      'reviewed' => (const Color(0xFF2563EB), '검토'),
      'ready' => (const Color(0xFF0D9488), '준비'),
      'done' => (const Color(0xFF16A34A), '완료'),
      _ => (const Color(0xFF94A3B8), status),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color)),
    );
  }
}

class _KindBadge extends StatelessWidget {
  final String kind;
  const _KindBadge({required this.kind});

  @override
  Widget build(BuildContext context) {
    final label = switch (kind) {
      'price_update' => '가격',
      'new_item' => '신규',
      _ => kind,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 11, color: Color(0xFF64748B))),
    );
  }
}

// ─── Apply-Ready Banner ───────────────────────────────────────────────────────

class _ApplyReadyBanner extends StatefulWidget {
  final VoidCallback onApplied;
  const _ApplyReadyBanner({required this.onApplied});

  @override
  State<_ApplyReadyBanner> createState() => _ApplyReadyBannerState();
}

class _ApplyReadyBannerState extends State<_ApplyReadyBanner> {
  bool _isApplying = false;

  Future<void> _apply({required bool execute}) async {
    final appState = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isApplying = true);
    try {
      final result = await appState.postJson(
        '/api/menu-workspace/apply-ready',
        body: {
          'execute': execute,
          'reason': execute ? 'mobile-apply' : ''
        },
      );
      if (!mounted) return;
      // 응답: {"apply_result": {"success_count": ..., "items": [...]}, "skipped": [...]}
      final applyResult = result['apply_result'] as Map? ?? {};
      final skippedList = result['skipped'] as List? ?? [];
      final applied = applyResult['success_count'] ?? 0;
      final failed = applyResult['failed_count'] ?? 0;
      final skippedCount = skippedList.length;

      final parts = <String>[
        if (execute) '$applied건 적용 완료' else '[미리보기] $applied건 적용 예정',
        if (failed > 0) '$failed건 실패',
        if (skippedCount > 0) '$skippedCount건 건너눠(상품코드 없음)',
      ];
      messenger.showSnackBar(SnackBar(
        content: Text(parts.join(' · ')),
        duration: const Duration(seconds: 4),
      ));
      if (execute && (applied as int) > 0) widget.onApplied();
    } catch (e) {
      if (!mounted) return;
      // ApiException 메시지에서 detail 추출 (e.g. '상품코드와 목표가...')
      final msg = e.toString().replaceFirst('ApiException: ', '');
      messenger.showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFDC2626),
        duration: const Duration(seconds: 5),
      ));
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(13, 148, 136, 0.08),
        border: Border.all(color: const Color(0xFF0D9488)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.rocket_launch_outlined,
              color: Color(0xFF0D9488), size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('준비완료 항목이 있습니다.',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A))),
          ),
          OutlinedButton(
            onPressed:
                _isApplying ? null : () => _apply(execute: false),
            style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact),
            child: const Text('미리보기'),
          ),
          const SizedBox(width: 6),
          FilledButton(
            onPressed: _isApplying
                ? null
                : () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('가격 적용'),
                        content: const Text(
                            '준비완료 상태의 가격변경 항목을 POS에 실제 반영합니다.\n계속하시겠습니까?'),
                        actions: [
                          TextButton(
                              onPressed: () =>
                                  Navigator.of(ctx).pop(false),
                              child: const Text('취소')),
                          FilledButton(
                              onPressed: () =>
                                  Navigator.of(ctx).pop(true),
                              child: const Text('적용')),
                        ],
                      ),
                    );
                    if (confirmed == true) _apply(execute: true);
                  },
            style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8),
                backgroundColor: const Color(0xFF0D9488),
                visualDensity: VisualDensity.compact),
            child: Text(_isApplying ? '적용 중...' : 'POS 적용'),
          ),
        ],
      ),
    );
  }
}

// ─── Metric Grid ──────────────────────────────────────────────────────────────

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
          children: cards
              .map((c) => SizedBox(width: width, child: c))
              .toList(growable: false),
        );
      },
    );
  }
}

// ─── Info Row ─────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style:
                    const TextStyle(color: Color(0xFF64748B))),
          ),
          Expanded(
            child: Text(value,
                style:
                    const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

String _statusLabel(String s) => switch (s) {
      'draft' => '작성중',
      'reviewed' => '검토됨',
      'ready' => '준비완료',
      'done' => '완료',
      _ => s,
    };

String _kindLabel(String k) => switch (k) {
      'price_update' => '가격 변경',
      'new_item' => '신규 등록',
      _ => k,
    };

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

String _wonSigned(int value) {
  final sign = value >= 0 ? '+' : '';
  return '$sign${_won(value)}';
}
