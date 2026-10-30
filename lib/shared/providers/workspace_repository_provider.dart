import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/network/network_agent_api.dart';
import '../../features/demo/data/demo_repository.dart';
import 'business_agent_provider.dart';
import 'storage_provider.dart';

/// The authenticated Web workspace retains its original API and account cache.
final workspaceRepositoryProvider = FutureProvider.autoDispose<DemoRepository?>(
  (ref) async {
    var active = true;
    ref.onDispose(() => active = false);
    final session = await ref.watch(businessAgentSessionProvider.future);
    if (!active || session == null) return null;
    final repository = DemoRepository.harness(
      ref.read(preferencesStorageProvider),
      NetworkAgentApi(session.dio),
      libraryApi: session.libraryApi,
      businessLibrary: true,
      userStorageKey: DemoRepository.businessStorageKey(
        AppConfig.environment,
        AppConfig.agentApiBaseUrl,
        session.userId,
      ),
    )..restore();
    ref.onDispose(repository.dispose);
    return repository;
  },
);
