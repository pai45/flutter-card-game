import 'package:flutter/material.dart';

import 'app.dart';
import 'utils/sound_effects.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Restore the persisted mute choice before the first frame plays any audio.
  AudioController.instance.loadMutePreference();
  runApp(const PitchDuelApp());
}
