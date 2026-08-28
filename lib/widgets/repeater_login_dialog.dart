import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/contact.dart';
import '../l10n/contact_localization.dart';
import '../connector/hamcore_connector.dart';
import '../connector/hamcore_protocol.dart';
import '../theme/mesh_theme.dart';
import '../widgets/mesh_ui.dart';
import '../utils/app_logger.dart';
import 'routing_sheet.dart';

class RepeaterLoginDialog extends StatefulWidget {
  final Contact repeater;
  final Function(String password, bool isAdmin) onLogin;

  const RepeaterLoginDialog({
    super.key,
    required this.repeater,
    required this.onLogin,
  });

  @override
  State<RepeaterLoginDialog> createState() => _RepeaterLoginDialogState();
}

class _RepeaterLoginDialogState extends State<RepeaterLoginDialog> {
  late HamCoreConnector _connector;
  bool _isLoggingIn = false;
  int _currentAttempt = 0;
  static const int _maxAttempts = 5;
  String? _loginError;

  @override
  void initState() {
    super.initState();
    _connector = Provider.of<HamCoreConnector>(context, listen: false);
  }

  int _resolveRepeaterIndex = -1;
  Contact _resolveRepeater(HamCoreConnector connector) {
    if (_resolveRepeaterIndex >= 0 &&
        _resolveRepeaterIndex < connector.contacts.length &&
        connector.contacts[_resolveRepeaterIndex].publicKeyHex ==
            widget.repeater.publicKeyHex) {
      return connector.contacts[_resolveRepeaterIndex];
    }
    _resolveRepeaterIndex = connector.contacts.indexWhere(
      (c) => c.publicKeyHex == widget.repeater.publicKeyHex,
    );
    if (_resolveRepeaterIndex == -1) {
      return widget.repeater;
    }
    return connector.contacts[_resolveRepeaterIndex];
  }

  // Guest access is granted unconditionally by the firmware now (no password
  // check at all) - this just asks for it via ANON_REQ_TYPE_LOGIN_GUEST
  // instead of the old password-based CMD_SEND_LOGIN. The reply is still the
  // same PUSH_CODE_LOGIN_SUCCESS/FAIL push the app has always listened for,
  // so _awaitLoginResponse below is unchanged.
  Future<void> _handleGuestLogin() async {
    if (_isLoggingIn) return;

    setState(() {
      _isLoggingIn = true;
      _currentAttempt = 0;
      _loginError = null;
    });

    try {
      final repeater = _resolveRepeater(_connector);
      appLogger.info(
        'Guest login started for ${repeater.name} (${repeater.publicKeyHex})',
        tag: 'RepeaterLogin',
      );
      final selection = await _connector.preparePathForContactSend(repeater);
      final loginFrame = buildSendLoginAnonReqFrame(
        repeater.publicKey,
        requestType: anonReqTypeLoginGuest,
      );
      final pathLengthValue = selection.useFlood ? -1 : selection.hopCount;
      final responseBytes = loginFrame.length > maxFrameSize
          ? loginFrame.length
          : maxFrameSize;
      final timeoutMs = _connector.calculateTimeout(
        pathLength: pathLengthValue,
        messageBytes: responseBytes,
      );
      final timeoutSeconds = (timeoutMs / 1000).ceil();
      final timeout = Duration(milliseconds: timeoutMs + 2000);
      final selectionLabel = selection.useFlood
          ? 'flood'
          : '${selection.hopCount} hops';
      appLogger.info('Login routing: $selectionLabel', tag: 'RepeaterLogin');
      bool? loginResult;
      bool isAdmin = false;
      for (int attempt = 0; attempt < _maxAttempts; attempt++) {
        if (!mounted) return;
        setState(() {
          _currentAttempt = attempt + 1;
        });

        appLogger.info(
          'Sending guest login attempt ${attempt + 1}/$_maxAttempts',
          tag: 'RepeaterLogin',
        );
        await _connector.sendFrame(loginFrame);

        (loginResult, isAdmin) = await _awaitLoginResponse(timeout);
        if (loginResult == true) {
          appLogger.info(
            'Guest login succeeded for ${repeater.name}',
            tag: 'RepeaterLogin',
          );
          break;
        }
        if (loginResult == false) {
          appLogger.warn(
            'Guest login failed for ${repeater.name}',
            tag: 'RepeaterLogin',
          );
          break;
        }
        appLogger.warn(
          'Guest login attempt ${attempt + 1} timed out after ${timeoutSeconds}s',
          tag: 'RepeaterLogin',
        );
      }

      if (loginResult == true) {
        _connector.recordRepeaterPathResult(repeater, selection, true, null);
      } else {
        _connector.recordRepeaterPathResult(repeater, selection, false, null);
      }

      if (loginResult != true) {
        if (mounted) {
          setState(() {
            _isLoggingIn = false;
            _loginError = context.l10n.login_failedMessage;
          });
        }
        return;
      }

      if (mounted) {
        Navigator.pop(context);
        Future.microtask(() => widget.onLogin('', isAdmin));
      }
    } catch (e) {
      final repeater = _resolveRepeater(_connector);
      appLogger.warn(
        'Guest login error for ${repeater.name}: $e',
        tag: 'RepeaterLogin',
      );
      if (mounted) {
        setState(() {
          _isLoggingIn = false;
          _loginError = context.l10n.login_failedMessage;
        });
      }
    }
  }

  // _awaitLoginResponse returns a record of bool, for success and if the client is an admin
  Future<(bool?, bool)> _awaitLoginResponse(Duration timeout) async {
    final completer = Completer<bool?>();
    Timer? timer;
    StreamSubscription<Uint8List>? subscription;
    final targetPrefix = widget.repeater.publicKey.sublist(0, 6);
    bool isAdmin = false;
    subscription = _connector.receivedFrames.listen((frame) {
      if (frame.isEmpty) return;
      final code = frame[0];
      if (code != pushCodeLoginSuccess && code != pushCodeLoginFail) return;
      if (frame.length < 8) return;
      isAdmin = (frame[1] == 1);
      final prefix = frame.sublist(2, 8);
      if (!listEquals(prefix, targetPrefix)) return;

      completer.complete(code == pushCodeLoginSuccess);
      subscription?.cancel();
      timer?.cancel();
    });

    timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.complete(null);
        subscription?.cancel();
      }
    });

    final result = await completer.future;
    timer.cancel();
    await subscription.cancel();
    return (result, isAdmin);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final connector = context.watch<HamCoreConnector>();
    final repeater = _resolveRepeater(connector);
    final isFloodMode = repeater.pathOverride == -1;
    return AlertDialog(
      title: Row(
        children: [
          AvatarCircle(
            name: repeater.name,
            size: 40,
            color: MeshPalette.warn,
            icon: Icons.cell_tower,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.login_repeaterLogin,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  repeater.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.normal,
                    color: scheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.login_repeaterDescription,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            if (_loginError != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error, size: 18, color: scheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _loginError!,
                      style: TextStyle(color: scheme.error, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLoggingIn ? null : _handleGuestLogin,
                icon: _isLoggingIn
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: scheme.onSurfaceVariant,
                        ),
                      )
                    : const Icon(Icons.visibility, size: 18),
                label: Text(
                  _isLoggingIn
                      ? l10n.login_attempt(_currentAttempt, _maxAttempts)
                      : l10n.repeater_guestAccess,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.admin_panel_settings, size: 18),
                label: Text(l10n.repeater_adminAccess),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.login_repeaterAccessUnavailable,
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const Divider(),
            Row(
              children: [
                Text(
                  l10n.login_routing,
                  style: MeshTheme.accentLabel(
                    color: scheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  icon: Icon(isFloodMode ? Icons.waves : Icons.route),
                  tooltip: l10n.login_routingMode,
                  onSelected: (mode) async {
                    if (mode == 'flood') {
                      await connector.setPathOverride(repeater, pathLen: -1);
                    } else {
                      await connector.setPathOverride(repeater, pathLen: null);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'auto',
                      child: Row(
                        children: [
                          Icon(
                            Icons.auto_mode,
                            size: 20,
                            color: !isFloodMode ? scheme.primary : null,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.login_autoUseSavedPath,
                            style: TextStyle(
                              fontWeight: !isFloodMode
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'flood',
                      child: Row(
                        children: [
                          Icon(
                            Icons.waves,
                            size: 20,
                            color: isFloodMode ? scheme.primary : null,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.login_forceFloodMode,
                            style: TextStyle(
                              fontWeight: isFloodMode
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              repeater.pathLabel(
                context.l10n,
                pathHashByteWidth: connector.pathHashByteWidth,
              ),
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () =>
                    ContactRoutingSheet.show(context, contact: repeater),
                icon: const Icon(Icons.timeline, size: 18),
                label: Text(l10n.login_managePaths),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.common_cancel),
        ),
      ],
    );
  }
}
