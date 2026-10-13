import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../shared/widgets/app_network_image.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/app_sheet.dart';
import '../../../../shared/widgets/app_skeleton.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../domain/conversation_generation.dart';
import '../../domain/conversation_generation_view.dart';
import '../../domain/conversation_snapshot.dart';
import '../../../role_guide/domain/home_creation.dart';
import '../conversation_controller.dart';
import 'conversation_card.dart';
import 'conversation_role_card.dart';
import 'conversation_timeline.dart'
    show MarkdownMessage, ConversationMediaView, conversationErrorText;

/// 生成确认使用会话偏好和实时估价，角色图先固定素材组合再授权。
class ConversationGenerationCard extends StatefulWidget {
  const ConversationGenerationCard({
    required this.block,
    required this.controller,
    this.onModelParametersRequested,
    super.key,
  });
  final ConversationBlock block;
  final ConversationController controller;
  final VoidCallback? onModelParametersRequested;
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
    final template = await AppSheet.showDraggable<ConversationRoleTemplate?>(
      context: context,
      initialChildSize: .65,
      builder: (context, scroll) =>
          _TemplatePicker(controller: widget.controller, scroll: scroll),
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
      description: AppLocalizations.of(
        context,
      )!.chatEstimatedPoints(selected.estimatedPoints.toString()),
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
    return ConversationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  card.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: _expanded
                    ? l10n.chatCollapseProfile
                    : l10n.roleGuideViewMore,
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
              ),
            ],
          ),
          Text(conversationStatusLabel(card.status, l10n)),
          if (_expanded) ...[
            if (card.isHomePlan) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final role in card.homeCast)
                    ConversationRoleCard(block: role, framed: false),
                ],
              ),
              if (card.homeTopic case final topic?) ...[
                const SizedBox(height: 12),
                Text(
                  topic.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                MarkdownMessage(text: topic.body, compact: true),
              ],
            ] else ...[
              if (card.previewRole case final role?)
                ConversationRoleCard(block: role, framed: false),
              if (_view.prompt.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: MarkdownMessage(text: _view.prompt, compact: true),
                ),
            ],
            if (_editable && !_loading && _view.threeView) ...[
              Row(
                children: [
                  Expanded(child: Text(l10n.chatReferenceImage)),
                  IconButton(
                    tooltip: l10n.chatReferenceImage,
                    onPressed: locked ? null : _uploadReference,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                  ),
                  if (_reference != null)
                    IconButton(
                      tooltip: l10n.removeImage,
                      onPressed: locked
                          ? null
                          : () {
                              setState(() => _reference = null);
                              unawaited(_estimate());
                            },
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
              if (_reference != null)
                ConversationMediaView(
                  id: _reference!,
                  repository: widget.controller.repository,
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.chatImageStyle),
                subtitle: Text(
                  _templateTitle.isEmpty
                      ? l10n.chatUnrestrictedStyle
                      : _templateTitle,
                ),
                trailing: IconButton(
                  tooltip: l10n.chatImageStyle,
                  onPressed: locked ? null : _chooseTemplate,
                  icon: const Icon(Icons.palette_outlined),
                ),
              ),
              if (_templateMediaId != null)
                ConversationMediaView(
                  id: _templateMediaId!,
                  repository: widget.controller.repository,
                ),
              if (card.roleImage != null)
                TextField(
                  controller: _requirements,
                  enabled: !locked,
                  maxLength: 8000,
                  minLines: 2,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: l10n.chatGenerationRequirements,
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
              for (final ref in _view.referenceIds(
                _view.referenceMediaId,
                _view.template['mediaId']?.toString(),
              ))
                ConversationMediaView(
                  id: ref,
                  repository: widget.controller.repository,
                ),
            ],
            if (_loading)
              AppSkeleton(
                label: l10n.loadingAssets,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppSkeletonBox(width: 160, height: 18),
                      SizedBox(height: 10),
                      AppSkeletonBox(height: 14),
                    ],
                  ),
                ),
              )
            else if (_editable && _config != null) ...[
              const SizedBox(height: 12),
              Text(
                '${_model?.name ?? l10n.chatUnavailable}\n${_config!.params.values.join(' / ')}',
              ),
              if (widget.onModelParametersRequested != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: l10n.roleModelParameters,
                    onPressed: _busy ? null : widget.onModelParametersRequested,
                    icon: const Icon(Icons.tune),
                  ),
                ),
              if (!_valid && _attempted == null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    l10n.chatInvalidGeneration,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _points == null
                      ? _estimating
                            ? l10n.roleEstimatePending
                            : l10n.chatUnavailable
                      : l10n.chatEstimatedPoints(_points.toString()),
                ),
              ),
            ] else ...[
              if (card.configuration.isNotEmpty) Text(card.configuration),
              if (card.estimatedPoints != null)
                Text(l10n.chatEstimatedPoints(card.estimatedPoints.toString())),
            ],
            if (_editable)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (card.isHomePlan ||
                        card.allowedActions.contains('cancel'))
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () async {
                                if (await widget.controller.confirm(
                                      card,
                                      'cancel',
                                    ) &&
                                    mounted) {
                                  setState(() => _submitted = true);
                                }
                              },
                        child: Text(l10n.cancel),
                      ),
                    FilledButton(
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
              ),
          ],
        ],
      ),
    );
  }
}

class _TemplatePicker extends StatefulWidget {
  const _TemplatePicker({required this.controller, required this.scroll});
  final ConversationController controller;
  final ScrollController scroll;
  @override
  State<_TemplatePicker> createState() => _TemplatePickerState();
}

class _TemplatePickerState extends State<_TemplatePicker> {
  final _token = CancelToken();
  late final Future<List<ConversationRoleTemplate>> _templates = _load();

  Future<List<ConversationRoleTemplate>> _load() async {
    try {
      return await widget.controller.repository.roleTemplates(
        cancelToken: _token,
      );
    } catch (error) {
      if (mounted && !_token.isCancelled) {
        AppToast.error(
          context,
          conversationErrorText(error, AppLocalizations.of(context)!),
        );
      }
      return const [];
    }
  }

  @override
  void dispose() {
    _token.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FutureBuilder<List<ConversationRoleTemplate>>(
      future: _templates,
      builder: (context, snapshot) {
        final items = snapshot.data;
        return ListView.builder(
          controller: widget.scroll,
          padding: const EdgeInsets.all(20),
          itemCount: items == null ? 2 : items.length + 2,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Text(
                l10n.chatImageStyle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              );
            }
            if (items == null) {
              return AppSkeletonList(label: l10n.loadingAssets, itemCount: 3);
            }
            if (index == 1) {
              return ListTile(
                title: Text(l10n.chatUnrestrictedStyle),
                onTap: () => Navigator.of(context).pop(
                  ConversationRoleTemplate.fromJson({'id': '', 'title': ''}),
                ),
              );
            }
            final template = items[index - 2];
            return ListTile(
              key: ValueKey(template.id),
              minVerticalPadding: 12,
              leading: template.coverUrl.isEmpty
                  ? const Icon(Icons.palette_outlined)
                  : SizedBox.square(
                      dimension: 56,
                      child: AppNetworkImage(
                        template.coverUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.palette_outlined),
                      ),
                    ),
              title: Text(template.title),
              onTap: () => Navigator.of(context).pop(template),
            );
          },
        );
      },
    );
  }
}
