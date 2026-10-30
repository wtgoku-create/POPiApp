import '../../../l10n/generated/app_localizations.dart';
import '../domain/demo_assistant_identity.dart';
import '../domain/demo_models.dart';
import 'widgets/demo_widgets.dart' show demoMemberName;

/// Resolves an assistant's given name consistently across all chat surfaces.
String demoSessionMemberName(
  AppLocalizations localizations,
  DemoSession session,
  String memberId, {
  String? snapshotName,
}) =>
    DemoAssistantIdentity.givenName(
      session,
      memberId,
      snapshotName: snapshotName,
    ) ??
    demoMemberName(localizations, memberId);

/// Single-assistant conversations are identified by the assistant's given name.
String demoSessionDisplayName(
  AppLocalizations localizations,
  DemoSession session,
) {
  if (session.members.length <= 1) {
    return demoSessionMemberName(
      localizations,
      session,
      DemoAssistantIdentity.primaryMemberId(session),
    );
  }
  final title = session.title.trim();
  return title.isNotEmpty
      ? title
      : localizations.demoBotGroupTitle(session.members.length);
}
