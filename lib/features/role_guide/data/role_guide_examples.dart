import '../../../l10n/generated/app_localizations.dart';
import '../../assets/domain/library_role.dart';

/// Figma fixtures for previews and tests; live role lists use the role repository.
List<LibraryRole> roleGuideExamples(AppLocalizations l10n) {
  final names = [
    l10n.roleExampleAlice,
    l10n.roleExampleErer,
    l10n.roleExampleHua,
    l10n.roleExampleDoudou,
    l10n.roleExampleConfused,
    l10n.roleExampleStrawberry,
    l10n.roleExampleQiqi,
    l10n.roleExampleMermaid,
  ];
  return [
    for (var i = 0; i < names.length; i++)
      LibraryRole(
        id: 'preview-role-${i + 1}',
        title: names[i],
        description: l10n.roleExampleDescription,
        avatar: 'assets/images/role_guide_avatar_${i + 1}.png',
        canCreate: true,
        profileComplete: true,
      ),
  ];
}

typedef RoleGuideStory = ({
  String title,
  String summary,
  String development,
  String content,
});

/// Local story suggestions until a recommendation repository is available.
List<RoleGuideStory> roleGuideStories(AppLocalizations l10n, int batch) =>
    batch == 0
    ? [
        (
          title: l10n.roleExampleStoryTitle1,
          summary: l10n.roleExampleStory1,
          development: l10n.roleExampleDevelopment1,
          content: l10n.roleExampleContent1,
        ),
        (
          title: l10n.roleExampleStoryTitle2,
          summary: l10n.roleExampleStory2,
          development: l10n.roleExampleDevelopment2,
          content: l10n.roleExampleContent2,
        ),
        (
          title: l10n.roleExampleStoryTitle3,
          summary: l10n.roleExampleStory3,
          development: l10n.roleExampleDevelopment3,
          content: l10n.roleExampleContent3,
        ),
      ]
    : [
        (
          title: l10n.roleExampleStoryTitle4,
          summary: l10n.roleExampleStory4,
          development: l10n.roleExampleDevelopment4,
          content: l10n.roleExampleContent4,
        ),
        (
          title: l10n.roleExampleStoryTitle5,
          summary: l10n.roleExampleStory5,
          development: l10n.roleExampleDevelopment5,
          content: l10n.roleExampleContent5,
        ),
        (
          title: l10n.roleExampleStoryTitle6,
          summary: l10n.roleExampleStory6,
          development: l10n.roleExampleDevelopment6,
          content: l10n.roleExampleContent6,
        ),
      ];
