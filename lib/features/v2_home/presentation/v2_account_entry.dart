import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/providers/storage_provider.dart';
import '../../ip_guide/presentation/ip_guide_page.dart';
import '../../v2_shared/data/v2_repository.dart';
import '../data/v2_onboarding_repository.dart';
import 'v2_home_page.dart';
import 'v2_guest_page.dart';

/// Keeps first-use progress scoped to the current signed-in account.
class V2AccountEntry extends ConsumerStatefulWidget {
  const V2AccountEntry({
    required this.repository,
    required this.userId,
    required this.routeActive,
    required this.routedContent,
    super.key,
  });

  final V2Repository repository;
  final String? userId;
  final bool routeActive;
  final Widget routedContent;

  @override
  ConsumerState<V2AccountEntry> createState() => _V2AccountEntryState();
}

class _V2AccountEntryState extends ConsumerState<V2AccountEntry> {
  V2OnboardingRepository? _guide;
  late bool _completed =
      widget.userId != null &&
      widget.repository.hasCompletedOnboarding(widget.userId!);
  String? _sessionId;

  @override
  void dispose() {
    _guide?.dispose();
    super.dispose();
  }

  void _created(String id) {
    setState(() {
      _completed = true;
      _sessionId = id;
    });
    // Completion is already durable; stale draft cleanup cannot undo it.
    unawaited(_guide!.clear().catchError((Object _) {}));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.userId == null) return const V2GuestPage();
    if (!_completed) {
      _guide ??= V2OnboardingRepository(
        ref.read(preferencesStorageProvider),
        widget.repository,
        AppLocalizations.of(context)!,
        userId: widget.userId!,
      );
      return Stack(
        fit: StackFit.expand,
        children: [
          Offstage(
            offstage: widget.routeActive,
            child: IpGuidePage(repository: _guide, onCreated: _created),
          ),
          if (widget.routeActive) widget.routedContent,
        ],
      );
    }
    return V2HomePage(
      repository: widget.repository,
      initialSessionId: _sessionId,
      routeActive: widget.routeActive,
      routedContent: widget.routedContent,
    );
  }
}
