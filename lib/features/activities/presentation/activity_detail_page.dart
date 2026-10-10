import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/network_api.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/providers/network_provider.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_toast.dart';
import '../data/activity_repository.dart';
import '../domain/activity.dart';
import 'widgets/activity_widgets.dart';
import 'widgets/book_card_confirmation.dart';

/// Redeems a selected campaign, including book-card acknowledgement and QR output.
class ActivityDetailPage extends ConsumerStatefulWidget {
  const ActivityDetailPage({
    required this.activityId,
    this.catalog,
    this.repository,
    super.key,
  });

  final int activityId;
  final ActivityCatalog? catalog;
  final ActivityRepository? repository;

  @override
  ConsumerState<ActivityDetailPage> createState() => _ActivityDetailPageState();
}

class _ActivityDetailPageState extends ConsumerState<ActivityDetailPage> {
  late final ActivityRepository _repository;
  final _code = TextEditingController();
  ActivityCatalog? _catalog;
  bool _loading = false;
  bool _failed = false;
  bool _busy = false;
  bool _sending = false;
  String? _qrUrl;
  int _qrAttempt = 0;

  Activity? get _activity => _catalog?.activities
      .where((item) => item.id == widget.activityId)
      .firstOrNull;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ??
        ActivityRepository(NetworkApi(ref.read(dioProvider)));
    _catalog = widget.catalog;
    if (_catalog == null) _load();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final catalog = await _repository.fetchCatalog();
      if (mounted) setState(() => _catalog = catalog);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final activity = _activity;
    final user = ref.read(userProvider);
    if (_busy || activity == null || user == null) return;
    final code = _code.text.trim();
    if (code.isEmpty || !activity.allowsMemberLevel(user.memberLevel)) return;
    final l10n = AppLocalizations.of(context)!;
    if (!activity.isActiveAt(DateTime.now())) {
      setState(() {});
      AppToast.error(context, l10n.activityUnavailable);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      if (activity.isBookCard) {
        final confirmed = await AppDialog.show<bool>(
          context: context,
          builder: (_) => const BookCardConfirmation(),
        );
        if (confirmed != true) return;
      }
      if (!mounted || ref.read(userProvider)?.id != user.id) return;
      final currentUser = ref.read(userProvider)!;
      setState(() => _sending = true);
      final qr = await _repository.redeem(
        activity,
        code,
        memberLevel: currentUser.memberLevel,
      );
      if (!mounted || ref.read(userProvider)?.id != user.id) return;
      _code.clear();
      setState(() => _qrUrl = qr);
      AppToast.success(context, l10n.activityExchangeSuccess);
      // Apply refreshed benefits only to the account that redeemed the code.
      try {
        final auth = ref.read(authRepositoryProvider);
        final updated = await auth.fetchCurrentUser();
        if (mounted &&
            ref.read(userProvider)?.id == user.id &&
            updated.id == user.id) {
          await ref.read(userProvider.notifier).setUser(updated);
        }
      } catch (_) {
        if (mounted && ref.read(userProvider)?.id == user.id) {
          AppToast.info(context, l10n.activityRefreshFailed);
        }
      }
    } catch (error) {
      if (mounted && ref.read(userProvider)?.id == user.id) {
        final message = error is ApiException ? error.message : null;
        AppToast.error(
          context,
          message?.isNotEmpty == true ? message! : l10n.activityExchangeFailed,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _sending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final user = ref.watch(userProvider);
    ref.listen(userProvider.select((user) => user?.id), (previous, next) {
      _code.clear();
      setState(() => _qrUrl = null);
    });
    final activity = _activity;
    final active = activity?.isActiveAt(DateTime.now()) ?? false;
    final eligible =
        user != null && active && activity!.allowsMemberLevel(user.memberLevel);
    final colors = Theme.of(context).colorScheme;
    return ActivityScaffold(
      title: activity?.name.isNotEmpty == true
          ? activity!.name
          : l10n.activityCenter,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _failed
          ? ActivityLoadError(onRetry: _load)
          : activity == null
          ? Center(child: Text(l10n.activityUnavailable))
          : SingleChildScrollView(
              key: const Key('activity-detail-scroll'),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              child: _qrUrl != null
                  ? Column(
                      children: [
                        Text(
                          l10n.activityQrTitle,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox.square(
                          dimension: 280,
                          child: Image.network(
                            _qrUrl!,
                            key: ValueKey('$_qrUrl:$_qrAttempt'),
                            fit: BoxFit.contain,
                            semanticLabel: l10n.activityQrTitle,
                            errorBuilder: (_, _, _) => ActivityLoadError(
                              onRetry: () => setState(() => _qrAttempt++),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ActivityBanner(url: activity.coverUrl),
                        if (activity.tags.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              for (final tag in activity.tags)
                                ActivityBadge(tag: tag),
                            ],
                          ),
                        ],
                        if (activity.description.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            activity.description,
                            style: const TextStyle(fontSize: 14, height: 1.5),
                          ),
                        ],
                        const SizedBox(height: 20),
                        Text(
                          activity.isBookCard
                              ? l10n.activityOrderNumber
                              : l10n.activityOfficialCode,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (!active || (user != null && !eligible)) ...[
                          Text(
                            !active
                                ? l10n.activityUnavailable
                                : l10n.activityMemberRestriction(
                                    activity.memberLevels
                                        .map(
                                          (level) =>
                                              _catalog!.memberLabels[level] ??
                                              l10n.activityMemberLevel(level),
                                        )
                                        .join('、'),
                                  ),
                            style: TextStyle(color: colors.onSurfaceVariant),
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextField(
                          key: const Key('activity-code-input'),
                          controller: _code,
                          enabled: eligible && !_busy,
                          maxLength: 64,
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _submit(),
                          textInputAction: TextInputAction.done,
                          style: const TextStyle(fontSize: 18),
                          decoration: InputDecoration(
                            hintText: activity.isBookCard
                                ? l10n.activityOrderPlaceholder
                                : l10n.activityCodePlaceholder,
                            counterText: '',
                            filled: true,
                            fillColor:
                                Theme.of(context).brightness == Brightness.light
                                ? Colors.white
                                : colors.surfaceContainer,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 15,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(100),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(100),
                              borderSide: BorderSide.none,
                            ),
                            disabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(100),
                              borderSide: BorderSide.none,
                            ),
                            hintMaxLines: 2,
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 50,
                          child: FilledButton(
                            key: const Key('activity-submit'),
                            onPressed: user == null
                                ? () => context.push('/login')
                                : eligible &&
                                      !_busy &&
                                      _code.text.trim().isNotEmpty
                                ? _submit
                                : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.brand,
                              shape: const StadiumBorder(),
                              textStyle: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            child: _sending
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    user == null
                                        ? l10n.loginOrRegister
                                        : l10n.confirm,
                                  ),
                          ),
                        ),
                      ],
                    ),
            ),
    );
  }
}
