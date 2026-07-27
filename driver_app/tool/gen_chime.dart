import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// Deterministic generator for `assets/audio/offer_chime.wav` — the classic
/// dispatch "da-ding": A5 (880Hz, ~0.28s) rising to a slightly louder E6
/// (1318.5Hz, ~0.32s), each with a fast ~10ms attack and an exponential
/// decay, peaking gently at ~0.35 amplitude. 16-bit PCM mono at 22050Hz,
/// ~26KB — web/wasm/Android safe with audioplayers, zero extra deps.
///
/// Run from apps/driver:
///
///   dart run tool/gen_chime.dart
///
/// Committed alongside the asset so the sound stays reproducible: same
/// script, same bytes.
void main() {
  const sampleRate = 22050;
  const attackSeconds = 0.010;

  // (frequencyHz, durationSeconds, peakAmplitude, decayPerSecond)
  const tones = <(double, double, double, double)>[
    (880.0, 0.28, 0.32, 9.0),
    (1318.5, 0.32, 0.35, 7.0),
  ];

  final samples = <int>[];
  for (final (frequency, duration, amplitude, decay) in tones) {
    final count = (duration * sampleRate).round();
    for (var i = 0; i < count; i++) {
      final t = i / sampleRate;
      final envelope = t < attackSeconds
          ? t / attackSeconds
          : math.exp(-(t - attackSeconds) * decay);
      final value =
          amplitude * envelope * math.sin(2 * math.pi * frequency * t);
      samples.add((value * 32767).round().clamp(-32768, 32767));
    }
  }

  final dataLength = samples.length * 2;
  final bytes = ByteData(44 + dataLength);
  void tag(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      bytes.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  // Canonical 44-byte RIFF/fmt/data header, all fields little-endian.
  tag(0, 'RIFF');
  bytes.setUint32(4, 36 + dataLength, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little); // PCM fmt chunk size
  bytes.setUint16(20, 1, Endian.little); // audio format: PCM
  bytes.setUint16(22, 1, Endian.little); // channels: mono
  bytes.setUint32(24, sampleRate, Endian.little);
  bytes.setUint32(28, sampleRate * 2, Endian.little); // byte rate
  bytes.setUint16(32, 2, Endian.little); // block align (mono 16-bit)
  bytes.setUint16(34, 16, Endian.little); // bits per sample
  tag(36, 'data');
  bytes.setUint32(40, dataLength, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    bytes.setInt16(44 + i * 2, samples[i], Endian.little);
  }

  final file = File('assets/audio/offer_chime.wav');
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes.buffer.asUint8List());
  stdout.writeln('Wrote ${file.path} (${bytes.lengthInBytes} bytes)');
}
