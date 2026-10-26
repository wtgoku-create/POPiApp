import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter_chat_core/flutter_chat_core.dart' as chat;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';

import '../../../app/theme.dart';
import '../../../core/clipboard/clipboard_images.dart';
import '../../../core/network/agent_api_exception.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_image_preview.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_menu.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../../shared/widgets/app_svg_icon.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../assets/domain/library_work.dart';
import '../../assets/domain/library_role.dart';
import '../../session/presentation/widgets/conversation_timeline.dart'
    show MarkdownMessage;
import '../../session/domain/conversation_snapshot.dart'
    show ConversationQuestionField;
import '../../session/presentation/widgets/conversation_question_card.dart';
import '../../session/presentation/widgets/popi_message_composer.dart';
import '../data/demo_repository.dart';
import '../data/demo_file_picker.dart';
import '../domain/demo_assistant_identity.dart';
import '../domain/demo_models.dart';
import '../domain/demo_role_mentions.dart';
import '../domain/demo_upload_file.dart';
import 'demo_assistant_display.dart';
import 'demo_assets_page.dart';
import 'demo_chat_controller.dart';
import 'demo_diy_role_sheet.dart';
import 'demo_file_import_sheet.dart';
import 'demo_settings_page.dart';
import 'demo_style_film_job_card.dart';
import 'demo_style_film_review_sheet.dart';
import 'demo_style_film_sheet.dart';
import 'demo_task_brief_sheet.dart';
import 'demo_remote_media.dart';
import 'widgets/demo_image_stack.dart';
import 'widgets/demo_activity_indicator.dart';
import 'widgets/demo_chat_header.dart';
import 'widgets/demo_content_role_avatar.dart';
import 'widgets/demo_new_session_role_guide.dart';
import 'widgets/demo_widgets.dart';

enum _AttachmentSource { device, library }

class _AttachmentSourceSheet extends StatelessWidget {
  const _AttachmentSourceSheet({
    required this.onSelected,
    required this.allowDevice,
  });

  final ValueChanged<_AttachmentSource> onSelected;
  final bool allowDevice;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    Widget option({
      required Key key,
      required String label,
      required IconData icon,
      required _AttachmentSource source,
    }) => Material(
      key: key,
      color: demoSurface(context),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => onSelected(source),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              Icon(icon, color: AppColors.brand),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
    return DemoSheetBody(
      title: l.demoAttachments,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (allowDevice) ...[
            option(
              key: const Key('demo-attachment-device'),
              label: l.demoUploadFromDevice,
              icon: Icons.upload_file_outlined,
              source: _AttachmentSource.device,
            ),
            const SizedBox(height: 10),
          ],
          option(
            key: const Key('demo-attachment-library'),
            label: l.demoSelectFromLibrary,
            icon: Icons.folder_outlined,
            source: _AttachmentSource.library,
          ),
        ],
      ),
    );
  }
}

class DemoChatPage extends StatefulWidget {
  const DemoChatPage({
    required this.repository,
    required this.sessionId,
    this.desktopLayout = false,
    this.active = true,
    this.pickAttachmentFiles,
    this.clipboardImageService,
    super.key,
  });
  final DemoRepository repository;
  final String sessionId;
  final bool desktopLayout;
  final bool active;
  final Future<List<DemoUploadFile>> Function()? pickAttachmentFiles;
  final ClipboardImageService? clipboardImageService;
  @override
  State<DemoChatPage> createState() => _DemoChatPageState();
}

class _DemoChatPageState extends State<DemoChatPage> {
  late final _conversation = DemoChatController(
    widget.repository,
    widget.sessionId,
  );
  final _composer = PopiMessageComposerController();
  final _scroll = ScrollController();
  final List<String> _attachments = [];
  final DemoRoleMentionTracker _roleMentions = DemoRoleMentionTracker();
  final Map<String, int> _imagePages = {};
  final Set<String> _dismissingMediaJobs = {};
  late final ClipboardImageService _clipboardImages;
  late final ClipboardImagePasteBinding _clipboardPasteBinding;
  bool _taskBriefOpen = false;
  bool? _referencePublishingConfigured;
  bool _composerFocused = false;
  bool _pastingImages = false;
  bool _followingLatest = false;
  bool _chatLayoutInitialized = false;
  bool _latestScrollScheduled = false;
  @override
  void initState() {
    super.initState();
    _clipboardImages =
        widget.clipboardImageService ?? createClipboardImageService();
    _clipboardPasteBinding = createClipboardImagePasteBinding(
      isFocused: () => _composerFocused,
      onImages: _importClipboardImages,
      onError: _showClipboardError,
    );
    _followingLatest = widget.desktopLayout;
    _composer.textController.addListener(_reconcileRoleMentions);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (widget.repository.isHarness) {
        await demoPerform(
          context,
          () => widget.repository.resumeHarnessSession(widget.sessionId),
        );
      } else if (_conversation.session.unread > 0) {
        await demoPerform(
          context,
          () => widget.repository.updateSession(
            widget.sessionId,
            (s) => s.copyWith(unread: 0),
          ),
        );
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleLatestScroll();
  }

  @override
  void didUpdateWidget(covariant DemoChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      _clipboardPasteBinding.setActive(widget.active && _composerFocused);
    }
    if (!oldWidget.active && widget.active) _scheduleLatestScroll();
  }

  @override
  void dispose() {
    _clipboardPasteBinding.dispose();
    _conversation.dispose();
    _composer.textController.removeListener(_reconcileRoleMentions);
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _reconcileRoleMentions() =>
      _roleMentions.reconcileEditingValue(_composer.textController.value);

  bool get _chatVisible =>
      mounted && widget.active && ModalRoute.of(context)?.isCurrent != false;

  bool _handleChatScroll(ScrollNotification notification) {
    if (!_chatVisible ||
        notification.depth != 0 ||
        notification.metrics.axis != Axis.vertical) {
      return false;
    }
    if (notification is UserScrollNotification &&
        notification.direction == ScrollDirection.forward) {
      _followingLatest = false;
    } else if ((notification is ScrollUpdateNotification ||
            notification is ScrollEndNotification) &&
        notification.metrics.extentAfter <= 1) {
      _followingLatest = true;
    }
    return false;
  }

  bool _handleChatMetrics(ScrollMetricsNotification notification) {
    if (!_chatVisible ||
        notification.depth != 0 ||
        notification.metrics.axis != Axis.vertical) {
      return false;
    }
    if (!_chatLayoutInitialized) {
      _chatLayoutInitialized = true;
      _followingLatest =
          _followingLatest || notification.metrics.extentAfter <= 1;
    }
    _scheduleLatestScroll();
    return false;
  }

  /// Recheck the laid-out end as streamed text and late media change its size.
  void _scheduleLatestScroll({bool force = false}) {
    if (force) _followingLatest = true;
    if (!_followingLatest || _latestScrollScheduled) return;
    _latestScrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _latestScrollScheduled = false;
      if (!_chatVisible || !_followingLatest || !_scroll.hasClients) return;
      final position = _scroll.position;
      if (!position.hasContentDimensions) return;
      if ((position.maxScrollExtent - position.pixels).abs() > 1) {
        _scroll.jumpTo(position.maxScrollExtent);
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  String _roleName(DemoSession session, String roleId) {
    final configured = session.roleProfiles[roleId]?.name.trim() ?? '';
    return configured.isNotEmpty ? configured : demoCharacter(roleId).name;
  }

  String _roleReferenceStatus(DemoRoleProfile? profile, AppLocalizations l) {
    return switch (demoRoleReferenceAvailability(
      profile: profile,
      assets: widget.repository.assets,
      referencePublishingConfigured: _referencePublishingConfigured == true,
    )) {
      DemoRoleReferenceAvailability.ready => l.chatReferenceImage,
      DemoRoleReferenceAvailability.localOnly => l.demoLocalReferenceOnly,
      DemoRoleReferenceAvailability.pending => l.demoReferencePending,
    };
  }

  Future<void> _loadReferencePublishingCapability() async {
    if (_referencePublishingConfigured != null) return;
    if (!widget.repository.isHarness) {
      _referencePublishingConfigured = false;
      return;
    }
    try {
      final catalog = await widget.repository.loadCapabilityCatalog(
        sessionId: widget.sessionId,
      );
      _referencePublishingConfigured = catalog.referencePublishingConfigured;
    } catch (_) {
      _referencePublishingConfigured = false;
    }
  }

  void _settings({int initialTab = 0}) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => DemoSettingsPage(
        repository: widget.repository,
        sessionId: widget.sessionId,
        initialTab: initialTab,
      ),
    ),
  );

  /// Keeps the overview in sync with the selected task's existing snapshot.
  Future<void> _showTaskBrief(DemoMediaJob selected) async {
    if (_taskBriefOpen) return;
    _taskBriefOpen = true;
    var openedOutputs = false;
    try {
      await DemoSheet.show<void>(
        context: context,
        builder: (sheetContext) => ListenableBuilder(
          listenable: widget.repository,
          builder: (context, _) {
            final session = widget.repository.sessions
                .where((session) => session.id == widget.sessionId)
                .firstOrNull;
            final job =
                session?.mediaJobs
                    .where((job) => job.jobId == selected.jobId)
                    .firstOrNull ??
                selected;
            final l = AppLocalizations.of(context)!;
            final presentation = _jobPresentation(l, job);
            final request = job.runId.isEmpty
                ? null
                : session?.messages
                      .where(
                        (message) => message.user && message.runId == job.runId,
                      )
                      .lastOrNull
                      ?.text;
            return DemoTaskBriefSheet(
              job: job,
              statusLabel: presentation.label,
              statusIcon: presentation.icon,
              statusColor: presentation.color,
              requestText: request,
              memberName: session == null
                  ? null
                  : _jobMemberName(l, session, job),
              onViewOutputs: presentation.hasOutputs && session != null
                  ? () {
                      if (openedOutputs ||
                          !mounted ||
                          ModalRoute.of(sheetContext)?.isCurrent != true) {
                        return;
                      }
                      openedOutputs = true;
                      Navigator.of(sheetContext).pop();
                      _settings(initialTab: 2);
                    }
                  : null,
            );
          },
        ),
      );
    } finally {
      _taskBriefOpen = false;
    }
  }

  Future<void> _send([String? prompt]) async {
    final input = prompt ?? _composer.markdown;
    if (!widget.active || _conversation.busy) return;
    final l = AppLocalizations.of(context)!;
    final session = _conversation.session;
    final memberId = session.members.contains(session.activeMemberId)
        ? session.activeMemberId
        : session.members.first;
    final botId = session.botIdFor(memberId);
    final filmEnabled = session
        .skillsFor(memberId)
        .contains(demoStyleFilmSkillId);
    final filmSelection = filmEnabled
        ? widget.repository.styleFilmDraft(session.id, botId)
        : null;
    final filmInvocation = filmSelection == null
        ? null
        : DemoStyleFilmInvocation(selection: filmSelection);
    final contextRoleIds = _roleMentions.resolve(
      draft: input,
      linkedRoleIds: session.roles,
      roleNames: {
        for (final roleId in session.roles) roleId: _roleName(session, roleId),
      },
    );
    if (filmInvocation != null) {
      if (_attachments.isNotEmpty || contextRoleIds.isNotEmpty) {
        AppToast.error(context, l.demoStyleFilmReferencesUnsupported);
        return;
      }
      final style = Localizations.localeOf(context).languageCode == 'zh'
          ? (filmSelection!.styleNameZh.isEmpty
                ? filmSelection.styleNameEn
                : filmSelection.styleNameZh)
          : (filmSelection!.styleNameEn.isEmpty
                ? filmSelection.styleNameZh
                : filmSelection.styleNameEn);
      final confirmed = await AppDialog.confirm(
        context: context,
        title: l.demoStyleFilmConfirmTitle,
        description:
            '${l.demoStyleFilmConfirmDescription(style, filmSelection.durationSeconds, filmSelection.aspectRatio)}\n\n'
            '${l.demoStyleFilmStoryboardReview}\n'
            '${l.demoStyleFilmCostPending}',
        cancelLabel: l.cancel,
        confirmLabel: l.demoStyleFilmCreate,
      );
      if (confirmed != true || !mounted || _conversation.busy) return;
    }
    var accepted = false;
    void clearAcceptedDraft() {
      if (accepted || !mounted) return;
      accepted = true;
      unawaited(_composer.setText(''));
      _roleMentions.clear();
      setState(_attachments.clear);
      _scheduleLatestScroll();
    }

    if (input.trim().isNotEmpty ||
        _attachments.isNotEmpty ||
        filmInvocation != null) {
      _scheduleLatestScroll(force: true);
    }
    await demoPerform(context, () async {
      final ok = await _conversation.send(
        input,
        List.of(_attachments),
        l,
        contextRoleIds: contextRoleIds,
        skillInvocation: filmInvocation,
        onAccepted: clearAcceptedDraft,
      );
      if (ok) clearAcceptedDraft();
    });
  }

  bool _roleMentionSheetOpen = false;

  Future<void> _showRoleMentionSheet() async {
    if (_roleMentionSheetOpen ||
        !widget.active ||
        _conversation.busy ||
        !mounted) {
      return;
    }
    _roleMentionSheetOpen = true;
    try {
      final session = _conversation.session;
      if (session.roles.isEmpty) {
        await showDemoRoleSheet(context, widget.repository, widget.sessionId);
        return;
      }
      await _loadReferencePublishingCapability();
      if (!mounted) return;
      final selectedId = await DemoSheet.show<String>(
        context: context,
        builder: (sheetContext) => DemoSheetBody(
          title: AppLocalizations.of(sheetContext)!.demoMentionRole,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppLocalizations.of(sheetContext)!.demoMentionRoleHint,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  key: const Key('demo-role-mention-list'),
                  padding: const EdgeInsets.only(bottom: 20),
                  itemCount: session.roles.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final roleId = session.roles[index];
                    final profile = session.roleProfiles[roleId];
                    return Material(
                      key: ValueKey('demo-role-mention-$roleId'),
                      color: demoSurface(context),
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => Navigator.of(sheetContext).pop(roleId),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              DemoContentRoleAvatar(
                                repository: widget.repository,
                                session: session,
                                roleId: roleId,
                                size: 44,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _roleName(session, roleId),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      _roleReferenceStatus(
                                        profile,
                                        AppLocalizations.of(context)!,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.alternate_email_rounded,
                                color: AppColors.brand,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
      if (selectedId == null ||
          !mounted ||
          !widget.active ||
          _conversation.busy) {
        return;
      }
      final current = _conversation.session;
      if (!current.roles.contains(selectedId)) return;
      final name = _roleName(current, selectedId);
      final insertion = buildDemoRoleMentionInsertion(
        _composer.textController.value,
        name,
      );
      _composer.textController.value = insertion.value;
      _roleMentions.recordSelection(
        roleId: selectedId,
        name: name,
        start: insertion.tokenStart,
        end: insertion.tokenEnd,
        value: insertion.value,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.active && !_conversation.busy) {
          _composer.requestInputFocus();
        }
      });
    } finally {
      _roleMentionSheetOpen = false;
    }
  }

  Future<void> _stop() => demoPerform(context, _conversation.stop);

  Future<bool> _answerQuestion(
    DemoQuestion question,
    String action,
    Map<String, Object?> answer,
  ) async {
    if (!widget.active) return false;
    try {
      return await _conversation.respondQuestion(question, action, answer);
    } catch (_) {
      if (mounted) {
        AppToast.error(
          context,
          AppLocalizations.of(context)!.chatRequestFailed,
        );
      }
      return false;
    }
  }

  Future<void> _dismissMediaJobNotice(String jobId) async {
    if (!_dismissingMediaJobs.add(jobId)) return;
    setState(() {});
    try {
      await demoPerform(
        context,
        () => widget.repository.dismissMediaJobNotice(widget.sessionId, jobId),
      );
    } finally {
      if (mounted) setState(() => _dismissingMediaJobs.remove(jobId));
    }
  }

  void _addAttachments(Iterable<DemoAsset> assets) {
    if (!mounted || !widget.active) return;
    final existing = _attachments.toSet();
    final added = assets
        .map((asset) => asset.id)
        .where((id) => existing.add(id))
        .toList();
    if (added.isEmpty) return;
    try {
      widget.repository.validateMessageAttachments([..._attachments, ...added]);
    } on AgentApiException catch (error) {
      final l = AppLocalizations.of(context)!;
      AppToast.error(
        context,
        error.code == 'message_attachment_limit'
            ? l.demoAttachmentLimit
            : error.code == 'message_attachment_too_large'
            ? l.demoAttachmentTooLarge
            : l.demoAttachmentInvalid,
      );
      return;
    }
    setState(() => _attachments.addAll(added));
  }

  void _handleComposerFocus(bool focused) {
    _composerFocused = focused;
    _clipboardPasteBinding.setActive(focused && widget.active);
  }

  Future<void> _pasteImagesFromClipboard() async {
    try {
      final images = await _clipboardImages.readImagesFromUserPaste();
      if (!mounted) return;
      if (images.isEmpty) {
        final text = await Clipboard.getData(Clipboard.kTextPlain);
        if (mounted && text?.text?.isNotEmpty == true) {
          _composer.insertPlainText(text!.text!);
        } else if (mounted) {
          AppToast.info(
            context,
            AppLocalizations.of(context)!.demoPasteImageUnavailable,
          );
        }
        return;
      }
      await _importClipboardImages(images);
    } on ClipboardImageException catch (error) {
      if (mounted) _showClipboardError(error);
    }
  }

  Future<void> _importClipboardImages(
    List<ClipboardImagePayload> images,
  ) async {
    if (_pastingImages || images.isEmpty || !mounted) return;
    final selected = [
      for (final id in _attachments)
        for (final asset in widget.repository.assets)
          if (asset.id == id) asset,
    ];
    final nextCount = selected.length + images.length;
    final nextBytes =
        selected.fold<int>(0, (sum, asset) => sum + asset.sizeBytes) +
        images.fold<int>(0, (sum, image) => sum + image.bytes.lengthInBytes);
    final nextImageBytes =
        selected
            .where((asset) => asset.kind == DemoAssetKind.image)
            .fold<int>(0, (sum, asset) => sum + asset.sizeBytes) +
        images.fold<int>(0, (sum, image) => sum + image.bytes.lengthInBytes);
    final l = AppLocalizations.of(context)!;
    if (nextCount > DemoUploadFile.messageAttachmentLimit) {
      AppToast.error(context, l.demoAttachmentLimit);
      return;
    }
    if (nextBytes > DemoUploadFile.messageAttachmentTotalLimitBytes ||
        nextImageBytes > DemoUploadFile.messageImageTotalLimitBytes) {
      AppToast.error(context, l.demoAttachmentTooLarge);
      return;
    }
    setState(() => _pastingImages = true);
    try {
      for (final image in images) {
        final asset = await widget.repository.uploadFile(
          DemoUploadFile.fromBytes(
            name: image.name,
            mimeType: image.mimeType,
            bytes: image.bytes,
          ),
        );
        if (!mounted) return;
        _addAttachments([asset]);
      }
    } catch (_) {
      if (mounted) AppToast.error(context, l.demoPasteImageFailed);
    } finally {
      if (mounted) setState(() => _pastingImages = false);
    }
  }

  void _showClipboardError(ClipboardImageException error) {
    if (!mounted) return;
    final l = AppLocalizations.of(context)!;
    final message = switch (error.code) {
      'empty' || 'unavailable' => l.demoPasteImageUnavailable,
      'too_many_images' => l.demoAttachmentLimit,
      'image_too_large' || 'total_too_large' => l.demoAttachmentTooLarge,
      _ => l.demoPasteImageFailed,
    };
    AppToast.error(context, message);
  }

  Future<void> _attach() async {
    if (!mounted || !widget.active || _conversation.busy) return;
    final source = await AppSheet.show<_AttachmentSource>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      maxHeightFraction: .5,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (sheetContext) => SizedBox(
        height: (MediaQuery.sizeOf(sheetContext).height * .38).clamp(
          260.0,
          320.0,
        ),
        child: _AttachmentSourceSheet(
          allowDevice: widget.repository.isHarness,
          onSelected: (value) => Navigator.of(sheetContext).pop(value),
        ),
      ),
    );
    if (!mounted || source == null || !widget.active || _conversation.busy) {
      return;
    }
    switch (source) {
      // Keep the sheet entry point for callers outside the compact menu.
      case _AttachmentSource.device:
        if (!widget.repository.isHarness) {
          return;
        }
        await DemoSheet.show<void>(
          context: context,
          builder: (_) => DemoFileImportSheet(
            repository: widget.repository,
            pickFiles: widget.pickAttachmentFiles ?? pickDemoAssetFiles,
            onImported: _addAttachments,
          ),
        );
        return;
      case _AttachmentSource.library:
        await DemoSheet.show<void>(
          context: context,
          builder: (sheetContext) => Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Column(
              children: [
                Text(
                  AppLocalizations.of(context)!.demoAttachments,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Expanded(
                  child: DemoAssetsView(
                    repository: widget.repository,
                    onSelect: (asset) {
                      _addAttachments([asset]);
                      Navigator.of(sheetContext).pop();
                    },
                  ),
                ),
              ],
            ),
          ),
        );
        return;
    }
  }

  Future<void> _attachFrom(_AttachmentSource source) async {
    if (!mounted || !widget.active || _conversation.busy) return;
    switch (source) {
      case _AttachmentSource.device:
        if (!widget.repository.isHarness) return;
        await DemoSheet.show<void>(
          context: context,
          builder: (_) => DemoFileImportSheet(
            repository: widget.repository,
            pickFiles: widget.pickAttachmentFiles ?? pickDemoAssetFiles,
            onImported: _addAttachments,
          ),
        );
        return;
      case _AttachmentSource.library:
        await DemoSheet.show<void>(
          context: context,
          builder: (sheetContext) => Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Column(
              children: [
                Text(
                  AppLocalizations.of(sheetContext)!.demoSelectFromLibrary,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: DemoAssetsView(
                    repository: widget.repository,
                    compactHeader: true,
                    onSelect: (asset) {
                      _addAttachments([asset]);
                      Navigator.of(sheetContext).pop();
                    },
                  ),
                ),
              ],
            ),
          ),
        );
        return;
    }
  }

  Future<void> _chooseStyleFilm(DemoSession session) async {
    if (!mounted || !widget.active || _conversation.busy) return;
    final memberId = session.members.contains(session.activeMemberId)
        ? session.activeMemberId
        : session.members.first;
    if (!session.skillsFor(memberId).contains(demoStyleFilmSkillId)) return;
    final botId = session.botIdFor(memberId);
    final selected = await showDemoStyleFilmSheet(
      context: context,
      initialSelection: widget.repository.styleFilmDraft(session.id, botId),
      loadCatalog:
          ({required query, category, required page, required pageSize}) =>
              widget.repository.loadStyleFilmCatalog(
                q: query,
                category: category,
                page: page,
                pageSize: pageSize,
              ),
    );
    if (selected == null || !mounted) return;
    await widget.repository.updateStyleFilmDraft(session.id, botId, selected);
  }

  Future<bool> _reviewStyleFilm(
    DemoStyleFilmJob job,
    String action,
    String? notes,
  ) async {
    try {
      await widget.repository.reviewStyleFilm(
        widget.sessionId,
        job.jobId,
        expectedRevision: job.revision,
        action: action,
        notes: notes,
      );
      return true;
    } catch (_) {
      if (mounted) {
        AppToast.error(
          context,
          AppLocalizations.of(context)!.demoStyleFilmReviewFailed,
        );
      }
      return false;
    }
  }

  Future<void> _openStyleFilmJob(DemoStyleFilmJob job) =>
      showDemoStyleFilmReviewSheet(
        context: context,
        job: job,
        jobListenable: widget.repository,
        jobResolver: () =>
            widget.repository.styleFilmJob(widget.sessionId, job.jobId) ?? job,
        onReview: _reviewStyleFilm,
      );

  void _previewAttachment(DemoAsset asset) {
    if (!mounted || !widget.active || _conversation.busy) return;
    openDemoAsset(context, asset, repository: widget.repository);
  }

  Widget _message(BuildContext context, DemoMessage message) {
    final localizations = AppLocalizations.of(context)!;
    final question = message.question;
    final activity = _conversation.activityFor(message);
    final filmJob = message.filmJobId.isEmpty
        ? null
        : _conversation.session.filmJobs
              .where((job) => job.jobId == message.filmJobId)
              .firstOrNull;
    final text = message.text.isNotEmpty
        ? message.text
        : switch (message.status) {
            'failed' => localizations.chatTextGenerationFailed,
            'interrupted' || 'stopped' => localizations.chatProgressStopped,
            _ => '',
          };
    final media = message.assetIds
        .map(
          (id) => widget.repository.assets.where((a) => a.id == id).firstOrNull,
        )
        .whereType<DemoAsset>()
        .toList();
    final batch =
        media.length > 1 && media.every((a) => a.kind == DemoAssetKind.image);
    if (text.isEmpty &&
        media.isEmpty &&
        question == null &&
        activity == null &&
        filmJob == null) {
      return const SizedBox.shrink();
    }
    final session = _conversation.session;
    final fallbackMemberId = session.members.length == 1
        ? DemoAssistantIdentity.primaryMemberId(session)
        : activity != null
        ? session.members.contains(session.activeMemberId)
              ? session.activeMemberId
              : session.members.firstOrNull ?? 'popi'
        : 'popi';
    final memberId = message.memberId.trim().isNotEmpty
        ? message.memberId
        : fallbackMemberId;
    final snapshotName = message.memberName.trim();
    final memberName = demoSessionMemberName(
      localizations,
      session,
      memberId,
      snapshotName: snapshotName,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        widget.desktopLayout ? 24 : 16,
        0,
        widget.desktopLayout ? 24 : 16,
        message.user ? 16 : 10,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: message.user
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!message.user && activity == null) ...[
            KeyedSubtree(
              key: ValueKey('demo-message-avatar-${message.id}-$memberId'),
              child: DemoAvatar(
                members: [memberId],
                memberAvatars: _conversation.session.memberAvatars,
                memberColors: _conversation.session.memberColors,
                size: 24,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: widget.desktopLayout
                    ? 760
                    : !message.user || question != null || activity != null
                    ? MediaQuery.sizeOf(context).width - 64
                    : MediaQuery.sizeOf(context).width * .82,
              ),
              child: Column(
                crossAxisAlignment: message.user
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (!message.user && activity == null) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 2, bottom: 4),
                      child: Text(
                        memberName,
                        key: ValueKey('demo-message-name-${message.id}'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                  if (text.isNotEmpty)
                    Semantics(
                      liveRegion: message.id == 'thinking',
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: message.user ? 10 : 12,
                        ),
                        decoration: BoxDecoration(
                          color: message.user
                              ? demoTint
                              : widget.desktopLayout &&
                                    Theme.of(context).brightness ==
                                        Brightness.light
                              ? const Color(0xFFF2F2F3)
                              : demoSurface(context),
                          borderRadius: BorderRadius.circular(
                            message.user ? 22 : 18,
                          ),
                        ),
                        child: MarkdownMessage(
                          text: text,
                          style: TextStyle(
                            fontSize: widget.desktopLayout ? 15 : 16,
                            height: 1.55,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  if (question != null) ...[
                    if (text.isNotEmpty) const SizedBox(height: 10),
                    ConversationQuestionCard(
                      key: ValueKey('demo-question-${question.id}'),
                      title: question.title.isNotEmpty
                          ? question.title
                          : question.questions.length == 1
                          ? question.questions.single.question
                          : '',
                      fields: [
                        for (final field in question.questions)
                          ConversationQuestionField(
                            id: field.id,
                            label: field.question,
                            multiple: field.multiSelect,
                            required: true,
                            options: [
                              for (final option in field.options) option.label,
                            ],
                            optionDescriptions: {
                              for (final option in field.options)
                                option.label: option.description,
                            },
                          ),
                      ],
                      status: question.status,
                      answer: question.answer,
                      busy:
                          !widget.active ||
                          _conversation.questionBusy(question.id),
                      instantSingleChoice: true,
                      onRespond: (action, answer) =>
                          _answerQuestion(question, action, answer),
                    ),
                  ],
                  if (filmJob != null) ...[
                    if (text.isNotEmpty || question != null)
                      const SizedBox(height: 10),
                    DemoStyleFilmJobCard(
                      job: filmJob,
                      onOpen: () => _openStyleFilmJob(filmJob),
                      onOpenOutput: filmJob.isCompleted
                          ? () => _settings(initialTab: 2)
                          : null,
                      onRetry: filmJob.allowedActions.contains('revise')
                          ? () => _openStyleFilmJob(filmJob)
                          : null,
                    ),
                  ],
                  if (media.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    if (batch)
                      DemoImageStack(
                        key: ValueKey('demo-image-stack-${message.id}'),
                        images: media,
                        messageId: message.id,
                        initialIndex: _imagePages[message.id] ?? 0,
                        onChanged: (index) => _imagePages[message.id] = index,
                      )
                    else
                      for (final asset in media)
                        SizedBox(
                          width: 245,
                          height:
                              (DemoAssetCard.heightForWidth(context, 245) + 10)
                                  .clamp(
                                    asset.kind == DemoAssetKind.audio ||
                                            asset.kind == DemoAssetKind.script
                                        ? 327.0
                                        : 0.0,
                                    double.infinity,
                                  ),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: DemoAssetCard(
                              asset: asset,
                              onTap: () => asset.kind == DemoAssetKind.image
                                  ? AppImagePreview.show(
                                      context: context,
                                      image: demoAssetImageProviderForContext(
                                        context,
                                        asset,
                                      ),
                                      heroTag:
                                          'message-${message.id}-${asset.id}',
                                      label: asset.title,
                                    )
                                  : openDemoAsset(
                                      context,
                                      asset,
                                      repository: widget.repository,
                                    ),
                            ),
                          ),
                        ),
                  ],
                  if (activity != null) ...[
                    if (text.isNotEmpty || question != null || media.isNotEmpty)
                      const SizedBox(height: 10),
                    DemoActivityIndicator(
                      key: ValueKey('demo-activity-${message.id}'),
                      activity: activity,
                      memberName: memberName,
                      avatar: TickerMode(
                        enabled: activity.status == 'running',
                        child: DemoAvatar(
                          members: [memberId],
                          memberAvatars: _conversation.session.memberAvatars,
                          memberColors: _conversation.session.memberColors,
                          size: 32,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: _conversation,
      builder: (context, _) {
        final s = widget.repository.sessions
            .where((session) => session.id == widget.sessionId)
            .firstOrNull;
        if (s == null) return const SizedBox.shrink();
        final hasMessages = _conversation.chatController.messages.isNotEmpty;
        final loadingSnapshot =
            widget.repository.isSessionLoading(widget.sessionId) &&
            !_conversation.running;
        final selectedAttachments = [
          for (final id in _attachments)
            for (final asset in widget.repository.assets)
              if (asset.id == id) asset,
        ];
        final activeMemberId = s.members.contains(s.activeMemberId)
            ? s.activeMemberId
            : s.members.first;
        final activeBotId = s.botIdFor(activeMemberId);
        final styleFilmEnabled = s
            .skillsFor(activeMemberId)
            .contains(demoStyleFilmSkillId);
        final styleFilmDraft = styleFilmEnabled
            ? widget.repository.styleFilmDraft(s.id, activeBotId)
            : null;
        final messageFilmJobIds = s.messages
            .map((message) => message.filmJobId)
            .where((id) => id.isNotEmpty)
            .toSet();
        final unlinkedFilmJobs = s.filmJobs
            .where((job) => !messageFilmJobIds.contains(job.jobId))
            .toList();
        return DemoScaffold(
          maxContentWidth: widget.desktopLayout ? 1120 : 640,
          backgroundColor: widget.desktopLayout
              ? Theme.of(context).colorScheme.surface
              : null,
          extendBodyBehindAppBar: true,
          appBar: DemoChatHeader(
            session: s,
            desktopLayout: widget.desktopLayout,
            toolbarHeight:
                (MediaQuery.textScalerOf(context).scale(16) * 1.2 + 26).clamp(
                  kToolbarHeight,
                  double.infinity,
                ),
            onBack: () => Navigator.of(context).pop(),
            onSettings: _settings,
          ),
          child: Builder(
            builder: (bodyContext) {
              // Scaffold includes the floating app bar in this body's top inset.
              final headerInset = MediaQuery.paddingOf(bodyContext).top;
              return Column(
                children: [
                  Expanded(
                    child:
                        widget.repository.isSessionLoading(widget.sessionId) &&
                            !hasMessages &&
                            !_conversation.waitingForResponse
                        ? Padding(
                            padding: EdgeInsets.only(top: headerInset),
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          )
                        : !hasMessages && s.members.length == 1
                        ? Padding(
                            padding: EdgeInsets.only(top: headerInset),
                            child: DemoNewSessionRoleGuide(
                              repository: widget.repository,
                              session: s,
                              onLinkRole: () => showDemoRoleSheet(
                                context,
                                widget.repository,
                                widget.sessionId,
                              ),
                              onUploadDiyRole: () async {
                                await showDemoDiyRoleSheet(
                                  context,
                                  widget.repository,
                                  widget.sessionId,
                                );
                              },
                              onCompleteRole: _settings,
                              onStartCreating: () {
                                if (widget.active && !_conversation.busy) {
                                  _composer.requestInputFocus();
                                }
                              },
                            ),
                          )
                        : Chat(
                            currentUserId: 'demo-user',
                            resolveUser: (id) async =>
                                _conversation.resolveUser(id, l),
                            chatController: _conversation.chatController,
                            backgroundColor: Colors.transparent,
                            builders: chat.Builders(
                              composerBuilder: (_) => const SizedBox.shrink(),
                              chatAnimatedListBuilder: (context, itemBuilder) =>
                                  NotificationListener<ScrollNotification>(
                                    onNotification: _handleChatScroll,
                                    child:
                                        NotificationListener<
                                          ScrollMetricsNotification
                                        >(
                                          onNotification: _handleChatMetrics,
                                          child: ChatAnimatedList(
                                            scrollController: _scroll,
                                            initialScrollToEndMode:
                                                InitialScrollToEndMode.none,
                                            shouldScrollToEndWhenSendingMessage:
                                                false,
                                            shouldScrollToEndWhenAtBottom:
                                                false,
                                            handleSafeArea: false,
                                            topPadding: headerInset + 10,
                                            bottomPadding: 10,
                                            keyboardDismissBehavior:
                                                ScrollViewKeyboardDismissBehavior
                                                    .onDrag,
                                            itemBuilder: itemBuilder,
                                          ),
                                        ),
                                  ),
                              chatMessageBuilder:
                                  (
                                    context,
                                    message,
                                    index,
                                    animation,
                                    child, {
                                    required isSentByMe,
                                    groupStatus,
                                    isRemoved,
                                  }) => _message(
                                    context,
                                    message.metadata!['demo'] as DemoMessage,
                                  ),
                            ),
                          ),
                  ),
                  if (s.mediaJobs.any(
                    (job) => !widget.repository.isMediaJobNoticeDismissed(
                      s.id,
                      job.jobId,
                    ),
                  ))
                    _DemoMediaJobsPanel(
                      jobs: s.mediaJobs
                          .where(
                            (job) => !widget.repository
                                .isMediaJobNoticeDismissed(s.id, job.jobId),
                          )
                          .toList(),
                      session: s,
                      dismissingJobIds: _dismissingMediaJobs,
                      onOpenOutputs: () => _settings(initialTab: 2),
                      onShowBrief: _showTaskBrief,
                      onDismiss: _dismissMediaJobNotice,
                    ),
                  if (unlinkedFilmJobs.isNotEmpty)
                    SizedBox(
                      key: const Key('demo-style-film-jobs-panel'),
                      height: 92,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: unlinkedFilmJobs.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final job = unlinkedFilmJobs[index];
                          return SizedBox(
                            width: widget.desktopLayout ? 360 : 310,
                            child: DemoStyleFilmJobCard(
                              job: job,
                              onOpen: () => _openStyleFilmJob(job),
                              onOpenOutput: job.isCompleted
                                  ? () => _settings(initialTab: 2)
                                  : null,
                              onRetry: job.allowedActions.contains('revise')
                                  ? () => _openStyleFilmJob(job)
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
                  PopiMessageComposer(
                    active: widget.active,
                    maxWidth: widget.desktopLayout ? 1000 : null,
                    conversationMode: true,
                    sessionLayout: true,
                    bottomPadding: PopiMessageComposer.bottomGap,
                    controller: _composer,
                    placeholderText: l.composerNamedPlaceholder(
                      demoSessionDisplayName(l, s),
                    ),
                    selectedImages: const [],
                    contextChips: styleFilmEnabled
                        ? [
                            _ComposerContextChip(
                              key: ValueKey('demo-style-film-bot-$activeBotId'),
                              label: demoSessionMemberName(
                                l,
                                s,
                                activeMemberId,
                              ),
                              leading: DemoAvatar(
                                members: [activeMemberId],
                                memberAvatars: s.memberAvatars,
                                memberColors: s.memberColors,
                                size: 24,
                              ),
                            ),
                            _ComposerContextChip(
                              key: const Key('demo-style-film-style-chip'),
                              label: styleFilmDraft == null
                                  ? l.demoStyleFilmSelect
                                  : _styleFilmSelectionName(
                                      styleFilmDraft,
                                      Localizations.localeOf(
                                        context,
                                      ).languageCode,
                                    ),
                              leading: const Icon(
                                Icons.palette_outlined,
                                size: 20,
                              ),
                              onPressed: _conversation.busy
                                  ? null
                                  : () => _chooseStyleFilm(s),
                              onClear:
                                  styleFilmDraft == null || _conversation.busy
                                  ? null
                                  : () =>
                                        widget.repository.updateStyleFilmDraft(
                                          s.id,
                                          activeBotId,
                                          null,
                                        ),
                              clearLabel: l.demoStyleFilmClear,
                            ),
                            if (_pastingImages)
                              _ComposerContextChip(
                                key: const Key('demo-pasting-images-chip'),
                                label: l.demoPastingImages,
                                leading: const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                          ]
                        : _pastingImages
                        ? [
                            _ComposerContextChip(
                              key: const Key('demo-pasting-images-chip'),
                              label: l.demoPastingImages,
                              leading: const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          ]
                        : const [],
                    selectedAssets: [
                      for (final asset in selectedAttachments)
                        LibraryWork(
                          id: asset.id,
                          previewUrl: asset.kind == DemoAssetKind.video
                              ? asset.posterUrl.isNotEmpty
                                    ? asset.posterUrl
                                    : asset.cover
                              : asset.thumbnailUrl.isNotEmpty
                              ? asset.thumbnailUrl
                              : asset.cover,
                          isVideo: asset.kind == DemoAssetKind.video,
                          videoUrl: asset.kind == DemoAssetKind.video
                              ? asset.contentUrl
                              : '',
                          imageUrls:
                              asset.kind == DemoAssetKind.image &&
                                  asset.contentUrl.isNotEmpty
                              ? [asset.contentUrl]
                              : const [],
                          createdAt: null,
                        ),
                    ],
                    selectedAssetThumbnailBuilder: (context, index) {
                      if (index < 0 || index >= selectedAttachments.length) {
                        return null;
                      }
                      final asset = selectedAttachments[index];
                      if (asset.kind == DemoAssetKind.image ||
                          asset.kind == DemoAssetKind.video) {
                        return null;
                      }
                      return Semantics(
                        label: asset.title,
                        image: true,
                        child: ExcludeSemantics(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    demoAssetIcon(asset.kind),
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    size: 26,
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    asset.title,
                                    maxLines: asset.isDocument ? 1 : 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      height: 1.15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (asset.isDocument)
                                    Text(
                                      asset.document?.format
                                              .trim()
                                              .toUpperCase() ??
                                          l.demoDocuments,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textTertiary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    onAttachment: _attach,
                    attachmentAction: AppMenuButton(
                      key: const Key('demo-composer-add-menu'),
                      tooltip: l.addAttachment,
                      enabled: widget.active && !_conversation.busy,
                      size: 40,
                      icon: const AppSvgIcon.asset(
                        'home_composer_add',
                        size: 16,
                      ),
                      entries: [
                        if (widget.repository.isHarness)
                          AppMenuItem(
                            key: const Key('demo-add-from-device'),
                            label: l.demoStyleFilmUpload,
                            icon: const DemoIcon('upload', size: 20),
                            onSelected: () => unawaited(
                              _attachFrom(_AttachmentSource.device),
                            ),
                          ),
                        AppMenuItem(
                          key: const Key('demo-add-from-library'),
                          label: l.demoStyleFilmLibrary,
                          icon: const DemoIcon('folder', size: 20),
                          onSelected: () =>
                              unawaited(_attachFrom(_AttachmentSource.library)),
                        ),
                        if (!kIsWeb)
                          AppMenuItem(
                            key: const Key('demo-paste-image'),
                            label: l.demoPasteImage,
                            icon: const Icon(Icons.content_paste_rounded),
                            onSelected: () =>
                                unawaited(_pasteImagesFromClipboard()),
                          ),
                        if (styleFilmEnabled) ...[
                          const AppMenuDivider(),
                          AppMenuItem(
                            key: const Key('demo-add-style-film'),
                            label: l.demoStyleFilmMenu,
                            selected: styleFilmDraft != null,
                            icon: const Icon(Icons.palette_outlined, size: 20),
                            onSelected: () => unawaited(_chooseStyleFilm(s)),
                          ),
                        ],
                      ],
                    ),
                    onRemoveImage: (_) {},
                    onRemoveAsset: (index) {
                      if (index < 0 || index >= selectedAttachments.length) {
                        return;
                      }
                      setState(
                        () =>
                            _attachments.remove(selectedAttachments[index].id),
                      );
                    },
                    onPreviewAsset: (index) {
                      if (index < 0 || index >= selectedAttachments.length) {
                        return;
                      }
                      _previewAttachment(selectedAttachments[index]);
                    },
                    onHeightChanged: (_) {},
                    onSubmitted: _send,
                    attachmentsReady: !_pastingImages,
                    onFocusChanged: _handleComposerFocus,
                    onPasteImageRequested: _pasteImagesFromClipboard,
                    enableMentions: true,
                    onMentionRequested: _showRoleMentionSheet,
                    sending: _conversation.sending || loadingSnapshot,
                    running: _conversation.running,
                    canStopRunning: _conversation.canStop,
                    onStop: _conversation.canStop ? _stop : null,
                    castRoles: [
                      for (final id in s.roles)
                        LibraryRole(
                          id: id,
                          title: _roleName(s, id),
                          description: '',
                          avatar: demoContentRoleAvatarSource(
                            widget.repository,
                            s,
                            id,
                          ),
                        ),
                    ],
                    onCastRequested: _showRoleMentionSheet,
                    castEnabled: widget.active && !_conversation.busy,
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

String _styleFilmSelectionName(
  DemoStyleFilmSelection selection,
  String languageCode,
) => languageCode == 'zh'
    ? (selection.styleNameZh.isEmpty
          ? selection.styleNameEn
          : selection.styleNameZh)
    : (selection.styleNameEn.isEmpty
          ? selection.styleNameZh
          : selection.styleNameEn);

class _ComposerContextChip extends StatelessWidget {
  const _ComposerContextChip({
    required this.label,
    required this.leading,
    this.onPressed,
    this.onClear,
    this.clearLabel,
    super.key,
  });

  final String label;
  final Widget leading;
  final VoidCallback? onPressed;
  final VoidCallback? onClear;
  final String? clearLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        leading,
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        if (onClear != null)
          SizedBox.square(
            dimension: 40,
            child: IconButton(
              key: const Key('demo-style-film-clear'),
              tooltip: clearLabel,
              onPressed: onClear,
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ),
      ],
    );
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: 44,
        maxWidth: MediaQuery.sizeOf(context).width - 40,
      ),
      child: Material(
        color: onPressed == null
            ? colors.surface
            : colors.primaryContainer.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: onPressed == null
            ? Padding(
                padding: EdgeInsets.fromLTRB(9, 2, onClear == null ? 13 : 2, 2),
                child: content,
              )
            : InkWell(
                onTap: onPressed,
                borderRadius: BorderRadius.circular(22),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    9,
                    2,
                    onClear == null ? 13 : 2,
                    2,
                  ),
                  child: content,
                ),
              ),
      ),
    );
  }
}

class _DemoMediaJobsPanel extends StatelessWidget {
  const _DemoMediaJobsPanel({
    required this.jobs,
    required this.session,
    required this.dismissingJobIds,
    required this.onOpenOutputs,
    required this.onShowBrief,
    required this.onDismiss,
  });

  final List<DemoMediaJob> jobs;
  final DemoSession session;
  final Set<String> dismissingJobIds;
  final VoidCallback onOpenOutputs;
  final ValueChanged<DemoMediaJob> onShowBrief;
  final ValueChanged<String> onDismiss;

  @override
  Widget build(BuildContext context) {
    final visible = jobs.reversed
        .where((job) => job.isPending)
        .followedBy(jobs.reversed.where((job) => !job.isPending))
        .take(2)
        .toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        children: [
          for (final job in visible)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _DemoMediaJobRow(
                job: job,
                memberName: _jobMemberName(
                  AppLocalizations.of(context)!,
                  session,
                  job,
                ),
                onOpenOutputs: onOpenOutputs,
                onShowBrief: () => onShowBrief(job),
                dismissing: dismissingJobIds.contains(job.jobId),
                onDismiss: job.isPending ? null : () => onDismiss(job.jobId),
              ),
            ),
        ],
      ),
    );
  }
}

String? _jobMemberName(
  AppLocalizations localizations,
  DemoSession session,
  DemoMediaJob job,
) {
  final memberId = job.memberId.isNotEmpty
      ? job.memberId
      : session.members.length == 1
      ? DemoAssistantIdentity.primaryMemberId(session)
      : null;
  return memberId == null
      ? null
      : demoSessionMemberName(localizations, session, memberId);
}

class _DemoMediaJobRow extends StatelessWidget {
  const _DemoMediaJobRow({
    required this.job,
    required this.onOpenOutputs,
    required this.onShowBrief,
    this.memberName,
    this.onDismiss,
    required this.dismissing,
  });

  final DemoMediaJob job;
  final String? memberName;
  final VoidCallback onOpenOutputs;
  final VoidCallback onShowBrief;
  final VoidCallback? onDismiss;
  final bool dismissing;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final presentation = _jobPresentation(l, job);
    final resolvedMemberName =
        memberName ??
        (job.memberId.isEmpty ? null : demoMemberName(l, job.memberId));
    final borderRadius = BorderRadius.circular(16);
    return Material(
      key: ValueKey('demo-media-job-${job.jobId}'),
      color: demoSurface(context),
      borderRadius: borderRadius,
      child: InkWell(
        key: ValueKey('demo-media-job-open-${job.jobId}'),
        borderRadius: borderRadius,
        onTap: presentation.hasOutputs ? onOpenOutputs : onShowBrief,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 24,
                child: Icon(
                  presentation.icon,
                  size: 20,
                  color: presentation.color,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      presentation.label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (resolvedMemberName?.isNotEmpty == true)
                          resolvedMemberName!,
                        l.demoTaskConfigRevision(job.configRevision),
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Tooltip(
                message: presentation.hasOutputs
                    ? l.demoViewOutputs
                    : l.demoTaskBrief,
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.textTertiary,
                ),
              ),
              if (onDismiss != null)
                SizedBox.square(
                  dimension: 40,
                  child: GestureDetector(
                    excludeFromSemantics: true,
                    behavior: HitTestBehavior.opaque,
                    onTap: dismissing ? () {} : null,
                    child: IconButton(
                      key: ValueKey('demo-media-job-dismiss-${job.jobId}'),
                      tooltip: l.demoDismissTaskNotice,
                      padding: EdgeInsets.zero,
                      onPressed: dismissing ? null : onDismiss,
                      icon: dismissing
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: AppColors.textTertiary,
                            ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

({String label, IconData icon, Color color, bool hasOutputs}) _jobPresentation(
  AppLocalizations l,
  DemoMediaJob job,
) {
  final state = job.state.toLowerCase();
  final ingestion = job.ingestionState.toLowerCase();
  if (ingestion == 'pending' || ingestion == 'ingesting') {
    return (
      label: l.demoTaskSaving,
      hasOutputs: false,
      icon: Icons.save_alt_rounded,
      color: AppColors.brand,
    );
  }
  if (const {'submitting', 'pending', 'queued'}.contains(state)) {
    return (
      label: l.demoTaskQueued,
      hasOutputs: false,
      icon: Icons.schedule_rounded,
      color: AppColors.brand,
    );
  }
  if (const {'running', 'processing'}.contains(state)) {
    return (
      label: l.demoTaskCreating,
      hasOutputs: false,
      icon: Icons.auto_awesome_rounded,
      color: AppColors.brand,
    );
  }
  if (const {'failed', 'error'}.contains(state) || ingestion == 'failed') {
    return (
      label: l.demoTaskFailed,
      hasOutputs: false,
      icon: Icons.error_outline_rounded,
      color: const Color(0xFFD63D43),
    );
  }
  if (job.assetIds.isNotEmpty || ingestion == 'completed') {
    return (
      label: l.demoTaskSaved,
      hasOutputs: true,
      icon: Icons.check_circle_outline_rounded,
      color: AppColors.success,
    );
  }
  return (
    label: l.demoTaskUnknown,
    hasOutputs: false,
    icon: Icons.help_outline_rounded,
    color: AppColors.textTertiary,
  );
}
