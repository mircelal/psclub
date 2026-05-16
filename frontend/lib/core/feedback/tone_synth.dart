import 'dart:math';
import 'dart:typed_data';

/// Qısa, yumşaq ton — WAV (PCM 16-bit mono). Kənar fade cızıltını azaldır.
Uint8List synthesizeToneWav(int frequency, int durationMs, {int sampleRate = 22050}) {
  final sampleCount = max(1, (sampleRate * durationMs / 1000).ceil());
  final fadeSamples = max(1, (sampleRate * 0.01).ceil());
  final pcm = ByteData(sampleCount * 2);

  for (var i = 0; i < sampleCount; i++) {
    final t = i / sampleRate;
    var env = 1.0;
    if (i < fadeSamples) {
      env = i / fadeSamples;
    } else if (i >= sampleCount - fadeSamples) {
      env = (sampleCount - i) / fadeSamples;
    }
    final wave = sin(2 * pi * frequency * t) * env * 0.32;
    final sample = (wave * 32767).round().clamp(-32767, 32767);
    pcm.setInt16(i * 2, sample, Endian.little);
  }

  return _wrapWav(pcm.buffer.asUint8List(), sampleRate);
}

Uint8List _wrapWav(Uint8List pcm, int sampleRate) {
  final dataSize = pcm.length;
  final fileSize = dataSize + 36;
  final header = ByteData(44);

  void writeStr(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      header.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  writeStr(0, 'RIFF');
  header.setUint32(4, fileSize, Endian.little);
  writeStr(8, 'WAVE');
  writeStr(12, 'fmt ');
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, 1, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, sampleRate * 2, Endian.little);
  header.setUint16(32, 2, Endian.little);
  header.setUint16(34, 16, Endian.little);
  writeStr(36, 'data');
  header.setUint32(40, dataSize, Endian.little);

  final out = Uint8List(44 + dataSize);
  out.setRange(0, 44, header.buffer.asUint8List());
  out.setRange(44, 44 + dataSize, pcm);
  return out;
}
