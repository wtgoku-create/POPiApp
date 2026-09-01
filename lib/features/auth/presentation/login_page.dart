import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/network/api_exception.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/widgets/app_toast.dart';
import '../domain/captcha_challenge.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key, this.onLoginSuccess});

  final VoidCallback? onLoginSuccess;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _captchaController = TextEditingController();
  final _codeController = TextEditingController();
  Timer? _countdownTimer;
  CaptchaChallenge? _captcha;
  int _countdown = 0;
  bool _agreed = false;
  bool _isCaptchaLoading = false;
  bool _isSendingCode = false;
  bool _isLoggingIn = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadCaptcha);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _phoneController.dispose();
    _captchaController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: Image.asset(
                                'assets/icons/popi_icon.png',
                                width: 72,
                                height: 72,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              l10n.loginTitle,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              l10n.loginSubtitle,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 40),
                            TextFormField(
                              key: const Key('login-phone-field'),
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              autofillHints: const [
                                AutofillHints.telephoneNumber
                              ],
                              maxLength: 11,
                              decoration: InputDecoration(
                                labelText: l10n.phoneNumber,
                                hintText: l10n.phoneNumberHint,
                                counterText: '',
                                prefixIcon: const Padding(
                                  padding: EdgeInsets.only(left: 18, right: 10),
                                  child: Center(
                                    widthFactor: 1,
                                    child: Text(
                                      '+86',
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              validator: (value) => _validatePhone(value, l10n),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    key: const Key('login-captcha-field'),
                                    controller: _captchaController,
                                    textInputAction: TextInputAction.next,
                                    decoration: InputDecoration(
                                      labelText: l10n.graphicalCaptcha,
                                      hintText: l10n.graphicalCaptchaHint,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                _CaptchaPreview(
                                  challenge: _captcha,
                                  loading: _isCaptchaLoading,
                                  refreshTooltip: l10n.refreshCaptcha,
                                  onRefresh:
                                      _isCaptchaLoading ? null : _loadCaptcha,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              key: const Key('login-code-field'),
                              controller: _codeController,
                              keyboardType: TextInputType.number,
                              autofillHints: const [AutofillHints.oneTimeCode],
                              maxLength: 6,
                              decoration: InputDecoration(
                                labelText: l10n.verificationCode,
                                hintText: l10n.verificationCodeHint,
                                counterText: '',
                                suffixIcon: Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: TextButton(
                                    key: const Key('send-code-button'),
                                    onPressed: _countdown == 0 &&
                                            !_isSendingCode &&
                                            !_isCaptchaLoading
                                        ? _sendCode
                                        : null,
                                    child: Text(
                                      _isSendingCode
                                          ? l10n.sendingVerificationCode
                                          : _countdown == 0
                                              ? l10n.sendVerificationCode
                                              : l10n
                                                  .resendCountdown(_countdown),
                                    ),
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (!RegExp(r'^\d{6}$')
                                    .hasMatch(value?.trim() ?? '')) {
                                  return l10n.invalidVerificationCode;
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 22),
                            SizedBox(
                              height: 52,
                              child: FilledButton(
                                key: const Key('phone-login-button'),
                                onPressed:
                                    _isLoggingIn ? null : _loginWithPhone,
                                child: _isLoggingIn
                                    ? const SizedBox.square(
                                        dimension: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        l10n.phoneLogin,
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 28),
                            Row(
                              children: [
                                const Expanded(child: Divider()),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Text(
                                    l10n.otherLoginMethods,
                                    style: const TextStyle(
                                      color: AppColors.textTertiary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const Expanded(child: Divider()),
                              ],
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              height: 52,
                              child: OutlinedButton.icon(
                                key: const Key('wechat-login-button'),
                                onPressed: _loginWithWechat,
                                icon: const Icon(
                                  Icons.wechat,
                                  color: Color(0xFF07C160),
                                  size: 25,
                                ),
                                label: Text(
                                  l10n.wechatLogin,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),
                            InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => setState(() => _agreed = !_agreed),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: Checkbox(
                                        key: const Key('agreement-checkbox'),
                                        value: _agreed,
                                        onChanged: (value) => setState(
                                          () => _agreed = value ?? false,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        l10n.loginAgreement,
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 13,
                                          height: 1.6,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String? _validatePhone(String? value, AppLocalizations l10n) {
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(value?.trim() ?? '')) {
      return l10n.invalidPhoneNumber;
    }
    return null;
  }

  Future<void> _loadCaptcha() async {
    if (_isCaptchaLoading) return;
    setState(() => _isCaptchaLoading = true);
    try {
      final captcha = await ref.read(authRepositoryProvider).createCaptcha();
      if (!mounted) return;
      setState(() {
        _captcha = captcha;
        _captchaController.clear();
      });
    } catch (error) {
      if (!mounted) return;
      AppToast.error(context, _errorMessage(error));
    } finally {
      if (mounted) setState(() => _isCaptchaLoading = false);
    }
  }

  Future<void> _sendCode() async {
    final l10n = AppLocalizations.of(context)!;
    final phoneError = _validatePhone(_phoneController.text, l10n);
    if (phoneError != null) {
      AppToast.error(context, phoneError);
      return;
    }
    if (!_ensureAgreement(l10n)) return;
    final captcha = _captcha;
    final captchaValue = _captchaController.text.trim();
    if (captcha == null || captchaValue.isEmpty) {
      AppToast.error(context, l10n.graphicalCaptchaRequired);
      return;
    }

    setState(() => _isSendingCode = true);
    try {
      await ref.read(authRepositoryProvider).sendLoginCode(
            phone: _phoneController.text.trim(),
            captchaId: captcha.id,
            captchaValue: captchaValue,
          );
      if (!mounted) return;
      _startCountdown();
      AppToast.success(context, l10n.verificationCodeSent);
    } catch (error) {
      if (!mounted) return;
      AppToast.error(context, _errorMessage(error));
      await _loadCaptcha();
    } finally {
      if (mounted) setState(() => _isSendingCode = false);
    }
  }

  Future<void> _loginWithPhone() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_ensureAgreement(l10n)) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoggingIn = true);
    try {
      await ref.read(userProvider.notifier).signInWithCode(
            phone: _phoneController.text.trim(),
            code: _codeController.text.trim(),
          );
      if (!mounted) return;
      AppToast.success(context, l10n.loginSucceeded);
      final onLoginSuccess = widget.onLoginSuccess;
      if (onLoginSuccess != null) {
        onLoginSuccess();
      } else {
        context.go('/');
      }
    } catch (error) {
      if (!mounted) return;
      AppToast.error(context, _errorMessage(error));
    } finally {
      if (mounted) setState(() => _isLoggingIn = false);
    }
  }

  void _loginWithWechat() {
    final l10n = AppLocalizations.of(context)!;
    if (!_ensureAgreement(l10n)) return;
    AppToast.info(context, l10n.wechatServicePending);
  }

  bool _ensureAgreement(AppLocalizations l10n) {
    if (_agreed) return true;
    AppToast.error(context, l10n.agreementRequired);
    return false;
  }

  void _startCountdown() {
    setState(() => _countdown = 60);
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() {
        _countdown--;
        if (_countdown == 0) timer.cancel();
      });
    });
  }

  String _errorMessage(Object error) {
    if (error case ApiException(message: final message)) return message;
    return AppLocalizations.of(context)!.networkRequestFailed;
  }
}

class _CaptchaPreview extends StatelessWidget {
  const _CaptchaPreview({
    required this.challenge,
    required this.loading,
    required this.refreshTooltip,
    required this.onRefresh,
  });

  final CaptchaChallenge? challenge;
  final bool loading;
  final String refreshTooltip;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: refreshTooltip,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(AppRadii.medium),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const Key('refresh-captcha-button'),
          onTap: onRefresh,
          child: SizedBox(
            width: 104,
            height: 56,
            child: Center(
              child: loading
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : challenge == null || challenge!.imageBase64.isEmpty
                      ? const Icon(Icons.image_not_supported_outlined)
                      : Image.memory(
                          challenge!.imageBytes,
                          key: const Key('captcha-image'),
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.broken_image_outlined),
                        ),
            ),
          ),
        ),
      ),
    );
  }
}
