import 'dart:async';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:luminara_photobooth/core/services/server_service.dart';

const String notificationChannelId = 'luminara_server_channel';
const int notificationId = 888;

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: notificationChannelId,
      initialNotificationTitle: 'Luminara Server',
      initialNotificationContent: 'Menunggu perintah...',
      foregroundServiceNotificationId: notificationId,
      foregroundServiceTypes: [AndroidForegroundType.dataSync],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  service.on('stopService').listen((event) async {
    await ServerService().stop();
    service.stopSelf();
  });

  final serverService = ServerService();

  service.on('startServer').listen((event) async {
    final port = event?['port'] ?? 3000;
    await serverService.start(port: port, isBackground: true);

    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: "Luminara Server Aktif",
        content: "Server berjalan di port $port. Siap melayani transaksi.",
      );
    }

    service.invoke('serverStatus', {'running': true});
  });

  service.on('stopServer').listen((event) async {
    await serverService.stop();
    service.invoke('serverStatus', {'running': false});
    service.stopSelf();
  });

  // Listen to events from server to broadcast to UI
  serverService.appEventStream.listen((event) {
    service.invoke('appEvent', {'event': event});
  });

  serverService.clientCountStream.listen((count) {
    service.invoke('clientCount', {'count': count});
  });
}
