import 'package:web/web.dart' as web;

const _key = 'iya-admin-theme';

String? readThemePref() {
  try {
    return web.window.localStorage.getItem(_key);
  } catch (_) {
    return null;
  }
}

void writeThemePref(String value) {
  try {
    web.window.localStorage.setItem(_key, value);
  } catch (_) {}
}
