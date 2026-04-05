import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../widgets/empty_state.dart';

// ─── 모델 ─────────────────────────────────────────────────────────────────────

class _SignageItem {
  String korean;
  String english;
  int price;
  String note;

  _SignageItem({
    required this.korean,
    required this.english,
    required this.price,
    this.note = '',
  });

  factory _SignageItem.fromJson(Map<String, dynamic> j) => _SignageItem(
        korean: (j['korean'] ?? '').toString(),
        english: (j['english'] ?? '').toString(),
        price: (j['price'] is int)
            ? (j['price'] as int)
            : int.tryParse(j['price'].toString()) ?? 0,
        note: (j['note'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {
        'korean': korean,
        'english': english,
        'price': price,
        'note': note.isEmpty ? null : note,
      };

  _SignageItem clone() => _SignageItem(
        korean: korean,
        english: english,
        price: price,
        note: note,
      );
}

class _SignageCategory {
  String id;
  String title;
  String description;
  List<_SignageItem> items;

  _SignageCategory({
    required this.id,
    required this.title,
    this.description = '',
    required this.items,
  });

  factory _SignageCategory.fromJson(Map<String, dynamic> j) => _SignageCategory(
        id: (j['id'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        description: (j['description'] ?? '').toString(),
        items: (j['items'] as List? ?? [])
            .map((e) => _SignageItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description.isEmpty ? null : description,
        'items': items.map((e) => e.toJson()).toList(),
      };

  _SignageCategory clone() => _SignageCategory(
        id: id,
        title: title,
        description: description,
        items: items.map((e) => e.clone()).toList(),
      );
}

class _SignageMenu {
  String shopName;
  String shopNameLine1;
  String shopNameLine2;
  String announcementText;
  List<_SignageCategory> categories;

  _SignageMenu({
    required this.shopName,
    required this.shopNameLine1,
    required this.shopNameLine2,
    required this.announcementText,
    required this.categories,
  });

  factory _SignageMenu.fromJson(Map<String, dynamic> j) {
    final announcement = j['announcement'];
    final text = announcement is Map
        ? (announcement['text'] ?? '').toString()
        : '';
    return _SignageMenu(
      shopName: (j['shopName'] ?? '').toString(),
      shopNameLine1: (j['shopNameLine1'] ?? '').toString(),
      shopNameLine2: (j['shopNameLine2'] ?? '').toString(),
      announcementText: text,
      categories: (j['categories'] as List? ?? [])
          .map((e) => _SignageCategory.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'shopName': shopName,
        'shopNameLine1': shopNameLine1,
        'shopNameLine2': shopNameLine2,
        'announcement': {'text': announcementText},
        'categories': categories.map((e) => e.toJson()).toList(),
      };

  _SignageMenu clone() => _SignageMenu(
        shopName: shopName,
        shopNameLine1: shopNameLine1,
        shopNameLine2: shopNameLine2,
        announcementText: announcementText,
        categories: categories.map((e) => e.clone()).toList(),
      );
}

// ─── 메인 화면 ────────────────────────────────────────────────────────────────

class SignageScreen extends StatefulWidget {
  const SignageScreen({super.key});

  @override
  State<SignageScreen> createState() => _SignageScreenState();
}

class _SignageScreenState extends State<SignageScreen> {
  _SignageMenu? _saved;
  _SignageMenu? _draft;
  bool _loading = true;
  String _error = '';
  bool _pushing = false;
  bool _dirty = false;
  String _successMessage = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final appState = context.read<AppState>();
    setState(() {
      _loading = true;
      _error = '';
      _successMessage = '';
    });
    try {
      final result = await appState.fetchMapParsed<_SignageMenu>(
        '/api/signage/menu',
        parser: _SignageMenu.fromJson,
        cacheTtl: Duration.zero,
      );
      if (!mounted) return;
      setState(() {
        _saved = result.data;
        _draft = result.data.clone();
        _dirty = false;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
    if (_successMessage.isNotEmpty) setState(() => _successMessage = '');
  }

  void _resetDraft() {
    if (_saved == null) return;
    setState(() {
      _draft = _saved!.clone();
      _dirty = false;
      _successMessage = '';
    });
  }

  Future<void> _push() async {
    final draft = _draft;
    if (draft == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('메뉴판에 반영'),
        content: const Text('현재 편집된 내용을 사이니지 서버에 즉시 반영합니다.\n계속하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('반영'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _pushing = true;
      _error = '';
      _successMessage = '';
    });

    try {
      final appState = context.read<AppState>();
      final result = await appState.postJson(
        '/api/signage/menu',
        body: draft.toJson(),
      );
      if (!mounted) return;
      final backup = result['backup'] as String?;
      setState(() {
        _saved = draft.clone();
        _dirty = false;
        _pushing = false;
        _successMessage = backup != null
            ? '메뉴판이 업데이트되었습니다. (백업: ${backup.split('/').last})'
            : '메뉴판이 성공적으로 업데이트되었습니다.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _pushing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF0D9488)));
    }

    if (_error.isNotEmpty && _draft == null) {
      return EmptyState(
        title: '메뉴판 데이터를 불러오지 못했습니다.',
        message: _error,
        action: FilledButton(onPressed: _load, child: const Text('다시 시도')),
      );
    }

    final draft = _draft;
    if (draft == null) {
      return EmptyState(
        title: '데이터 없음',
        action: FilledButton(onPressed: _load, child: const Text('새로고침')),
      );
    }

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            // 오류/성공 배너
            if (_error.isNotEmpty) _Banner(text: _error, isError: true),
            if (_successMessage.isNotEmpty) _Banner(text: _successMessage, isError: false),

            // 가게 정보
            _SectionCard(
              title: '가게 정보',
              child: Column(
                children: [
                  _LabeledField(
                    label: '가게명',
                    value: draft.shopName,
                    onChanged: (v) {
                      draft.shopName = v;
                      _markDirty();
                    },
                  ),
                  const SizedBox(height: 8),
                  _LabeledField(
                    label: '가게명 1줄',
                    value: draft.shopNameLine1,
                    onChanged: (v) {
                      draft.shopNameLine1 = v;
                      _markDirty();
                    },
                  ),
                  const SizedBox(height: 8),
                  _LabeledField(
                    label: '가게명 2줄',
                    value: draft.shopNameLine2,
                    onChanged: (v) {
                      draft.shopNameLine2 = v;
                      _markDirty();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 공지 사항
            _SectionCard(
              title: '공지 사항',
              child: _LabeledField(
                label: '공지 내용',
                value: draft.announcementText,
                maxLines: 3,
                onChanged: (v) {
                  draft.announcementText = v;
                  _markDirty();
                },
              ),
            ),
            const SizedBox(height: 12),

            // 카테고리 목록
            ...draft.categories.asMap().entries.map((entry) {
              final catIdx = entry.key;
              final cat = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _CategoryCard(
                  category: cat,
                  onChanged: _markDirty,
                  onDelete: () => setState(() {
                    draft.categories.removeAt(catIdx);
                    _markDirty();
                  }),
                ),
              );
            }),

            // 카테고리 추가
            OutlinedButton.icon(
              onPressed: () => setState(() {
                draft.categories.add(
                  _SignageCategory(id: '', title: '', items: []),
                );
                _markDirty();
              }),
              icon: const Icon(Icons.add),
              label: const Text('카테고리 추가'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0D9488),
                side: const BorderSide(color: Color(0xFF0D9488)),
              ),
            ),
          ],
        ),

        // 하단 스티키 액션 바
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _ActionBar(
            dirty: _dirty,
            pushing: _pushing,
            onRefresh: _loading || _pushing ? null : _load,
            onReset: _dirty && !_pushing ? _resetDraft : null,
            onPush: _dirty && !_pushing ? _push : null,
          ),
        ),
      ],
    );
  }
}

// ─── 서브 위젯 ────────────────────────────────────────────────────────────────

class _Banner extends StatelessWidget {
  final String text;
  final bool isError;

  const _Banner({required this.text, required this.isError});

  @override
  Widget build(BuildContext context) {
    final bg = isError ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7);
    final border = isError ? const Color(0xFFEF4444) : const Color(0xFF22C55E);
    final fg = isError ? const Color(0xFFB91C1C) : const Color(0xFF15803D);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(color: fg, fontSize: 13)),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _LabeledField extends StatefulWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final int maxLines;

  const _LabeledField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.maxLines = 1,
  });

  @override
  State<_LabeledField> createState() => _LabeledFieldState();
}

class _LabeledFieldState extends State<_LabeledField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_LabeledField old) {
    super.didUpdateWidget(old);
    if (widget.value != _ctrl.text) {
      _ctrl.text = widget.value;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: widget.maxLines > 1
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            widget.label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ),
        Expanded(
          child: TextField(
            controller: _ctrl,
            maxLines: widget.maxLines,
            onChanged: widget.onChanged,
            style: const TextStyle(fontSize: 14),
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── 카테고리 카드 ────────────────────────────────────────────────────────────

class _CategoryCard extends StatelessWidget {
  final _SignageCategory category;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  const _CategoryCard({
    required this.category,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 카테고리 헤더
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _InlineField(
                        value: category.title,
                        placeholder: '카테고리 제목',
                        width: 130,
                        bold: true,
                        onChanged: (v) {
                          category.title = v;
                          onChanged();
                        },
                      ),
                      _InlineField(
                        value: category.id,
                        placeholder: 'id (영문)',
                        width: 90,
                        onChanged: (v) {
                          category.id = v;
                          onChanged();
                        },
                      ),
                      _InlineField(
                        value: category.description,
                        placeholder: '설명 (선택)',
                        width: 150,
                        onChanged: (v) {
                          category.description = v;
                          onChanged();
                        },
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  tooltip: '카테고리 삭제',
                  color: const Color(0xFF94A3B8),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // 컬럼 헤더
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Expanded(flex: 3, child: _ColumnLabel('한글명')),
                SizedBox(width: 6),
                Expanded(flex: 3, child: _ColumnLabel('English')),
                SizedBox(width: 6),
                SizedBox(width: 80, child: _ColumnLabel('가격')),
                SizedBox(width: 6),
                Expanded(flex: 2, child: _ColumnLabel('비고')),
                SizedBox(width: 32),
              ],
            ),
          ),

          // 아이템 목록
          ...category.items.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            return _ItemRow(
              item: item,
              onChanged: onChanged,
              onDelete: () {
                category.items.removeAt(idx);
                onChanged();
              },
            );
          }),

          // 품목 추가 버튼
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextButton.icon(
              onPressed: () {
                category.items.add(_SignageItem(korean: '', english: '', price: 0));
                onChanged();
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('품목 추가', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF0D9488),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColumnLabel extends StatelessWidget {
  final String text;
  const _ColumnLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
    );
  }
}

// ─── 아이템 행 ────────────────────────────────────────────────────────────────

class _ItemRow extends StatelessWidget {
  final _SignageItem item;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  const _ItemRow({
    required this.item,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: _ItemTextField(
              value: item.korean,
              placeholder: '한글명',
              onChanged: (v) {
                item.korean = v;
                onChanged();
              },
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 3,
            child: _ItemTextField(
              value: item.english,
              placeholder: 'English',
              onChanged: (v) {
                item.english = v;
                onChanged();
              },
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 80,
            child: _PriceField(
              value: item.price,
              onChanged: (v) {
                item.price = v;
                onChanged();
              },
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: _ItemTextField(
              value: item.note,
              placeholder: '비고',
              onChanged: (v) {
                item.note = v;
                onChanged();
              },
            ),
          ),
          SizedBox(
            width: 32,
            child: IconButton(
              icon: const Icon(Icons.close, size: 16),
              tooltip: '삭제',
              color: const Color(0xFF94A3B8),
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemTextField extends StatefulWidget {
  final String value;
  final String placeholder;
  final ValueChanged<String> onChanged;

  const _ItemTextField({
    required this.value,
    required this.placeholder,
    required this.onChanged,
  });

  @override
  State<_ItemTextField> createState() => _ItemTextFieldState();
}

class _ItemTextFieldState extends State<_ItemTextField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_ItemTextField old) {
    super.didUpdateWidget(old);
    if (widget.value != _ctrl.text) {
      // 외부에서 reset된 경우만 갱신 (커서 보존)
      _ctrl.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      onChanged: widget.onChanged,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: widget.placeholder,
        isDense: true,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
    );
  }
}

class _PriceField extends StatefulWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _PriceField({required this.value, required this.onChanged});

  @override
  State<_PriceField> createState() => _PriceFieldState();
}

class _PriceFieldState extends State<_PriceField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value.toString());
  }

  @override
  void didUpdateWidget(_PriceField old) {
    super.didUpdateWidget(old);
    if (widget.value.toString() != _ctrl.text) {
      _ctrl.text = widget.value.toString();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.right,
      onChanged: (v) {
        final n = int.tryParse(v);
        if (n != null && n >= 0) widget.onChanged(n);
      },
      style: const TextStyle(fontSize: 13),
      decoration: const InputDecoration(
        hintText: '0',
        isDense: true,
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
    );
  }
}

class _InlineField extends StatefulWidget {
  final String value;
  final String placeholder;
  final double width;
  final bool bold;
  final ValueChanged<String> onChanged;

  const _InlineField({
    required this.value,
    required this.placeholder,
    required this.width,
    required this.onChanged,
    this.bold = false,
  });

  @override
  State<_InlineField> createState() => _InlineFieldState();
}

class _InlineFieldState extends State<_InlineField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_InlineField old) {
    super.didUpdateWidget(old);
    if (widget.value != _ctrl.text) {
      _ctrl.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: TextField(
        controller: _ctrl,
        onChanged: widget.onChanged,
        style: TextStyle(
          fontSize: widget.bold ? 14 : 12,
          fontWeight: widget.bold ? FontWeight.w600 : FontWeight.normal,
        ),
        decoration: InputDecoration(
          hintText: widget.placeholder,
          isDense: true,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        ),
      ),
    );
  }
}

// ─── 하단 액션 바 ─────────────────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  final bool dirty;
  final bool pushing;
  final VoidCallback? onRefresh;
  final VoidCallback? onReset;
  final VoidCallback? onPush;

  const _ActionBar({
    required this.dirty,
    required this.pushing,
    required this.onRefresh,
    required this.onReset,
    required this.onPush,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: dirty ? const Color(0xFF0D9488) : const Color(0xFFE2E8F0),
            width: dirty ? 2 : 1,
          ),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            dirty ? '미저장 변경 사항 있음' : '저장된 상태',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: dirty ? const Color(0xFF0F766E) : const Color(0xFF64748B),
            ),
          ),
          const Spacer(),
          OutlinedButton(
            onPressed: onRefresh,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('새로고침', style: TextStyle(fontSize: 13)),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: onReset,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('되돌리기', style: TextStyle(fontSize: 13)),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onPush,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0D9488),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              pushing ? '반영 중...' : '메뉴판에 반영',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
