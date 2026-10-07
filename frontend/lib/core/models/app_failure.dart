/// A bounded, safe message for the app. Provider exceptions and tokens never
/// cross this boundary into presentation or local history.
class AppFailure implements Exception {
  const AppFailure(this.kind, this.userMessage);

  final String kind;
  final String userMessage;

  @override
  String toString() => userMessage;
}
