import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'utils/sound_effects.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Draw behind the status + navigation bars so the app's own chrome fills them
  // (no black OS strips), and make those bars transparent with light icons.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light, // Android
    statusBarBrightness: Brightness.dark, // iOS
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarContrastEnforced: false,
  ));
  // Restore the persisted mute choice before the first frame plays any audio.
  AudioController.instance.loadMutePreference();
  runApp(const PitchDuelApp());
}
