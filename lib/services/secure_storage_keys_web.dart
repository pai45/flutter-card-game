import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// flutter_secure_storage's web backend keeps each value in `localStorage`
/// as `<prefix><key>`; returns the bare keys.
List<String> storedSecureKeys(String prefix) {
  final storage = globalContext['localStorage'] as JSObject?;
  if (storage == null) return const [];
  final length = (storage['length'] as JSNumber).toDartInt;
  final keys = <String>[];
  for (var i = 0; i < length; i++) {
    final key = storage.callMethod<JSString?>('key'.toJS, i.toJS)?.toDart;
    if (key != null && key.startsWith(prefix)) {
      keys.add(key.substring(prefix.length));
    }
  }
  return keys;
}
