import 'theme_pref_store_stub.dart'
    if (dart.library.js_interop) 'theme_pref_store_web.dart'
    as impl;

/// Guarda la preferencia de tema en este navegador (en otras plataformas
/// solo dura la sesión).
String? readThemePref() => impl.readThemePref();
void writeThemePref(String value) => impl.writeThemePref(value);
