import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_network_image.dart';
import '../../../../shared/widgets/app_skeleton.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../data/session_repository.dart';
import '../../domain/conversation_generation.dart';
import 'conversation_timeline.dart' show conversationErrorText;

/// Keeps style choices local until the sheet's confirmation action.
class ConversationStyleLibrarySheet extends StatefulWidget {
  const ConversationStyleLibrarySheet({
    required this.repository,
    this.selectedId,
    super.key,
  });

  final SessionRepository repository;
  final String? selectedId;

  static const shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(45)),
  );

  @override
  State<ConversationStyleLibrarySheet> createState() =>
      _ConversationStyleLibrarySheetState();
}

class _ConversationStyleLibrarySheetState
    extends State<ConversationStyleLibrarySheet> {
  static const _unrestricted = ConversationRoleTemplate(id: '', title: '');
  final _token = CancelToken();
  final _scroll = ScrollController();
  late String _selectedId = widget.selectedId ?? '';
  List<ConversationRoleTemplate>? _templates;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final templates = await widget.repository.roleTemplates(
        cancelToken: _token,
      );
      if (mounted && !_token.isCancelled) {
        setState(() => _templates = [...templates, _unrestricted]);
      }
    } catch (error) {
      if (!mounted || _token.isCancelled) return;
      AppToast.error(
        context,
        conversationErrorText(error, AppLocalizations.of(context)!),
      );
      setState(() => _templates = const [_unrestricted]);
    }
  }

  @override
  void dispose() {
    _token.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final selection = _templates
        ?.where((template) => template.id == _selectedId)
        .firstOrNull;
    return Padding(
      key: const Key('conversation-style-library'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        minimum: const EdgeInsets.only(bottom: 20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns =
                ((constraints.maxWidth + 10) /
                        (80 * (scaler.scale(12) / 12) + 10))
                    .floor()
                    .clamp(2, 4);
            final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
            final twoLines = width < 90 || scaler.scale(12) > 14.4;
            final labelHeight = scaler.scale(twoLines ? 30 : 15);
            final extent = width - 20 + 5 + labelHeight + 25;
            final count = _templates?.length ?? 8;
            final rows = (count / columns).ceil();
            final gridHeight = rows * extent + math.max(0, rows - 1) * 10;
            Widget grid = GridView.builder(
              key: const Key('conversation-style-grid'),
              controller: _scroll,
              padding: EdgeInsets.zero,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                mainAxisExtent: extent,
              ),
              itemCount: count,
              itemBuilder: (context, index) {
                final template = _templates?[index];
                if (template == null) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 15),
                    child: Column(
                      children: [
                        AppSkeletonBox(
                          width: width - 20,
                          height: width - 20,
                          radius: 20,
                        ),
                        const SizedBox(height: 5),
                        AppSkeletonBox(height: labelHeight),
                      ],
                    ),
                  );
                }
                return _StyleTile(
                  template: template,
                  selected: template.id == _selectedId,
                  imageSize: width - 20,
                  labelHeight: labelHeight,
                  maxLines: twoLines ? 2 : 1,
                  onPressed: () => setState(() => _selectedId = template.id),
                );
              },
            );
            if (_templates == null) {
              grid = AppSkeleton(label: l10n.loadingAssets, child: grid);
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.chatStyleLibrary,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                Flexible(
                  child: SizedBox(height: gridHeight, child: grid),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  key: const Key('conversation-style-confirm'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 15,
                    ),
                    textStyle: theme.textTheme.labelLarge?.copyWith(
                      fontSize: 16,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: selection == null
                      ? null
                      : () => Navigator.of(context).pop(selection),
                  child: Text(l10n.confirm),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StyleTile extends StatelessWidget {
  const _StyleTile({
    required this.template,
    required this.selected,
    required this.imageSize,
    required this.labelHeight,
    required this.maxLines,
    required this.onPressed,
  });

  final ConversationRoleTemplate template;
  final bool selected;
  final double imageSize;
  final double labelHeight;
  final int maxLines;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = template.id.isEmpty
        ? AppLocalizations.of(context)!.chatStyleUnrestricted
        : template.title;
    final unavailable = ColoredBox(
      color: theme.colorScheme.surfaceContainerLow,
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
    final image = template.id.isEmpty
        ? Image.asset(
            'assets/images/style_unrestricted.png',
            width: imageSize,
            height: imageSize,
            fit: BoxFit.cover,
          )
        : template.coverUrl.isEmpty
        ? unavailable
        : AppNetworkImage(
            template.coverUrl,
            width: imageSize,
            height: imageSize,
            fit: BoxFit.cover,
            loadingBuilder: (_, child, progress) => progress == null
                ? child
                : AppSkeletonBox(
                    width: imageSize,
                    height: imageSize,
                    radius: 20,
                  ),
            errorBuilder: (_, __, ___) => unavailable,
          );
    return Semantics(
      selected: selected,
      child: Tooltip(
        message: title,
        child: TextButton(
          key: ValueKey('role-template:${template.id}'),
          onPressed: onPressed,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 15),
            minimumSize: Size.zero,
            backgroundColor: selected
                ? theme.colorScheme.primary.withValues(alpha: .05)
                : Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.card),
            ),
          ),
          child: Column(
            children: [
              SizedBox.square(
                dimension: imageSize,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  child: image,
                ),
              ),
              const SizedBox(height: 5),
              SizedBox(
                height: labelHeight,
                width: double.infinity,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontSize: 12,
                    height: 1.25,
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
