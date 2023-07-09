import 'dart:io';
import 'package:flutter/material.dart';
import 'package:rattata_vision/views/main.dart';
import 'package:rattata_vision/views/settings.dart';
import 'package:window_size/window_size.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // If settings file doesn't exist, create one from defaults
  File settingsFile = File('./settings.json');
  try {
    if (!settingsFile.existsSync()) {
      Settings settings = Settings.fromDefault();
      settingsFile.writeAsStringSync('${settings.toJson()}\n');
    }
  } catch (e) {
    // Failed to create a default settings file, keep going as is
  }
  // Set minimum width and height to stop my responsive nightmares
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    setWindowTitle('Rattata Vision');
    setWindowMinSize(const Size(800, 400));
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rattata Vision',
      theme: ThemeData(
        primarySwatch: Colors.purple,
        scrollbarTheme: ScrollbarThemeData(
          trackColor: MaterialStateProperty.all(Colors.white.withOpacity(0.5)),
          thumbColor: MaterialStateProperty.all(Colors.purple),
          trackVisibility: MaterialStateProperty.all(true),
          thumbVisibility: MaterialStateProperty.all(true),
        ),
      ),
      home: const MainWidget(),
      debugShowCheckedModeBanner: false,
    );
  }
}
