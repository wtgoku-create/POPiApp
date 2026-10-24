import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_svg_icon.dart';
import '../../../shared/widgets/app_toast.dart';

typedef HarnessSignInCallback =
    Future<void> Function(String username, String password);
typedef HarnessAccessErrorMessageBuilder =
    String Function(BuildContext context, Object error);

/// Native-only sign-in surface for a remotely hosted Harness.
class HarnessAccessLoginPage extends StatefulWidget {
  const HarnessAccessLoginPage({
    required this.onSignIn,
    required this.errorMessageBuilder,
    this.authenticating = false,
    super.key,
  });

  final HarnessSignInCallback onSignIn;
  final HarnessAccessErrorMessageBuilder errorMessageBuilder;
  final bool authenticating;

  @override
  State<HarnessAccessLoginPage> createState() => _HarnessAccessLoginPageState();
}

class _HarnessAccessLoginPageState extends State<HarnessAccessLoginPage> {
  final _usernameController = TextEditingController(text: 'popi');
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  bool _passwordVisible = false;
  bool _submitting = false;

  bool get _busy => _submitting || widget.authenticating;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final l10n = AppLocalizations.of(context)!;
    if (username.isEmpty || password.isEmpty) {
      AppToast.error(context, l10n.harnessAccessRequired);
      return;
    }

    setState(() => _submitting = true);
    try {
      await widget.onSignIn(username, password);
    } on Object catch (error) {
      if (mounted) {
        AppToast.error(context, widget.errorMessageBuilder(context, error));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: colorScheme.brightness == Brightness.light
          ? AppColors.profileBackground
          : colorScheme.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth <= 360 ? 20.0 : 28.0;
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                24,
                horizontalPadding,
                24 + bottomInset,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - 48 - bottomInset).clamp(
                    0,
                    double.infinity,
                  ),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: AutofillGroup(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            child: Container(
                              width: 104,
                              height: 80,
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: colorScheme.primary.withValues(
                                      alpha: .18,
                                    ),
                                    blurRadius: 28,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: const AppSvgIcon.asset(
                                'home_welcome_logo',
                                size: 72,
                                semanticsLabel: 'POPi',
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            l10n.harnessAccessTitle,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            l10n.harnessAccessSubtitle,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.45,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 36),
                          TextField(
                            key: const Key('harness-access-username'),
                            controller: _usernameController,
                            enabled: !_busy,
                            autocorrect: false,
                            enableSuggestions: false,
                            textCapitalization: TextCapitalization.none,
                            autofillHints: const [AutofillHints.username],
                            textInputAction: TextInputAction.next,
                            onSubmitted: (_) =>
                                _passwordFocusNode.requestFocus(),
                            decoration: InputDecoration(
                              labelText: l10n.harnessAccessUsername,
                              hintText: l10n.harnessAccessUsernameHint,
                              prefixIcon: const Icon(
                                Icons.person_outline_rounded,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            key: const Key('harness-access-password'),
                            controller: _passwordController,
                            focusNode: _passwordFocusNode,
                            enabled: !_busy,
                            obscureText: !_passwordVisible,
                            autocorrect: false,
                            enableSuggestions: false,
                            smartDashesType: SmartDashesType.disabled,
                            smartQuotesType: SmartQuotesType.disabled,
                            textCapitalization: TextCapitalization.none,
                            autofillHints: const [AutofillHints.password],
                            keyboardType: TextInputType.visiblePassword,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              labelText: l10n.harnessAccessPassword,
                              hintText: l10n.passwordHint,
                              prefixIcon: const Icon(
                                Icons.lock_outline_rounded,
                              ),
                              suffixIcon: IconButton(
                                key: const Key(
                                  'harness-access-password-visibility',
                                ),
                                tooltip: _passwordVisible
                                    ? l10n.hidePassword
                                    : l10n.showPassword,
                                onPressed: _busy
                                    ? null
                                    : () => setState(
                                        () => _passwordVisible =
                                            !_passwordVisible,
                                      ),
                                icon: Icon(
                                  _passwordVisible
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 54,
                            child: FilledButton(
                              key: const Key('harness-access-submit'),
                              onPressed: _busy ? null : _submit,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 160),
                                child: _busy
                                    ? Row(
                                        key: const Key(
                                          'harness-access-submitting',
                                        ),
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox.square(
                                            dimension: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: colorScheme.onPrimary,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Flexible(
                                            child: Text(
                                              l10n.harnessAccessSigningIn,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Text(
                                        l10n.harnessAccessSignIn,
                                        key: const Key(
                                          'harness-access-submit-label',
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ],
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
}
