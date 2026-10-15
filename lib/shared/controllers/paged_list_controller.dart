import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../type/list_page.dart';

/// Local pagination with cancellation, stable IDs and retained rows on failure.
class PagedListController<T> extends ChangeNotifier {
  PagedListController({required this.fetch, required this.itemId});

  final Future<ListPage<T>> Function(int, CancelToken) fetch;
  final String Function(T) itemId;
  List<T> items = const [];
  int page = 0;
  bool hasMore = true;
  bool loading = false;
  bool failed = false;
  CancelToken? _token;
  bool _disposed = false;
  bool get disposed => _disposed;

  void remove(String id) {
    _token?.cancel();
    _token = null;
    loading = false;
    items = items.where((item) => itemId(item) != id).toList(growable: false);
    page = 0;
    hasMore = true;
    notifyListeners();
  }

  Future<void> load({bool reset = false}) async {
    if (_disposed || (!reset && (loading || !hasMore))) return;
    _token?.cancel();
    final token = _token = CancelToken();
    loading = true;
    failed = false;
    notifyListeners();
    try {
      final result = await fetch(reset ? 1 : page + 1, token);
      if (_disposed || token.isCancelled) return;
      final merged = <String, T>{
        if (!reset)
          for (final item in items) itemId(item): item,
        for (final item in result.items) itemId(item): item,
      };
      items = List.unmodifiable(merged.values);
      page = result.page;
      hasMore = result.hasMore;
    } catch (_) {
      if (_disposed || token.isCancelled) return;
      failed = true;
      rethrow;
    } finally {
      if (!_disposed && identical(_token, token)) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _token?.cancel();
    super.dispose();
  }
}
