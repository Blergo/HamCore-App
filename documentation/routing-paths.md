# Routing Paths

This page covers how MeshCore Open represents, selects, validates, and stores routing paths in the UI and data layer.

## Path Routing

MeshCore supports variable-length multi-byte routing paths so the app can scale from small meshes to very large node sets.

### Hash Width and Multi-Byte Paths

The device capability determines the hash width (number of bytes per hop):

| Width | Max Unique Nodes | Typical Use |
|-------|-----------------|-------------|
| 1 byte | 256 | Single-byte node IDs |
| 2 bytes | 65,536 | Medium meshes |
| 3 bytes | 16.7M | Large networks |

### Device Capability Detection

On device connection, the app reads the firmware capability to set `pathHashByteWidth`:

```dart
// Read from device info response (offset 81)
final modeRaw = firmwareBytes.length >= 82
    ? (firmwareBytes[81] & 0xFF)
    : 0;
final mode = modeRaw.clamp(0, 2);
_pathHashByteWidth = mode + 1; // 1, 2, or 3 bytes per hop
```

The current implementation intentionally clamps to modes `0..2`, so the supported hop width is `1..3` bytes. Do not document 4-byte hops unless the connector implementation is widened first.

### Path Data Structure

Paths in messages and storage consist of:

- **`pathLength`**: Hop count reported in the radio header (may differ from decoded path)
- **`pathBytes`**: Raw bytes of the path, grouped by `pathHashByteWidth`
- **Example**: With `pathHashByteWidth=2`, a 3-hop path needs 6 bytes:
  - `pathBytes = [0xA1, 0xA2, 0xB1, 0xB2, 0xC1, 0xC2]`
  - Hops: `[0xA1A2]`, `[0xB1B2]`, `[0xC1C2]`

### Hop Count Calculation

Convert path byte length to hop count:

```dart
int hopCount = (byteCount + hashByteWidth - 1) ~/ hashByteWidth;
```

Use this consistently when displaying hop counts in UI to avoid mismatch between metadata (`pathLength`) and observed paths (`pathBytes`).

### Path Usage in Different Message Types

- **Direct messages**: Extract path from decrypted payload to trace sender route.
- **Channel messages**: Decrypt hop-by-hop routing chain from payload; header includes `pathLength` metadata.
- **Contact storage**: Path length in byte 32, raw path bytes in bytes 33-96, grouped by detected `pathHashByteWidth`.

### UI Hop Count Display

⚠️ **Important**: In screens like "Channel Message Path", prefer the actual decoded `pathBytes` hop count over `pathLength` metadata:

```dart
// Preferred: use actual observed path length
final effectiveHopCount = (pathBytes.length + width - 1) ~/ width;

// Avoid: using radio metadata directly
// pathLength can diverge from decoded bytes and cause UI mismatches
```

Example scenario:
- Radio header reports `pathLength: 32`
- Decoded path bytes: `[0xAB, 0xCD]` (2 bytes = 1 hop with width=2)
- **Display**: "1 hop" (from pathBytes), NOT "32 hops" (from pathLength)

