import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const sampleRate = 44100;
final random = Random(6072026);

void main() {
  final directory = Directory('assets/audio')..createSync(recursive: true);
  final cues = <String, List<double>>{
    'ui_tap.wav': tone(880, .08, decay: 22, harmonic: .25),
    'footstep.wav': noiseHit(.12, 90, .65),
    'release.wav': sweep(480, 1180, .16, .45),
    'bounce.wav': tone(150, .11, decay: 18, harmonic: .42),
    'clean_hit.wav': mix([
      tone(210, .24, decay: 9, harmonic: .55),
      noiseHit(.08, 1300, .28),
    ]),
    'edge.wav': mix([tone(1250, .12, decay: 25), noiseHit(.09, 2400, .22)]),
    'roll.wav': rolling(.7),
    'catch.wav': mix([noiseHit(.16, 500, .5), tone(105, .17, decay: 16)]),
    'stumps.wav': clatter(.55),
    'throw.wav': sweep(900, 180, .28, .38),
    'four_crowd.wav': crowd(.95, bright: false),
    'six_crowd.wav': crowd(1.15, bright: true),
    'wicket.wav': mix([
      clatter(.55),
      crowd(.85, bright: false, descending: true),
    ]),
    'victory.wav': chord([440, 554.37, 659.25], 1.15, rising: true),
    'defeat.wav': chord([293.66, 277.18, 220], 1.05, rising: false),
    'ambience.wav': ambience(5),
  };
  for (final entry in cues.entries) {
    final loop = entry.key == 'ambience.wav';
    final category = loop
        ? 'ambient'
        : entry.key == 'ui_tap.wav'
        ? 'ui'
        : {
            'four_crowd.wav',
            'six_crowd.wav',
            'wicket.wav',
            'victory.wav',
            'defeat.wav',
          }.contains(entry.key)
        ? 'reward'
        : 'gameplay';
    final mastered = master(entry.value, category: category, loop: loop);
    File('${directory.path}/${entry.key}').writeAsBytesSync(wav(mastered));
  }
  stdout.writeln('Generated ${cues.length} original Final Over audio cues.');
}

List<double> tone(
  double hz,
  double seconds, {
  double decay = 6,
  double harmonic = .15,
}) {
  final count = (seconds * sampleRate).round();
  return List.generate(count, (i) {
    final t = i / sampleRate;
    final env = exp(-decay * t) * min(1, i / 90);
    return (sin(2 * pi * hz * t) + harmonic * sin(4 * pi * hz * t)) * env * .72;
  });
}

List<double> sweep(double from, double to, double seconds, double volume) {
  final count = (seconds * sampleRate).round();
  var phase = 0.0;
  return List.generate(count, (i) {
    final p = i / count;
    phase += 2 * pi * (from + (to - from) * p) / sampleRate;
    return sin(phase) * sin(pi * p) * volume;
  });
}

List<double> noiseHit(double seconds, double lowPassHz, double volume) {
  final count = (seconds * sampleRate).round();
  var smooth = 0.0;
  final alpha = min(1.0, 2 * pi * lowPassHz / sampleRate);
  return List.generate(count, (i) {
    smooth += alpha * ((random.nextDouble() * 2 - 1) - smooth);
    return smooth * exp(-18 * i / sampleRate) * volume;
  });
}

List<double> rolling(double seconds) {
  final count = (seconds * sampleRate).round();
  var smooth = 0.0;
  return List.generate(count, (i) {
    smooth += .11 * ((random.nextDouble() * 2 - 1) - smooth);
    final pulse = .35 + .65 * pow(sin(2 * pi * 18 * i / sampleRate), 2);
    return smooth * pulse * (1 - i / count) * .28;
  });
}

List<double> clatter(double seconds) {
  final base = List<double>.filled((seconds * sampleRate).round(), 0);
  for (final offset in [0.0, .07, .13, .21]) {
    final hit = mix([
      tone((720 + random.nextInt(500)).toDouble(), .16, decay: 20),
      noiseHit(.12, 1800, .3),
    ]);
    addInto(base, hit, (offset * sampleRate).round());
  }
  return base;
}

List<double> crowd(
  double seconds, {
  required bool bright,
  bool descending = false,
}) {
  final count = (seconds * sampleRate).round();
  var smooth = 0.0;
  return List.generate(count, (i) {
    final p = i / count;
    smooth += .035 * ((random.nextDouble() * 2 - 1) - smooth);
    final swell = descending ? (1 - p) : sin(pi * min(1, p * .75));
    final chant = sin(2 * pi * (bright ? 310 : 220) * i / sampleRate) * .035;
    return (smooth * .8 + chant) * swell * .7;
  });
}

List<double> chord(List<double> notes, double seconds, {required bool rising}) {
  final count = (seconds * sampleRate).round();
  return List.generate(count, (i) {
    final t = i / sampleRate;
    var value = 0.0;
    for (var n = 0; n < notes.length; n++) {
      final start = rising ? n * .11 : n * .08;
      if (t >= start) {
        value += sin(2 * pi * notes[n] * (t - start)) * exp(-2.4 * (t - start));
      }
    }
    return value / notes.length * min(1, i / 150) * .8;
  });
}

List<double> ambience(int seconds) {
  final count = seconds * sampleRate;
  var lowCrowd = 0.0;
  final output = List.generate(count, (i) {
    final t = i / sampleRate;
    lowCrowd += .012 * ((random.nextDouble() * 2 - 1) - lowCrowd);
    final stadiumAir =
        sin(2 * pi * 31 * t) * .018 +
        sin(2 * pi * 67 * t) * .012 +
        sin(2 * pi * 113 * t) * .008;
    final distantCrowd =
        lowCrowd * (.16 + .04 * sin(2 * pi * 0.4 * t)) +
        sin(2 * pi * 181 * t) * .004 +
        sin(2 * pi * 233 * t) * .003;
    return stadiumAir + distantCrowd;
  });
  final seam = (.4 * sampleRate).round();
  for (var i = 0; i < seam; i++) {
    final blend = i / seam;
    final index = count - seam + i;
    final target =
        output[count - seam] + (output.first - output[count - seam]) * blend;
    output[index] = output[index] * (1 - blend) + target * blend;
  }
  output[count - 1] = output.first;
  return output;
}

List<double> master(
  List<double> source, {
  required String category,
  required bool loop,
}) {
  final output = List<double>.from(source);
  final mean = output.reduce((a, b) => a + b) / output.length;
  for (var i = 0; i < output.length; i++) {
    output[i] -= mean;
  }
  if (!loop) {
    final fade = min(output.length ~/ 4, (.008 * sampleRate).round());
    for (var i = 0; i < fade; i++) {
      final gain = i / fade;
      output[i] *= gain;
      output[output.length - 1 - i] *= gain;
    }
  }
  final rms = sqrt(
    output.map((sample) => sample * sample).reduce((a, b) => a + b) /
        output.length,
  );
  final loudnessDb = switch (category) {
    'ui' => -22.0,
    'gameplay' => -18.0,
    'reward' => -16.0,
    _ => -30.0,
  };
  final loudnessGain = pow(10, loudnessDb / 20) / max(rms, 1e-9);
  for (var i = 0; i < output.length; i++) {
    output[i] *= loudnessGain;
  }
  final peak = output.map((sample) => sample.abs()).reduce(max);
  final peakTarget = switch (category) {
    'ui' => .42,
    'gameplay' => .72,
    'reward' => .89,
    _ => .13,
  };
  final peakGain = peak > peakTarget ? peakTarget / peak : 1.0;
  return output.map((sample) => sample * peakGain).toList();
}

List<double> mix(List<List<double>> sources) {
  final length = sources.map((s) => s.length).fold(0, max);
  final output = List<double>.filled(length, 0);
  for (final source in sources) {
    addInto(output, source, 0);
  }
  return output.map((v) => v.clamp(-1.0, 1.0)).toList();
}

void addInto(List<double> target, List<double> source, int offset) {
  for (var i = 0; i < source.length && i + offset < target.length; i++) {
    target[i + offset] = (target[i + offset] + source[i]).clamp(-1.0, 1.0);
  }
}

Uint8List wav(List<double> samples) {
  final dataSize = samples.length * 2;
  final bytes = ByteData(44 + dataSize);
  void ascii(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      bytes.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  bytes.setUint32(4, 36 + dataSize, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little);
  bytes.setUint16(22, 1, Endian.little);
  bytes.setUint32(24, sampleRate, Endian.little);
  bytes.setUint32(28, sampleRate * 2, Endian.little);
  bytes.setUint16(32, 2, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  bytes.setUint32(40, dataSize, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    bytes.setInt16(
      44 + i * 2,
      (samples[i].clamp(-1.0, 1.0) * 32767).round(),
      Endian.little,
    );
  }
  return bytes.buffer.asUint8List();
}
