import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/providers/social_binding_provider.dart';
import '../../../../shared/providers/user_provider.dart';
import '../../../../shared/type/social_app_type.dart';
import '../../../../shared/widgets/app_svg_icon.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../domain/social_app_binding.dart';
import 'profile_settings_row.dart';

/// Loads fresh binding state whenever the profile is opened or the user changes.
class SocialAppBindingRow extends ConsumerStatefulWidget {
  const SocialAppBindingRow({required this.app, super.key});

  final SocialAppType app;

  @override
  ConsumerState<SocialAppBindingRow> createState() =>
      _SocialAppBindingRowState();
}

class _SocialAppBindingRowState extends ConsumerState<SocialAppBindingRow> {
  AsyncValue<SocialAppBinding?> _binding = const AsyncData(null);
  bool _bindingInProgress = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    ref.listenManual(
      userProvider.select((user) => user?.id),
      (_, __) => unawaited(_load()),
      fireImmediately: true,
    );
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final signedIn = ref.read(userProvider) != null;
    setState(() {
      _bindingInProgress = false;
      _binding = signedIn ? const AsyncLoading() : const AsyncData(null);
    });
    if (!signedIn) return;
    final result = await AsyncValue.guard(
      () =>
          ref.read(socialAppBindingRepositoryProvider).fetchStatus(widget.app),
    );
    if (mounted && generation == _generation) {
      setState(() => _binding = result);
    }
  }

  Future<void> _bind() async {
    if (_bindingInProgress || _binding.valueOrNull?.bound != false) return;
    final generation = _generation;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _bindingInProgress = true);
    try {
      final binding = await ref
          .read(socialAppBindingRepositoryProvider)
          .bind(
            widget.app,
            isCurrentUser: () => mounted && generation == _generation,
          );
      if (!mounted || generation != _generation) return;
      setState(() => _binding = AsyncData(binding));
      AppToast.success(context, l10n.socialBindingSucceeded);
    } catch (error) {
      if (!mounted || generation != _generation) return;
      final reason = error is SocialBindingException ? error.reason : null;
      if (reason == SocialBindingFailure.canceled) {
        AppToast.info(context, l10n.socialBindingCanceled);
      } else {
        AppToast.error(
          context,
          reason == SocialBindingFailure.unavailable
              ? l10n.socialBindingUnavailable
              : l10n.socialBindingFailed,
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _bindingInProgress = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final binding = _binding.valueOrNull;
    final busy = _binding.isLoading || _bindingInProgress;
    final canBind = binding?.bound == false && !busy;
    final canRetry = _binding.hasError && !busy;
    final value = busy
        ? l10n.socialBindingLoading
        : _binding.hasError
        ? l10n.socialBindingLoadFailed
        : binding == null
        ? '--'
        : binding.bound
        ? (binding.nickname.isEmpty ? l10n.socialBound : binding.nickname)
        : l10n.socialUnbound;

    return SettingsRow(
      key: Key('profile-${widget.app.name}-binding'),
      iconWidget: AppSvgIcon.asset(
        widget.app == SocialAppType.wechat
            ? 'profile_settings_wechat'
            : 'profile_settings_douyin',
        size: widget.app == SocialAppType.wechat ? 21 : 20,
      ),
      label: widget.app == SocialAppType.wechat ? l10n.wechatId : l10n.douyin,
      value: value,
      onTap: canRetry
          ? _load
          : canBind
          ? _bind
          : null,
      showChevron: canRetry || canBind,
    );
  }
}
