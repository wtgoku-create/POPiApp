import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../data/auth_repository.dart';
import '../domain/captcha_challenge.dart';

class SliderCaptchaSheet extends StatefulWidget {
  const SliderCaptchaSheet({
    super.key,
    required this.phone,
    required this.repository,
    required this.onVerified,
  });

  final String phone;
  final AuthRepository repository;
  final Future<void> Function(String) onVerified;

  @override
  State<SliderCaptchaSheet> createState() => _SliderCaptchaSheetState();
}

class _SliderCaptchaSheetState extends State<SliderCaptchaSheet> {
  CaptchaChallenge? _challenge;
  bool _loading = true;
  bool _verifying = false;
  bool _imageFailed = false;
  String? _error;
  double _offset = 0;
  Offset? _start;
  Offset? _last;
  final _watch = Stopwatch();
  final List<List<double>> _trail = [];
  int _failures = 0;
  final Map<String, ImageProvider> _images = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool manual = false}) async {
    setState(() {
      if (manual) _failures = 0;
      _loading = true;
      _challenge = null;
      _images.clear();
      _imageFailed = false;
      _offset = 0;
      _start = null;
    });
    try {
      final challenge = await widget.repository.createCaptcha(
        phone: widget.phone,
      );
      if (mounted) setState(() => _challenge = challenge);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = AppLocalizations.of(context)!.captchaLoadFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verify(double width) async {
    final challenge = _challenge;
    final start = _start;
    final last = _last;
    _start = null;
    _watch.stop();
    if (challenge == null || start == null || last == null || _offset <= 0) {
      setState(() => _offset = 0);
      return;
    }
    setState(() => _verifying = true);
    try {
      // Match the web's 280x140 background, 52px puzzle and 44px handle.
      final scale = 280 / width;
      final token = await widget.repository.verifyCaptcha(
        SliderCaptchaVerification(
          captchaId: challenge.id,
          phone: widget.phone,
          x: _offset / (width - 44) * 228,
          y: (last.dy - start.dy) * scale,
          sliderOffsetX: _offset / (width - 44) * 236,
          duration: _watch.elapsedMilliseconds,
          trail: _trail
              .map((point) => [point[0] * scale, point[1] * scale])
              .toList(),
        ),
      );
      if (!mounted) return;
      await widget.onVerified(token);
    } catch (_) {
      if (!mounted) return;
      _failures++;
      setState(
        () => _error = _failures >= 5
            ? AppLocalizations.of(context)!.captchaTooManyErrors
            : AppLocalizations.of(context)!.captchaVerificationFailed,
      );
      if (_failures < 5) await _load();
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Widget _image(String source, {double? width, required double height}) {
    Widget failed(BuildContext context, Object error, StackTrace? stack) {
      if (!_imageFailed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _imageFailed = true);
        });
      }
      return const Center(child: Icon(Icons.broken_image_outlined));
    }

    try {
      // MemoryImage uses byte identity, so retain the provider during dragging.
      final provider = _images.putIfAbsent(source, () {
        if (source.startsWith('data:')) {
          return MemoryImage(
            base64Decode(source.substring(source.indexOf(',') + 1)),
          );
        }
        return NetworkImage(source);
      });
      return Image(
        image: provider,
        width: width,
        height: height,
        fit: BoxFit.fill,
        errorBuilder: failed,
      );
    } catch (error) {
      return failed(context, error, null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final enabled =
        !_loading &&
        !_verifying &&
        !_imageFailed &&
        _challenge != null &&
        _failures < 5;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.graphicalCaptcha,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    key: const Key('refresh-captcha-button'),
                    tooltip: l10n.refreshCaptcha,
                    onPressed: _loading || _verifying
                        ? null
                        : () {
                            _error = null;
                            _load(manual: true);
                          },
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final height = width / 2;
                  return SizedBox(
                    width: width,
                    child: Column(
                      children: [
                        SizedBox(
                          height: height,
                          width: width,
                          child: _challenge == null
                              ? Center(
                                  child: _loading
                                      ? const CircularProgressIndicator()
                                      : const Icon(
                                          Icons.image_not_supported_outlined,
                                        ),
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Stack(
                                    children: [
                                      _image(
                                        _challenge!.bgUrl,
                                        width: width,
                                        height: height,
                                      ),
                                      Positioned(
                                        left:
                                            _offset /
                                            (width - 44) *
                                            (width - 52 * width / 280),
                                        top: 0,
                                        child: _image(
                                          _challenge!.puzzleUrl,
                                          width: 52 * width / 280,
                                          height: height,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 44,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: colors.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        left: 44,
                                        right: 4,
                                      ),
                                      child: Text(
                                        _verifying
                                            ? l10n.captchaVerifying
                                            : _start != null
                                            ? l10n.captchaSliderMoving
                                            : l10n.captchaSliderHint,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: _offset,
                                top: 0,
                                child: GestureDetector(
                                  key: const Key('captcha-slider-handle'),
                                  onPanDown: enabled
                                      ? (details) {
                                          _start = details.globalPosition;
                                          _last = _start;
                                          _trail
                                            ..clear()
                                            ..add([_start!.dx, _start!.dy]);
                                          _watch
                                            ..reset()
                                            ..start();
                                          setState(() => _error = null);
                                        }
                                      : null,
                                  onPanUpdate: enabled
                                      ? (details) {
                                          if (_start == null) return;
                                          _last = details.globalPosition;
                                          _trail.add([_last!.dx, _last!.dy]);
                                          setState(
                                            () => _offset =
                                                (_last!.dx - _start!.dx).clamp(
                                                  0,
                                                  width - 44,
                                                ),
                                          );
                                        }
                                      : null,
                                  onPanEnd: enabled
                                      ? (_) => _verify(width)
                                      : null,
                                  onPanCancel: () {
                                    _watch.stop();
                                    setState(() {
                                      _start = null;
                                      _offset = 0;
                                    });
                                  },
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: enabled
                                          ? colors.primary
                                          : colors.outline,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: _verifying
                                        ? const Padding(
                                            padding: EdgeInsets.all(12),
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Icon(
                                            Icons.chevron_right,
                                            color: colors.onPrimary,
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              if (_error != null || _imageFailed)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _imageFailed ? l10n.captchaLoadFailed : _error!,
                    style: TextStyle(color: colors.error),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
