import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/contact.dart';
import '../l10n/contact_localization.dart';
import '../connector/hamcore_connector.dart';
import '../theme/mesh_theme.dart';
import '../widgets/mesh_ui.dart';
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
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.visibility, size: 18),
                label: Text(l10n.repeater_guestAccess),
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
