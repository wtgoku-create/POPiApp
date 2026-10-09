import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../core/network/network_api.dart';
import '../../../../shared/providers/network_provider.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_svg_icon.dart';
import '../../../assets/data/role_library_repository.dart';
import '../../../assets/domain/library_role.dart';
import 'role_guide_controls.dart';

/// Both the compact grid and full library use the existing paginated role API.
class RoleGuidePicker extends ConsumerStatefulWidget {
  const RoleGuidePicker({
    required this.selected,
    required this.onToggle,
    required this.onDetails,
    required this.onCreate,
    required this.onCategoryChanged,
    this.initialCategory = 'official',
    this.fullLibrary = false,
    this.scrollController,
    this.onMore,
    super.key,
  });

  final List<LibraryRole> Function() selected;
  final ValueChanged<LibraryRole> onToggle;
  final ValueChanged<LibraryRole> onDetails;
  final VoidCallback onCreate;
  final ValueChanged<String> onCategoryChanged;
  final String initialCategory;
  final bool fullLibrary;
  final ScrollController? scrollController;
  final VoidCallback? onMore;

  @override
  ConsumerState<RoleGuidePicker> createState() => _RoleGuidePickerState();
}

class _RoleGuidePickerState extends ConsumerState<RoleGuidePicker> {
  late final RoleLibraryRepository _repository;
  late String _category;
  final _roles = <LibraryRole>[];
  bool _loading = true;
  bool _failed = false;
  bool _hasMore = false;
  int _page = 0;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _repository = RoleLibraryRepository(NetworkApi(ref.read(dioProvider)));
    _category = widget.initialCategory;
    _load();
  }

  @override
  void didUpdateWidget(RoleGuidePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCategory != oldWidget.initialCategory &&
        widget.initialCategory != _category) {
      _changeCategory(widget.initialCategory, notify: false);
    }
  }

  void _changeCategory(String category, {bool notify = true}) {
    if (_category == category) return;
    _generation++;
    setState(() {
      _category = category;
      _roles.clear();
      _page = 0;
      _loading = false;
      _hasMore = false;
    });
    if (notify) widget.onCategoryChanged(category);
    _load();
  }

  Future<void> _load() async {
    if (_loading && _page > 0) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final result = await _repository.fetchPage(
        category: _category,
        page: _page + 1,
        pageSize: 20,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        final ids = _roles.map((role) => role.id).toSet();
        _roles.addAll(result.items.where((role) => ids.add(role.id)));
        _page = result.page;
        _hasMore = result.hasMore;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _failed = true);
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final controls = LayoutBuilder(
      builder: (context, constraints) {
        double labelWidth(String label) {
          final painter = TextPainter(
            text: TextSpan(
              text: label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            locale: Localizations.localeOf(context),
          )..layout();
          final width = painter.width;
          painter.dispose();
          return width;
        }

        // Reserve intrinsic label widths before choosing a compact row.
        final createWidth = labelWidth(l10n.createNewRole) + 20 + 5 + 36;
        final categoryLabelWidth = labelWidth(
          l10n.officialRoles,
        ).clamp(labelWidth(l10n.myRoles), double.infinity);
        final categoriesWidth = (categoryLabelWidth + 14) * 2 + 6;
        final categories = RoleGuideSegments(
          labels: [l10n.officialRoles, l10n.myRoles],
          selected: _category == 'official' ? 0 : 1,
          filledTrack: !widget.fullLibrary,
          onSelected: (i) => _changeCategory(i == 0 ? 'official' : 'personal'),
        );
        final create = TextButton(
          key: const Key('role-guide-create-role'),
          onPressed: widget.onCreate,
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.standard,
            backgroundColor: AppColors.brand.withValues(alpha: .1),
            foregroundColor: AppColors.brand,
            minimumSize: const Size(117, 40),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(fontSize: 14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 20,
                height: 20,
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const AppSvgIcon.asset('role_guide_add'),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  l10n.createNewRole,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
        if (constraints.maxWidth < createWidth + categoriesWidth + 5) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              categories,
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerRight, child: create),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: categories),
            const SizedBox(width: 5),
            create,
          ],
        );
      },
    );
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_roles.isNotEmpty)
          if (widget.fullLibrary)
            Column(
              children: [
                for (final role in _roles)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _row(role),
                  ),
              ],
            )
          else
            RoleGuideGrid(
              roles: _roles.take(8).toList(),
              selected: widget.selected(),
              onToggle: _toggle,
              onDetails: widget.onDetails,
              onMore: widget.onMore,
            ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_failed)
          TextButton(
            key: const Key('role-guide-retry'),
            onPressed: _load,
            child: Text(l10n.retryLoadingRoles),
          )
        else if (_roles.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 45),
            child: Text(
              _category == 'official' ? l10n.noOfficialRoles : l10n.noMyRoles,
              textAlign: TextAlign.center,
            ),
          )
        else if (widget.fullLibrary && _hasMore)
          TextButton(
            key: const Key('role-guide-load-more'),
            onPressed: _load,
            child: Text(l10n.roleGuideViewMore),
          ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.fullLibrary)
          Padding(
            key: const Key('role-guide-library-controls'),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: controls,
          )
        else
          controls,
        const SizedBox(height: 20),
        if (widget.fullLibrary)
          Expanded(
            child: SingleChildScrollView(
              key: const Key('role-guide-library-scroll'),
              controller: widget.scrollController,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: content,
            ),
          )
        else
          content,
      ],
    );
  }

  void _toggle(LibraryRole role) {
    widget.onToggle(role);
    setState(() {});
  }

  Widget _row(LibraryRole role) {
    final order =
        widget.selected().indexWhere((item) => item.id == role.id) + 1;
    return Semantics(
      selected: order > 0,
      button: true,
      child: Material(
        color: order > 0 ? roleGuideTint(context) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          key: Key('role-library-select-${role.id}'),
          onTap: () => _toggle(role),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RoleGuideAvatar(role: role, size: 70),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          role.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          role.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                RoleSelectionBadge(order: order),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Character thumbnails separate selection taps from the profile command.
class RoleGuideGrid extends StatelessWidget {
  const RoleGuideGrid({
    required this.roles,
    required this.selected,
    required this.onToggle,
    required this.onDetails,
    this.onMore,
    super.key,
  });

  final List<LibraryRole> roles;
  final List<LibraryRole> selected;
  final ValueChanged<LibraryRole> onToggle;
  final ValueChanged<LibraryRole> onDetails;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth < 270 ? 2 : 3;
      final width = (constraints.maxWidth - 15 * (columns - 1)) / columns;
      return Wrap(
        spacing: 15,
        runSpacing: 15,
        children: [
          for (final role in roles)
            SizedBox(width: width, child: _tile(context, role, width)),
          if (onMore != null)
            SizedBox(
              width: width,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: Material(
                        color: AppColors.brand.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          key: const Key('role-guide-more'),
                          onTap: onMore,
                          borderRadius: BorderRadius.circular(20),
                          child: const Center(
                            child: SizedBox(
                              width: 42,
                              height: 45,
                              child: AppSvgIcon.asset('role_guide_library'),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _name(
                      context,
                      AppLocalizations.of(context)!.roleGuideViewMore,
                      onMore!,
                      'more',
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );

  Widget _tile(BuildContext context, LibraryRole role, double width) {
    final order = selected.indexWhere((item) => item.id == role.id) + 1;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: order > 0 ? roleGuideTint(context) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                Semantics(
                  label: role.title,
                  selected: order > 0,
                  button: true,
                  child: GestureDetector(
                    key: Key('role-guide-select-${role.id}'),
                    onTap: () => onToggle(role),
                    child: RoleGuideAvatar(role: role, size: width - 20),
                  ),
                ),
                const SizedBox(height: 10),
                _name(context, role.title, () => onDetails(role), role.id),
              ],
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: SizedBox.square(
              dimension: 40,
              child: IconButton(
                key: Key('role-guide-check-${role.id}'),
                tooltip: role.title,
                onPressed: () => onToggle(role),
                padding: const EdgeInsets.all(10),
                icon: RoleSelectionBadge(order: order),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _name(
    BuildContext context,
    String name,
    VoidCallback onTap,
    String id,
  ) => InkWell(
    key: Key('role-guide-details-$id'),
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 18),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 14,
                height: 18 / 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 2),
          SizedBox(
            width: 5,
            height: 10,
            child: AppSvgIcon.asset(
              'role_guide_chevron',
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}
