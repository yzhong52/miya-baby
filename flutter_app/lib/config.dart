/// Build-time switches.
library;

/// Sign-in and family sharing, while the Firebase work (#17) is in
/// progress. Off by default; turn on with
/// `flutter run --dart-define=FIREBASE_SYNC=true`. Removed once Firestore
/// becomes the default (PR 5 of the plan).
const kFirebaseSync = bool.fromEnvironment('FIREBASE_SYNC');
