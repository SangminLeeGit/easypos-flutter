// Models for the costing (원가 관리) feature.

class CostingDashboardSummary {
  final int ingredientCount;
  final int pricedIngredientCount;
  final int recipeCount;
  final int alertRecipeCount;
  final int recentPriceChangeCount;
  final String lastPriceChangeAt;

  const CostingDashboardSummary({
    required this.ingredientCount,
    required this.pricedIngredientCount,
    required this.recipeCount,
    required this.alertRecipeCount,
    required this.recentPriceChangeCount,
    required this.lastPriceChangeAt,
  });

  factory CostingDashboardSummary.fromJson(Map<String, dynamic> json) {
    return CostingDashboardSummary(
      ingredientCount: _asInt(json['ingredient_count']),
      pricedIngredientCount: _asInt(json['priced_ingredient_count']),
      recipeCount: _asInt(json['recipe_count']),
      alertRecipeCount: _asInt(json['alert_recipe_count']),
      recentPriceChangeCount: _asInt(json['recent_price_change_count']),
      lastPriceChangeAt: _asString(json['last_price_change_at']),
    );
  }
}

class RecipeSummaryRow {
  final int recipeId;
  final String menuCode;
  final String menuName;
  final String sizeCode;
  final String temperatureCode;
  final int sellingPrice;
  final double targetCostRatio;
  final int totalCost;
  final double costRatio;
  final int marginAmount;
  final String status;
  final int itemCount;

  const RecipeSummaryRow({
    required this.recipeId,
    required this.menuCode,
    required this.menuName,
    required this.sizeCode,
    required this.temperatureCode,
    required this.sellingPrice,
    required this.targetCostRatio,
    required this.totalCost,
    required this.costRatio,
    required this.marginAmount,
    required this.status,
    required this.itemCount,
  });

  factory RecipeSummaryRow.fromJson(Map<String, dynamic> json) {
    return RecipeSummaryRow(
      recipeId: _asInt(json['recipe_id']),
      menuCode: _asString(json['menu_code']),
      menuName: _asString(json['menu_name']),
      sizeCode: _asString(json['size_code']),
      temperatureCode: _asString(json['temperature_code']),
      sellingPrice: _asInt(json['selling_price']),
      targetCostRatio: _asDouble(json['target_cost_ratio']),
      totalCost: _asInt(json['total_cost']),
      costRatio: _asDouble(json['cost_ratio']),
      marginAmount: _asInt(json['margin_amount']),
      status: _asString(json['status']),
      itemCount: _asInt(json['item_count']),
    );
  }

  bool get isOverCost => costRatio > targetCostRatio && sellingPrice > 0 && targetCostRatio > 0;
}

class CostingDashboardData {
  final String error;
  final CostingDashboardSummary summary;
  final List<RecipeSummaryRow> recentRecipes;
  final List<RecipeSummaryRow> alerts;

  const CostingDashboardData({
    required this.error,
    required this.summary,
    required this.recentRecipes,
    required this.alerts,
  });

  factory CostingDashboardData.fromJson(Map<String, dynamic> json) {
    return CostingDashboardData(
      error: _asString(json['error']),
      summary: CostingDashboardSummary.fromJson(_asMap(json['summary'])),
      recentRecipes: _asListOfMaps(json['recent_recipes'])
          .map(RecipeSummaryRow.fromJson)
          .toList(growable: false),
      alerts: _asListOfMaps(json['alerts'])
          .map(RecipeSummaryRow.fromJson)
          .toList(growable: false),
    );
  }
}

class Ingredient {
  final int ingredientId;
  final String name;
  final String category;
  final String baseUnit;
  final String supplierName;
  final bool isActive;
  final String notes;
  final int priceCount;
  final double? currentUnitCost;

  const Ingredient({
    required this.ingredientId,
    required this.name,
    required this.category,
    required this.baseUnit,
    required this.supplierName,
    required this.isActive,
    required this.notes,
    required this.priceCount,
    this.currentUnitCost,
  });

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    final rawCost = json['current_unit_cost'];
    return Ingredient(
      ingredientId: _asInt(json['ingredient_id']),
      name: _asString(json['name']),
      category: _asString(json['category']),
      baseUnit: _asString(json['base_unit']),
      supplierName: _asString(json['supplier_name']),
      isActive: json['is_active'] == true,
      notes: _asString(json['notes']),
      priceCount: _asInt(json['price_count']),
      currentUnitCost: rawCost == null ? null : _asDouble(rawCost),
    );
  }
}

class IngredientPrice {
  final int priceId;
  final int ingredientId;
  final double unitCost;
  final double? packageSize;
  final double? packageCost;
  final String packageUnit;
  final String effectiveDate;
  final String supplierName;
  final String notes;

  const IngredientPrice({
    required this.priceId,
    required this.ingredientId,
    required this.unitCost,
    this.packageSize,
    this.packageCost,
    required this.packageUnit,
    required this.effectiveDate,
    required this.supplierName,
    required this.notes,
  });

  factory IngredientPrice.fromJson(Map<String, dynamic> json) {
    return IngredientPrice(
      priceId: _asInt(json['price_id']),
      ingredientId: _asInt(json['ingredient_id']),
      unitCost: _asDouble(json['unit_cost']),
      packageSize: json['package_size'] == null ? null : _asDouble(json['package_size']),
      packageCost: json['package_cost'] == null ? null : _asDouble(json['package_cost']),
      packageUnit: _asString(json['package_unit']),
      effectiveDate: _asString(json['effective_date']),
      supplierName: _asString(json['supplier_name']),
      notes: _asString(json['notes']),
    );
  }
}

class RecipeItem {
  final int recipeItemId;
  final int recipeId;
  final int ingredientId;
  final String ingredientName;
  final String ingredientBaseUnit;
  final double qty;
  final double? currentUnitCost;
  final double? lineCost;
  final String notes;

  const RecipeItem({
    required this.recipeItemId,
    required this.recipeId,
    required this.ingredientId,
    required this.ingredientName,
    required this.ingredientBaseUnit,
    required this.qty,
    this.currentUnitCost,
    this.lineCost,
    required this.notes,
  });

  factory RecipeItem.fromJson(Map<String, dynamic> json) {
    return RecipeItem(
      recipeItemId: _asInt(json['recipe_item_id']),
      recipeId: _asInt(json['recipe_id']),
      ingredientId: _asInt(json['ingredient_id']),
      ingredientName: _asString(json['ingredient_name']),
      ingredientBaseUnit: _asString(json['ingredient_base_unit']),
      qty: _asDouble(json['qty']),
      currentUnitCost: json['current_unit_cost'] == null ? null : _asDouble(json['current_unit_cost']),
      lineCost: json['line_cost'] == null ? null : _asDouble(json['line_cost']),
      notes: _asString(json['notes']),
    );
  }
}

class RecipeCalculateSummary {
  final int totalCost;
  final double costRatio;
  final int marginAmount;
  final int recommendedPrice;
  final int itemCount;

  const RecipeCalculateSummary({
    required this.totalCost,
    required this.costRatio,
    required this.marginAmount,
    required this.recommendedPrice,
    required this.itemCount,
  });

  factory RecipeCalculateSummary.fromJson(Map<String, dynamic> json) {
    return RecipeCalculateSummary(
      totalCost: _asInt(json['total_cost']),
      costRatio: _asDouble(json['cost_ratio']),
      marginAmount: _asInt(json['margin_amount']),
      recommendedPrice: _asInt(json['recommended_price']),
      itemCount: _asInt(json['item_count']),
    );
  }
}

class RecipeDetailData {
  final RecipeSummaryRow recipe;
  final List<RecipeItem> items;
  final RecipeCalculateSummary summary;

  const RecipeDetailData({
    required this.recipe,
    required this.items,
    required this.summary,
  });

  factory RecipeDetailData.fromJson(Map<String, dynamic> json) {
    return RecipeDetailData(
      recipe: RecipeSummaryRow.fromJson(_asMap(json['recipe'])),
      items: _asListOfMaps(json['items'])
          .map(RecipeItem.fromJson)
          .toList(growable: false),
      summary: RecipeCalculateSummary.fromJson(_asMap(json['summary'])),
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
