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
  bool _isClearingCache = false;
  bool _isLoggingOut = false;
  late final TextEditingController _currentPasswordController;
  late final TextEditingController _newPasswordController;
  late final TextEditingController _confirmPasswordController;
  bool _isChangingPassword = false;
  String _passwordMessage = '';
  bool _passwordOk = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
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
        _statusOk = response.data['ok'] == true;
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
          '기본 서버 주소는 192.168.1.220:8087 입니다.',
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
            hintText: 'http://192.168.1.220:8087',
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
                    const SnackBar(
                        content: Text('기본 서버 주소로 되돌리고 저장값을 삭제했습니다.')),
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
          '인증 상태',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),
        _buildInfoRow(
          '로그인 상태',
          appState.isAuthenticated
              ? (appState.offlineMode ? '오프라인 세션 유지' : '로그인됨')
              : '로그아웃됨',
        ),
        _buildInfoRow('계정', appState.loginId ?? '-'),
        _buildInfoRow('권한', appState.role ?? '-'),
        _buildInfoRow(
          '접근 범위',
          appState.hasAdminAccess
              ? 'admin · operator · viewer'
              : appState.hasOperatorAccess
                  ? 'operator · viewer'
                  : 'viewer',
        ),
        _buildInfoRow('캐시 항목', '${appState.cacheEntryCount}개'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isClearingCache
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        setState(() {
                          _isClearingCache = true;
                        });
                        final removed = await appState.clearCache();
                        if (!mounted) {
                          return;
                        }
                        setState(() {
                          _isClearingCache = false;
                        });
                        messenger.showSnackBar(
                          SnackBar(content: Text('캐시 $removed건을 삭제했습니다.')),
                        );
                      },
                icon: const Icon(Icons.cleaning_services_outlined),
                label: Text(_isClearingCache ? '삭제 중...' : '캐시 비우기'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _isLoggingOut || !appState.isAuthenticated
                    ? null
                    : () async {
                        setState(() {
                          _isLoggingOut = true;
                        });
                        await appState.logout();
                        if (!mounted) {
                          return;
                        }
                        setState(() {
                          _isLoggingOut = false;
                        });
                      },
                icon: const Icon(Icons.logout),
                label: Text(_isLoggingOut ? '정리 중...' : '로그아웃'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        const Text(
          '비밀번호 변경',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _currentPasswordController,
          decoration: const InputDecoration(
            labelText: '현재 비밀번호',
            border: OutlineInputBorder(),
          ),
          obscureText: true,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _newPasswordController,
          decoration: const InputDecoration(
            labelText: '새 비밀번호',
            helperText: '최소 12자 이상',
            border: OutlineInputBorder(),
          ),
          obscureText: true,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _confirmPasswordController,
          decoration: const InputDecoration(
            labelText: '새 비밀번호 확인',
            border: OutlineInputBorder(),
          ),
          obscureText: true,
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _isChangingPassword || !appState.isAuthenticated
              ? null
              : () async {
                  final messenger = ScaffoldMessenger.of(context);
                  if (_newPasswordController.text !=
                      _confirmPasswordController.text) {
                    setState(() {
                      _passwordOk = false;
                      _passwordMessage = '새 비밀번호가 일치하지 않습니다.';
                    });
                    return;
                  }

                  setState(() {
                    _isChangingPassword = true;
                    _passwordMessage = '';
                  });

                  try {
                    await appState.changePassword(
                      currentPassword: _currentPasswordController.text,
                      newPassword: _newPasswordController.text,
                    );
                    if (!mounted) {
                      return;
                    }
                    setState(() {
                      _passwordOk = true;
                      _passwordMessage = '비밀번호가 변경되었습니다. 다시 로그인해 주세요.';
                      _currentPasswordController.clear();
                      _newPasswordController.clear();
                      _confirmPasswordController.clear();
                    });
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('비밀번호가 변경되어 세션이 종료되었습니다.'),
                      ),
                    );
                  } catch (error) {
                    if (!mounted) {
                      return;
                    }
                    setState(() {
                      _passwordOk = false;
                      _passwordMessage = error.toString();
                    });
                  } finally {
                    if (mounted) {
                      setState(() {
                        _isChangingPassword = false;
                      });
                    }
                  }
                },
          icon: const Icon(Icons.key_outlined),
          label: Text(_isChangingPassword ? '변경 중...' : '비밀번호 변경'),
        ),
        if (_passwordMessage.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            _passwordMessage,
            style: TextStyle(
              color:
                  _passwordOk ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
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
          '세션 확인',
          UiFormat.compactDateTime(
            appState.lastSessionSyncAt?.toIso8601String(),
          ),
        ),
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
