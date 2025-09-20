import 'dart:typed_data';

class WadLump {
  final String name;
  final int offset;
  final int size;
  final Uint8List data;

  WadLump({
    required this.name,
    required this.offset,
    required this.size,
    required this.data,
  });

  @override
  String toString() => 'WadLump(name: $name, offset: $offset, size: $size)';
}

class WadData {
  final String type;
  final List<WadLump> lumps;
  final Map<String, WadLump> _lumpsByName = {};

  WadData._({
    required this.type,
    required this.lumps,
  }) {
    for (final lump in lumps) {
      _lumpsByName[lump.name] = lump;
    }
  }

  static WadData fromBytes(Uint8List bytes) {
    if (bytes.length < 12) {
      throw Exception('WAD file too small: must be at least 12 bytes');
    }

    final byteData = ByteData.sublistView(bytes);

    final wadType = String.fromCharCodes(bytes.sublist(0, 4));
    if (wadType != 'IWAD' && wadType != 'PWAD') {
      // TODO: warn
      // throw Exception('Invalid WAD type: $wadType. Must be IWAD or PWAD');
    }

    final numLumps = byteData.getUint32(4, Endian.little);
    final directoryOffset = byteData.getUint32(8, Endian.little);

    if (directoryOffset + (numLumps * 16) > bytes.length) {
      // TODO: warn
      // throw Exception('Directory extends beyond file size');
    }

    final lumps = <WadLump>[];

    for (int i = 0; i < numLumps; i++) {
      final entryOffset = directoryOffset + (i * 16);

      if(entryOffset + 16 > byteData.lengthInBytes) {
        break;  // TODO: warn
      }

      final lumpOffset = byteData.getUint32(entryOffset, Endian.little);
      final lumpSize = byteData.getUint32(entryOffset + 4, Endian.little);

      final nameBytes = bytes.sublist(entryOffset + 8, entryOffset + 16);
      final nullIndex = nameBytes.indexOf(0);
      final actualNameBytes = nullIndex >= 0 ? nameBytes.sublist(0, nullIndex) : nameBytes;
      final lumpName = String.fromCharCodes(actualNameBytes);

      if (lumpOffset + lumpSize > bytes.length) {
        // TODO: warn
        // throw Exception('Lump $lumpName extends beyond file size');
        continue;
      }

      final lumpData = bytes.sublist(lumpOffset, lumpOffset + lumpSize);

      lumps.add(WadLump(
        name: lumpName,
        offset: lumpOffset,
        size: lumpSize,
        data: lumpData,
      ));
    }

    return WadData._(
      type: wadType,
      lumps: lumps,
    );
  }

  WadLump? getLump(String name) {
    return _lumpsByName[name.toUpperCase()];
  }

  List<WadLump> getLumpsByPattern(Pattern pattern) {
    return lumps.where((lump) => pattern.allMatches(lump.name).isNotEmpty).toList();
  }

  bool hasLump(String name) {
    return _lumpsByName.containsKey(name.toUpperCase());
  }

  bool get isIWAD => type == 'IWAD';
  bool get isPWAD => type == 'PWAD';

  @override
  String toString() {
    return 'WadData(type: $type, lumps: ${lumps.length})';
  }
}