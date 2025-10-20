import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' show get;

/// Loads SVGA file data from various sources
///
/// This function can load SVGA files from:
/// - HTTPS URLs (network loading)
/// - Asset bundle paths (local asset loading)
///
/// Security note: HTTP URLs are not supported for security reasons.
/// Only HTTPS URLs are allowed for network loading.
///
/// [url] - The URL or asset path of the SVGA file to load
///
// ignore: unintended_html_in_doc_comment
/// Returns a Future that resolves to the file bytes as a List<int>
///
/// Throws an exception if an HTTP URL is provided (only HTTPS is allowed)
Future<List<int>> loader({required String url}) async {
  // Security check: reject HTTP URLs for security reasons
  if (url.startsWith('http://')) throw 'SVGA only support https:// url';

  // Return empty list for empty URLs
  if (url.isEmpty) return [];

  // Load from network if it's an HTTPS URL
  if (url.startsWith(RegExp('https://'))) {
    final response = await get(Uri.parse(url));
    return response.bodyBytes;
  } else {
    // Load from asset bundle for local asset paths
    final result = await rootBundle.load(url);
    return result.buffer.asUint8List();
  }
}
