import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'storage_provider.dart';

final themeModeProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

class ThemeModeController extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() {
    return switch (ref.read(preferencesStorageProvider).getString(_key)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await ref.read(preferencesStorageProvider).setString(_key, mode.name);
  }
}

final localeProvider =
    NotifierProvider<LocaleController, Locale?>(LocaleController.new);

class LocaleController extends Notifier<Locale?> {
  static const _key = 'locale';

  @override
  Locale? build() {
    final languageCode =
        ref.read(preferencesStorageProvider).getString(_key) ?? 'system';
    return languageCode == 'system' ? null : Locale(languageCode);
  }

  Future<void> setLocale(Locale? locale) async {
    state = locale;
    await ref
        .read(preferencesStorageProvider)
        .setString(_key, locale?.languageCode ?? 'system');
  }
}
