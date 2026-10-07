import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/legal_document_links.dart';
import '../data/wechat_login_service.dart';
import '../data/douyin_auth_api.dart';
import '../data/douyin_login_service.dart';
import 'slider_captcha_sheet.dart';
import '../domain/wechat_app_login.dart';
import '../domain/douyin_app_login.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({
    super.key,
    this.onLoginSuccess,
    this.wechatAuthorizationCode,
  });

  final VoidCallback? onLoginSuccess;
  final String? wechatAuthorizationCode;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  Timer? _countdownTimer;
  int _countdown = 0;
  bool _agreed = false;
  bool _isSendingCode = false;
  bool _isLoggingIn = false;
  bool _passwordLogin = false;
  bool _passwordVisible = false;
  bool _isWechatLoggingIn = false;
  bool _isDouyinLoggingIn = false;
  String? _wechatRegisterToken;
  String? _douyinRegisterToken;

  @override
  void initState() {
    super.initState();
    final wechatAuthorizationCode = widget.wechatAuthorizationCode?.trim();
    if (wechatAuthorizationCode != null && wechatAuthorizationCode.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _completeWechatLogin(wechatAuthorizationCode);
      });
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        resizeToAvoidBottomInset: true,
        body: GestureDetector(
          key: const Key('login-keyboard-dismiss-area'),
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _LoginDesignViewport(
                keyboardInset: keyboardInset,
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: colorScheme.brightness == Brightness.light
                              ? const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xFFEDE9FD),
                                    Color(0xFFF8F8F8),
                                  ],
                                )
                              : null,
                        ),
                      ),
                    ),
                    const _LoginIllustration(),
                    _PhoneLoginDesign(
                      phoneController: _phoneController,
                      codeController: _codeController,
                      passwordController: _passwordController,
                      passwordLogin: _passwordLogin,
                      passwordVisible: _passwordVisible,
                      onToggleLoginMode: _toggleLoginMode,
                      onTogglePasswordVisibility: () =>
                          setState(() => _passwordVisible = !_passwordVisible),
                      agreed: _agreed,
                      countdown: _countdown,
                      sendingCode: _isSendingCode,
                      loggingIn: _isLoggingIn,
                      phoneBindingRequired:
                          _wechatRegisterToken != null ||
                          _douyinRegisterToken != null,
                      wechatLoggingIn: _isWechatLoggingIn,
                      douyinLoggingIn: _isDouyinLoggingIn,
                      onWechatLogin: _loginWithWechat,
                      onDouyinLogin: _loginWithDouyin,
                      onBack: _closePage,
                      onAgreementChanged: _toggleAgreement,
                      onSendCode: _showCaptchaSheet,
                      onLogin: _loginWithPhone,
                    ),
                  ],
                ),
              ),
              if (keyboardInset > 0)
                Positioned(
                  left: 20,
                  top: MediaQuery.paddingOf(context).top + 8,
                  width: 40,
                  height: 40,
                  child: _LoginKeyboardBackButton(
                    onPressed: () =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleAgreement() => setState(() => _agreed = !_agreed);

  void _toggleLoginMode() {
    if (!AppConfig.passwordLoginEnabled ||
        _isLoggingIn ||
        _isWechatLoggingIn ||
        _isDouyinLoggingIn ||
        _isSendingCode ||
        _wechatRegisterToken != null ||
        _douyinRegisterToken != null) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _passwordLogin = !_passwordLogin;
      _passwordVisible = false;
      _passwordController.clear();
      _codeController.clear();
    });
  }

  void _closePage() {
    FocusManager.instance.primaryFocus?.unfocus();
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      SystemNavigator.pop();
    }
  }

  Future<void> _showCaptchaSheet() async {
    final l10n = AppLocalizations.of(context)!;
    final phoneError = _validatePhone(_phoneController.text, l10n);
    if (phoneError != null) {
      AppToast.error(context, phoneError);
      return;
    }
    if (!_ensureAgreement(l10n)) return;
    if (_countdown > 0 || _isSendingCode) return;
    final phone = _phoneController.text.trim();
    FocusManager.instance.primaryFocus?.unfocus();
    await AppDialog.show<void>(
      context: context,
      builder: (dialogContext) => AppDialog(
        width: 360,
        padding: EdgeInsets.zero,
        child: SliderCaptchaSheet(
          phone: phone,
          repository: ref.read(authRepositoryProvider),
          onVerified: (token) async {
            final sent = await _sendCode(phone, token);
            if (!sent) throw const ApiException();
            if (dialogContext.mounted) Navigator.of(dialogContext).pop();
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

  Future<bool> _sendCode(String phone, String captchaToken) async {
    final l10n = AppLocalizations.of(context)!;
    if (_isSendingCode || _countdown > 0) return false;
    setState(() => _isSendingCode = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .sendLoginCode(phone: phone, captchaToken: captchaToken);
      if (!mounted) return false;
      _startCountdown();
      AppToast.success(context, l10n.verificationCodeSent);
      return true;
    } catch (error) {
      if (!mounted) return false;
      AppToast.error(context, _errorMessage(error));
      return false;
    } finally {
      if (mounted) setState(() => _isSendingCode = false);
    }
  }

  Future<void> _loginWithPhone() async {
    if (_isLoggingIn || _isWechatLoggingIn || _isDouyinLoggingIn) return;
    final l10n = AppLocalizations.of(context)!;
    if (!_ensureAgreement(l10n)) return;
    final phoneError = _validatePhone(_phoneController.text, l10n);
    if (phoneError != null) {
      AppToast.error(context, phoneError);
      return;
    }
    if (_passwordLogin) {
      if (!AppConfig.passwordLoginEnabled) return;
      if (_passwordController.text.trim().length < 6) {
        AppToast.error(context, l10n.invalidPassword);
        return;
      }
    } else {
      if (!RegExp(r'^\d{6}$').hasMatch(_codeController.text.trim())) {
        AppToast.error(context, l10n.invalidVerificationCode);
        return;
      }
    }

    setState(() => _isLoggingIn = true);
    try {
      final registerToken = _wechatRegisterToken;
      final douyinRegisterToken = _douyinRegisterToken;
      if (_passwordLogin) {
        await ref
            .read(userProvider.notifier)
            .signInWithPassword(
              phone: _phoneController.text.trim(),
              password: _passwordController.text,
            );
      } else if (douyinRegisterToken != null) {
        await ref
            .read(userProvider.notifier)
            .registerDouyinAppByPhone(
              registerToken: douyinRegisterToken,
              phone: _phoneController.text.trim(),
              code: _codeController.text.trim(),
            );
      } else if (registerToken == null) {
        await ref
            .read(userProvider.notifier)
            .signInWithCode(
              phone: _phoneController.text.trim(),
              code: _codeController.text.trim(),
            );
      } else {
        await ref
            .read(userProvider.notifier)
            .registerWechatAppByPhone(
              registerToken: registerToken,
              phone: _phoneController.text.trim(),
              code: _codeController.text.trim(),
            );
      }
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

  Future<void> _loginWithWechat() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_ensureAgreement(l10n)) return;
    if (_isLoggingIn || _isWechatLoggingIn || _isDouyinLoggingIn) return;

    setState(() => _isWechatLoggingIn = true);
    try {
      final authorization = await WechatLoginService().authorize();
      if (!mounted) return;
      switch (authorization.status) {
        case WechatAuthorizationStatus.authorized:
          setState(() => _isWechatLoggingIn = false);
          await _completeWechatLogin(authorization.code!);
          return;
        case WechatAuthorizationStatus.canceled:
          AppToast.info(context, l10n.wechatLoginCanceled);
          return;
        case WechatAuthorizationStatus.unavailable:
          AppToast.error(context, l10n.wechatLoginUnavailable);
          return;
        case WechatAuthorizationStatus.failed:
          AppToast.error(context, l10n.wechatLoginFailed);
          return;
      }
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'WeChat authorization failed: '
          '${error.runtimeType}: $error\n$stackTrace',
        );
      }
      if (mounted) AppToast.error(context, _errorMessage(error));
    } finally {
      if (mounted) setState(() => _isWechatLoggingIn = false);
    }
  }

  Future<void> _completeWechatLogin(String code) async {
    if (_isWechatLoggingIn) return;

    setState(() => _isWechatLoggingIn = true);
    try {
      final result = await ref
          .read(userProvider.notifier)
          .signInWithWechatApp(code: code);
      if (!mounted) return;
      if (result case WechatAppSignInPhoneBindingRequired(
        registerToken: final registerToken,
      )) {
        setState(() {
          _wechatRegisterToken = registerToken;
          _douyinRegisterToken = null;
          _passwordLogin = false;
          _passwordVisible = false;
          _passwordController.clear();
        });
        AppToast.info(
          context,
          AppLocalizations.of(context)!.wechatPhoneBindingRequired,
        );
        return;
      }
      AppToast.success(context, AppLocalizations.of(context)!.loginSucceeded);
      final onLoginSuccess = widget.onLoginSuccess;
      if (onLoginSuccess != null) {
        onLoginSuccess();
      } else {
        context.go('/');
      }
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'WeChat app login completion failed: '
          '${error.runtimeType}: $error\n$stackTrace',
        );
      }
      if (mounted) AppToast.error(context, _errorMessage(error));
    } finally {
      if (mounted) setState(() => _isWechatLoggingIn = false);
    }
  }

  Future<void> _loginWithDouyin() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_ensureAgreement(l10n)) return;
    if (_isLoggingIn || _isWechatLoggingIn || _isDouyinLoggingIn) return;

    setState(() => _isDouyinLoggingIn = true);
    try {
      final authorization = await ref
          .read(douyinLoginServiceProvider)
          .authorize();
      if (!mounted) return;
      switch (authorization.status) {
        case DouyinAuthorizationStatus.authorized:
          setState(() => _isDouyinLoggingIn = false);
          await _completeDouyinLogin(authorization.code!);
          return;
        case DouyinAuthorizationStatus.canceled:
          AppToast.info(context, l10n.douyinLoginCanceled);
          return;
        case DouyinAuthorizationStatus.unavailable:
          AppToast.error(context, l10n.douyinLoginUnavailable);
          return;
        case DouyinAuthorizationStatus.failed:
          AppToast.error(context, l10n.douyinLoginFailed);
          return;
      }
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'Douyin authorization failed: '
          '${error.runtimeType}: $error\n$stackTrace',
        );
      }
      if (mounted) AppToast.error(context, _errorMessage(error));
    } finally {
      if (mounted) setState(() => _isDouyinLoggingIn = false);
    }
  }

  Future<void> _completeDouyinLogin(String code) async {
    if (_isDouyinLoggingIn) return;

    setState(() => _isDouyinLoggingIn = true);
    try {
      final result = await ref
          .read(userProvider.notifier)
          .signInWithDouyinApp(code: code);
      if (!mounted) return;
      if (result case DouyinAppSignInPhoneBindingRequired(
        registerToken: final registerToken,
      )) {
        setState(() {
          _douyinRegisterToken = registerToken;
          _wechatRegisterToken = null;
          _passwordLogin = false;
          _passwordVisible = false;
          _passwordController.clear();
        });
        AppToast.info(
          context,
          AppLocalizations.of(context)!.douyinPhoneBindingRequired,
        );
        return;
      }
      AppToast.success(context, AppLocalizations.of(context)!.loginSucceeded);
      final onLoginSuccess = widget.onLoginSuccess;
      if (onLoginSuccess != null) {
        onLoginSuccess();
      } else {
        context.go('/');
      }
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'Douyin app login completion failed: '
          '${error.runtimeType}: $error\n$stackTrace',
        );
      }
      if (mounted) AppToast.error(context, _errorMessage(error));
    } finally {
      if (mounted) setState(() => _isDouyinLoggingIn = false);
    }
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
    if (error is DouyinLoginUnavailableException) {
      return AppLocalizations.of(context)!.douyinLoginUnavailable;
    }
    if (error case ApiException(
      message: final String message,
    ) when message.trim().isNotEmpty) {
      return message;
    }
    return AppLocalizations.of(context)!.networkRequestFailed;
  }
}

class _LoginDesignViewport extends StatefulWidget {
  const _LoginDesignViewport({
    required this.child,
    required this.keyboardInset,
  });

  static const designSize = Size(440, 956);

  final Widget child;
  final double keyboardInset;

  @override
  State<_LoginDesignViewport> createState() => _LoginDesignViewportState();
}

class _LoginDesignViewportState extends State<_LoginDesignViewport> {
  final _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant _LoginDesignViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.keyboardInset > oldWidget.keyboardInset) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = math.min(
          constraints.maxWidth / _LoginDesignViewport.designSize.width,
          1.0,
        );
        final scaledSize = _LoginDesignViewport.designSize * scale;
        final keyboardOpen = widget.keyboardInset > 0;
        final needsScrolling =
            keyboardOpen || scaledSize.height > constraints.maxHeight;
        final canvas = SizedBox(
          width: scaledSize.width,
          height: scaledSize.height,
          child: FittedBox(
            fit: BoxFit.fill,
            child: SizedBox.fromSize(
              size: _LoginDesignViewport.designSize,
              child: widget.child,
            ),
          ),
        );

        return SingleChildScrollView(
          key: const Key('login-design-scroll-view'),
          controller: _scrollController,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: needsScrolling
              ? const ClampingScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Align(
              alignment: needsScrolling
                  ? Alignment.topCenter
                  : Alignment.bottomCenter,
              child: canvas,
            ),
          ),
        );
      },
    );
  }
}

class _PhoneLoginDesign extends StatelessWidget {
  const _PhoneLoginDesign({
    required this.phoneController,
    required this.codeController,
    required this.passwordController,
    required this.passwordLogin,
    required this.passwordVisible,
    required this.onToggleLoginMode,
    required this.onTogglePasswordVisibility,
    required this.agreed,
    required this.countdown,
    required this.sendingCode,
    required this.loggingIn,
    required this.phoneBindingRequired,
    required this.wechatLoggingIn,
    required this.douyinLoggingIn,
    required this.onWechatLogin,
    required this.onDouyinLogin,
    required this.onBack,
    required this.onAgreementChanged,
    required this.onSendCode,
    required this.onLogin,
  });

  final TextEditingController phoneController;
  final TextEditingController codeController;
  final TextEditingController passwordController;
  final bool passwordLogin;
  final bool passwordVisible;
  final VoidCallback onToggleLoginMode;
  final VoidCallback onTogglePasswordVisibility;
  final bool agreed;
  final int countdown;
  final bool sendingCode;
  final bool loggingIn;
  final bool phoneBindingRequired;
  final bool wechatLoggingIn;
  final bool douyinLoggingIn;
  final VoidCallback onWechatLogin;
  final VoidCallback onDouyinLogin;
  final VoidCallback onBack;
  final VoidCallback onAgreementChanged;
  final VoidCallback onSendCode;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final fieldColor = colorScheme.brightness == Brightness.light
        ? const Color(0xFFF0F4F9)
        : colorScheme.surfaceContainerHighest;
    final textStyle = TextStyle(
      color: colorScheme.onSurface,
      fontSize: 18,
      height: 24 / 18,
    );

    return Stack(
      children: [
        _LoginBackButton(onPressed: onBack),
        Positioned(
          left: 0,
          top: 351,
          width: 440,
          height: 605,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(45),
              ),
            ),
          ),
        ),
        Positioned(
          left: 40,
          top: 391,
          width: 360,
          child: Column(
            children: [
              _LoginFieldShell(
                color: fieldColor,
                child: Row(
                  children: [
                    Text('+86', style: textStyle),
                    const SizedBox(width: 11),
                    const _LoginFieldDivider(),
                    const SizedBox(width: 11),
                    Expanded(
                      child: TextField(
                        key: const Key('login-phone-field'),
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.telephoneNumber],
                        maxLength: 11,
                        style: textStyle,
                        decoration: _fieldDecoration(l10n.phoneNumberHint),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              _LoginFieldShell(
                color: fieldColor,
                padding: const EdgeInsets.only(left: 20, right: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: passwordLogin
                          ? TextField(
                              key: const Key('login-password-field'),
                              controller: passwordController,
                              obscureText: !passwordVisible,
                              enableSuggestions: false,
                              autocorrect: false,
                              keyboardType: TextInputType.visiblePassword,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              style: textStyle,
                              decoration: _fieldDecoration(l10n.passwordHint),
                              onSubmitted: (_) => onLogin(),
                            )
                          : TextField(
                              key: const Key('login-code-field'),
                              controller: codeController,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.oneTimeCode],
                              maxLength: 6,
                              style: textStyle,
                              decoration: _fieldDecoration(
                                l10n.verificationCodeHint,
                              ),
                              onSubmitted: (_) => onLogin(),
                            ),
                    ),
                    const SizedBox(width: 8),
                    if (passwordLogin)
                      IconButton(
                        key: const Key('login-password-visibility'),
                        tooltip: passwordVisible
                            ? l10n.hidePassword
                            : l10n.showPassword,
                        onPressed: onTogglePasswordVisibility,
                        icon: Icon(
                          passwordVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      )
                    else
                      TextButton(
                        key: const Key('send-code-button'),
                        onPressed: countdown > 0 || sendingCode
                            ? null
                            : onSendCode,
                        style: TextButton.styleFrom(
                          fixedSize: const Size(116, 40),
                          minimumSize: const Size(116, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          backgroundColor: colorScheme.surface,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: AppColors.brand,
                          disabledForegroundColor: colorScheme.onSurfaceVariant,
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            sendingCode
                                ? l10n.sendingVerificationCode
                                : countdown > 0
                                ? l10n.resendCountdown(countdown)
                                : l10n.sendVerificationCode,
                            maxLines: 1,
                            softWrap: false,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              _LoginActionButton(
                key: const Key('phone-login-button'),
                label: phoneBindingRequired
                    ? l10n.bindPhone
                    : passwordLogin
                    ? l10n.passwordLogin
                    : l10n.loginOrRegister,
                onPressed: loggingIn || wechatLoggingIn || douyinLoggingIn
                    ? null
                    : onLogin,
                loading: loggingIn,
              ),
              if (AppConfig.passwordLoginEnabled && !phoneBindingRequired) ...[
                const SizedBox(height: 8),
                TextButton(
                  key: const Key('login-mode-switch'),
                  onPressed:
                      loggingIn ||
                          wechatLoggingIn ||
                          douyinLoggingIn ||
                          sendingCode
                      ? null
                      : onToggleLoginMode,
                  child: Text(
                    passwordLogin ? l10n.codeLogin : l10n.passwordLogin,
                  ),
                ),
              ],
            ],
          ),
        ),
        Positioned(
          left: 100,
          top: 838,
          width: 240,
          child: Row(
            children: [
              Expanded(
                child: TextButton(
                  key: const Key('wechat-login-button'),
                  onPressed: loggingIn || wechatLoggingIn || douyinLoggingIn
                      ? null
                      : onWechatLogin,
                  style: TextButton.styleFrom(
                    fixedSize: const Size(115, 38),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 4,
                    ),
                  ),
                  child: Row(
                    children: [
                      if (wechatLoggingIn)
                        const SizedBox.square(
                          dimension: 30,
                          child: Padding(
                            padding: EdgeInsets.all(5),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else
                        Image.asset(
                          'assets/images/login_wechat.png',
                          width: 30,
                          height: 30,
                        ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          l10n.wechatLogin,
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextButton(
                  key: const Key('douyin-login-button'),
                  onPressed: loggingIn || wechatLoggingIn || douyinLoggingIn
                      ? null
                      : onDouyinLogin,
                  style: TextButton.styleFrom(
                    fixedSize: const Size(115, 38),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 4,
                    ),
                  ),
                  child: Row(
                    children: [
                      if (douyinLoggingIn)
                        const SizedBox.square(
                          dimension: 30,
                          child: Padding(
                            padding: EdgeInsets.all(5),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else
                        Image.asset(
                          'assets/images/login_douyin.png',
                          width: 30,
                          height: 30,
                        ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          l10n.douyinLogin,
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 14,
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
        Positioned(
          left: 93,
          top: 896,
          width: 279,
          child: _LoginAgreement(agreed: agreed, onChanged: onAgreementChanged),
        ),
      ],
    );
  }

  static InputDecoration _fieldDecoration(String hintText) => InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(
      color: Color(0xFF999999),
      fontSize: 18,
      height: 24 / 18,
    ),
    counterText: '',
    isCollapsed: true,
    filled: false,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    contentPadding: EdgeInsets.zero,
  );
}

class _LoginBackButton extends StatelessWidget {
  const _LoginBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 15,
      top: 60,
      width: 40,
      height: 40,
      child: IconButton(
        key: const Key('login-back-button'),
        tooltip: AppLocalizations.of(context)!.backToPreviousPage,
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        color: Theme.of(context).colorScheme.onSurface,
        icon: const Icon(Icons.arrow_back_ios_new, size: 18),
      ),
    );
  }
}

class _LoginKeyboardBackButton extends StatelessWidget {
  const _LoginKeyboardBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const Key('login-keyboard-back-button'),
      tooltip: AppLocalizations.of(context)!.backToPreviousPage,
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      color: Theme.of(context).colorScheme.onSurface,
      icon: const Icon(Icons.arrow_back_ios_new, size: 21),
    );
  }
}

class _LoginIllustration extends StatelessWidget {
  const _LoginIllustration();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          key: const Key('login-welcome-illustration'),
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              left: 0,
              top: 0,
              width: 440,
              height: 610,
              child: Image.asset(
                'assets/images/login_illustration_glow.png',
                fit: BoxFit.fill,
              ),
            ),
            Positioned(
              left: 93,
              top: 108,
              width: 254,
              height: 250,
              child: Image.asset(
                'assets/images/login_character.png',
                fit: BoxFit.fill,
              ),
            ),
            Positioned(
              left: 236.54,
              top: 152.42,
              width: 175,
              height: 112,
              child: Image.asset(
                'assets/images/login_brand_bubble.png',
                fit: BoxFit.fill,
              ),
            ),
            Positioned(
              left: 21.99,
              top: 81,
              width: 419,
              height: 276,
              child: Image.asset(
                'assets/images/login_topic_bubbles.png',
                fit: BoxFit.fill,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginFieldShell extends StatelessWidget {
  const _LoginFieldShell({
    required this.color,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  final Color color;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      height: 60,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: child,
    );
  }
}

class _LoginFieldDivider extends StatelessWidget {
  const _LoginFieldDivider();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        dark ? Theme.of(context).colorScheme.onSurface : AppColors.textPrimary,
        BlendMode.srcIn,
      ),
      child: SvgPicture.asset(
        'assets/icons/login_field_divider.svg',
        width: 1,
        height: 15,
      ),
    );
  }
}

class _LoginActionButton extends StatelessWidget {
  const _LoginActionButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 360,
      height: 60,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.brand.withValues(alpha: .55),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w400),
        ),
        child: loading
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(label),
      ),
    );
  }
}

class _LoginAgreement extends StatelessWidget {
  const _LoginAgreement({required this.agreed, required this.onChanged});

  final bool agreed;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          checked: agreed,
          button: true,
          child: InkResponse(
            key: const Key('agreement-checkbox'),
            onTap: onChanged,
            radius: 22,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: agreed ? AppColors.brand : const Color(0xFFDAD6E5),
                  width: 2,
                ),
              ),
              child: agreed
                  ? SvgPicture.asset(
                      'assets/icons/login_checkbox_check.svg',
                      width: 20,
                      height: 20,
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: LegalDocumentLinks(
            key: const Key('login-legal-document-links'),
            text: l10n.loginAgreement,
            userAgreementLabel: l10n.userAgreement,
            privacyPolicyLabel: l10n.privacyPolicy,
            openFailedMessage: l10n.networkRequestFailed,
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 12,
              height: 22 / 12,
            ),
            linkStyle: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 12,
              height: 22 / 12,
            ),
          ),
        ),
      ],
    );
  }
}
