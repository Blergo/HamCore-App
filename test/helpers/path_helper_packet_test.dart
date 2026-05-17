import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshcore_open/helpers/path_helper.dart';

void main() {
  test('detectPathHashWidth identifies 1,2,3,4-byte widths from first byte', () {
    // mode 0 -> width 1 (00xxxxxx)
    expect(PathHelper.detectPathHashWidth([0x12]), equals(1));

    // mode 1 -> width 2 (01xxxxxx)
    expect(PathHelper.detectPathHashWidth([0x40]), equals(2));
    expect(PathHelper.detectPathHashWidth([0x7F]), equals(2));

    // mode 2 -> width 3 (10xxxxxx)
    expect(PathHelper.detectPathHashWidth([0x80]), equals(3));

    // mode 3 -> width 4 (11xxxxxx)
    expect(PathHelper.detectPathHashWidth([0xC0]), equals(4));
  });

  test('packet-aware split uses detected width vs fallback', () {
    // Packet has mode=0 (1-byte hops) but fallback is 2
    final packet = [0x01, 0x02, 0x03];
    final detected = PathHelper.detectPathHashWidth(packet, fallback: 2);
    expect(detected, equals(1));

    final hops = PathHelper.splitPathBytes(packet, detected);
    expect(hops, hasLength(3));
    expect(hops.first, equals(Uint8List.fromList([0x01])));

    // Packet with mode=1 (2-byte hops)
    final packet2 = [0x40, 0xAA, 0xBB, 0xCC];
    final detected2 = PathHelper.detectPathHashWidth(packet2, fallback: 1);
    expect(detected2, equals(2));
    final hops2 = PathHelper.splitPathBytes(packet2, detected2);
    expect(hops2, hasLength(2));
    expect(hops2.first, equals(Uint8List.fromList([0x40, 0xAA])));
  });
}
