import 'dart:js_interop';

@JS('unlabelNotFound')
external JSBoolean? get _unlabelNotFound;

@JS('unlabelNotFound')
external set _unlabelNotFound(JSBoolean value);

@JS('history.replaceState')
external void _replaceState(JSAny? data, JSString title, JSString url);

@JS('history.state')
external JSAny? get _historyState;

bool get isMissingWebPage => _unlabelNotFound?.toDart ?? false;

void clearMissingWebPage() {
  _unlabelNotFound = false.toJS;
  _replaceState(_historyState, ''.toJS, '/#/'.toJS);
}
