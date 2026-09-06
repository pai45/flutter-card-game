// Shared plumbing for the ESPN extraction generators under tool/.
//
// Extracted from generate_league_stats.dart when a second generator
// (generate_football_match_players.dart) needed the same retrying HTTP client,
// concurrency pool and argument parsing. The original generator deliberately
// still carries its own private copies: migrating it is a separate change that
// is only safe once its `--check` has been re-run against the network, and
// quietly rewriting a verified generator to prove a refactor is the wrong
// trade.

import 'dart:convert';
import 'dart:io';

/// Parallel in-flight requests. ESPN throttles aggressively above this.
const espnConcurrency = 6;

const espnTimeout = Duration(seconds: 20);
const espnMaxAttempts = 4;

/// Runs [task] over [items] with at most [espnConcurrency] requests in flight.
Future<void> espnPool<T>(
  List<T> items,
  Future<void> Function(T) task, {
  int concurrency = espnConcurrency,
}) async {
  var next = 0;
  Future<void> worker() async {
    while (true) {
      final index = next++;
      if (index >= items.length) return;
      await task(items[index]);
    }
  }

  await Future.wait([
    for (var i = 0; i < concurrency && i < items.length; i++) worker(),
  ]);
}

class EspnFeedClient {
  final HttpClient _client = HttpClient()..connectionTimeout = espnTimeout;

  void close() => _client.close(force: true);

  /// GETs [url], retrying transient failures with a short backoff. Returns null
  /// only once every attempt has failed.
  Future<Map<String, dynamic>?> getJson(String url) async {
    for (var attempt = 1; attempt <= espnMaxAttempts; attempt++) {
      try {
        final request = await _client
            .getUrl(Uri.parse(url))
            .timeout(espnTimeout);
        request.headers.set(HttpHeaders.acceptHeader, 'application/json');
        final response = await request.close().timeout(espnTimeout);
        if (response.statusCode != 200) {
          await response.drain<void>();
          // 404 is a real answer (no such feed), not a transient failure.
          if (response.statusCode == 404) return null;
          throw HttpException('HTTP ${response.statusCode}');
        }
        final body = await response
            .transform(utf8.decoder)
            .join()
            .timeout(espnTimeout);
        final decoded = jsonDecode(body);
        return decoded is Map<String, dynamic> ? decoded : null;
      } catch (e) {
        if (attempt == espnMaxAttempts) {
          stderr.writeln('  ! gave up on $url: $e');
          return null;
        }
        await Future<void>.delayed(Duration(milliseconds: 250 * attempt));
      }
    }
    return null;
  }
}

/// Pulls the trailing id out of a core-API reference URL, e.g.
/// `.../athletes/277128?lang=en` becomes `277128`.
String? espnIdFromRef(Object? ref) {
  if (ref is! String) return null;
  final segments = Uri.tryParse(ref)?.pathSegments;
  if (segments == null || segments.isEmpty) return null;
  return segments.last.isEmpty ? null : segments.last;
}

/// Reads `--name value` out of [args], removing both entries.
String? espnOptionValue(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index < 0 || index + 1 >= args.length) return null;
  final value = args[index + 1];
  args.removeRange(index, index + 2);
  return value;
}

int? espnIntOption(List<String> args, String name) {
  final raw = espnOptionValue(args, name);
  return raw == null ? null : int.tryParse(raw);
}

/// Re-encodes JSON without the keys in [ignoring] so a fresh run can be
/// compared against a committed asset whose timestamp changes every run.
/// Structural rather than line-based, because these assets are written compact.
String espnWithoutKeys(String source, Set<String> ignoring) {
  final decoded = jsonDecode(source);
  if (decoded is! Map<String, dynamic>) return source;
  return jsonEncode(<String, Object?>{
    for (final entry in decoded.entries)
      if (!ignoring.contains(entry.key)) entry.key: entry.value,
  });
}
