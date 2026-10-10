import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/network_api.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/providers/network_provider.dart';
import '../../../assets/data/role_library_repository.dart';
import '../../../assets/domain/library_role.dart';
import '../../../assets/domain/role_profile_edit.dart';
import 'role_guide_controls.dart';
import 'role_guide_sheet.dart';

/// Loads profiles independently and preserves selection order while browsing.
class RoleProfileSheet extends ConsumerStatefulWidget {
  const RoleProfileSheet({
    required this.roles,
    required this.onFullProfile,
    super.key,
  });

  final List<LibraryRole> roles;
  final ValueChanged<LibraryRole> onFullProfile;

  @override
  ConsumerState<RoleProfileSheet> createState() => _RoleProfileSheetState();
}

class _RoleProfileSheetState extends ConsumerState<RoleProfileSheet> {
  final _profiles = <String, Future<LibraryRole>>{};
  int _index = 0;

  Future<LibraryRole> _profile(LibraryRole role) => _profiles.putIfAbsent(
    role.id,
    () => RoleLibraryRepository(
      NetworkApi(ref.read(dioProvider)),
    ).fetchDetail(role.id),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final role = widget.roles[_index];
    return RoleGuideSheet(
      key: const Key('role-guide-profile-sheet'),
      title: l10n.roleProfilePage(_index + 1, widget.roles.length),
      initialSize: .875,
      actions: [
        IconButton(
          key: const Key('role-profile-previous'),
          tooltip: l10n.rolePreviousProfile,
          onPressed: _index == 0 ? null : () => setState(() => _index--),
          icon: const Icon(Icons.chevron_left, size: 20),
        ),
        IconButton(
          key: const Key('role-profile-next'),
          tooltip: l10n.roleNextProfile,
          onPressed: _index == widget.roles.length - 1
              ? null
              : () => setState(() => _index++),
          icon: const Icon(Icons.chevron_right, size: 20),
        ),
      ],
      builder: (context, controller) => SingleChildScrollView(
        controller: controller,
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.paddingOf(context).bottom + 20,
        ),
        child: FutureBuilder<LibraryRole>(
          key: ValueKey(role.id),
          future: _profile(role),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: TextButton(
                  key: const Key('role-profile-retry'),
                  onPressed: () => setState(() => _profiles.remove(role.id)),
                  child: Text(l10n.retryLoadingRoles),
                ),
              );
            }
            final loaded = snapshot.data;
            if (loaded == null) {
              return const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final fields = RoleProfileEdit.fromRole(loaded).fields;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: roleGuideTint(context),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      RoleGuideAvatar(role: loaded, size: 70),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              loaded.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              loaded.profileComplete
                                  ? l10n.roleProfileReady
                                  : l10n.roleProfilePending,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (!fields.any(
                  (field) => field.type == RoleProfileFieldType.positioning,
                ))
                  RoleGuideTextSection(
                    title: l10n.rolePositioning,
                    text: loaded.description.isEmpty
                        ? l10n.roleFieldPending
                        : loaded.description,
                  ),
                for (final field in fields)
                  RoleGuideTextSection(
                    title: switch (field.type) {
                      RoleProfileFieldType.positioning => l10n.rolePositioning,
                      RoleProfileFieldType.style => l10n.roleStyle,
                      RoleProfileFieldType.audience => l10n.roleAudience,
                      RoleProfileFieldType.tags => l10n.roleTags,
                      RoleProfileFieldType.appearance => l10n.roleAppearance,
                      RoleProfileFieldType.boundaries => l10n.roleBoundaries,
                      RoleProfileFieldType.custom =>
                        field.label.isEmpty
                            ? field.profileDataKey!
                            : field.label,
                    },
                    text: field.text.isEmpty
                        ? l10n.roleFieldPending
                        : field.text,
                  ),
                OutlinedButton.icon(
                  key: const Key('role-guide-full-profile'),
                  onPressed: () => widget.onFullProfile(loaded),
                  label: Text(l10n.roleFullProfile),
                  icon: const Icon(Icons.chevron_right, size: 20),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class RoleGuideTextSection extends StatelessWidget {
  const RoleGuideTextSection({
    required this.title,
    required this.text,
    super.key,
  });
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 16,
            height: 1.4,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}
