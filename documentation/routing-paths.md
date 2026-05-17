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

On device connection, the app reads the firmware capability to set `pathHashByteWidth` reported by the device. The device encodes a "mode" value (0..3) which maps to `width = mode + 1` (1..4 bytes per hop). The connector uses this width as the authoritative send width when composing paths for that device.

```dart
// Read from device info response (offset 81)
final modeRaw = firmwareBytes.length >= 82
  ? (firmwareBytes[81] & 0xFF)
  : 0;
final mode = modeRaw.clamp(0, 3);
_pathHashByteWidth = mode + 1; // 1..4 bytes per hop
```

Note: the app now supports up to 4 bytes per hop when reported by devices. UI validation for user-entered paths still uses the device's configured `pathHashByteWidth` for outbound paths, but inbound packets are interpreted per-packet (see below).

### Path Data Structure

Paths in messages and storage consist of:

- **`pathLength`**: Encoded path length in bytes as carried by the frame/header. This is not the hop count when `pathHashByteWidth > 1`.
- **`pathBytes`**: Raw bytes of the path, grouped by `pathHashByteWidth`
- **`hopCount`**: Derived display value computed from bytes and width: `(byteCount + hashByteWidth - 1) ~/ hashByteWidth`
- **Example**: With `pathHashByteWidth=2`, a 3-hop path needs 6 bytes, so `pathLength = 6` and `hopCount = 3`:
  - `pathBytes = [0xA1, 0xA2, 0xB1, 0xB2, 0xC1, 0xC2]`
  - Hops: `[0xA1A2]`, `[0xB1B2]`, `[0xC1C2]`

### Hop Count Calculation

Convert path byte length to hop count:

```dart
int hopCount = (byteCount + hashByteWidth - 1) ~/ hashByteWidth;
```

Use this consistently when displaying hop counts in UI. Do not treat `pathLength` as a hop count when the path uses multi-byte hop hashes.

### Path Usage in Different Message Types

- **Direct messages**: Extract path from decrypted payload to trace sender route.
- **Channel messages**: Decrypt hop-by-hop routing chain from payload; the header carries the encoded byte length for the path blob, not the derived hop count.
### Packet-aware parsing (incoming packets)

Inbound frames may encode the effective hop width inside the path bytes themselves (top two bits of the first path byte). To avoid misinterpreting a 1-byte packet as a 2-byte path when the node configuration differs, the client detects the packet's width and uses it when splitting and matching hops for that specific packet.

Use the per-packet detection for display, contact lookups and inferred-position calculations. Continue to use the device's configured `pathHashByteWidth` for composing and validating outbound paths.

The helper used by the client implements detection equivalent to meshcore_py:

```dart
static int detectPathHashWidth(List<int> pathBytes, {int fallback = 1}) {
  if (pathBytes.isEmpty) return fallback.clamp(1,4);
  final first = pathBytes[0];
  final mode = ((first & 0xC0) >> 6) & 0x03;
  return (mode + 1).clamp(1,4);
}
```

This ensures that display and matching are packet-aware and robust across mixed-width networks.
- **Contact storage**: Path length in byte 32, raw path bytes in bytes 33-96, grouped by detected `pathHashByteWidth`.

### UI Hop Count Display

⚠️ **Important**: In screens like "Channel Message Path", prefer the actual decoded `pathBytes` hop count over `pathLength` metadata:

```dart
// Preferred: use actual observed path length
final effectiveHopCount = (pathBytes.length + width - 1) ~/ width;

// Avoid: using encoded byte length as if it were a hop count
// pathLength is bytes; converting it twice causes inflated counts
```

Example scenario:
- Radio header reports `pathLength: 32` bytes
- Decoded path bytes: `[0xAB, 0xCD]` (2 bytes = 1 hop with width=2)
- **Display**: "1 hop" (from `pathBytes`), not "32 hops" (which would double-count the encoded length)

