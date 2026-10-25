/// Fire-and-forget writes for stores backed by Firestore.
library;

import 'package:flutter/foundation.dart';

/// Start [write] without waiting for it, and report it if it fails.
///
/// A Firestore write's future only completes once the server acknowledges
/// it, which never happens while offline, so the UI must not wait on one.
/// The local cache (and every listener) sees the write immediately anyway.
/// [what] describes the write in the error report.
void backgroundWrite(Future<void> write, String what) {
  write.catchError((Object e, StackTrace st) {
    FlutterError.reportError(FlutterErrorDetails(
      exception: e,
      stack: st,
      library: 'miya_baby',
      context: ErrorDescription(what),
    ));
  });
}
