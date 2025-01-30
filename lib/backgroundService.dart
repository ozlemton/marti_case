import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:location/location.dart';

class BackgroundService {
  static void initializeService() {
    FlutterBackgroundService().configure(
        androidConfiguration: AndroidConfiguration(
          onStart: onServiceStart,
          autoStart: true,
          isForegroundMode: true,
          foregroundServiceNotificationId: 888,
        ),
        iosConfiguration: IosConfiguration(
          autoStart: true,
        ));
    FlutterBackgroundService().startService();
  }

  static void onServiceStart(ServiceInstance service) {
    Location location = Location();

    // listening location services
    location.onLocationChanged.listen((LocationData currentLocation) {
      if (currentLocation.latitude != null && currentLocation.longitude != null) {
        print("Location on Background: ${currentLocation.latitude}, ${currentLocation.longitude}");
      }
    });
    // service.setForegroundMode(true);
  }
}
