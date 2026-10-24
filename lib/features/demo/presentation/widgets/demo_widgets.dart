import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/type/bot_avatar_type.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/app_bot_avatar.dart';
import '../../../../shared/widgets/app_sheet.dart';
import '../../../../shared/widgets/app_svg_icon.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../data/demo_fixtures.dart';
import 'demo_frosted_backdrop.dart';

const demoBackground = AppColors.profileBackground;
const demoTint = Color(0x0D6F47F5);

Color demoSurface(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? Theme.of(context).colorScheme.surfaceContainer
    : Colors.white.withValues(alpha: .5);

String demoMemberName(AppLocalizations l, String id) => switch (id) {
  'designer' => l.demoDesigner,
  'writer' => l.demoWriter,
  'director' => l.demoDirector,
  'sound' => l.demoSound,
  _ => l.demoPopi,
};
String demoMemberDescription(AppLocalizations l, String id) => switch (id) {
  'designer' => l.demoDesignerDescription,
  'writer' => l.demoWriterDescription,
  'director' => l.demoDirectorDescription,
  'sound' => l.demoSoundDescription,
  _ => l.demoPopiDescription,
};

class DemoIcon extends StatelessWidget {
  const DemoIcon(this.name, {this.size = 22, this.color, super.key});
  final String name;
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) => AppSvgIcon.asset(
    'demo_$name',
    size: size,
    color: color ?? Theme.of(context).colorScheme.onSurface,
  );
}

class DemoAvatar extends StatelessWidget {
  const DemoAvatar({
    this.members = const ['popi'],
    this.size = 70,
    this.image,
    this.background,
    this.memberAvatars = const {},
    this.memberColors = const {},
    super.key,
  });
  final List<String> members;
  final double size;
  final String? image;
  final Color? background;
  final Map<String, String> memberAvatars;
  final Map<String, int> memberColors;
  @override
  Widget build(BuildContext context) {
    Widget avatar(String path, double dimension, [Color? color]) {
      final resolvedPath = DemoFixtures.normalizeAvatarAsset(path);
      final character = BotAvatarCharacter.fromStillAsset(resolvedPath);
      return Container(
        width: dimension,
        height: dimension,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color ?? background ?? Colors.white,
          border: Border.all(
            color: Theme.of(context).scaffoldBackgroundColor,
            width: 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: character != null
            ? AppBotAvatar(character: character, size: dimension)
            : Image.asset(
                resolvedPath,
                fit: BoxFit.cover,
                cacheWidth: (dimension * 3).ceil(),
              ),
      );
    }

    if (image != null) return avatar(image!, size);
    final images = (members.isEmpty ? ['popi'] : members)
        .take(4)
        .map((m) => DemoFixtures.memberImage(m, savedImage: memberAvatars[m]))
        .toList();
    Color? memberColor(int i) {
      final ids = members.isEmpty ? ['popi'] : members;
      final value = memberColors[ids[i]];
      return value == null ? null : Color(value);
    }

    if (images.length == 1) return avatar(images.first, size, memberColor(0));
    final small = size * (images.length == 2 ? .66 : .6);
    final positions = images.length == 2
        ? [Offset.zero, Offset(size - small, size - small)]
        : images.length == 3
        ? [
            Offset((size - small) / 2, 0),
            Offset(0, size - small),
            Offset(size - small, size - small),
          ]
        : [
            Offset.zero,
            Offset(size - small, 0),
            Offset(0, size - small),
            Offset(size - small, size - small),
          ];
    return SizedBox.square(
      dimension: size,
      child: Stack(
        children: [
          for (var i = 0; i < images.length; i++)
            Positioned(
              left: positions[i].dx,
              top: positions[i].dy,
              child: avatar(images[i], small, memberColor(i)),
            ),
        ],
      ),
    );
  }
}

class DemoScaffold extends StatelessWidget {
  const DemoScaffold({
    this.title,
    this.appBar,
    required this.child,
    this.actions,
    this.leading,
    this.leadingWidth,
    this.bottom,
    this.floatingBottom = false,
    this.extendBodyBehindAppBar = false,
    this.frostedBottom = true,
    this.actionsPadding = 12,
    this.maxContentWidth = 640,
    this.backgroundColor,
    super.key,
  });
  final Widget? title;
  final PreferredSizeWidget? appBar;
  final Widget child;
  final List<Widget>? actions;
  final Widget? leading;
  final double? leadingWidth;
  final Widget? bottom;
  final bool floatingBottom;
  final bool extendBodyBehindAppBar;
  final bool frostedBottom;
  final double actionsPadding;
  final double maxContentWidth;
  final Color? backgroundColor;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: backgroundColor,
    extendBody: floatingBottom,
    extendBodyBehindAppBar: extendBodyBehindAppBar,
    appBar:
        appBar ??
        AppBar(
          leadingWidth: leadingWidth,
          centerTitle: true,
          title: title,
          titleTextStyle: Theme.of(context).textTheme.titleMedium!.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          leading:
              leading ??
              (Navigator.of(context).canPop()
                  ? IconButton(
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).backButtonTooltip,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const RotatedBox(
                        quarterTurns: 1,
                        child: DemoIcon('back', size: 40),
                      ),
                    )
                  : null),
          actions: actions == null
              ? null
              : [...actions!, SizedBox(width: actionsPadding)],
        ),
    body: SafeArea(
      top: false,
      bottom: bottom == null,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: child,
        ),
      ),
    ),
    bottomNavigationBar: floatingBottom && bottom != null
        ? frostedBottom
              ? DemoBottomOverlay(child: bottom!)
              : ColoredBox(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: bottom!,
                )
        : bottom,
  );
}

/// A continuous mask fades the backdrop into the floating controls.
class DemoBottomOverlay extends StatelessWidget {
  const DemoBottomOverlay({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(child: IgnorePointer(child: DemoFrostedBackdrop())),
      Padding(padding: const EdgeInsets.only(top: 20), child: child),
    ],
  );
}

class DemoSegments extends StatelessWidget {
  const DemoSegments({
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.height = 34,
    this.selectedFontWeight = FontWeight.w600,
    this.unselectedColor,
    super.key,
  });
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;
  final double height;
  final FontWeight selectedFontWeight;
  final Color? unselectedColor;
  @override
  Widget build(BuildContext context) => Container(
    height: height,
    padding: const EdgeInsets.all(3),
    decoration: const ShapeDecoration(color: demoTint, shape: StadiumBorder()),
    child: Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Semantics(
              selected: i == selected,
              child: TextButton(
                onPressed: () => onChanged(i),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  foregroundColor: selected == i
                      ? Theme.of(context).colorScheme.onSurface
                      : unselectedColor ?? AppColors.textTertiary,
                  backgroundColor: selected == i
                      ? Theme.of(context).colorScheme.surface
                      : Colors.transparent,
                  shape: const StadiumBorder(),
                  textStyle: Theme.of(context).textTheme.labelLarge!.copyWith(
                    fontSize: 14,
                    fontWeight: selected == i
                        ? selectedFontWeight
                        : FontWeight.w400,
                  ),
                ),
                child: Text(
                  labels[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class DemoSearch extends StatelessWidget {
  const DemoSearch({
    required this.hint,
    required this.onChanged,
    this.controller,
    this.height = 42,
    this.outlined = false,
    super.key,
  });
  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  final double height;
  final bool outlined;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: outlined ? const TextStyle(fontSize: 14) : null,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF9994A6)),
        fillColor: outlined ? demoSurface(context) : null,
        prefixIconConstraints: outlined
            ? BoxConstraints(minWidth: 38, minHeight: height)
            : null,
        prefixIcon: Padding(
          padding: outlined
              ? const EdgeInsets.fromLTRB(12, 12, 8, 12)
              : const EdgeInsets.all(12),
          child: DemoIcon(
            'search',
            size: 18,
            color: outlined ? const Color(0xFF9994A6) : null,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(outlined ? 18 : 16),
          borderSide: outlined
              ? BorderSide(color: Theme.of(context).colorScheme.surface)
              : BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(outlined ? 18 : 16),
          borderSide: outlined
              ? BorderSide(color: Theme.of(context).colorScheme.surface)
              : BorderSide.none,
        ),
      ),
    ),
  );
}

class DemoPrimaryButton extends StatelessWidget {
  const DemoPrimaryButton({
    required this.label,
    required this.onPressed,
    this.busy = false,
    super.key,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 44,
    child: FilledButton(
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
    ),
  );
}

/// The large selection sheets share the design's fixed heading and actions.
abstract final class DemoSheet {
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool enableDrag = true,
  }) {
    final top = MediaQuery.paddingOf(context).top + 60;
    return AppSheet.show<T>(
      context: context,
      useSafeArea: false,
      isScrollControlled: true,
      enableDrag: enableDrag,
      maxHeightFraction: 1,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height:
              (MediaQuery.sizeOf(context).height -
                      top -
                      MediaQuery.viewInsetsOf(context).bottom)
                  .clamp(200.0, double.infinity),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: ColoredBox(
                color: Theme.of(
                  context,
                ).colorScheme.surface.withValues(alpha: .9),
                child: builder(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DemoSheetBody extends StatelessWidget {
  const DemoSheetBody({
    required this.title,
    required this.child,
    this.footer,
    this.uploadLayout = false,
    super.key,
  });
  final String title;
  final Widget child;
  final Widget? footer;
  final bool uploadLayout;
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Padding(
        padding: uploadLayout
            ? const EdgeInsets.fromLTRB(18, 24, 18, 0)
            : const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: uploadLayout ? 22 : 16),
            Expanded(child: child),
          ],
        ),
      ),
      if (footer != null)
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: uploadLayout
              ? Padding(
                  padding: EdgeInsets.fromLTRB(
                    18,
                    16,
                    18,
                    MediaQuery.paddingOf(context).bottom.clamp(17, 40),
                  ),
                  child: footer!,
                )
              : DemoBottomOverlay(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      MediaQuery.paddingOf(context).bottom.clamp(20, 40),
                    ),
                    child: footer!,
                  ),
                ),
        ),
    ],
  );
}

class DemoSelectionMark extends StatelessWidget {
  const DemoSelectionMark({required this.selected, this.number, super.key});
  final bool selected;
  final int? number;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.brand : Colors.white,
        border: selected
            ? null
            : Border.all(color: const Color(0xFFECECEC), width: 4),
      ),
      child: !selected
          ? null
          : number == null
          ? const DemoIcon('check', size: 20, color: Colors.white)
          : Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  fontSize: 14,
                  height: 1,
                  color: Colors.white,
                ),
              ),
            ),
    ),
  );
}

class DemoPinnedHeader extends SliverPersistentHeaderDelegate {
  DemoPinnedHeader({required this.height, required this.child});
  final double height;
  final Widget child;
  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => SizedBox(
    height: height,
    child: ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: child,
    ),
  );
  @override
  bool shouldRebuild(DemoPinnedHeader oldDelegate) =>
      oldDelegate.height != height || oldDelegate.child != child;
}

Future<bool> demoPerform(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
    return true;
  } catch (error) {
    if (error is DioException && CancelToken.isCancel(error)) return false;
    if (context.mounted) {
      final l = AppLocalizations.of(context)!;
      AppToast.error(
        context,
        error is DioException || error is ApiException
            ? l.networkRequestFailed
            : l.demoStorageError,
      );
    }
    return false;
  }
}

Future<void> demoEditText(
  BuildContext context, {
  required String title,
  required String value,
  required Future<void> Function(String) onSave,
  bool multiline = false,
  String? label,
  int maxLength = 15,
}) => AppDialog.show<void>(
  context: context,
  builder: (_) => _EditDialog(
    title: title,
    value: value,
    onSave: onSave,
    multiline: multiline,
    label: label,
    maxLength: maxLength,
  ),
);

class _EditDialog extends StatefulWidget {
  const _EditDialog({
    required this.title,
    required this.value,
    required this.onSave,
    required this.multiline,
    required this.label,
    required this.maxLength,
  });
  final String title;
  final String value;
  final Future<void> Function(String) onSave;
  final bool multiline;
  final String? label;
  final int maxLength;
  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  late final _text = TextEditingController(text: widget.value);
  bool _busy = false;
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || _text.text.trim().isEmpty) return;
    setState(() => _busy = true);
    final saved = await demoPerform(
      context,
      () => widget.onSave(_text.text.trim()),
    );
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop();
    } else {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return PopScope(
      canPop: !_busy,
      child: AppDialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 25),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.label ?? l.demoSessionName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _text,
              autofocus: false,
              enabled: !_busy,
              minLines: widget.multiline ? 3 : 1,
              maxLines: widget.multiline ? 7 : 1,
              maxLength: widget.multiline ? 1000 : widget.maxLength,
              style: const TextStyle(fontSize: 18),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _save(),
              decoration: InputDecoration(
                counterText: '',
                filled: true,
                fillColor: demoTint,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: widget.multiline
                    ? null
                    : Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Center(
                          widthFactor: 1,
                          child: Text(
                            '${_text.text.characters.length}/${widget.maxLength}',
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 25),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: demoTint,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onSurface,
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Text(l.cancel),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DemoPrimaryButton(
                    label: l.confirm,
                    busy: _busy,
                    onPressed: _text.text.trim().isEmpty ? null : _save,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
