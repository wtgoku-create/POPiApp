import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/network_api.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/providers/network_provider.dart';
import '../../../shared/providers/user_provider.dart';
import '../data/redemption_repository.dart';
import 'widgets/invitation_tab.dart';
import 'widgets/registration_reward_tab.dart';

class RedemptionPage extends ConsumerWidget {
  const RedemptionPage({this.repository, super.key});

  final RedemptionRepository? repository;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final userId = ref.watch(userProvider.select((user) => user?.id));
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark
        ? Theme.of(context).colorScheme.surface
        : const Color(0xFFF5F4FA);
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        centerTitle: true,
        leading: IconButton(
          tooltip: l10n.back,
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new, size: 21),
        ),
        title: Text(
          l10n.redemptionPageTitle,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ),
      body: userId == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.redemptionLoginRequired),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.push('/login'),
                    child: Text(l10n.loginOrRegister),
                  ),
                ],
              ),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: _RedemptionContent(
                  key: ValueKey(userId),
                  repository:
                      repository ??
                      RedemptionRepository(NetworkApi(ref.read(dioProvider))),
                  onReward: () async {
                    final users = ref.read(userProvider.notifier);
                    final points = ref.read(userPointsProvider.notifier);
                    try {
                      await users.refreshUser();
                    } catch (_) {
                      /* Keep cached user on refresh failure. */
                    }
                    if (context.mounted &&
                        ref.read(userProvider)?.id == userId) {
                      await points.refresh();
                    }
                  },
                ),
              ),
            ),
    );
  }
}

class _RedemptionContent extends StatefulWidget {
  const _RedemptionContent({
    required this.repository,
    required this.onReward,
    super.key,
  });
  final RedemptionRepository repository;
  final Future<void> Function() onReward;

  @override
  State<_RedemptionContent> createState() => _RedemptionContentState();
}

class _RedemptionContentState extends State<_RedemptionContent> {
  int _index = 0;
  final _opened = [true, false];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final labels = [l10n.redemptionMyCodes, l10n.redemptionRegistrationReward];
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: .05),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              children: [
                for (var i = 0; i < labels.length; i++)
                  Expanded(
                    child: Semantics(
                      selected: _index == i,
                      child: TextButton(
                        key: Key('redemption-tab-$i'),
                        onPressed: () => setState(() {
                          _index = i;
                          _opened[i] = true;
                        }),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 8,
                          ),
                          minimumSize: const Size(0, 34),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          backgroundColor: _index == i
                              ? colors.surface
                              : Colors.transparent,
                          foregroundColor: _index == i
                              ? colors.onSurface
                              : colors.onSurfaceVariant,
                          shape: const StadiumBorder(),
                        ),
                        child: Text(
                          labels[i],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: _index == i
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _index,
            children: [
              InvitationTab(
                repository: widget.repository,
                onReward: widget.onReward,
              ),
              if (_opened[1])
                RegistrationRewardTab(
                  repository: widget.repository,
                  onReward: widget.onReward,
                )
              else
                const SizedBox.shrink(),
            ],
          ),
        ),
      ],
    );
  }
}
