import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/dashboard_model.dart';
import '../services/api.dart';
import '../state/app_state.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _controller;
  bool _isChecking = false;
  bool _statusOk = false;
  String _statusMessage = '';
  String _lastSyncedApiBaseUrl = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkConnection() async {
    final baseUrl = ApiService.normalizeBaseUrl(_controller.text);
    setState(() {
      _isChecking = true;
      _statusMessage = '';
    });

    try {
      final response = await ApiService.fetchJson(baseUrl, '/healthz');
      if (!mounted) {
        return;
      }
      setState(() {
        _statusOk = response['ok'] == true;
        _statusMessage = _statusOk ? '백엔드 연결 성공' : '헬스체크 응답이 비정상입니다.';
        _isChecking = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusOk = false;
        _statusMessage = error.toString();
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    if (_lastSyncedApiBaseUrl != appState.apiBaseUrl) {
      _lastSyncedApiBaseUrl = appState.apiBaseUrl;
      _controller.text = appState.apiBaseUrl;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '앱 설정',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
        ),
        const SizedBox(height: 6),
        const Text(
          '안드로이드 에뮬레이터는 기본적으로 10.0.2.2:8087을 사용합니다.',
          style: TextStyle(color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 24),
        const Text(
          '백엔드 서버 주소',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'http://10.0.2.2:8087',
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: () async {
                  final appState = context.read<AppState>();
                  final messenger = ScaffoldMessenger.of(context);

                  await appState.updateApiBaseUrl(_controller.text);
                  if (!context.mounted) {
                    return;
                  }
                  messenger.showSnackBar(
                    const SnackBar(content: Text('서버 주소를 저장하고 적용했습니다.')),
                  );
                },
                child: const Text('적용'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final appState = context.read<AppState>();
                  final messenger = ScaffoldMessenger.of(context);

                  await appState.resetApiBaseUrl();
                  if (!context.mounted) {
                    return;
                  }
                  setState(() {
                    _statusMessage = '';
                  });
                  messenger.showSnackBar(
                    const SnackBar(content: Text('기본 서버 주소로 되돌리고 저장값을 삭제했습니다.')),
                  );
                },
                child: const Text('기본값'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _isChecking ? null : _checkConnection,
          icon: const Icon(Icons.health_and_safety_outlined),
          label: Text(_isChecking ? '확인 중...' : '연결 테스트'),
        ),
        if (_statusMessage.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            _statusMessage,
            style: TextStyle(
              color:
                  _statusOk ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 32),
        const Text(
          '실행 정보',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),
        _buildInfoRow('앱 버전', '0.1.0-alpha'),
        _buildInfoRow('현재 서버', appState.apiBaseUrl),
        _buildInfoRow(
          '오늘 날짜',
          UiFormat.weekday(ApiService.formatDate(DateTime.now())),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 15, color: Color(0xFF475569)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
