import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_toast.dart';

/// In-app browser for public H5 content. It never adds app credentials.
class H5Page extends StatefulWidget {
  const H5Page({required this.title, required this.url, super.key});

  final String title;
  final Uri url;

  @override
  State<H5Page> createState() => _H5PageState();
}

class _H5PageState extends State<H5Page> {
  WebViewController? _controller;
  bool _failed = false;
  int _progress = 0;
  late Uri _pageUrl;

  @override
  void initState() {
    super.initState();
    _pageUrl = widget.url;
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    if (WebViewPlatform.instance == null) return;
    try {
      final controller = WebViewController();
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (request.isMainFrame && uri != null && _isWebUrl(uri)) {
              _pageUrl = uri;
            }
            return uri != null && _isWebUrl(uri)
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
          onPageStarted: (url) {
            if (!mounted) return;
            _pageUrl = Uri.parse(url);
            setState(() {
              _failed = false;
              _progress = 0;
            });
          },
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _progress = 100);
          },
          onWebResourceError: (error) {
            // An unavailable image or analytics request must not hide the document.
            if (error.isForMainFrame == true) _showFailure();
          },
          onHttpError: (error) {
            final uri = error.request?.uri ?? error.response?.uri;
            if (uri?.replace(fragment: '') == _pageUrl.replace(fragment: '')) {
              _showFailure();
            }
          },
        ),
      );
      if (!mounted) return;
      setState(() => _controller = controller);
      await _load();
    } catch (_) {
      _showFailure();
    }
  }

  bool _isWebUrl(Uri uri) =>
      (uri.scheme == 'https' || uri.scheme == 'http') && uri.host.isNotEmpty;

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _failed = false;
      _progress = 0;
      _pageUrl = widget.url;
    });
    if (!_isWebUrl(widget.url)) {
      _showFailure();
      return;
    }
    if (_controller == null) {
      await _initialize();
      return;
    }
    try {
      await _controller!.loadRequest(widget.url);
    } catch (_) {
      _showFailure();
    }
  }

  void _showFailure() {
    if (mounted) setState(() => _failed = true);
  }

  Future<void> _openInBrowser() async {
    try {
      if (_isWebUrl(widget.url) &&
          await launchUrl(widget.url, mode: LaunchMode.externalApplication)) {
        return;
      }
    } catch (_) {
      // A platform launch failure uses the same localized feedback.
    }
    if (mounted) {
      AppToast.error(
        context,
        AppLocalizations.of(context)!.networkRequestFailed,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final controller = _controller;
    final supported = WebViewPlatform.instance != null;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        leading: IconButton(
          tooltip: l10n.back,
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
          icon: const Icon(Icons.arrow_back_ios_new, size: 21),
        ),
        actions: [
          if (supported)
            IconButton(
              tooltip: l10n.webPageRefresh,
              onPressed: controller == null && !_failed ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _failed || !supported
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _failed ? Icons.cloud_off_outlined : Icons.language,
                        size: 40,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _failed
                            ? l10n.webPageLoadFailed
                            : l10n.webPageBrowserRequired,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      if (supported)
                        FilledButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: Text(l10n.retry),
                        ),
                      TextButton.icon(
                        onPressed: _openInBrowser,
                        icon: const Icon(Icons.open_in_new),
                        label: Text(l10n.webPageOpenInBrowser),
                      ),
                    ],
                  ),
                ),
              )
            : Stack(
                children: [
                  if (controller != null) WebViewWidget(controller: controller),
                  if (_progress < 100)
                    Align(
                      alignment: Alignment.topCenter,
                      child: LinearProgressIndicator(
                        value: _progress == 0 ? null : _progress / 100,
                        semanticsLabel: l10n.webPageLoading,
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
