import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../data/redemption_repository.dart';
import '../../domain/redemption.dart';
import 'redemption_banner.dart';

/// Displays and claims the registration reward using a friend's invite code.
class RegistrationRewardTab extends StatefulWidget {
  const RegistrationRewardTab({
    required this.repository,
    required this.onReward,
    super.key,
  });

  final RedemptionRepository repository;
  final Future<void> Function() onReward;

  @override
  State<RegistrationRewardTab> createState() => _RegistrationRewardTabState();
}

class _RegistrationRewardTabState extends State<RegistrationRewardTab> {
  final _input = TextEditingController();
  RegistrationReward? _reward;
  bool _loading = false;
  bool _submitting = false;
  Object? _error;

  bool get _claimed => _reward?.claimed == true;
  bool get _canSubmit =>
      !_loading &&
      !_submitting &&
      !_claimed &&
      _error == null &&
      _reward != null &&
      _input.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading || _submitting) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final reward = await widget.repository.fetchRegistrationReward();
      if (!mounted) return;
      setState(() {
        _reward = reward;
        if (reward.claimed) _input.text = reward.code;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final code = _input.text.trim();
    final l10n = AppLocalizations.of(context)!;
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    try {
      await widget.repository.claimRegistrationReward(code);
      if (!mounted) return;
      setState(() {
        _reward = RegistrationReward(
          points: _reward!.points,
          claimed: true,
          code: code,
        );
        _input.text = code;
      });
      AppToast.success(context, l10n.redemptionClaimSuccess);
      unawaited(widget.onReward());
    } catch (error) {
      if (mounted) {
        AppToast.error(
          context,
          redemptionErrorMessage(error, l10n.redemptionFailed),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final showRewardContent =
        _reward != null && _error is! RegistrationRewardUnavailable;
    final content = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        if (showRewardContent) ...[
          RedemptionBanner(
            title: l10n.redemptionRewardTitle,
            description: l10n.redemptionRewardDescription(_reward!.points),
            points: _reward!.points,
          ),
          const SizedBox(height: 20),
          Text(
            l10n.redemptionFriendCode,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
        ] else
          const SizedBox(height: 32),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_error != null) ...[
          Text(
            _error is RegistrationRewardUnavailable
                ? l10n.redemptionRewardClosed
                : l10n.redemptionLoadFailed,
            key: const Key('redemption-reward-error'),
            textAlign: TextAlign.center,
          ),
          if (_error is! RegistrationRewardUnavailable)
            TextButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retry),
            ),
        ] else ...[
          TextField(
            key: const Key('redemption-friend-input'),
            controller: _input,
            readOnly: _claimed || _submitting,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
            style: const TextStyle(fontSize: 18),
            decoration: InputDecoration(
              hintText: l10n.redemptionFriendPlaceholder,
              hintStyle: TextStyle(
                fontSize: 16,
                color: colors.onSurfaceVariant,
              ),
              filled: true,
              fillColor: colors.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(100),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(100),
                borderSide: BorderSide.none,
              ),
              suffixIcon: _claimed
                  ? Icon(Icons.check_circle, color: colors.primary, size: 20)
                  : null,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 50,
            child: FilledButton(
              key: const Key('redemption-claim'),
              onPressed: _canSubmit ? _submit : null,
              style: FilledButton.styleFrom(
                shape: const StadiumBorder(),
                disabledBackgroundColor: _claimed ? colors.primary : null,
                disabledForegroundColor: _claimed ? colors.onPrimary : null,
              ),
              child: _submitting
                  ? SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.onPrimary,
                      ),
                    )
                  : Text(
                      _claimed ? l10n.redemptionClaimed : l10n.confirm,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ],
    );
    return RefreshIndicator(onRefresh: _load, child: content);
  }
}

String redemptionErrorMessage(Object error, String fallback) {
  final message = switch (error) {
    ApiException() => error.message,
    DioException() => ApiException.fromDioException(error).message,
    _ => null,
  };
  return message?.trim().isNotEmpty == true ? message! : fallback;
}
