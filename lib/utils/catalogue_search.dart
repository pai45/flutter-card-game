/// Shared local search rules; every word must match available metadata.
String normalizeCatalogueQuery(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

bool catalogueMatches(String query, Iterable<String> fields) {
  final normalized = normalizeCatalogueQuery(query);
  if (normalized.length < 2) return false;
  final haystack = normalizeCatalogueQuery(fields.join(' '));
  return normalized.split(' ').every(haystack.contains);
}

int catalogueMatchPriority(String name, String query) {
  final normalized = normalizeCatalogueQuery(name);
  final needle = normalizeCatalogueQuery(query);
  return normalized == needle
      ? 0
      : normalized.startsWith(needle)
      ? 1
      : 2;
}
