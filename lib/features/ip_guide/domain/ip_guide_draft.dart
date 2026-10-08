enum IpContentDirection {
  campus,
  emotion,
  growth,
  career,
  family,
  humor,
  mystery,
  pets,
  knowledge,
}

enum IpAudienceFeeling {
  authentic,
  moving,
  healing,
  gripping,
  destiny,
  surprising,
}

enum IpPresentation { aiReal, animation2d, animation3d, liveAction }

enum IpContentFormat { shortFilm, comicDrama, interactiveDrama, talkingHead }

/// Keeps selection order so the first choice is primary and the second auxiliary.
class IpGuideSelection<T extends Enum> {
  final List<T> _values = [];
  String _customText = '';

  List<T> get values => List.unmodifiable(_values);
  String get customText => _customText;
  bool get isEmpty => _values.isEmpty && _customText.trim().isEmpty;

  set customText(String text) {
    _customText = text;
    if (text.trim().isNotEmpty) _values.clear();
  }

  bool toggle(T value) {
    if (_values.remove(value)) return true;
    if (_values.length == 2) return false;
    _customText = '';
    _values.add(value);
    return true;
  }
}

/// Local form draft; no account is persisted until a backend creation flow exists.
class IpGuideDraft {
  final directions = IpGuideSelection<IpContentDirection>();
  final feelings = IpGuideSelection<IpAudienceFeeling>();
  IpPresentation? presentation;
  IpContentFormat format = IpContentFormat.shortFilm;
  String customFormat = '';
  String nickname = '';

  int? get firstIncompleteStep {
    if (directions.isEmpty) return 1;
    if (feelings.isEmpty) return 2;
    if (presentation == null) return 3;
    return null;
  }
}
