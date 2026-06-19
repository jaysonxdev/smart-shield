import 'package:permission_handler/permission_handler.dart';

Future<bool> requestStoragePermission() async {
  if (await Permission.storage.isGranted) {
    return true;
  }

  final status = await Permission.storage.request();

  if (status.isGranted) {
    return true;
  }

  if (status.isPermanentlyDenied) {
    await openAppSettings();
  }

  return false;
}
