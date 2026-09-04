import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../../app/theme.dart';
import '../../../core/network/api_exception.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/legal_document_links.dart';
import '../domain/captcha_challenge.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key, this.onLoginSuccess});

  final VoidCallback? onLoginSuccess;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
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
  bool _showPhoneLogin = false;

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
    final colorScheme = Theme.of(context).colorScheme;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return PopScope(
      canPop: !_showPhoneLogin,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _showPhoneLogin) _showWelcomeLogin();
      },
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
                  children: [
                    const _LoginIllustration(),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 420),
                      reverseDuration: const Duration(milliseconds: 340),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        final phoneDesign =
                            child.key == const ValueKey('phone-login-design');
                        final curved = CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                          reverseCurve: Curves.easeInCubic,
                        );
                        return FadeTransition(
                          opacity: curved,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: Offset(0, phoneDesign ? .055 : -.035),
                              end: Offset.zero,
                            ).animate(curved),
                            child: ScaleTransition(
                              scale: Tween<double>(begin: .985, end: 1)
                                  .animate(curved),
                              child: child,
                            ),
                          ),
                        );
                      },
                      child: _showPhoneLogin
                          ? _PhoneLoginDesign(
                              key: const ValueKey('phone-login-design'),
                              phoneController: _phoneController,
                              codeController: _codeController,
                              agreed: _agreed,
                              countdown: _countdown,
                              sendingCode: _isSendingCode,
                              loggingIn: _isLoggingIn,
                              onBack: _showWelcomeLogin,
                              onAgreementChanged: _toggleAgreement,
                              onSendCode: _showCaptchaSheet,
                              onLogin: _loginWithPhone,
                            )
                          : _WelcomeLoginDesign(
                              key: const ValueKey('welcome-login-design'),
                              agreed: _agreed,
                              onBack: _closePage,
                              onAgreementChanged: _toggleAgreement,
                              onPhoneLogin: _openPhoneLogin,
                              onWechatLogin: _loginWithWechat,
                            ),
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
                    onPressed: _showPhoneLogin ? _showWelcomeLogin : _closePage,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleAgreement() => setState(() => _agreed = !_agreed);

  void _closePage() {
    FocusManager.instance.primaryFocus?.unfocus();
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      SystemNavigator.pop();
    }
  }

  void _openPhoneLogin() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _showPhoneLogin = true);
  }

  void _showWelcomeLogin() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_showPhoneLogin) setState(() => _showPhoneLogin = false);
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
    if (_captcha == null && !_isCaptchaLoading) await _loadCaptcha();
    if (!mounted) return;

    await AppSheet.show<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> refreshCaptcha() async {
            await _loadCaptcha();
            if (sheetContext.mounted) setSheetState(() {});
          }

          Future<void> confirm() async {
            final sent = await _sendCode();
            if (sent && sheetContext.mounted) {
              Navigator.of(sheetContext).pop();
            } else if (sheetContext.mounted) {
              setSheetState(() {});
            }
          }

          final colorScheme = Theme.of(context).colorScheme;
          return Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              4,
              24,
              24 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.graphicalCaptcha,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('login-captcha-field'),
                        controller: _captchaController,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          hintText: l10n.graphicalCaptchaHint,
                        ),
                        onSubmitted: (_) => confirm(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _CaptchaPreview(
                      challenge: _captcha,
                      loading: _isCaptchaLoading,
                      refreshTooltip: l10n.refreshCaptcha,
                      onRefresh: _isCaptchaLoading ? null : refreshCaptcha,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    key: const Key('confirm-send-code-button'),
                    onPressed: _isSendingCode ? null : confirm,
                    child: _isSendingCode
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(l10n.sendVerificationCode),
                  ),
                ),
              ],
            ),
          );
        },
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

  Future<bool> _sendCode() async {
    final l10n = AppLocalizations.of(context)!;
    final phoneError = _validatePhone(_phoneController.text, l10n);
    if (phoneError != null) {
      AppToast.error(context, phoneError);
      return false;
    }
    if (!_ensureAgreement(l10n)) return false;
    final captcha = _captcha;
    final captchaValue = _captchaController.text.trim();
    if (captcha == null || captchaValue.isEmpty) {
      AppToast.error(context, l10n.graphicalCaptchaRequired);
      return false;
    }

    setState(() => _isSendingCode = true);
    try {
      await ref.read(authRepositoryProvider).sendLoginCode(
            phone: _phoneController.text.trim(),
            captchaId: captcha.id,
            captchaValue: captchaValue,
          );
      if (!mounted) return false;
      _startCountdown();
      AppToast.success(context, l10n.verificationCodeSent);
      return true;
    } catch (error) {
      if (!mounted) return false;
      AppToast.error(context, _errorMessage(error));
      await _loadCaptcha();
      return false;
    } finally {
      if (mounted) setState(() => _isSendingCode = false);
    }
  }

  Future<void> _loginWithPhone() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_ensureAgreement(l10n)) return;
    final phoneError = _validatePhone(_phoneController.text, l10n);
    if (phoneError != null) {
      AppToast.error(context, phoneError);
      return;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(_codeController.text.trim())) {
      AppToast.error(context, l10n.invalidVerificationCode);
      return;
    }

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
    if (error case ApiException(message: final String message)
        when message.trim().isNotEmpty) {
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
          physics: keyboardOpen
              ? const ClampingScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Align(
              alignment:
                  keyboardOpen ? Alignment.topCenter : Alignment.bottomCenter,
              child: canvas,
            ),
          ),
        );
      },
    );
  }
}

class _WelcomeLoginDesign extends StatelessWidget {
  const _WelcomeLoginDesign({
    required this.agreed,
    required this.onBack,
    required this.onAgreementChanged,
    required this.onPhoneLogin,
    required this.onWechatLogin,
    super.key,
  });

  final bool agreed;
  final VoidCallback onBack;
  final VoidCallback onAgreementChanged;
  final VoidCallback onPhoneLogin;
  final VoidCallback onWechatLogin;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        _LoginBackButton(onPressed: onBack),
        const Positioned(
          left: 26,
          top: 678,
          width: 388,
          child: _LoginBrandCopy(),
        ),
        Positioned(
          left: 57,
          top: 768,
          width: 326,
          child: Column(
            children: [
              _LoginActionButton(
                key: const Key('login-phone-entry-button'),
                label: l10n.phoneLogin,
                onPressed: onPhoneLogin,
              ),
              const SizedBox(height: 10),
              _LoginActionButton(
                key: const Key('wechat-login-button'),
                label: l10n.wechatLogin,
                onPressed: onWechatLogin,
                backgroundColor: colorScheme.brightness == Brightness.light
                    ? const Color(0xFFF0F4F9)
                    : colorScheme.surfaceContainerHighest,
                foregroundColor: colorScheme.onSurface,
                borderColor: colorScheme.brightness == Brightness.light
                    ? const Color(0xFFDAD6E5)
                    : colorScheme.outline,
              ),
            ],
          ),
        ),
        Positioned(
          left: 26,
          top: 918,
          width: 388,
          child: _LoginAgreement(
            agreed: agreed,
            onChanged: onAgreementChanged,
          ),
        ),
      ],
    );
  }
}

class _PhoneLoginDesign extends StatelessWidget {
  const _PhoneLoginDesign({
    required this.phoneController,
    required this.codeController,
    required this.agreed,
    required this.countdown,
    required this.sendingCode,
    required this.loggingIn,
    required this.onBack,
    required this.onAgreementChanged,
    required this.onSendCode,
    required this.onLogin,
    super.key,
  });

  final TextEditingController phoneController;
  final TextEditingController codeController;
  final bool agreed;
  final int countdown;
  final bool sendingCode;
  final bool loggingIn;
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
        const Positioned(
          left: 26,
          top: 613,
          width: 388,
          child: _LoginBrandCopy(),
        ),
        Positioned(
          left: 57,
          top: 703,
          width: 326,
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
              const SizedBox(height: 10),
              _LoginFieldShell(
                color: fieldColor,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('login-code-field'),
                        controller: codeController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        maxLength: 6,
                        style: textStyle,
                        decoration: _fieldDecoration(l10n.verificationCodeHint),
                        onSubmitted: (_) => onLogin(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const _LoginFieldDivider(),
                    const SizedBox(width: 14),
                    TextButton(
                      key: const Key('send-code-button'),
                      onPressed:
                          countdown > 0 || sendingCode ? null : onSendCode,
                      style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: colorScheme.onSurface,
                        disabledForegroundColor: colorScheme.onSurfaceVariant,
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      child: Text(
                        sendingCode
                            ? l10n.sendingVerificationCode
                            : countdown > 0
                                ? l10n.resendCountdown(countdown)
                                : l10n.sendVerificationCode,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _LoginActionButton(
                key: const Key('phone-login-button'),
                label: l10n.loginOrRegister,
                onPressed: loggingIn ? null : onLogin,
                loading: loggingIn,
              ),
            ],
          ),
        ),
        Positioned(
          left: 26,
          top: 918,
          width: 388,
          child: _LoginAgreement(
            agreed: agreed,
            onChanged: onAgreementChanged,
          ),
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
      left: 20,
      top: 76,
      width: 40,
      height: 40,
      child: IconButton(
        key: const Key('login-back-button'),
        tooltip: AppLocalizations.of(context)!.backToPreviousPage,
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        color: Theme.of(context).colorScheme.onSurface,
        icon: const Icon(Icons.arrow_back_ios_new, size: 21),
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
    return Positioned(
      left: 6.5,
      top: 170,
      width: 427,
      height: 427,
      child: Lottie.asset(
        'assets/images/login_welcome_animation.json',
        key: const Key('login-welcome-illustration'),
        fit: BoxFit.cover,
        repeat: true,
        animate: !MediaQuery.disableAnimationsOf(context),
      ),
    );
  }
}

class _LoginBrandCopy extends StatelessWidget {
  const _LoginBrandCopy();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Text(
      'POPi\n${l10n.splashTagline}',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: 25,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: .25,
      ),
    );
  }
}

class _LoginFieldShell extends StatelessWidget {
  const _LoginFieldShell({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 326,
      height: 55,
      padding: const EdgeInsets.symmetric(horizontal: 20),
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
    this.backgroundColor = AppColors.brand,
    this.foregroundColor = Colors.white,
    this.borderColor,
    this.loading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? borderColor;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 326,
      height: 55,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          disabledBackgroundColor: backgroundColor.withValues(alpha: .55),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            side: borderColor == null
                ? BorderSide.none
                : BorderSide(color: borderColor!),
          ),
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w400,
          ),
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
              width: 15,
              height: 15,
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
                      width: 15,
                      height: 15,
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
              fontSize: 10,
              height: 1.5,
            ),
            linkStyle: const TextStyle(
              color: AppColors.brand,
              fontSize: 10,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
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
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: refreshTooltip,
      child: Material(
        color: colorScheme.surface,
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
