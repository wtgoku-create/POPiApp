import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/type/media_preview_type.dart';
import '../../../shared/widgets/app_media_gallery.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../data/demo_fixtures.dart';
import '../data/demo_repository.dart';
import '../data/demo_website_character_catalog.dart';
import '../domain/demo_models.dart';
import '../domain/demo_role_preview.dart';
import 'demo_remote_media.dart';
import 'demo_role_image.dart';

/// Opens the read-only Demo character profile and returns the role selected for
/// editing, if the user chose the explicit edit action.
Future<String?> showDemoRoleProfilePreview(
  BuildContext context, {
  required DemoRepository repository,
  required String sessionId,
  required List<String> roleIds,
  required String initialRoleId,
  Map<String, DemoRoleProfile> profileSnapshots = const {},
  Set<String> editableRoleIds = const {},
}) {
  if (roleIds.isEmpty || !roleIds.contains(initialRoleId)) {
    return Future<String?>.value(null);
  }
  return AppSheet.show<String>(
    context: context,
    useSafeArea: false,
    isScrollControlled: true,
    maxHeightFraction: .9,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
    ),
    builder: (context) => SizedBox(
      height: MediaQuery.sizeOf(context).height * .84,
      child: DemoRoleProfilePreviewSheet(
        repository: repository,
        sessionId: sessionId,
        roleIds: roleIds,
        initialRoleId: initialRoleId,
        profileSnapshots: profileSnapshots,
        editableRoleIds: editableRoleIds,
      ),
    ),
  );
}

class DemoRoleProfilePreviewSheet extends StatefulWidget {
  const DemoRoleProfilePreviewSheet({
    required this.repository,
    required this.sessionId,
    required this.roleIds,
    required this.initialRoleId,
    this.profileSnapshots = const {},
    this.editableRoleIds = const {},
    super.key,
  });

  final DemoRepository repository;
  final String sessionId;
  final List<String> roleIds;
  final String initialRoleId;
  final Map<String, DemoRoleProfile> profileSnapshots;
  final Set<String> editableRoleIds;

  @override
  State<DemoRoleProfilePreviewSheet> createState() =>
      _DemoRoleProfilePreviewSheetState();
}

class _DemoRoleProfilePreviewSheetState
    extends State<DemoRoleProfilePreviewSheet> {
  late int _index = widget.roleIds
      .indexOf(widget.initialRoleId)
      .clamp(0, widget.roleIds.length - 1);
  bool _instructionsExpanded = false;
  bool _sessionMissing = false;
  bool _closeScheduled = false;

  String get _roleId => widget.roleIds[_index];

  DemoSession? get _currentSession => widget.repository.sessions
      .where((session) => session.id == widget.sessionId)
      .firstOrNull;

  DemoRoleProfile get _profile {
    final sessionProfile = _currentSession?.roleProfiles[_roleId];
    final profile =
        sessionProfile ??
        widget.profileSnapshots[_roleId] ??
        widget.repository.libraryRoleProfile(_roleId) ??
        DemoWebsiteCharacterCatalog.profile(_roleId) ??
        const DemoRoleProfile();
    final role = widget.repository.libraryRole(_roleId);
    if (!widget.repository.usesBusinessLibrary || role == null) return profile;
    final basic = role['basicInfo'];
    final avatars = {role['avatarUrl'], if (basic is Map) basic['avatar']};
    final references = (role['references'] as List? ?? const [])
        .whereType<Map>();
    return profile.copyWith(
      referenceImageUrls: profile.referenceImageUrls
          .where(
            (url) =>
                !avatars.contains(url) ||
                references.any(
                  (reference) =>
                      reference['url'] == url || reference['contentUrl'] == url,
                ),
          )
          .toList(),
    );
  }

  bool _canEdit(String roleId) {
    final session = _currentSession;
    return session != null &&
        session.roles.contains(roleId) &&
        widget.editableRoleIds.contains(roleId);
  }

  String get _fallbackName {
    final character = DemoFixtures.characters
        .where((character) => character.id == _roleId)
        .firstOrNull;
    if (character != null) return character.name;
    if (_roleId.startsWith('custom:')) return _roleId.substring(7);
    return _roleId;
  }

  String? get _bundledAvatar =>
      DemoWebsiteCharacterCatalog.bundledAvatar(_roleId) ??
      DemoFixtures.characters
          .where((character) => character.id == _roleId)
          .firstOrNull
          ?.image;

  DemoRolePreviewData get _data => DemoRolePreviewData.fromProfile(
    roleId: _roleId,
    profile: _profile,
    fallbackName: _fallbackName,
    assets: widget.repository.assets,
  );

  @override
  void initState() {
    super.initState();
    widget.repository.addListener(_handleRepositoryChange);
    if (_currentSession == null) {
      _sessionMissing = true;
      _scheduleCloseIfCurrent();
    }
  }

  @override
  void dispose() {
    widget.repository.removeListener(_handleRepositoryChange);
    super.dispose();
  }

  void _handleRepositoryChange() {
    if (!mounted) return;
    final missing = _currentSession == null;
    if (missing) {
      setState(() => _sessionMissing = true);
      _scheduleCloseIfCurrent();
      return;
    }
    setState(() => _sessionMissing = false);
  }

  void _scheduleCloseIfCurrent() {
    if (_closeScheduled) return;
    _closeScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _closeScheduled = false;
      if (!mounted || !_sessionMissing || _currentSession != null) return;
      if (ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop();
      }
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final data = _data;
    return Material(
      key: const Key('demo-role-preview-sheet'),
      color: colors.surface,
      clipBehavior: Clip.antiAlias,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
      child: CustomScrollView(
        key: ValueKey('demo-role-preview-scroll-$_roleId'),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.paddingOf(context).bottom + 28,
            ),
            sliver: SliverList.list(
              children: [
                _summary(context, data),
                const SizedBox(height: 20),
                _overview(
                  context,
                  key: const Key('demo-role-preview-overview-expression'),
                  title: AppLocalizations.of(context)!.roleStyle,
                  value: data.expressionStyle,
                ),
                _overview(
                  context,
                  key: const Key('demo-role-preview-overview-audience'),
                  title: AppLocalizations.of(context)!.roleAudience,
                  value: data.targetAudience,
                ),
                _overview(
                  context,
                  key: const Key('demo-role-preview-overview-tags'),
                  title: AppLocalizations.of(context)!.roleTags,
                  value: data.contentTags,
                ),
                _instructions(context, data),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summary(BuildContext context, DemoRolePreviewData data) {
    final l = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final light = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: light
            ? AppColors.brand.withValues(alpha: .05)
            : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Row(
              children: [
                _avatar(context),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              data.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                height: 1.25,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (widget.roleIds.length > 1) ...[
                            const SizedBox(width: 6),
                            Text(
                              '${_index + 1}/${widget.roleIds.length}',
                              key: const Key('demo-role-preview-page'),
                              style: TextStyle(
                                fontSize: 14,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            _pageButton(
                              key: const Key('demo-role-preview-previous'),
                              tooltip: l.rolePreviousProfile,
                              icon: Icons.chevron_left,
                              onPressed: _index == 0
                                  ? null
                                  : () => _selectRole(_index - 1),
                            ),
                            _pageButton(
                              key: const Key('demo-role-preview-next'),
                              tooltip: l.roleNextProfile,
                              icon: Icons.chevron_right,
                              onPressed: _index == widget.roleIds.length - 1
                                  ? null
                                  : () => _selectRole(_index + 1),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data.isReady
                            ? l.roleProfileReady
                            : l.roleProfilePending,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.25,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      if (data.contentTags.isNotEmpty)
                        Text(
                          data.contentTags,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.25,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_canEdit(_roleId)) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const Key('demo-role-preview-edit'),
                onPressed: _requestEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(l.demoRolePreviewEdit),
              ),
            ),
          ],
          const SizedBox(height: 8),
          _reference(context, data),
          if (data.missingReferenceCount > 0) ...[
            const SizedBox(height: 8),
            Text(
              l.demoRolePreviewMissingReferences(data.missingReferenceCount),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pageButton({
    required Key key,
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
  }) => IconButton(
    key: key,
    tooltip: tooltip,
    constraints: const BoxConstraints.tightFor(width: 36, height: 36),
    padding: EdgeInsets.zero,
    visualDensity: VisualDensity.compact,
    onPressed: onPressed,
    icon: Icon(icon, size: 20),
  );

  Widget _avatar(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget image;
    final businessAvatar =
        widget.repository.libraryRole(_roleId)?['avatarUrl']?.toString() ?? '';
    final bundledAvatar = _bundledAvatar;
    if (widget.repository.usesBusinessLibrary && businessAvatar.isNotEmpty) {
      image = DemoRoleImage(
        repository: widget.repository,
        source: businessAvatar,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _avatarPlaceholder(colors),
      );
    } else if (!widget.repository.usesBusinessLibrary &&
        bundledAvatar != null) {
      image = Image.asset(
        bundledAvatar,
        fit: BoxFit.cover,
        cacheWidth: 192,
        errorBuilder: (_, __, ___) => _avatarPlaceholder(colors),
      );
    } else {
      // Unknown custom roles do not borrow a reference sheet (or Alice) as an
      // identity avatar. Their reference images remain in the gallery below.
      image = _avatarPlaceholder(colors);
    }
    return Container(
      key: const Key('demo-role-preview-avatar'),
      width: 70,
      height: 70,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: ColoredBox(color: colors.surface, child: image),
      ),
    );
  }

  Widget _avatarPlaceholder(ColorScheme colors) => ColoredBox(
    color: colors.surfaceContainerHighest,
    child: Icon(Icons.person_outline, size: 32, color: colors.onSurfaceVariant),
  );

  Widget _reference(BuildContext context, DemoRolePreviewData data) {
    final l = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    if (data.references.isEmpty) {
      return AspectRatio(
        key: const Key('demo-role-preview-reference-empty'),
        aspectRatio: 16 / 9,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image_not_supported_outlined,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(height: 8),
              Text(
                l.demoRolePreviewNoReferences,
                style: TextStyle(fontSize: 14, color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }
    final reference = data.references.first;
    final image = _referenceImage(context, reference);
    return Semantics(
      button: true,
      label: l.chatPreviewImage,
      child: GestureDetector(
        key: const Key('demo-role-preview-reference'),
        onTap: () => _showReferences(data),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: ColoredBox(
                  color: colors.surface,
                  child: Center(child: image),
                ),
              ),
            ),
            if (data.references.length > 1)
              Positioned(
                right: 10,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: colors.inverseSurface.withValues(alpha: .78),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    l.demoRolePreviewReferenceCount(data.references.length),
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onInverseSurface,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _referenceImage(
    BuildContext context,
    DemoRolePreviewReference reference,
  ) {
    final colors = Theme.of(context).colorScheme;
    Widget placeholder() => Center(
      child: Icon(Icons.broken_image_outlined, color: colors.onSurfaceVariant),
    );
    if (reference.asset case final asset?) {
      return DemoAssetImage(
        asset: asset,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.contain,
        cacheWidth: 1280,
      );
    }
    final bundledReference = DemoWebsiteCharacterCatalog.bundledReferenceImage(
      reference.url!,
    );
    if (bundledReference != null) {
      final viewportWidth = MediaQuery.sizeOf(context).width.clamp(1.0, 640.0);
      return Image.asset(
        bundledReference,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.contain,
        cacheWidth: (viewportWidth * MediaQuery.devicePixelRatioOf(context))
            .ceil(),
        errorBuilder: (_, __, ___) => placeholder(),
      );
    }
    return DemoRoleImage(
      repository: widget.repository,
      source: reference.url!,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.contain,
      loadingBuilder: (_, child, progress) => progress == null
          ? child
          : const Center(
              child: SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
      errorBuilder: (_, __, ___) => placeholder(),
    );
  }

  Widget _overview(
    BuildContext context, {
    required Key key,
    required String title,
    required String value,
  }) {
    final colors = Theme.of(context).colorScheme;
    final display = value.trim().isEmpty
        ? AppLocalizations.of(context)!.demoNotConfigured
        : value;
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              height: 1.25,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            display,
            style: TextStyle(
              fontSize: 16,
              height: 1.45,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _instructions(BuildContext context, DemoRolePreviewData data) {
    final l = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: AppColors.brand.withValues(alpha: .08)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            expanded: _instructionsExpanded,
            child: TextButton(
              key: const Key('demo-role-preview-instructions-toggle'),
              onPressed: () => setState(
                () => _instructionsExpanded = !_instructionsExpanded,
              ),
              style: TextButton.styleFrom(
                foregroundColor: colors.onSurface,
                minimumSize: const Size.fromHeight(60),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _instructionsExpanded
                          ? l.demoRolePreviewCollapseInstructions
                          : l.demoRolePreviewFullInstructions,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _instructionsExpanded ? .5 : 0,
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 180),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      size: 22,
                      color: AppColors.brand,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_instructionsExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: SelectableText(
                data.instructions.trim().isEmpty
                    ? l.demoNotConfigured
                    : data.instructions,
                key: const Key('demo-role-preview-instructions'),
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _selectRole(int index) {
    if (index < 0 || index >= widget.roleIds.length || index == _index) return;
    setState(() {
      _index = index;
      _instructionsExpanded = false;
    });
  }

  Future<void> _showReferences(DemoRolePreviewData data) async {
    await AppMediaGallery.show(
      context: context,
      items: [
        for (final reference in data.references)
          ImagePreviewItem(
            image: _referenceProvider(context, reference),
            heroTag: 'demo-role-preview-$_roleId-${reference.key}',
            label: data.name,
          ),
      ],
    );
    if (!mounted || !_sessionMissing) return;
    _scheduleCloseIfCurrent();
  }

  void _requestEdit() {
    if (!_canEdit(_roleId)) return;
    Navigator.of(context).pop(_roleId);
  }

  ImageProvider _referenceProvider(
    BuildContext context,
    DemoRolePreviewReference reference,
  ) {
    if (reference.asset != null) {
      return demoAssetImageProviderForContext(context, reference.asset!);
    }
    final bundledReference = DemoWebsiteCharacterCatalog.bundledReferenceImage(
      reference.url!,
    );
    return bundledReference == null
        ? roleImageProvider(context, widget.repository, reference.url!)
        : AssetImage(bundledReference);
  }
}
