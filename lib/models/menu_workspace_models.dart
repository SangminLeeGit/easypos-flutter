// Models for the menu workspace (메뉴 워크스페이스) feature.

class MenuEntry {
  final int id;
  final String kind;
  final String status;
  final String itemCode;
  final String itemName;
  final int? currentPrice;
  final int? targetPrice;
  final String categoryHint;
  final String majorCategory;
  final String middleCategory;
  final String minorCategory;
  final String unitName;
  final String taxMode;
  final String useMode;
  final String stockMode;
  final String barcode;
  final String description;
  final int? costPrice;
  final int? supplyPrice;
  final String notes;
  final String source;
  final String createdAt;
  final String updatedAt;

  const MenuEntry({
    required this.id,
    required this.kind,
    required this.status,
    required this.itemCode,
    required this.itemName,
    this.currentPrice,
    this.targetPrice,
    required this.categoryHint,
    required this.majorCategory,
    required this.middleCategory,
    required this.minorCategory,
    required this.unitName,
    required this.taxMode,
    required this.useMode,
    required this.stockMode,
    required this.barcode,
    required this.description,
    this.costPrice,
    this.supplyPrice,
    required this.notes,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MenuEntry.fromJson(Map<String, dynamic> json) {
    return MenuEntry(
      id: _asInt(json['id']),
      kind: _asString(json['kind']),
      status: _asString(json['status']),
      itemCode: _asString(json['item_code']),
      itemName: _asString(json['item_name']),
      currentPrice: json['current_price'] == null ? null : _asInt(json['current_price']),
      targetPrice: json['target_price'] == null ? null : _asInt(json['target_price']),
      categoryHint: _asString(json['category_hint']),
      majorCategory: _asString(json['major_category']),
      middleCategory: _asString(json['middle_category']),
      minorCategory: _asString(json['minor_category']),
      unitName: _asString(json['unit_name']),
      taxMode: _asString(json['tax_mode']),
      useMode: _asString(json['use_mode']),
      stockMode: _asString(json['stock_mode']),
      barcode: _asString(json['barcode']),
      description: _asString(json['description']),
      costPrice: json['cost_price'] == null ? null : _asInt(json['cost_price']),
      supplyPrice: json['supply_price'] == null ? null : _asInt(json['supply_price']),
      notes: _asString(json['notes']),
      source: _asString(json['source']),
      createdAt: _asString(json['created_at']),
      updatedAt: _asString(json['updated_at']),
    );
  }

  int get priceDelta => (targetPrice ?? 0) - (currentPrice ?? 0);
}

class WorkspaceSnapshotSummary {
  final int totalEntries;
  final int priceDeltaTotal;
  final int newItemCount;
  final int readyCount;

  const WorkspaceSnapshotSummary({
    required this.totalEntries,
    required this.priceDeltaTotal,
    required this.newItemCount,
    required this.readyCount,
  });

  factory WorkspaceSnapshotSummary.fromJson(Map<String, dynamic> json) {
    return WorkspaceSnapshotSummary(
      totalEntries: _asInt(json['total_entries']),
      priceDeltaTotal: _asInt(json['price_delta_total']),
      newItemCount: _asInt(json['new_item_count']),
      readyCount: _asInt(json['ready_count']),
    );
  }
}

class WorkspaceSnapshot {
  final List<MenuEntry> entries;
  final Map<String, int> statusCounts;
  final Map<String, int> kindCounts;
  final WorkspaceSnapshotSummary summary;

  const WorkspaceSnapshot({
    required this.entries,
    required this.statusCounts,
    required this.kindCounts,
    required this.summary,
  });

  factory WorkspaceSnapshot.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['status_counts'];
    final statusCounts = <String, int>{};
    if (rawStatus is Map) {
      rawStatus.forEach((k, v) => statusCounts[k.toString()] = _asInt(v));
    }

    final rawKind = json['kind_counts'];
    final kindCounts = <String, int>{};
    if (rawKind is Map) {
      rawKind.forEach((k, v) => kindCounts[k.toString()] = _asInt(v));
    }

    return WorkspaceSnapshot(
      entries: _asListOfMaps(json['entries'])
          .map(MenuEntry.fromJson)
          .toList(growable: false),
      statusCounts: statusCounts,
      kindCounts: kindCounts,
      summary: WorkspaceSnapshotSummary.fromJson(_asMap(json['summary'])),
    );
  }
}

class PriceApplyRun {
  final String taskId;
  final String status;
  final int totalItems;
  final int appliedCount;
  final int failedCount;
  final String startedAt;
  final String finishedAt;
  final String errorMessage;

  const PriceApplyRun({
    required this.taskId,
    required this.status,
    required this.totalItems,
    required this.appliedCount,
    required this.failedCount,
    required this.startedAt,
    required this.finishedAt,
    required this.errorMessage,
  });

  factory PriceApplyRun.fromJson(Map<String, dynamic> json) {
    return PriceApplyRun(
      taskId: _asString(json['task_id']),
      status: _asString(json['status']),
      totalItems: _asInt(json['total_items']),
      appliedCount: _asInt(json['applied_count']),
      failedCount: _asInt(json['failed_count']),
      startedAt: _asString(json['started_at']),
      finishedAt: _asString(json['finished_at']),
      errorMessage: _asString(json['error_message']),
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
