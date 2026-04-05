import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/dashboard_model.dart';
import '../services/api.dart';
import '../state/app_state.dart';

// ─── Admin models ────────────────────────────────────────────────────────────

class _AdminUser {
  final String id;
  final String loginId;
  final String role;
  final bool isActive;
  final String? lastLogin;

  const _AdminUser({
    required this.id,
    required this.loginId,
    required this.role,
    required this.isActive,
    this.lastLogin,
  });

  factory _AdminUser.fromJson(Map<String, dynamic> j) => _AdminUser(
        id: (j['id'] ?? '').toString(),
        loginId: j['login_id']?.toString() ?? '',
        role: j['role']?.toString() ?? '',
        isActive: j['is_active'] == true,
        lastLogin: j['last_login']?.toString(),
      );
}

class _AuditEntry {
  final String id;
  final String loginId;
  final String action;
  final String? detail;
  final String? createdAt;

  const _AuditEntry({
    required this.id,
    required this.loginId,
    required this.action,
    this.detail,
    this.createdAt,
  });

  factory _AuditEntry.fromJson(Map<String, dynamic> j) => _AuditEntry(
        id: (j['id'] ?? '').toString(),
        loginId: j['login_id']?.toString() ?? '',
        action: j['action']?.toString() ?? '',
        detail: j['detail']?.toString(),
        createdAt: j['created_at']?.toString(),
      );
}

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
        if (appState.hasAdminAccess) ...[
          const SizedBox(height: 32),
          const Text(
            '관리자',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const _UserManagementScreen()),
            ),
            icon: const Icon(Icons.manage_accounts_outlined),
            label: const Text('계정 관리'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const _AuditLogScreen()),
            ),
            icon: const Icon(Icons.history_outlined),
            label: const Text('감사 로그'),
          ),
        ],
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

// ─── Admin: User Management ───────────────────────────────────────────────────

class _UserManagementScreen extends StatefulWidget {
  const _UserManagementScreen();

  @override
  State<_UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<_UserManagementScreen> {
  List<_AdminUser> _users = [];
  bool _loading = true;
  String _error = '';

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
    });
    try {
      final result = await appState.fetchListParsed<List<_AdminUser>>(
        '/api/auth/users',
        parser: (json) => json
            .map((e) => _AdminUser.fromJson(e as Map<String, dynamic>))
            .toList(),
        cacheTtl: Duration.zero,
      );
      if (!mounted) return;
      setState(() {
        _users = result.data;
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

  Future<void> _editRole(_AdminUser user) async {
    final appState = context.read<AppState>();
    final roles = ['viewer', 'operator', 'admin'];
    String selected = user.role;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('${user.loginId} 권한 변경'),
          content: RadioGroup<String>(
            groupValue: selected,
            onChanged: (v) {
              if (v != null) setDialogState(() => selected = v);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: roles
                  .map(
                    (r) => RadioListTile<String>(
                      value: r,
                      title: Text(r),
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('적용'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      await appState.postJson(
        '/api/auth/users/${user.id}',
        body: {'role': selected},
        method: 'PATCH',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${user.loginId} 권한이 $selected로 변경되었습니다.')),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('계정 관리', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error,
                        style: const TextStyle(color: Color(0xFFDC2626))),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _users.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final u = _users[i];
                      return Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              u.loginId.isNotEmpty
                                  ? u.loginId[0].toUpperCase()
                                  : '?',
                            ),
                          ),
                          title: Text(u.loginId,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            '${u.role}  ·  ${u.isActive ? '활성' : '비활성'}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _editRole(u),
                            tooltip: '권한 변경',
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

// ─── Admin: Audit Log ─────────────────────────────────────────────────────────

class _AuditLogScreen extends StatefulWidget {
  const _AuditLogScreen();

  @override
  State<_AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<_AuditLogScreen> {
  List<_AuditEntry> _entries = [];
  bool _loading = true;
  String _error = '';

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
    });
    try {
      final result = await appState.fetchListParsed<List<_AuditEntry>>(
        '/api/auth/audit-logs',
        parser: (json) => json
            .map((e) => _AuditEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        cacheTtl: Duration.zero,
      );
      if (!mounted) return;
      setState(() {
        _entries = result.data;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('감사 로그', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error,
                        style: const TextStyle(color: Color(0xFFDC2626))),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _entries.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final e = _entries[i];
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.receipt_long_outlined,
                            size: 18, color: Color(0xFF64748B)),
                        title: Text(
                          e.action,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${e.loginId}${e.detail != null ? '  ·  ${e.detail}' : ''}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: e.createdAt != null
                            ? Text(
                                UiFormat.compactDateTime(e.createdAt),
                                style: const TextStyle(
                                    fontSize: 11, color: Color(0xFF94A3B8)),
                              )
                            : null,
                      );
                    },
                  ),
                ),
    );
  }
}
