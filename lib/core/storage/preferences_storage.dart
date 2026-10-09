import 'package:shared_preferences/shared_preferences.dart';

class PreferencesStorage {
  const PreferencesStorage(this.preferences);

  final SharedPreferences preferences;

  String? getString(String key) => preferences.getString(key);

  Future<void> setString(String key, String value) =>
      preferences.setString(key, value);
}
