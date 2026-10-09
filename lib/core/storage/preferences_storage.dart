import 'package:shared_preferences/shared_preferences.dart';

class PreferencesStorage {
  const PreferencesStorage(this.preferences);

  final SharedPreferences preferences;

  String? getString(String key) => preferences.getString(key);

  Future<void> setString(String key, String value) async {
    if (!await preferences.setString(key, value)) {
      throw StateError('Failed to persist preference: $key');
    }
  }

  Future<void> remove(String key) async {
    if (!await preferences.remove(key)) {
      throw StateError('Failed to remove preference: $key');
    }
  }
}
