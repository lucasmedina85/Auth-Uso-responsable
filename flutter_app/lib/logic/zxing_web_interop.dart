// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:typed_data';
import 'dart:js_util' as js_util;
import 'dart:js' as js;

Future<String?> scanPdf417Wasm(Uint8List bytes) async {
  try {
    final promise = js.context.callMethod('scanPdf417Wasm', [bytes]);
    if (promise != null) {
      final result = await js_util.promiseToFuture<String?>(promise);
      return result;
    }
  } catch (e) {
    print('Error calling WASM ZXing: \$e');
  }
  return null;
}
