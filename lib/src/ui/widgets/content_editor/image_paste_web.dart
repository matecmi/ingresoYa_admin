import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

void Function() listenForImagePaste(void Function(Uint8List, String) receive) {
  final listener = ((web.Event event) {
    final files = (event as web.ClipboardEvent).clipboardData?.files;
    if (files == null) return;
    for (var i = 0; i < files.length; i++) {
      final file = files.item(i)!;
      if (!file.type.startsWith('image/')) continue;
      event.preventDefault();
      file.arrayBuffer().toDart.then((buffer) {
        receive(buffer.toDart.asUint8List(), file.name);
      });
      break;
    }
  }).toJS;
  web.document.addEventListener('paste', listener);
  return () => web.document.removeEventListener('paste', listener);
}
