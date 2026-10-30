Uri get webLoginLocation => Uri.base;
void cleanWebLoginCallback() {}
WebLoginWindow? openWebLoginWindow() => null;

class WebLoginWindow {
  void navigate(String url) => throw UnsupportedError('Browser required');
  void close() {}
}
