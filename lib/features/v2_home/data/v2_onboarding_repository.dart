import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../ip_accounts/domain/account_preferences.dart';
import '../../ip_guide/data/ip_guide_repository.dart';
import '../../ip_guide/domain/ip_guide_draft.dart';
import '../../ip_guide/presentation/ip_guide_copy.dart';
import '../../v2_shared/data/v2_repository.dart';

/// Saves guide choices locally and creates one configured session on confirmation.
class V2OnboardingRepository extends IpGuideDraftRepository {
  V2OnboardingRepository(
    super.storage,
    this._sessions,
    this._l10n, {
    required String userId,
  }) : _userId = userId,
       super(userId: userId, namespace: 'v2_onboarding_draft_v1');

  final V2Repository _sessions;
  final AppLocalizations _l10n;
  final String _userId;
  bool _disposed = false;

  @override
  void dispose() => _disposed = true;

  @override
  Future<List<AccountPreferenceStep>> preferenceOptions({
    CancelToken? cancelToken,
  }) async => [
    _step(
      'contentDirections',
      _l10n.ipContentDirection,
      IpContentDirection.values.map((value) => directionLabel(value, _l10n)),
    ),
    _step(
      'audienceFeelings',
      _l10n.ipAudienceFeeling,
      IpAudienceFeeling.values.map((value) => feelingLabel(value, _l10n)),
      descriptions: IpAudienceFeeling.values.map(
        (value) => feelingDescription(value, _l10n),
      ),
    ),
    _step(
      'presentationFormats',
      _l10n.ipPresentation,
      IpPresentation.values.map((value) => presentationLabel(value, _l10n)),
      maxSelections: 1,
    ),
    _step(
      'targetAudience',
      _l10n.ipTargetAudience,
      IpTargetAudience.values.map((value) => audienceLabel(value, _l10n)),
      descriptions: IpTargetAudience.values.map(
        (value) => audienceDescription(value, _l10n),
      ),
    ),
  ];

  AccountPreferenceStep _step(
    String key,
    String title,
    Iterable<String> labels, {
    Iterable<String>? descriptions,
    int maxSelections = 2,
  }) {
    final names = labels.toList();
    final copy = descriptions?.toList();
    return AccountPreferenceStep(
      key: key,
      title: title,
      required: true,
      maxSelections: maxSelections,
      options: [
        for (var i = 0; i < names.length; i++)
          AccountPreferenceOption(name: names[i], description: copy?[i] ?? ''),
      ],
    );
  }

  @override
  Future<String> create(
    IpGuideDraft draft,
    Map<String, Object?> profile,
  ) async {
    if (_disposed) throw StateError('Onboarding owner changed');
    draft.sessionRequestId ??= const Uuid().v4();
    await save(draft);
    if (_disposed) throw StateError('Onboarding owner changed');
    return _sessions.completeOnboarding(
      userId: _userId,
      requestId: draft.sessionRequestId!,
      title: draft.nickname,
      profile: profile,
    );
  }
}
