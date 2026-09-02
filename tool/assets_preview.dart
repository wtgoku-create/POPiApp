import 'package:flutter/material.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/assets/presentation/assets_page.dart';

void main() {
  final screen = Uri.base.queryParameters['screen'];
  final home = switch (screen) {
    'history-empty' => const AssetsPage(),
    'works-empty' => const AssetsPage(
        initialSection: AssetLibrarySection.works,
      ),
    'roles-empty' => const AssetsPage(
        initialSection: AssetLibrarySection.roles,
      ),
    'works' => const AssetsPage.sample(
        initialSection: AssetLibrarySection.works,
      ),
    'roles' => const AssetsPage.sample(
        initialSection: AssetLibrarySection.roles,
      ),
    _ => const AssetsPage.sample(),
  };

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: home,
    ),
  );
}
