import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/network_api.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/providers/network_provider.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/widgets/app_image_preview.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../../shared/widgets/app_toast.dart';
import '../data/teaching_reader_bridge.dart';
import '../data/teaching_repository.dart';
import '../domain/teaching.dart';

/// Native navigation and authenticated data loading around the shared Web reader.
class TeachingDocumentPage extends ConsumerStatefulWidget {
  const TeachingDocumentPage({
    required this.courseId,
    this.course,
    this.repository,
    this.readerUrl,
    super.key,
  });

  final int courseId;
  final TeachingCourse? course;
  final TeachingRepository? repository;
  final Uri? readerUrl;

  @override
  ConsumerState<TeachingDocumentPage> createState() =>
      _TeachingDocumentPageState();
}

class _TeachingDocumentPageState extends ConsumerState<TeachingDocumentPage> {
  WebViewController? _controller;
  TeachingReaderBridge? _bridge;
  TeachingDocument? _document;
  Map<int, String> _memberLabels = {};
  List<TeachingHeading> _catalog = [];
  final _activeHeading = ValueNotifier<String>('');
  Timer? _timeout;
  String? _requestId;
  int _attempt = 0;
  bool _ready = false;
  bool _pageTrusted = false;
  bool _rendered = false;
  bool _failed = false;
  bool _empty = false;
  bool _openingMembership = false;
  (bool, String, double)? _appearance;

  TeachingRepository get _repository =>
      widget.repository ??
      TeachingRepository(NetworkApi(ref.read(dioProvider)));

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appearance = (
      Theme.of(context).brightness == Brightness.dark,
      Localizations.localeOf(context).languageCode,
      MediaQuery.textScalerOf(context).scale(16) / 16,
    );
    if (_appearance != appearance) {
      _appearance = appearance;
      if (_ready && _document != null) unawaited(_sendDocument());
    }
  }

  @override
  void didUpdateWidget(TeachingDocumentPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.courseId != widget.courseId ||
        oldWidget.readerUrl != widget.readerUrl) {
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _attempt++;
    _timeout?.cancel();
    _activeHeading.dispose();
    super.dispose();
  }

  void _armTimeout() {
    _timeout?.cancel();
    _timeout = Timer(const Duration(seconds: 30), _showFailure);
  }

  Future<void> _load() async {
    final attempt = ++_attempt;
    _timeout?.cancel();
    setState(() {
      _bridge = TeachingReaderBridge(
        url: widget.readerUrl ?? Uri.parse(AppConfig.teachingReaderUrl),
        session: const Uuid().v4(),
      );
      _ready = false;
      _pageTrusted = false;
      _rendered = false;
      _failed = false;
      _empty = false;
      _document = null;
      _catalog = [];
      _requestId = null;
      _activeHeading.value = '';
    });
    if (WebViewPlatform.instance == null) return;
    _armTimeout();
    unawaited(_loadDocument(attempt));
    try {
      if (_controller == null) {
        final controller = WebViewController();
        await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
        await controller.addJavaScriptChannel(
          'PopiTeaching',
          onMessageReceived: (message) => _handleMessage(message.message),
        );
        await controller.setNavigationDelegate(
          NavigationDelegate(
            onNavigationRequest: (request) {
              final uri = Uri.tryParse(request.url);
              if (uri != null &&
                  request.isMainFrame &&
                  _bridge?.acceptsNavigation(uri) == true) {
                return NavigationDecision.navigate;
              }
              return NavigationDecision.prevent;
            },
            onPageStarted: (url) {
              if (!mounted) return;
              _pageTrusted = _bridge?.acceptsNavigation(Uri.parse(url)) == true;
              _ready = false;
              _requestId = null;
              if (!_pageTrusted) {
                _showFailure();
              } else if (!_failed && !_empty) {
                setState(() {
                  _rendered = false;
                  _catalog = [];
                });
                _armTimeout();
              }
            },
            onWebResourceError: (error) {
              if (error.isForMainFrame == true) _showFailure();
            },
            onHttpError: (error) {
              final uri = error.request?.uri ?? error.response?.uri;
              if (uri != null && _bridge?.acceptsNavigation(uri) == true) {
                _showFailure();
              }
            },
          ),
        );
        if (!mounted || attempt != _attempt) return;
        setState(() => _controller = controller);
      }
      if (!mounted || attempt != _attempt) return;
      if (!TeachingReaderBridge.isWebUrl(_bridge!.url)) {
        _showFailure();
        return;
      }
      await _controller!.loadRequest(_bridge!.url);
    } catch (_) {
      if (mounted && attempt == _attempt) _showFailure();
    }
  }

  Future<void> _loadDocument(int attempt) async {
    try {
      final repository = _repository;
      final documentRequest = repository.fetchCourseDocument(widget.courseId);
      final labelsRequest = repository.fetchMemberLabels().catchError(
        (_) => <int, String>{},
      );
      final document = await documentRequest;
      final labels = await labelsRequest;
      if (!mounted || attempt != _attempt || _failed) return;
      setState(() {
        _document = document;
        _memberLabels = labels;
        _empty = document == null;
      });
      if (_empty) {
        _timeout?.cancel();
      } else if (_ready) {
        await _sendDocument();
      }
    } catch (_) {
      if (mounted && attempt == _attempt) _showFailure();
    }
  }

  Future<void> _sendDocument() async {
    final document = _document;
    final bridge = _bridge;
    final appearance = _appearance;
    if (!mounted ||
        !_ready ||
        !_pageTrusted ||
        _failed ||
        document == null ||
        bridge == null ||
        appearance == null) {
      return;
    }
    final requestId = const Uuid().v4();
    _requestId = requestId;
    _armTimeout();
    final l10n = AppLocalizations.of(context)!;
    final level = document.memberLevels.firstOrNull;
    try {
      await _controller!.runJavaScript(
        bridge.renderScript(
          requestId: requestId,
          document: document,
          course:
              widget.course ??
              TeachingCourse(id: widget.courseId, name: l10n.teachingCenter),
          mediaBaseUrl: _repository.networkApi.mediaBaseUrl,
          requiredMemberLevelName:
              _memberLabels[level] ?? l10n.teachingRequiredMember,
          dark: appearance.$1,
          locale: appearance.$2,
          textScale: appearance.$3,
        ),
      );
    } catch (_) {
      if (mounted && _requestId == requestId) _showFailure();
    }
  }

  void _handleMessage(String message) {
    if (!mounted || !_pageTrusted || _failed) return;
    final event = _bridge?.parseEvent(message);
    if (event == null) return;
    if (event.type == 'ready') {
      if (_ready) return;
      _ready = true;
      unawaited(_sendDocument());
      return;
    }
    if (event.requestId != _requestId || _requestId == null) return;
    switch (event.type) {
      case 'rendered':
        _timeout?.cancel();
        setState(() {
          _rendered = true;
          _catalog = event.catalog;
        });
      case 'error':
        _showFailure();
      case 'activeHeading':
        if (_catalog.any((item) => item.id == event.id)) {
          _activeHeading.value = event.id!;
        }
      case 'previewImage':
        if (_rendered) {
          unawaited(
            AppImagePreview.show(
              context: context,
              image: NetworkImage(event.url!.toString()),
              heroTag: 'teaching-document-image',
              label: event.label,
            ),
          );
        }
      case 'openLink':
        if (_rendered) unawaited(_openLink(event.url!));
      case 'upgrade':
        if (_rendered) unawaited(_openMembership());
    }
  }

  Future<void> _openLink(Uri uri) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      /* Use the shared localized error below. */
    }
    if (mounted) {
      AppToast.error(
        context,
        AppLocalizations.of(context)!.networkRequestFailed,
      );
    }
  }

  Future<void> _openMembership() async {
    if (_openingMembership) return;
    _openingMembership = true;
    try {
      if (ref.read(userProvider) == null) {
        await context.push('/login');
        if (!mounted || ref.read(userProvider) == null) return;
      }
      if (!mounted) return;
      await context.push('/profile/membership');
    } finally {
      _openingMembership = false;
      if (mounted) await _load();
    }
  }

  void _showFailure() {
    _timeout?.cancel();
    if (mounted) {
      setState(() {
        _failed = true;
        _rendered = false;
      });
    }
  }

  Future<void> _showCatalog() async {
    final bridge = _bridge;
    final id = await AppSheet.show<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Text(
                AppLocalizations.of(context)!.teachingCatalog,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Flexible(
              child: ValueListenableBuilder<String>(
                valueListenable: _activeHeading,
                builder: (context, active, _) => ListView.builder(
                  shrinkWrap: true,
                  itemCount: _catalog.length,
                  itemBuilder: (context, index) {
                    final item = _catalog[index];
                    return ListTile(
                      contentPadding: EdgeInsets.only(
                        left: item.level == 2 ? 40 : 24,
                        right: 24,
                      ),
                      title: Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      selected: item.id == active,
                      trailing: item.id == active
                          ? const Icon(Icons.check, size: 20)
                          : null,
                      onTap: () => Navigator.of(context).pop(item.id),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted || id == null || _failed || bridge != _bridge) return;
    try {
      await _controller?.runJavaScript(bridge!.scrollToScript(id));
    } catch (_) {
      if (mounted) _showFailure();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    ref.listen(userProvider.select((user) => (user?.id, user?.memberLevel)), (
      previous,
      next,
    ) {
      if (previous != next && !_openingMembership) unawaited(_load());
    });
    final supported = WebViewPlatform.instance != null;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          widget.course?.name.isNotEmpty == true
              ? widget.course!.name
              : l10n.teachingCenter,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          tooltip: l10n.back,
          icon: const Icon(Icons.arrow_back_ios_new, size: 21),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/teaching'),
        ),
        actions: [
          IconButton(
            tooltip: l10n.teachingCatalog,
            icon: const Icon(Icons.format_list_bulleted),
            onPressed: _rendered && _catalog.isNotEmpty ? _showCatalog : null,
          ),
          IconButton(
            tooltip: l10n.webPageRefresh,
            icon: const Icon(Icons.refresh),
            onPressed: supported ? _load : null,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: !supported || _failed || _empty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _empty
                            ? Icons.article_outlined
                            : Icons.cloud_off_outlined,
                        size: 40,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        !supported
                            ? l10n.teachingReaderUnavailable
                            : _empty
                            ? l10n.teachingDocumentEmpty
                            : l10n.teachingDocumentFailed,
                        textAlign: TextAlign.center,
                      ),
                      if (supported) ...[
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: Text(l10n.retry),
                        ),
                      ],
                    ],
                  ),
                ),
              )
            : Stack(
                children: [
                  if (_controller != null)
                    IgnorePointer(
                      ignoring: !_rendered,
                      child: Opacity(
                        opacity: _rendered ? 1 : 0,
                        child: WebViewWidget(controller: _controller!),
                      ),
                    ),
                  if (!_rendered)
                    Center(
                      child: CircularProgressIndicator(
                        semanticsLabel: l10n.teachingLoading,
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
