import 'dart:async';

import 'package:flutter/foundation.dart';

/// Rows from [fetch] first, then live updates from [live] — and it never
/// surfaces a realtime failure to the UI.
///
/// A dropped or refused realtime channel (RealtimeSubscribeException /
/// channelError) used to end the stream with an error, and the screen showed
/// that raw exception instead of the orders. Now the rows are loaded over
/// plain REST straight away, the socket is re-attached after a short delay,
/// and a REST poll keeps the list current while the socket is down.
Stream<List<Map<String, dynamic>>> resilientRows({
  required Future<List<Map<String, dynamic>>> Function() fetch,
  required Stream<List<Map<String, dynamic>>> Function() live,
}) {
  late final StreamController<List<Map<String, dynamic>>> controller;
  StreamSubscription<List<Map<String, dynamic>>>? sub;
  Timer? poll;
  Timer? retry;
  var closed = false;

  Future<void> refresh() async {
    try {
      final rows = await fetch();
      if (!closed) controller.add(rows);
    } catch (e) {
      debugPrint('Orders REST fetch failed: $e');
    }
  }

  void connect() {
    if (closed) return;
    sub?.cancel();
    sub = live().listen(
      (rows) {
        // Socket is healthy again; the fallback poll is no longer needed.
        poll?.cancel();
        poll = null;
        if (!closed) controller.add(rows);
      },
      onError: (Object e) {
        debugPrint('Orders realtime failed, falling back to polling: $e');
        sub?.cancel();
        sub = null;
        poll ??= Timer.periodic(const Duration(seconds: 10), (_) => refresh());
        retry?.cancel();
        retry = Timer(const Duration(seconds: 5), connect);
      },
      cancelOnError: true,
    );
  }

  controller = StreamController<List<Map<String, dynamic>>>(
    onListen: () {
      refresh();
      connect();
    },
    onCancel: () {
      closed = true;
      poll?.cancel();
      retry?.cancel();
      sub?.cancel();
    },
  );
  return controller.stream;
}
