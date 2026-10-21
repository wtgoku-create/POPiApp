import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/app_sheet.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/generation_credit_notice.dart';
import '../../domain/conversation_generation.dart';
import '../../domain/conversation_generation_view.dart';
import '../../domain/conversation_snapshot.dart';
import '../../../role_guide/domain/home_creation.dart';
import '../conversation_controller.dart';
import 'conversation_card.dart';
import 'conversation_card_content.dart';
import 'conversation_generation_configuration.dart';
import 'conversation_home_plan_card.dart';
import 'conversation_role_card.dart';
import 'conversation_role_image_setup.dart';
import 'conversation_style_library_sheet.dart';
import 'conversation_timeline.dart'
    show MarkdownMessage, ConversationMediaView, conversationErrorText;

/// 生成确认使用会话偏好和实时估价，角色图先固定素材组合再授权。
class ConversationGenerationCard extends StatefulWidget {
  const ConversationGenerationCard({
    required this.block,
    required this.controller,
    this.readOnly = false,
    this.embedded = false,
    super.key,
  });
  final ConversationBlock block;
  final ConversationController controller;

  /// Saved plans never load live preferences or expose editing actions.
  final bool readOnly;

  /// Shares the parent card's frame and expand/collapse control.
  final bool embedded;
  @override
  State<ConversationGenerationCard> createState() =>
      _ConversationGenerationCardState();
}

class _ConversationGenerationCardState extends State<ConversationGenerationCard>
    with AutomaticKeepAliveClientMixin {
  final _token = CancelToken();
  CancelToken? _estimateToken;
  Timer? _estimateDebounce;
  ConversationGenerationOptions? _options;
  HomeConfig? _config;
  ConversationGenerationSelection? _attempted;
  late ConversationGenerationView _view;
  late final TextEditingController _requirements;
  String? _reference;
  String? _templateId;
  String? _templateMediaId;
  String _templateTitle = '';
  num? _points;
  bool _loading = true;
  bool _estimating = false;
  bool _uploading = false;
  bool _submitted = false;
  bool _expanded = true;
  int _preferencesEpoch = 0;
  int _loadEpoch = 0;

  @override
  bool get wantKeepAlive => true;
  bool get _editable =>
      !widget.readOnly &&
      !_submitted &&
      (widget.block.isHomePlan
          ? widget.block.status == 'ready'
          : widget.block.confirmationAvailable);
  bool get _busy =>
      widget.controller.pending ||
      widget.controller.loading ||
      widget.controller.running ||
      _uploading;
  HomeModel? get _model => _options?.models
      .where((model) => model.id == _config?.modelId)
      .firstOrNull;
  List<String> get _references =>
      _view.referenceIds(_reference, _templateMediaId);
  bool get _valid {
    if (_reference != null && _reference == _templateMediaId) return false;
    if (_config == null ||
        _model?.accepts(_config!) != true ||
        _view.threeView && _config!.params['ratio'] != '16:9') {
      return false;
    }
    if (_view.threeView &&
        !(_reference != null ||
            _templateId != null ||
            _requirements.text.trim().isNotEmpty ||
            _view.useProfile && _view.hasProfile)) {
      return false;
    }
    return !_view.threeView ||
        _model!.acceptsImageReferences(_references.length);
  }

  @override
  void initState() {
    super.initState();
    _view = ConversationGenerationView(widget.block);
    _preferencesEpoch = widget.controller.mediaPreferencesEpoch;
    _requirements = TextEditingController(text: _view.requirements);
    _reference = _view.referenceMediaId;
    _templateId = _view.templateId;
    _templateMediaId = _view.template['mediaId']?.toString();
    _templateTitle = _view.templateTitle;
    if (_editable) {
      unawaited(_load());
    } else {
      _loading = false;
    }
  }

  @override
  void didUpdateWidget(ConversationGenerationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _view = ConversationGenerationView(widget.block);
    if (_preferencesEpoch != widget.controller.mediaPreferencesEpoch &&
        _editable) {
      _preferencesEpoch = widget.controller.mediaPreferencesEpoch;
      unawaited(_load());
    }
    if (oldWidget.block.status != widget.block.status && !_editable) {
      _estimateToken?.cancel();
      _estimateDebounce?.cancel();
      _loading = false;
    }
  }

  Future<void> _load() async {
    final epoch = ++_loadEpoch;
    _estimateToken?.cancel();
    _estimateDebounce?.cancel();
    setState(() {
      _loading = true;
      _estimating = false;
    });
    try {
      final options = await widget.controller.repository.generationOptions(
        widget.controller.userId,
        widget.controller.sessionId!,
        widget.block,
        cancelToken: _token,
      );
      if (!mounted || _token.isCancelled || epoch != _loadEpoch) return;
      final recovery = options.recovery;
      final preferred = _view.mediaType == 'image'
          ? options.preferences.image
          : options.preferences.video;
      final config = recovery?.config ?? preferred ?? _view.config;
      setState(() {
        _options = options;
        _attempted = recovery;
        _config = config;
        if (recovery != null) {
          _requirements.text = recovery.requirements;
          _reference = recovery.referenceMediaId;
          _templateId = recovery.roleTemplateId;
          _templateTitle = recovery.roleTemplateTitle;
          _templateMediaId = recovery.roleTemplateMediaId;
          _points = recovery.estimatedPoints;
        }
      });
      if (recovery == null) await _estimate();
    } catch (error) {
      if (mounted && !_token.isCancelled && epoch == _loadEpoch) {
        _showError(error);
      }
    } finally {
      if (mounted && !_token.isCancelled && epoch == _loadEpoch) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _estimate() async {
    _estimateDebounce?.cancel();
    _estimateToken?.cancel();
    setState(() {
      _points = null;
      _estimating = _valid && _attempted == null;
    });
    if (!_valid || _attempted != null) return;
    final token = _estimateToken = CancelToken();
    try {
      final points = await widget.controller.repository.estimateGeneration(
        _view.mediaType,
        _config!,
        cancelToken: token,
      );
      if (mounted && !token.isCancelled) setState(() => _points = points);
    } catch (error) {
      if (mounted && !token.isCancelled) _showError(error);
    } finally {
      if (mounted && !token.isCancelled) {
        setState(() => _estimating = false);
      }
    }
  }

  Future<void> _chooseTemplate() async {
    final template = await AppSheet.show<ConversationRoleTemplate>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      shape: ConversationStyleLibrarySheet.shape,
      builder: (context) => ConversationStyleLibrarySheet(
        repository: widget.controller.repository,
        selectedId: _templateId,
        selectedTemplate: _templateId == null
            ? null
            : ConversationRoleTemplate(
                id: _templateId!,
                title: _templateTitle,
                mediaId: _templateMediaId,
              ),
      ),
    );
    if (!mounted || template == null) return;
    setState(() {
      _templateId = template.id.isEmpty ? null : template.id;
      _templateTitle = template.title;
      _templateMediaId = template.mediaId;
    });
    await _estimate();
  }

  Future<void> _uploadReference() async {
    setState(() {
      _uploading = true;
    });
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (image == null || !mounted) return;
      if (await image.length() > 6 * 1024 * 1024) {
        throw const FormatException('Image too large');
      }
      final id = await widget.controller.repository.upload(
        widget.controller.userId,
        image.name,
        await image.readAsBytes(),
        cancelToken: _token,
      );
      if (mounted && !_token.isCancelled) {
        setState(() => _reference = id);
        await _estimate();
      }
    } catch (error) {
      if (mounted && !_token.isCancelled) _showError(error);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _showError(Object error) => AppToast.error(
    context,
    conversationErrorText(error, AppLocalizations.of(context)!),
  );

  Future<void> _confirm() async {
    final l10n = AppLocalizations.of(context)!;
    if (_busy || _loading || _estimating || !_editable) return;
    if (_attempted == null) {
      if (_options == null) {
        await _load();
      } else if (_valid && _points == null) {
        await _estimate();
      }
      if (!mounted || _busy || !_editable || !_valid || _points == null) return;
    }
    final selected =
        _attempted ??
        ConversationGenerationSelection(
          config: _config!,
          estimatedPoints: _points!,
          mediaPreferencesRevision: _options!.preferences.revision,
          roleTemplateId: _templateId,
          roleTemplateTitle: _templateTitle,
          roleTemplateMediaId: _templateMediaId,
          referenceMediaId: _reference,
          requirements: _requirements.text.trim(),
          useProfile: _view.useProfile,
          referencePurpose: _view.referencePurpose,
        );
    final confirmed = await AppDialog.confirm(
      context: context,
      title: widget.block.title,
      description:
          '${l10n.chatEstimatedPoints(selected.estimatedPoints.toString())}\n\n${l10n.generationCreditNotice}',
      cancelLabel: AppLocalizations.of(context)!.cancel,
      confirmLabel: AppLocalizations.of(context)!.chatConfirmGeneration,
    );
    if (!mounted || confirmed != true || _busy || !_editable) return;
    setState(() => _attempted = selected);
    final success = await widget.controller.confirmGeneration(
      widget.block,
      selected,
    );
    if (!mounted) return;
    if (success) {
      setState(() => _submitted = true);
    } else {
      await _load();
    }
  }

  @override
  void dispose() {
    _token.cancel();
    _estimateToken?.cancel();
    _estimateDebounce?.cancel();
    _requirements.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context)!;
    final card = widget.block;
    final locked = _busy || _attempted != null;
    final colors = Theme.of(context).colorScheme;
    if (card.isHomePlan) {
      return ConversationHomePlanCard(
        block: card,
        view: _view,
        expanded: _expanded,
        onToggle: () => setState(() => _expanded = !_expanded),
        editable: _editable,
        loading: _loading,
        estimating: _estimating,
        config: _config,
        model: _model,
        points: _points,
        actions: _actions(l10n),
        embedded: widget.embedded,
        validationMessage:
            !_loading && _config != null && !_valid && _attempted == null
            ? l10n.chatInvalidGeneration
            : null,
      );
    }
    return ConversationCard(
      framed: !widget.embedded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.embedded)
            Row(
              children: [
                Expanded(
                  child: Text(
                    card.title,
                    style: ConversationCardTypography.title.copyWith(
                      color: colors.primary,
                    ),
                  ),
                ),
                SizedBox.square(
                  dimension: 32,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    tooltip: _expanded
                        ? l10n.chatCollapseProfile
                        : l10n.roleGuideViewMore,
                    onPressed: () => setState(() => _expanded = !_expanded),
                    icon: Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: colors.primary.withValues(alpha: .6),
                    ),
                  ),
                ),
              ],
            ),
          if (!widget.embedded && card.status != 'ready')
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                conversationStatusLabel(card.status, l10n),
                style: ConversationCardTypography.caption.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          if (widget.embedded || _expanded) ...[
            if (!widget.embedded) const SizedBox(height: 12),
            if (card.previewRole case final role?)
              ConversationRoleCard(block: role, compact: true),
            if ((!_editable || !_view.threeView) &&
                _view.savedReferenceIds.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _view.templateTitle.isNotEmpty
                          ? l10n.chatImageStyle
                          : l10n.chatReferenceImage,
                      style: ConversationCardTypography.title.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      key: const Key('conversation-generation-references'),
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final id in _view.savedReferenceIds)
                          ConversationMediaView(
                            key: ValueKey(
                              'conversation-generation-reference-$id',
                            ),
                            id: id,
                            repository: widget.controller.repository,
                            thumbnailSize: 80,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ConversationCardContent(
              storageId: 'generation:${card.id}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_editable && !_loading && _view.threeView)
                    ConversationRoleImageSetup(
                      reference: _reference == null
                          ? null
                          : ConversationMediaView(
                              id: _reference!,
                              repository: widget.controller.repository,
                              thumbnailSize: 80,
                            ),
                      styleTitle: _templateTitle,
                      uploading: _uploading,
                      onUpload: locked ? null : _uploadReference,
                      onRemove: locked
                          ? null
                          : () {
                              setState(() => _reference = null);
                              unawaited(_estimate());
                            },
                      onChooseStyle: locked ? null : _chooseTemplate,
                    ),
                  if (_view.prompt.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: MarkdownMessage(
                        text: _view.prompt,
                        compact: true,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  if (_editable && !_loading && _view.threeView) ...[
                    if (card.roleImage != null)
                      TextField(
                        controller: _requirements,
                        enabled: !locked,
                        maxLength: 8000,
                        minLines: 2,
                        maxLines: 5,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                          height: 1.5,
                        ),
                        decoration: InputDecoration(
                          hintText: l10n.chatGenerationRequirements,
                          counterText: '',
                          isDense: true,
                          contentPadding: const EdgeInsets.all(12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: colors.outlineVariant,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: colors.primary),
                          ),
                        ),
                        onChanged: (_) {
                          _estimateToken?.cancel();
                          _estimateDebounce?.cancel();
                          setState(() {
                            _points = null;
                            _estimating = true;
                          });
                          _estimateDebounce = Timer(
                            const Duration(milliseconds: 350),
                            () => unawaited(_estimate()),
                          );
                        },
                      ),
                  ] else if (!_editable) ...[
                    if (_view.templateTitle.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          '${l10n.chatImageStyle}：${_view.templateTitle}',
                          style: ConversationCardTypography.caption,
                        ),
                      ),
                    if (_view.requirements.isNotEmpty &&
                        _view.requirements != _view.prompt)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: MarkdownMessage(
                          text: _view.requirements,
                          compact: true,
                        ),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            ConversationGenerationConfiguration(
              config: _editable ? _config : _view.config,
              model: _model,
              points: _editable ? _points : card.estimatedPoints,
              savedConfiguration: _editable
                  ? const []
                  : _view.configurationLines,
              loading: _loading,
              estimating: _estimating,
            ),
            if (!_loading &&
                _editable &&
                _config != null &&
                !_valid &&
                _attempted == null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l10n.chatInvalidGeneration,
                  style: TextStyle(fontSize: 13, color: colors.error),
                ),
              ),
            if (_editable) ...[const GenerationCreditNotice(), _actions(l10n)],
          ],
        ],
      ),
    );
  }

  Widget _actions(AppLocalizations l10n) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Wrap(
      alignment: WrapAlignment.end,
      spacing: 10,
      runSpacing: 10,
      children: [
        if (widget.block.isHomePlan ||
            widget.block.allowedActions.contains('cancel'))
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              minimumSize: const Size(80, 36),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              textStyle: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontSize: 14),
            ),
            onPressed: _busy
                ? null
                : () async {
                    if (await widget.controller.confirm(
                          widget.block,
                          'cancel',
                        ) &&
                        mounted) {
                      setState(() => _submitted = true);
                    }
                  },
            child: Text(l10n.cancel),
          ),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(110, 36),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            textStyle: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontSize: 14),
          ),
          onPressed:
              _busy ||
                  _loading ||
                  _estimating ||
                  _attempted == null && _options != null && !_valid
              ? null
              : _confirm,
          child: Text(l10n.chatConfirmGeneration),
        ),
      ],
    ),
  );
}
