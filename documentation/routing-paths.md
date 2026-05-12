# Routing Paths

This page covers how MeshCore Open represents, selects, validates, and stores routing paths in the UI and data layer.

## Path Routing

MeshCore supports variable-length multi-byte routing paths so the app can scale from small meshes to very large node sets.

### Path Encoding Format

Each path byte packs both the hop count and the hash width:

```
Bit 7-6: Hash mode  (2 bits) → hash_bytes = 1 << mode
Bit 5-0: Hop count   (6 bits) → max 63 hops
```

| Mode | Hash Bytes | Max Hops | Max Unique Nodes | Firmware |
|------|-----------|----------|------------------|----------|
| 0 | 1 | 63 | 256 | v1.13+ |
| 1 | 2 | 63 | 65,536 | v1.14+ |
| 2 | 3 | 63 | 16.7M | v1.14+ |
| 3 | 4 | 63 | 4.3B | v1.14+ |

### Path Byte Calculation

```dart
final pathLenRaw = frameData[index];
final hopCount = pathLenRaw & 0x3F;
final hashMode = (pathLenRaw >> 6) & 0x03;
final hashBytes = 1 << hashMode;

final pathByteLength = hopCount * hashBytes;
final pathData = frameData.sublist(index + 1, index + 1 + pathByteLength);
```

### Device Capability Detection

The app reads the device's reported capability byte to determine whether multi-byte paths are available:

```dart
if (firmwareBytes.length >= 82) {
  final mode = (firmwareBytes[81] & 0xFF).clamp(0, 2);
  pathHashByteWidth = mode + 1;
} else {
  pathHashByteWidth = 1;
}
```

### Path Usage in Different Message Types

- Direct messages extract the path from the decrypted payload to trace the sender route.
- Channel messages decrypt a hop-by-hop routing chain from the payload.
- Contact storage keeps the path length encoding in byte 32 and the raw path bytes in bytes 33-96.

### Example Contact Path Parsing

```dart
// Mode 0 (1-byte): 3 hops = 3 bytes needed
// [0x83, 0xA1, 0xB2, 0xC3] → hopCount=3, mode=0, path=[A1,B2,C3]

// Mode 1 (2-byte): 3 hops = 6 bytes needed
// [0xC3, 0xA1, 0xA2, 0xB1, 0xB2, 0xC1, 0xC2]
// → hopCount=3, mode=1, path=[A1A2, B1B2, C1C2]
```

