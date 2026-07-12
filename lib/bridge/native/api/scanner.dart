export '../models.dart';

import 'media_ffi.dart';

Future<int> scanDirectory(
    {required String directory, required String appDir}) async {
  return MediaFfi.instance.scanDirectory(directory, appDir);
}
