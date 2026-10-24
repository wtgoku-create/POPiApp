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
import '../../../shared/widgets/app_glass_app_bar.dart';
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
  int? _previewAmount;
  int? _previewPoints;

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
      unawaited(_check(notify: false));
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _loading = true);
    final service = ref.read(androidPaymentServiceProvider);
    _service = service;
    try {
      if (!service.available) throw const ApiException();
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
      if (widget.product.kind == PaymentProductKind.subscription) {
        final preview = await service.repository.preview(widget.product);
        _previewAmount = preview.amountFen;
        _previewPoints = preview.grantPoints;
      }
    } catch (error) {
      if (mounted) {
        AppToast.error(
          context,
          error is ApiException && error.message?.isNotEmpty == true
              ? error.message!
              : l10n.paymentUnavailable,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _run(
    Future<PaymentResult> Function() action, {
    bool notify = true,
  }) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final result = await action();
      if (!mounted) return;
      setState(() {
        _result =
            result.outcome == PaymentOutcome.canceled ||
                result.state?.payment == 'canceled'
            ? null
            : result;
      });
      if (notify && result.state?.payment != 'canceled') {
        final l10n = AppLocalizations.of(context)!;
        switch (result.outcome) {
          case PaymentOutcome.completed:
            AppToast.success(context, l10n.purchaseSuccess);
          case PaymentOutcome.processing:
            AppToast.info(context, l10n.paymentProcessing);
          case PaymentOutcome.unknown:
            if (result.message case final String message
                when message.isNotEmpty) {
              AppToast.error(context, message);
            } else {
              AppToast.info(context, l10n.paymentUnknown);
            }
          case PaymentOutcome.failed:
            AppToast.error(context, result.message ?? l10n.paymentNotCompleted);
          case PaymentOutcome.canceled:
            break;
        }
      }
    } catch (error) {
      if (mounted && notify) {
        final l10n = AppLocalizations.of(context)!;
        AppToast.error(
          context,
          error is ApiException && error.message?.isNotEmpty == true
              ? error.message!
              : l10n.paymentUnavailable,
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _pay() => _run(
    () => _service!.purchase(
      widget.product,
      _channel,
      confirmPreview: (preview) async {
        if (!mounted) return false;
        if (_previewAmount == preview.amountFen &&
            _previewPoints == preview.grantPoints) {
          return true;
        }
        setState(() {
          _previewAmount = preview.amountFen;
          _previewPoints = preview.grantPoints;
        });
        final l10n = AppLocalizations.of(context)!;
        return await AppDialog.confirm(
              context: context,
              title: l10n.paymentTitle,
              description:
                  '${formatPaymentAmount(preview.amountFen)}\n'
                  '${l10n.paymentGrantPoints(preview.grantPoints)}',
              cancelLabel: l10n.cancel,
              confirmLabel: l10n.paymentConfirm,
            ) ??
            false;
      },
    ),
  );

  Future<void> _check({bool notify = true}) async {
    final pending = _result?.pending;
    if (pending != null) {
      await _run(() => _service!.check(pending), notify: notify);
    }
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
      appBar: AppGlassAppBar(
        extendBackdrop: false,
        child: AppBar(
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
                      if (_previewPoints != null && !hasPending && !completed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            l10n.paymentGrantPoints(_previewPoints!),
                            key: const Key('payment-grant-points'),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      if (_loading)
                        const Center(child: CircularProgressIndicator())
                      else ...[
                        if (!completed) ...[
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
                          onPressed: _loading || _working
                              ? null
                              : completed
                              ? () => context.pop(true)
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
                                      : l10n.paymentConfirm,
                                  textAlign: TextAlign.center,
                                ),
                        ),
                      ),
                      if (hasPending && pending.tradeNo != null)
                        TextButton(
                          onPressed: _working ? null : _check,
                          child: Text(l10n.paymentCheckAgain),
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
