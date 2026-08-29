import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/safe_area_provider.dart';

class SafeAreaStoreSync extends ConsumerStatefulWidget {
  const SafeAreaStoreSync({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<SafeAreaStoreSync> createState() => _SafeAreaStoreSyncState();
}

class _SafeAreaStoreSyncState extends ConsumerState<SafeAreaStoreSync> {
  EdgeInsets? _scheduledInsets;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleSync(MediaQuery.viewPaddingOf(context));
  }

  void _scheduleSync(EdgeInsets insets) {
    if (_scheduledInsets == insets) return;
    _scheduledInsets = insets;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(safeAreaInsetsProvider.notifier).update(insets);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
