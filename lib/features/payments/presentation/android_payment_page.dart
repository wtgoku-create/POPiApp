import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/providers/payment_provider.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/type/payment_type.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_svg_icon.dart';
import '../../../shared/widgets/app_toast.dart';
import '../data/android_payment_service.dart';
import '../domain/mobile_payment.dart';

/// Shared Android checkout for both membership plans and points packages.
class AndroidPaymentPage extends ConsumerStatefulWidget {
  const AndroidPaymentPage({required this.product, super.key});

  final PaymentProduct product;

  @override
  ConsumerState<AndroidPaymentPage> createState() => _AndroidPaymentPageState();
}

class _AndroidPaymentPageState extends ConsumerState<AndroidPaymentPage>
    with WidgetsBindingObserver {
  AndroidPaymentService? _service;
  PaymentChannel _channel = PaymentChannel.wechat;
  final _channels = <PaymentChannel, bool>{};
  PaymentResult? _result;
  bool _loading = true;
  bool _working = false;
  String? _error;
  int? _previewAmount;
  List<PendingPayment> _history = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !_working &&
        !_loading &&
        _result?.pending?.tradeNo != null &&
        _result?.state?.terminal != true) {
      unawaited(_check());
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _loading = true;
      _error = null;
    });
    final service = ref.read(androidPaymentServiceProvider);
    _service = service;
    try {
      if (!service.available) throw const ApiException();
      final pending = service.storage.read(widget.product);
      if (pending != null) {
        _result = await service.check(pending);
        _channel = pending.channel;
      } else if (widget.product.kind == PaymentProductKind.subscription) {
        final preview = await service.repository.preview(widget.product);
        _previewAmount = paymentInteger(preview['amount_fen']);
      }
      for (final channel in PaymentChannel.values) {
        try {
          _channels[channel] = await service.sdk.available(channel);
        } catch (_) {
          _channels[channel] = false;
        }
      }
      if (_channels[_channel] != true &&
          _channels[PaymentChannel.alipay] == true) {
        _channel = PaymentChannel.alipay;
      }
      _refreshHistory();
    } catch (error) {
      _error = error is ApiException ? error.message : null;
      _error ??= l10n.paymentUnavailable;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _refreshHistory() {
    _history = _service!.storage
        .readAll()
        .where(
          (item) =>
              item.tradeNo != null && item.tradeNo != _result?.pending?.tradeNo,
        )
        .toList(growable: false);
  }

  Future<void> _run(Future<PaymentResult> Function() action) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final result = await action();
      if (!mounted) return;
      setState(() {
        _result = result;
        _refreshHistory();
      });
      if (result.outcome == PaymentOutcome.completed) {
        AppToast.success(
          context,
          AppLocalizations.of(context)!.purchaseSuccess,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = AppLocalizations.of(context)!.paymentUnavailable,
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _pay() =>
      _run(() => _service!.purchase(widget.product, _channel));

  Future<void> _check() async {
    final pending = _result?.pending;
    if (pending != null) await _run(() => _service!.check(pending));
  }

  Future<void> _checkHistory(PendingPayment pending) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final result = await _service!.check(pending);
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      if (result.outcome == PaymentOutcome.completed) {
        AppToast.success(context, l10n.purchaseSuccess);
      } else {
        AppToast.info(
          context,
          result.outcome == PaymentOutcome.failed
              ? l10n.paymentNotCompleted
              : l10n.paymentProcessing,
        );
      }
      setState(_refreshHistory);
    } catch (_) {
      if (mounted) {
        AppToast.info(
          context,
          AppLocalizations.of(context)!.paymentUnavailable,
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _newPurchase() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await AppDialog.confirm(
      context: context,
      title: l10n.paymentNewPurchase,
      description: l10n.paymentNewPurchaseWarning,
      cancelLabel: l10n.cancel,
      confirmLabel: l10n.paymentNewPurchase,
    );
    if (!mounted || confirmed != true || _working) return;
    try {
      await _service!.abandon(widget.product);
    } catch (_) {
      if (mounted) AppToast.info(context, l10n.paymentUnavailable);
      return;
    }
    if (!mounted) return;
    setState(() {
      _result = null;
      _error = null;
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    // Closing on account changes prevents actions against a different login.
    ref.listen(userProvider.select((user) => user?.id), (previous, next) {
      if (previous != next && mounted) context.pop(false);
    });
    final result = _result;
    final pending = result?.pending;
    final completed = result?.outcome == PaymentOutcome.completed;
    final hasPending = pending != null && result?.state?.terminal != true;
    final amount =
        result?.state?.amountFen ?? pending?.amountFen ?? _previewAmount;

    return Scaffold(
      key: const Key('android-payment-page'),
      appBar: AppBar(
        toolbarHeight: 48,
        leadingWidth: 80,
        title: Text(l10n.paymentTitle),
        leading: Center(
          child: SizedBox.square(
            dimension: 40,
            child: IconButton(
              tooltip: l10n.back,
              padding: EdgeInsets.zero,
              onPressed: () => context.pop(completed),
              icon: const Icon(Icons.arrow_back_ios_new, size: 21),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    children: [
                      Center(
                        child: Icon(
                          completed
                              ? Icons.check_circle_outline
                              : Icons.receipt_long_outlined,
                          size: 36,
                          color: completed
                              ? const Color(0xFF3E975B)
                              : colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.product.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        amount == null
                            ? widget.product.priceLabel
                            : formatPaymentAmount(amount),
                        key: const Key('payment-amount'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        amount == null
                            ? l10n.paymentCatalogPrice
                            : l10n.paymentAmount,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 32),
                      if (_loading)
                        const Center(child: CircularProgressIndicator())
                      else if (_error != null) ...[
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.error),
                        ),
                        Center(
                          child: TextButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh),
                            label: Text(l10n.paymentRetry),
                          ),
                        ),
                      ] else ...[
                        if (!completed && !hasPending) ...[
                          Text(
                            l10n.paymentChooseMethod,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          RadioGroup<PaymentChannel>(
                            groupValue: _channel,
                            onChanged: (value) {
                              if (value != null && !_working) {
                                setState(() => _channel = value);
                              }
                            },
                            child: Column(
                              children: PaymentChannel.values
                                  .map(
                                    (channel) => _PaymentMethodRow(
                                      channel: channel,
                                      enabled:
                                          !_working &&
                                          _channels[channel] == true,
                                      installed: _channels[channel] == true,
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ],
                        if (result != null) ...[
                          const SizedBox(height: 16),
                          _PaymentStatus(result: result),
                          if (pending?.tradeNo case final String tradeNo) ...[
                            const SizedBox(height: 16),
                            Text(
                              l10n.paymentOrderNumber,
                              style: TextStyle(
                                fontSize: 13,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: SelectableText(
                                    tradeNo,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                IconButton(
                                  tooltip: l10n.paymentCopyOrder,
                                  icon: const Icon(
                                    Icons.content_copy,
                                    size: 18,
                                  ),
                                  onPressed: () async {
                                    await Clipboard.setData(
                                      ClipboardData(text: tradeNo),
                                    );
                                    if (context.mounted) {
                                      AppToast.info(
                                        context,
                                        l10n.paymentOrderCopied,
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ],
                        if (_history.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          const Divider(),
                          Text(
                            l10n.paymentPendingOrders,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          for (final order in _history)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(order.product.title),
                              subtitle: Text(order.tradeNo!, softWrap: true),
                              trailing: IconButton(
                                tooltip: l10n.paymentCheckAgain,
                                onPressed: _working
                                    ? null
                                    : () => _checkHistory(order),
                                icon: const Icon(Icons.refresh),
                              ),
                            ),
                        ],
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton(
                          key: const Key('payment-confirm'),
                          onPressed: _loading || _working || _error != null
                              ? null
                              : completed
                              ? () => context.pop(true)
                              : hasPending
                              ? (pending.tradeNo == null ? null : _check)
                              : _channels[_channel] == true
                              ? _pay
                              : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: colors.onSurface,
                            foregroundColor: colors.surface,
                            shape: const StadiumBorder(),
                          ),
                          child: _working
                              ? SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colors.surface,
                                  ),
                                )
                              : Text(
                                  completed
                                      ? l10n.paymentDone
                                      : hasPending
                                      ? l10n.paymentCheckAgain
                                      : l10n.paymentConfirm,
                                  textAlign: TextAlign.center,
                                ),
                        ),
                      ),
                      if (hasPending)
                        TextButton(
                          onPressed: _working ? null : _newPurchase,
                          child: Text(l10n.paymentNewPurchase),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentMethodRow extends StatelessWidget {
  const _PaymentMethodRow({
    required this.channel,
    required this.enabled,
    required this.installed,
  });

  final PaymentChannel channel;
  final bool enabled;
  final bool installed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final wechat = channel == PaymentChannel.wechat;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: colors.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: RadioListTile<PaymentChannel>(
          key: Key('payment-method-${channel.name}'),
          value: channel,
          enabled: enabled,
          controlAffinity: ListTileControlAffinity.trailing,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          secondary: wechat
              ? const AppSvgIcon.asset(
                  'profile_settings_wechat',
                  size: 28,
                  color: Color(0xFF07B957),
                )
              : const AppSvgIcon.asset('payment_alipay', size: 32),
          title: Text(
            wechat ? l10n.paymentWechat : l10n.paymentAlipay,
            style: const TextStyle(fontSize: 16),
          ),
          subtitle: installed
              ? null
              : Text(
                  l10n.paymentAppNotInstalled,
                  style: const TextStyle(fontSize: 12),
                ),
        ),
      ),
    );
  }
}

class _PaymentStatus extends StatelessWidget {
  const _PaymentStatus({required this.result});

  final PaymentResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final text = switch (result.outcome) {
      PaymentOutcome.completed => l10n.purchaseSuccess,
      PaymentOutcome.processing => l10n.paymentProcessing,
      PaymentOutcome.canceled => l10n.paymentCanceledPending,
      PaymentOutcome.unknown => l10n.paymentUnknown,
      PaymentOutcome.failed => result.message ?? l10n.paymentNotCompleted,
    };
    return Text(
      text,
      key: const Key('payment-status'),
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 15,
        height: 1.5,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
