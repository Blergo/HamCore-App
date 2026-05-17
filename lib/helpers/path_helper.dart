import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import '../models/contact.dart';
import '../connector/meshcore_protocol.dart';

class PathHelper {
  static String formatPathHex(List<int> pathBytes) {
    return pathBytes
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(',');
  }

  static String formatHopHex(List<int> hopBytes) {
    return hopBytes
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join();
  }

  static List<Uint8List> splitPathBytes(List<int> pathBytes, int hashByteWidth) {
    if (pathBytes.isEmpty) return const [];

    final width = hashByteWidth.clamp(1, 4);
    final hops = <Uint8List>[];
    for (int i = 0; i < pathBytes.length; i += width) {
      final endIdx = (i + width).clamp(0, pathBytes.length);
      final hopBytes = pathBytes.sublist(i, endIdx);
      if (hopBytes.isNotEmpty) {
        hops.add(Uint8List.fromList(hopBytes));
      }
    }
    return hops;
  }

  /// Detect the path hash width encoded in a packet's path bytes.
  ///
  /// MeshCore packets encode a "mode" in the high bits of the path bytes
  /// (same rule used by meshcore_py): mode = ((firstByte & 0xC0) >> 6),
  /// width = mode + 1 (yielding 1..4). If the packet is empty or detection
  /// fails, `fallback` is returned (clamped to 1..4).
  static int detectPathHashWidth(List<int> pathBytes, {int fallback = 1}) {
    final fb = fallback.clamp(1, 4);
    if (pathBytes.isEmpty) return fb;
    final first = pathBytes[0] & 0xFF;
    final mode = (first & 0xC0) >> 6;
    final width = (mode & 0x03) + 1;
    return width.clamp(1, 4);
  }

  /// Resolves path bytes to contact names, supporting multi-byte hash widths.

  /// Groups path bytes according to [hashByteWidth]:
  /// - 1: Single byte per hop (256 unique nodes)
  /// - 2: Two bytes per hop (65K unique nodes)
  /// - 3: Three bytes per hop (16M unique nodes)
  static String resolvePathNames(
    List<int> pathBytes,
    List<Contact> allContacts,
    int hashByteWidth,
  ) {
    if (pathBytes.isEmpty) return '';

    final parts = <String>[];

    for (final hopBytes in splitPathBytes(pathBytes, hashByteWidth)) {
      final hex = formatHopHex(hopBytes);

      // Find matching contacts by comparing public key prefix
      final matches = allContacts
          .where((c) {
            if (c.publicKey.length < hopBytes.length) return false;
            if (c.type != advTypeRepeater && c.type != advTypeRoom) return false;
            // Compare bytes using listEquals for multi-byte support
            return listEquals(
              c.publicKey.sublist(0, hopBytes.length),
              hopBytes,
            );
          })
          .toList();
      
      if (matches.isEmpty) {
        parts.add(hex);
      } else if (matches.length == 1) {
        parts.add(matches.first.name);
      } else {
        parts.add(matches.map((c) => c.name).join(' | '));
      }
    }
    
    return parts.join(' \u2192 ');
  }
}
