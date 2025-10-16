import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' show get;

Future<List<int>> loader({required String url}) async {
  if (url.startsWith('http://')) throw 'SVGA only support https:// url';
  if (url.isEmpty) return [];
  if (url.startsWith(RegExp('https://'))) {
    final response = await get(Uri.parse(url));
    return response.bodyBytes;
  } else {
    final result = await rootBundle.load(url);
    return result.buffer.asUint8List();
  }
}
