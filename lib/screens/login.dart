import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final TextEditingController _loginIdController;
  late final TextEditingController _passwordController;
  bool _isSubmitting = false;
  bool _isChecking = false;
  bool _statusOk = false;
  String _errorMessage = '';
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _loginIdController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _loginIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final appState = context.read<AppState>();
    setState(() {
      _isSubmitting = true;
      _errorMessage = '';
    });

    try {
      await appState.login(
        _loginIdController.text,
        _passwordController.text,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _checkConnection() async {
    final appState = context.read<AppState>();
    setState(() {
      _isChecking = true;
      _statusMessage = '';
    });

    try {
      await appState.refreshSession();
      if (!mounted) {
        return;
      }
      setState(() {
        _statusOk = true;
        _statusMessage = '인증 서버 연결 성공';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusOk = false;
        _statusMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  Future<void> _editServerAddress() async {
    final appState = context.read<AppState>();
    final controller = TextEditingController(text: appState.apiBaseUrl);

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('서버 주소 변경'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'http://192.168.1.220:8087',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                await appState.resetApiBaseUrl();
                if (!context.mounted) {
                  return;
                }
                Navigator.of(context).pop();
              },
              child: const Text('기본값'),
            ),
            FilledButton(
              onPressed: () async {
                await appState.updateApiBaseUrl(controller.text);
                if (!context.mounted) {
                  return;
                }
                Navigator.of(context).pop();
              },
              child: const Text('저장'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final setupBlocked =
        appState.setupRequired && !appState.bootstrapConfigured;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'EasyPOS Mobile',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: Color(0xFF0F766E),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '운영 콘솔 로그인',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          '모바일 앱도 웹과 같은 세션 쿠키 및 CSRF 인증 절차를 사용합니다.',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildServerPanel(appState),
                        const SizedBox(height: 20),
                        if (appState.offlineMode) ...[
                          _buildInfoBanner(
                            backgroundColor: const Color(0xFFECFEFF),
                            borderColor: const Color(0xFFA5F3FC),
                            textColor: const Color(0xFF155E75),
                            message: '저장된 세션과 캐시로 오프라인 모드가 유지되고 있습니다.',
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (setupBlocked) ...[
                          _buildInfoBanner(
                            backgroundColor: const Color(0xFFFFF7ED),
                            borderColor: const Color(0xFFFED7AA),
                            textColor: const Color(0xFF9A3412),
                            message:
                                '초기 관리자 계정이 아직 준비되지 않았습니다. `EASYPOS_ADMIN_BOOTSTRAP_ID`, `EASYPOS_ADMIN_BOOTSTRAP_PASSWORD`를 먼저 설정해야 합니다.',
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (_errorMessage.isNotEmpty) ...[
                          _buildInfoBanner(
                            backgroundColor: const Color(0xFFFFF1F2),
                            borderColor: const Color(0xFFFECDD3),
                            textColor: const Color(0xFF9F1239),
                            message: _errorMessage,
                          ),
                          const SizedBox(height: 16),
                        ],
                        TextField(
                          controller: _loginIdController,
                          decoration: const InputDecoration(
                            labelText: '아이디',
                            border: OutlineInputBorder(),
                          ),
                          autofillHints: const [AutofillHints.username],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passwordController,
                          decoration: const InputDecoration(
                            labelText: '비밀번호',
                            border: OutlineInputBorder(),
                          ),
                          obscureText: true,
                          autofillHints: const [AutofillHints.password],
                          onSubmitted: (_) => _isSubmitting ? null : _submit(),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed:
                              _isSubmitting || setupBlocked ? null : _submit,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(_isSubmitting ? '로그인 중...' : '로그인'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServerPanel(AppState appState) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '접속 서버',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            appState.apiBaseUrl,
            style: const TextStyle(
              color: Color(0xFF334155),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _editServerAddress,
                  icon: const Icon(Icons.tune_outlined),
                  label: const Text('서버 주소'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isChecking ? null : _checkConnection,
                  icon: const Icon(Icons.health_and_safety_outlined),
                  label: Text(_isChecking ? '확인 중...' : '연결 테스트'),
                ),
              ),
            ],
          ),
          if (_statusMessage.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _statusMessage,
              style: TextStyle(
                color: _statusOk
                    ? const Color(0xFF0F766E)
                    : const Color(0xFFB91C1C),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoBanner({
    required Color backgroundColor,
    required Color borderColor,
    required Color textColor,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
      ),
    );
  }
}
