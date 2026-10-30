import 'dart:js_interop';

Uri get webLoginLocation => Uri.parse(_location.href);

/// Open synchronously from the click event so browsers can allow the popup.
WebLoginWindow? openWebLoginWindow() {
  final window = _open('about:blank', '_blank', 'popup,width=560,height=760');
  return window == null ? null : WebLoginWindow._(window);
}

class WebLoginWindow {
  WebLoginWindow._(this._window);
  final _BrowserWindow _window;

  void navigate(String url) {
    // OAuth pages do not need access to the application window.
    _window.opener = null;
    _window.location.assign(url);
  }

  void close() => _window.close();
}

void cleanWebLoginCallback() {
  final uri = webLoginLocation;
  final query = Map<String, String>.of(uri.queryParameters)
    ..remove('douyin_callback')
    ..remove('douyin_state');
  final fragment = Uri.tryParse(uri.fragment);
  final fragmentQuery = Map<String, String>.of(fragment?.queryParameters ?? {})
    ..remove('douyin_callback')
    ..remove('douyin_state');
  final cleaned = uri.replace(
    query: query.isEmpty ? '' : Uri(queryParameters: query).query,
    fragment: fragment
        ?.replace(
          query: fragmentQuery.isEmpty
              ? ''
              : Uri(queryParameters: fragmentQuery).query,
        )
        .toString(),
  );
  _history.replaceState(null, '', cleaned.toString());
}

@JS('window.location')
external _Location get _location;
@JS('window.history')
external _History get _history;
@JS('window.open')
external _BrowserWindow? _open(String url, String target, String features);

extension type _BrowserWindow(JSObject _) implements JSObject {
  external _Location get location;
  external set opener(JSAny? value);
  external void close();
}

extension type _Location(JSObject _) implements JSObject {
  external String get href;
  external void assign(String url);
}

extension type _History(JSObject _) implements JSObject {
  external void replaceState(JSAny? data, String title, String url);
}
