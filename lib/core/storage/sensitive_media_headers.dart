bool hasSensitiveMediaHeaders(Map<String, String> headers) =>
    headers.entries.any(
      (entry) =>
          entry.value.trim().isNotEmpty &&
          (entry.key.toLowerCase() == 'cookie' ||
              entry.key.toLowerCase() == 'authorization'),
    );
