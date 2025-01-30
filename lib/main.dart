import 'package:flutter/material.dart';
import 'package:marti_case/tracking.dart';
import 'dart:async';

import 'backgroundService.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  BackgroundService.initializeService(); // start background

  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: MartiTracking(),
  ));
}
