import '../../../l10n/generated/app_localizations.dart';
import '../domain/ip_guide_draft.dart';

String directionLabel(IpContentDirection value, AppLocalizations l10n) =>
    switch (value) {
      IpContentDirection.campus => l10n.ipDirectionCampus,
      IpContentDirection.emotion => l10n.ipDirectionEmotion,
      IpContentDirection.growth => l10n.ipDirectionGrowth,
      IpContentDirection.career => l10n.ipDirectionCareer,
      IpContentDirection.family => l10n.ipDirectionFamily,
      IpContentDirection.humor => l10n.ipDirectionHumor,
      IpContentDirection.mystery => l10n.ipDirectionMystery,
      IpContentDirection.pets => l10n.ipDirectionPets,
      IpContentDirection.knowledge => l10n.ipDirectionKnowledge,
    };

String feelingLabel(IpAudienceFeeling value, AppLocalizations l10n) =>
    switch (value) {
      IpAudienceFeeling.authentic => l10n.ipFeelingAuthentic,
      IpAudienceFeeling.moving => l10n.ipFeelingMoving,
      IpAudienceFeeling.healing => l10n.ipFeelingHealing,
      IpAudienceFeeling.gripping => l10n.ipFeelingGripping,
      IpAudienceFeeling.destiny => l10n.ipFeelingDestiny,
      IpAudienceFeeling.surprising => l10n.ipFeelingSurprising,
    };

String feelingDescription(IpAudienceFeeling value, AppLocalizations l10n) =>
    switch (value) {
      IpAudienceFeeling.authentic => l10n.ipFeelingAuthenticDescription,
      IpAudienceFeeling.moving => l10n.ipFeelingMovingDescription,
      IpAudienceFeeling.healing => l10n.ipFeelingHealingDescription,
      IpAudienceFeeling.gripping => l10n.ipFeelingGrippingDescription,
      IpAudienceFeeling.destiny => l10n.ipFeelingDestinyDescription,
      IpAudienceFeeling.surprising => l10n.ipFeelingSurprisingDescription,
    };

String presentationLabel(IpPresentation value, AppLocalizations l10n) =>
    switch (value) {
      IpPresentation.aiReal => l10n.ipPresentationAiReal,
      IpPresentation.animation2d => l10n.ipPresentation2d,
      IpPresentation.animation3d => l10n.ipPresentation3d,
      IpPresentation.liveAction => l10n.ipPresentationLive,
    };

String formatLabel(IpContentFormat value, AppLocalizations l10n) =>
    switch (value) {
      IpContentFormat.shortFilm => l10n.ipFormatShortFilm,
      IpContentFormat.comicDrama => l10n.ipFormatComicDrama,
      IpContentFormat.interactiveDrama => l10n.ipFormatInteractiveDrama,
      IpContentFormat.talkingHead => l10n.ipFormatTalkingHead,
    };

String selectionLabel<T extends Enum>(
  IpGuideSelection<T> selection,
  String Function(T) label,
  String separator,
  AppLocalizations l10n,
) {
  if (selection.customText.trim().isNotEmpty) {
    return selection.customText.trim();
  }
  if (selection.isEmpty) return l10n.ipNotSelected;
  return selection.values.map(label).join(separator);
}

/// Serializes the same values shown in the review into the session's initial prompt.
String guideSessionPrompt(IpGuideDraft draft, AppLocalizations l10n) =>
    l10n.ipGuideSessionPrompt(
      draft.nickname.trim().isEmpty ? l10n.ipNewAccount : draft.nickname.trim(),
      selectionLabel(
        draft.directions,
        (value) => directionLabel(value, l10n),
        ' × ',
        l10n,
      ),
      selectionLabel(
        draft.feelings,
        (value) => feelingLabel(value, l10n),
        ' / ',
        l10n,
      ),
      draft.presentation == null
          ? l10n.ipNotSelected
          : presentationLabel(draft.presentation!, l10n),
      draft.customFormat.trim().isEmpty
          ? formatLabel(draft.format, l10n)
          : draft.customFormat.trim(),
      l10n.ipTargetAudienceValue,
    );
