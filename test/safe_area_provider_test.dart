import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:popi_ai_app/shared/providers/safe_area_provider.dart';
import 'package:popi_ai_app/shared/widgets/safe_area_store_sync.dart';

void main() {
  testWidgets('syncs MediaQuery view padding into the global store', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    Future<void> pumpWithInsets(EdgeInsets insets) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MediaQuery(
            data: MediaQueryData(viewPadding: insets),
            child: const SafeAreaStoreSync(child: SizedBox()),
          ),
        ),
      );
      await tester.pump();
    }

    const initialInsets = EdgeInsets.fromLTRB(4, 52, 6, 34);
    await pumpWithInsets(initialInsets);
    expect(container.read(safeAreaInsetsProvider), initialInsets);

    const updatedInsets = EdgeInsets.fromLTRB(8, 60, 10, 24);
    await pumpWithInsets(updatedInsets);
    expect(container.read(safeAreaInsetsProvider), updatedInsets);
  });
}
