import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'services/secure_storage_service.dart';
import 'utils/sound_effects.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await prepareLocalProfilesForLaunch();
  // Draw behind the status + navigation bars so the app's own chrome fills them
  // (no black OS strips), and make those bars transparent with light icons.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light, // Android
      statusBarBrightness: Brightness.dark, // iOS
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarContrastEnforced: false,
    ),
  );
  // Restore the persisted mute choice before the first frame plays any audio.
  AudioController.instance.loadMutePreference();
  runApp(const PitchDuelApp());
}

/// Profile setup is best effort at launch. A browser with an old, full, or
/// unavailable store must still reach the app's first frame and existing save.
Future<void> prepareLocalProfilesForLaunch({SecureGameStorage? storage}) async {
  // Create the secure-storage key before the blocs' first-boot write burst.
  await SecureGameStorage.warmUp();
  // Create both save slots and finish the one-time returning-profile preset
  // before any bloc reads career state.
  try {
    await (storage ?? SecureGameStorage()).bootstrapLocalProfiles();
  } catch (error, stack) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'local profile bootstrap',
      ),
    );
  }
}
