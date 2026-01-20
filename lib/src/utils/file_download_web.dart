import 'package:web/web.dart' as web;

void downloadTextFile({required String filename, required String contents}) {
  final encoded = Uri.encodeComponent(contents);
  final url = 'data:text/plain;charset=utf-8,$encoded';

  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;

  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
}
