import 'package:flutter_test/flutter_test.dart';
import 'package:hamcore/connector/hamcore_connector.dart';

void main() {
  group('shouldIgnoreLateTcpConnectError', () {
    test('returns true for manual cancel during disconnecting state', () {
      final result = HamCoreConnector.shouldIgnoreLateTcpConnectError(
        manualDisconnect: true,
        state: HamCoreConnectionState.disconnecting,
        activeTransport: HamCoreTransportType.bluetooth,
        tcpManagerConnected: false,
      );

      expect(result, isTrue);
    });

    test(
      'returns true for manual cancel after reaching disconnected state',
      () {
        final result = HamCoreConnector.shouldIgnoreLateTcpConnectError(
          manualDisconnect: true,
          state: HamCoreConnectionState.disconnected,
          activeTransport: HamCoreTransportType.bluetooth,
          tcpManagerConnected: false,
        );

        expect(result, isTrue);
      },
    );

    test('returns false when not a manual disconnect', () {
      final result = HamCoreConnector.shouldIgnoreLateTcpConnectError(
        manualDisconnect: false,
        state: HamCoreConnectionState.disconnecting,
        activeTransport: HamCoreTransportType.bluetooth,
        tcpManagerConnected: false,
      );

      expect(result, isFalse);
    });

    test('returns false for connected state handshake failures', () {
      final result = HamCoreConnector.shouldIgnoreLateTcpConnectError(
        manualDisconnect: true,
        state: HamCoreConnectionState.connected,
        activeTransport: HamCoreTransportType.tcp,
        tcpManagerConnected: true,
      );

      expect(result, isFalse);
    });

    test('returns false when TCP is still active while disconnecting', () {
      final result = HamCoreConnector.shouldIgnoreLateTcpConnectError(
        manualDisconnect: true,
        state: HamCoreConnectionState.disconnecting,
        activeTransport: HamCoreTransportType.tcp,
        tcpManagerConnected: true,
      );

      expect(result, isFalse);
    });
  });

  group('shouldResetStateAfterTcpConnectAbort', () {
    test('returns true when TCP connect is still in connecting state', () {
      final result = HamCoreConnector.shouldResetStateAfterTcpConnectAbort(
        state: HamCoreConnectionState.connecting,
        activeTransport: HamCoreTransportType.tcp,
      );

      expect(result, isTrue);
    });

    test('returns false when state is already disconnected', () {
      final result = HamCoreConnector.shouldResetStateAfterTcpConnectAbort(
        state: HamCoreConnectionState.disconnected,
        activeTransport: HamCoreTransportType.tcp,
      );

      expect(result, isFalse);
    });

    test('returns false when transport switched away from TCP', () {
      final result = HamCoreConnector.shouldResetStateAfterTcpConnectAbort(
        state: HamCoreConnectionState.connecting,
        activeTransport: HamCoreTransportType.bluetooth,
      );

      expect(result, isFalse);
    });
  });
}
