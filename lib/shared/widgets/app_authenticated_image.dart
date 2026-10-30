import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Prevents the memory image cache from sharing protected bytes between logins.
class AppAuthenticatedImage extends ImageProvider<AppAuthenticatedImage> {
  const AppAuthenticatedImage(this.url, {this.headers = const {}});
  final String url;
  final Map<String, String> headers;
  @override
  Future<AppAuthenticatedImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);
  @override
  ImageStreamCompleter loadImage(
    AppAuthenticatedImage key,
    ImageDecoderCallback decode,
  ) {
    final delegate = NetworkImage(key.url, headers: key.headers);
    // Flutter delegates still expose loadImage for custom cache identities.
    // ignore: deprecated_member_use
    return delegate.loadImage(delegate, decode);
  }

  @override
  bool operator ==(Object other) =>
      other is AppAuthenticatedImage &&
      url == other.url &&
      mapEquals(headers, other.headers);
  @override
  int get hashCode => Object.hash(
    url,
    Object.hashAllUnordered(
      headers.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );
}
