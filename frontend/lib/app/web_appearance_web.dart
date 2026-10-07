import 'dart:js_interop';

@JS('unlabelSetAppearance')
external void _setAppearance(JSString mode);

void setWebAppearance(String mode) => _setAppearance(mode.toJS);
