import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_svg_icon.dart';
import '../../domain/ip_account_home.dart';

/// Account creation archives shared by the overview and history page.
class IpAccountHistory extends StatelessWidget {
  const IpAccountHistory({
    required this.creations,
    required this.loading,
    required this.failed,
    required this.onRetry,
    required this.onOpen,
    required this.onOpenAll,
    super.key,
  });

  final List<IpAccountCreation> creations;
  final bool loading;
  final bool failed;
  final VoidCallback onRetry;
  final ValueChanged<IpAccountCreation> onOpen;
  final VoidCallback onOpenAll;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const Key('ip-account-history-section'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.brightness == Brightness.light
            ? Colors.white.withValues(alpha: .5)
            : colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.creationHistory,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox.square(
                dimension: 40,
                child: IconButton(
                  key: const Key('ip-account-history-all'),
                  tooltip: l10n.creationHistory,
                  onPressed: onOpenAll,
                  alignment: Alignment.centerRight,
                  icon: AppSvgIcon.asset(
                    'ip_account_chevron',
                    size: 12,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (failed)
            Row(
              children: [
                Expanded(child: Text(l10n.creationHistoryLoadFailed)),
                IconButton(
                  key: const Key('ip-account-history-retry'),
                  tooltip: l10n.retry,
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            )
          else if (creations.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                l10n.noHistory,
                style: TextStyle(fontSize: 14, color: colors.onSurfaceVariant),
              ),
            )
          else
            for (final creation in creations.take(3))
              IpAccountHistoryRow(
                creation: creation,
                onTap: () => onOpen(creation),
              ),
        ],
      ),
    );
  }
}

/// Shared archive title and summary row for the overview and history page.
class IpAccountHistoryRow extends StatelessWidget {
  const IpAccountHistoryRow({
    required this.creation,
    required this.onTap,
    this.arrowColor,
    super.key,
  });

  final IpAccountCreation creation;
  final VoidCallback onTap;
  final Color? arrowColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      child: InkWell(
        key: ValueKey('ip-account-history-${creation.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 90),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        creation.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    AppSvgIcon.asset(
                      'ip_account_chevron',
                      size: 10,
                      color: arrowColor ?? colors.onSurface,
                    ),
                  ],
                ),
                if (creation.summary.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    creation.summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: colors.onSurface),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
