import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/providers/harness_access_provider.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../domain/demo_style_film_models.dart';
import 'widgets/demo_widgets.dart';

typedef DemoStyleFilmReviewer =
    Future<bool> Function(DemoStyleFilmJob job, String action, String? notes);

Future<void> showDemoStyleFilmReviewSheet({
  required BuildContext context,
  required DemoStyleFilmJob job,
  required DemoStyleFilmReviewer onReview,
  Listenable? jobListenable,
  DemoStyleFilmJob Function()? jobResolver,
}) => DemoSheet.show<void>(
  context: context,
  enableDrag: !job.isAwaitingReview,
  builder: (_) => DemoStyleFilmReviewSheet(
    job: job,
    onReview: onReview,
    jobListenable: jobListenable,
    jobResolver: jobResolver,
  ),
);

class DemoStyleFilmReviewSheet extends StatefulWidget {
  const DemoStyleFilmReviewSheet({
    required this.job,
    required this.onReview,
    this.jobListenable,
    this.jobResolver,
    super.key,
  });

  final DemoStyleFilmJob job;
  final DemoStyleFilmReviewer onReview;
  final Listenable? jobListenable;
  final DemoStyleFilmJob Function()? jobResolver;

  @override
  State<DemoStyleFilmReviewSheet> createState() =>
      _DemoStyleFilmReviewSheetState();
}

class _DemoStyleFilmReviewSheetState extends State<DemoStyleFilmReviewSheet>
    with WidgetsBindingObserver {
  final _notes = TextEditingController();
  final _notesFocus = FocusNode();
  final _notesKey = GlobalKey();
  final _scroll = ScrollController();
  bool _revising = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notes.dispose();
    _notesFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (_revising && _notesFocus.hasFocus) {
      _scheduleNotesReveal(focus: false);
    }
  }

  void _startRevision() {
    if (_busy || _revising) return;
    setState(() => _revising = true);
    _scheduleNotesReveal(focus: true);
  }

  void _scheduleNotesReveal({required bool focus}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_revising) return;
      unawaited(_revealNotes(focus: focus));
    });
  }

  Future<void> _revealNotes({required bool focus}) async {
    if (!mounted) return;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220);
    var notesContext = _notesKey.currentContext;
    if (notesContext == null && _scroll.hasClients) {
      if (duration == Duration.zero) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      } else {
        await _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: duration,
          curve: Curves.easeOutCubic,
        );
      }
      if (!mounted) return;
      await WidgetsBinding.instance.endOfFrame;
      notesContext = _notesKey.currentContext;
    }
    if (notesContext == null || !mounted || !notesContext.mounted) return;
    await Scrollable.ensureVisible(
      notesContext,
      alignment: .08,
      duration: duration,
      curve: Curves.easeOutCubic,
    );
    if (!mounted || !focus) return;
    _notesFocus.requestFocus();
    _scheduleNotesReveal(focus: false);
  }

  Future<void> _review(String action) async {
    if (_busy) return;
    setState(() => _busy = true);
    final job = widget.jobResolver?.call() ?? widget.job;
    final ok = await widget.onReview(
      job,
      action,
      action == 'revise' ? _notes.text.trim() : null,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final listenable = widget.jobListenable;
    if (listenable == null) return _buildContent(context);
    return ListenableBuilder(
      listenable: listenable,
      builder: (context, _) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final job = widget.jobResolver?.call() ?? widget.job;
    final canRevise =
        job.allowedActions.contains('revise') ||
        job.state == 'failed_planning_unknown';
    final canApprove =
        job.isAwaitingReview &&
        (job.allowedActions.isEmpty || job.allowedActions.contains('approve'));
    final allowEmptyRevision = job.state == 'failed_planning_unknown';
    return PopScope(
      canPop: !_busy,
      child: DemoSheetBody(
        key: ValueKey('demo-style-film-review-${job.jobId}'),
        title: job.title.trim().isEmpty
            ? l.demoStyleFilmAwaitingStoryboard
            : job.title,
        footer: job.isAwaitingReview || canRevise
            ? _revising
                  ? DemoPrimaryButton(
                      key: const Key('demo-style-film-submit-revision'),
                      label: allowEmptyRevision
                          ? l.demoStyleFilmRetry
                          : l.demoStyleFilmSubmitRevision,
                      busy: _busy,
                      onPressed:
                          _notes.text.trim().isEmpty && !allowEmptyRevision
                          ? null
                          : () => _review('revise'),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: OutlinedButton(
                              key: const Key('demo-style-film-revise'),
                              onPressed: _busy || !canRevise
                                  ? null
                                  : _startRevision,
                              child: Text(l.demoStyleFilmReviseStoryboard),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DemoPrimaryButton(
                            key: const Key('demo-style-film-approve'),
                            label: l.demoStyleFilmApproveStoryboard,
                            busy: _busy,
                            onPressed: canApprove
                                ? () => _review('approve')
                                : null,
                          ),
                        ),
                      ],
                    )
            : null,
        child: CustomScrollView(
          controller: _scroll,
          slivers: [
            if (job.storyboard.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text(l.demoStyleFilmNoStoryboard)),
              )
            else
              SliverList.separated(
                itemCount: job.storyboard.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) => _StoryboardCard(
                  storyboard: job.storyboard[index],
                  index: index,
                ),
              ),
            if (_revising) ...[
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverToBoxAdapter(
                child: Column(
                  key: _notesKey,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l.demoStyleFilmRevisionNotice,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      key: const Key('demo-style-film-revision-notes'),
                      controller: _notes,
                      focusNode: _notesFocus,
                      enabled: !_busy,
                      minLines: 3,
                      maxLines: 7,
                      maxLength: 2000,
                      style: const TextStyle(fontSize: 16),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: l.demoStyleFilmRevisionNotes,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            SliverToBoxAdapter(
              child: SizedBox(
                height:
                    (_revising ? 132 : 104) +
                    MediaQuery.paddingOf(context).bottom,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryboardCard extends ConsumerWidget {
  const _StoryboardCard({required this.storyboard, required this.index});

  final DemoStyleFilmStoryboard storyboard;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final url = storyboard.previewUrl;
    return Container(
      key: ValueKey('demo-style-film-storyboard-${storyboard.id}'),
      decoration: BoxDecoration(
        color: demoSurface(context),
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: url.isEmpty
                ? ColoredBox(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    child: Center(child: Text(l.demoStyleFilmPreviewLabel)),
                  )
                : AppNetworkImage(
                    url,
                    fit: BoxFit.cover,
                    semanticLabel: l.demoStyleFilmPreviewLabel,
                    headers: ref.watch(harnessAccessHeadersProvider(url)),
                    cacheKey: ref.watch(harnessAccessCacheKeyProvider(url)),
                    onUnauthorized: ref.watch(
                      harnessAccessUnauthorizedProvider(url),
                    ),
                    loadingBuilder: (context, child, progress) =>
                        progress == null
                        ? child
                        : const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                    errorBuilder: (_, _, _) =>
                        const Center(child: Icon(Icons.broken_image_outlined)),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  storyboard.title.trim().isEmpty
                      ? '${index + 1}'
                      : storyboard.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (storyboard.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    storyboard.description,
                    style: const TextStyle(fontSize: 13, height: 1.5),
                  ),
                ],
                const SizedBox(height: 5),
                Text(
                  '${storyboard.startSeconds.toStringAsFixed(1)}s · '
                  '${storyboard.durationSeconds.toStringAsFixed(1)}s',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
