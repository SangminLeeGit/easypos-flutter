import 'package:flutter/material.dart';

import '../models/dashboard_model.dart';

class CacheNotice extends StatelessWidget {
  final DateTime? cachedAt;
  final String prefix;

  const CacheNotice({
    super.key,
    required this.cachedAt,
    this.prefix = '오프라인 캐시',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Text(
        '$prefix · ${UiFormat.compactDateTime(cachedAt?.toIso8601String())}',
        style: const TextStyle(
          color: Color(0xFF9A3412),
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
