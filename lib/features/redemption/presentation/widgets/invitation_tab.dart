import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/app_svg_icon.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../data/redemption_repository.dart';
import '../../domain/redemption.dart';
import 'redemption_banner.dart';
import 'wechat_binding_dialog.dart';

class InvitationTab extends StatefulWidget {
  const InvitationTab({
    required this.repository,
    required this.onReward,
    super.key,
  });
  final RedemptionRepository repository;
  final Future<void> Function() onReward;

  @override
  State<InvitationTab> createState() => _InvitationTabState();
}

class _InvitationTabState extends State<InvitationTab> {
  bool? _bound;
  bool _bindingLoading = false;
  bool _bindingError = false;
  bool _dialogOpen = false;
  bool _codesLoading = false;
  bool _recordsLoading = false;
  bool _codesError = false;
  bool _recordsError = false;
  bool _moreCodes = true;
  bool _moreRecords = true;
  int _codesPage = 1;
  int _recordsPage = 1;
  List<InvitationCode> _codes = [];
  List<InvitationRecord> _records = [];

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    if (_bindingLoading || _codesLoading || _recordsLoading) return;
    setState(() {
      _bindingLoading = true;
      _bindingError = false;
    });
    try {
      final bound = await widget.repository.isWechatBound();
      if (!mounted) return;
      setState(() {
        _bound = bound;
        if (!bound) {
          _codes = [];
          _records = [];
        }
      });
      if (bound) {
        await Future.wait([_loadCodes(reset: true), _loadRecords(reset: true)]);
      }
    } catch (_) {
      if (mounted) setState(() => _bindingError = true);
    } finally {
      if (mounted) setState(() => _bindingLoading = false);
    }
  }

  Future<void> _loadCodes({bool reset = false}) async {
    if (_codesLoading || (!reset && !_moreCodes)) return;
    final page = reset ? 1 : _codesPage;
    setState(() {
      _codesLoading = true;
      _codesError = false;
    });
    try {
      final result = await widget.repository.fetchCodes(page);
      if (!mounted) return;
      setState(() {
        _codes = reset ? result.items : [..._codes, ...result.items];
        _moreCodes = result.hasMore;
        _codesPage = page + 1;
      });
    } catch (_) {
      if (mounted) setState(() => _codesError = true);
    } finally {
      if (mounted) setState(() => _codesLoading = false);
    }
  }

  Future<void> _loadRecords({bool reset = false}) async {
    if (_recordsLoading || (!reset && !_moreRecords)) return;
    final page = reset ? 1 : _recordsPage;
    setState(() {
      _recordsLoading = true;
      _recordsError = false;
    });
    try {
      final result = await widget.repository.fetchRecords(page);
      if (!mounted) return;
      setState(() {
        _records = reset ? result.items : [..._records, ...result.items];
        _moreRecords = result.hasMore;
        _recordsPage = page + 1;
      });
    } catch (_) {
      if (mounted) setState(() => _recordsError = true);
    } finally {
      if (mounted) setState(() => _recordsLoading = false);
    }
  }

  Future<void> _bind() async {
    if (_dialogOpen) return;
    setState(() => _dialogOpen = true);
    try {
      final bound = await AppDialog.show<bool>(
        context: context,
        builder: (_) => WechatBindingDialog(repository: widget.repository),
      );
      if (!mounted || bound != true) return;
      AppToast.success(
        context,
        AppLocalizations.of(context)!.redemptionBindingSuccess,
      );
      unawaited(widget.onReward());
      await _refresh();
    } finally {
      if (mounted) setState(() => _dialogOpen = false);
    }
  }

  Future<void> _copy(String code) async {
    try {
      await Clipboard.setData(ClipboardData(text: code));
      if (mounted) {
        AppToast.success(
          context,
          AppLocalizations.of(context)!.redemptionCopied,
        );
      }
    } catch (_) {
      if (mounted) {
        AppToast.error(context, AppLocalizations.of(context)!.redemptionFailed);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final surface = Theme.of(context).brightness == Brightness.light
        ? Colors.white.withValues(alpha: .5)
        : colors.surfaceContainerLow;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          RedemptionBanner(
            title: l10n.redemptionInviteTitle,
            description: l10n.redemptionInviteDescription,
            points: 200,
          ),
          const SizedBox(height: 16),
          if (_bindingLoading && _bound == null)
            const Center(child: CircularProgressIndicator())
          else if (_bindingError)
            _ListStatus(
              error: true,
              loading: false,
              empty: false,
              more: false,
              onLoad: _refresh,
            )
          else if (_bound == false) ...[
            const SizedBox(height: 20),
            Text(
              l10n.redemptionBindRequired,
              key: const Key('redemption-bind-required'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _dialogOpen ? null : _bind,
              child: Text(l10n.redemptionBindAction),
            ),
          ] else if (_bound == true) ...[
            Text(
              l10n.redemptionMyCodes,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            for (final code in _codes)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  key: ValueKey('invite-code-${code.code}'),
                  padding: const EdgeInsets.fromLTRB(20, 15, 12, 15),
                  decoration: BoxDecoration(
                    color: code.isUsed
                        ? colors.primary.withValues(alpha: .05)
                        : surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              code.code,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                if (code.isUsed) ...[
                                  Icon(
                                    Icons.check,
                                    size: 18,
                                    color: colors.primary,
                                  ),
                                  const SizedBox(width: 5),
                                ],
                                Expanded(
                                  child: Text(
                                    code.isUsed
                                        ? l10n.redemptionUsed
                                        : l10n.redemptionPending,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: code.isUsed
                                          ? colors.primary
                                          : colors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (code.isUsed)
                        const Text(
                          '+200',
                          style: TextStyle(
                            color: AppColors.brand,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      else
                        IconButton(
                          key: ValueKey('invite-copy-${code.code}'),
                          tooltip: l10n.copyAction,
                          onPressed: () => _copy(code.code),
                          icon: AppSvgIcon.asset(
                            'redemption_copy',
                            size: 18,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            _ListStatus(
              key: const Key('invite-codes-status'),
              error: _codesError,
              loading: _codesLoading,
              empty: _codes.isEmpty,
              more: _moreCodes,
              emptyLabel: l10n.redemptionCodesEmpty,
              onLoad: () => _loadCodes(),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.redemptionRecords,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < _records.length; i++)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 15,
                ),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _records[i].name.isEmpty ? '--' : _records[i].name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _formatDate(_records[i].createdAt),
                            style: TextStyle(
                              fontSize: 14,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.redemptionRegistered,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 16,
                          color: colors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            _ListStatus(
              key: const Key('invite-records-status'),
              error: _recordsError,
              loading: _recordsLoading,
              empty: _records.isEmpty,
              more: _moreRecords,
              emptyLabel: l10n.redemptionRecordsEmpty,
              onLoad: () => _loadRecords(),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.redemptionFooter,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: colors.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _ListStatus extends StatelessWidget {
  const _ListStatus({
    required this.error,
    required this.loading,
    required this.empty,
    required this.more,
    required this.onLoad,
    this.emptyLabel = '',
    super.key,
  });
  final bool error;
  final bool loading;
  final bool empty;
  final bool more;
  final String emptyLabel;
  final VoidCallback onLoad;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error) {
      return Column(
        children: [
          Text(l10n.redemptionLoadFailed, textAlign: TextAlign.center),
          TextButton.icon(
            onPressed: onLoad,
            icon: const Icon(Icons.refresh),
            label: Text(l10n.retry),
          ),
        ],
      );
    }
    if (empty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(emptyLabel, textAlign: TextAlign.center),
      );
    }
    if (more) {
      return TextButton.icon(
        onPressed: onLoad,
        icon: const Icon(Icons.expand_more),
        label: Text(l10n.redemptionLoadMore),
      );
    }
    return const SizedBox.shrink();
  }
}

String _formatDate(DateTime? date) {
  if (date == null) return '--';
  final local = date.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}
