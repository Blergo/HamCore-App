import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:hamcore/helpers/path_helper.dart';

import '../connector/hamcore_connector.dart';
import '../helpers/path_hop_resolver.dart';
import '../l10n/app_localizations.dart';
import '../models/contact.dart';
import '../theme/mesh_theme.dart';
import 'mesh_ui.dart';

/// A single resolved hop along an observed path, shared by the message-path
/// detail/map screens and the per-repeater repeats screen.
class PathHop {
  final int index;
  final int prefix;
  final Contact? contact;
  final LatLng? position;
  final AppLocalizations l10n;
  final Uint8List? hopBytes;

  const PathHop({
    required this.index,
    required this.prefix,
    required this.contact,
    required this.position,
    required this.l10n,
    this.hopBytes,
  });

  bool get hasLocation => position != null;

  String get displayLabel {
    final prefixLabel = hopBytes != null && hopBytes!.isNotEmpty
        ? hopBytes!
              .map((b) => b.toRadixString(16).padLeft(2, '0'))
              .join('')
              .toUpperCase()
        : formatPrefix(prefix);
    return '($prefixLabel) ${resolveHopName(contact, l10n)}';
  }
}

String formatPrefix(int prefix) {
  return prefix.toRadixString(16).padLeft(2, '0').toUpperCase();
}

String resolveHopName(Contact? contact, AppLocalizations l10n) {
  if (contact == null) return l10n.channelPath_unknownRepeater;
  final name = contact.name.trim();
  if (name.isEmpty || name.toLowerCase() == 'unknown') {
    return l10n.channelPath_unknownRepeater;
  }
  return name;
}

LatLng? _resolvePosition(Contact? contact) {
  if (contact == null) return null;
  if (!contact.hasLocation) return null;
  final latitude = contact.latitude;
  final longitude = contact.longitude;
  if (latitude == null || longitude == null) return null;
  return LatLng(latitude, longitude);
}

List<PathHop> buildPathHops(
  Uint8List pathBytes,
  HamCoreConnector connector,
  AppLocalizations l10n,
  int hashByteWidth, {
  bool resolveFromEnd = false,
}) {
  if (pathBytes.isEmpty) return const [];
  final width = hashByteWidth.clamp(1, 4).toInt();
  final endpoint =
      (connector.selfLatitude != null && connector.selfLongitude != null)
      ? LatLng(connector.selfLatitude!, connector.selfLongitude!)
      : null;
  final resolvedContacts = PathHopResolver.resolve(
    pathBytes: pathBytes,
    contacts: connector.allContacts,
    endpoint: endpoint,
    resolveFromEnd: resolveFromEnd,
    pathHashByteWidth: width,
  );

  final hopChunks = PathHelper.splitPathBytes(pathBytes, width);
  final hops = <PathHop>[];
  for (var i = 0; i < hopChunks.length; i++) {
    final hopBytes = hopChunks[i];
    final contact = i < resolvedContacts.length ? resolvedContacts[i] : null;
    final resolvedPosition = _resolvePosition(contact);
    hops.add(
      PathHop(
        index: i + 1,
        prefix: hopBytes.isNotEmpty ? hopBytes[0] : 0,
        contact: contact,
        position: resolvedPosition,
        l10n: l10n,
        hopBytes: hopBytes,
      ),
    );
  }
  return hops;
}

/// Renders a vertical timeline of resolved hops, one avatar+label per node.
Widget buildHopTimeline(
  BuildContext context,
  List<PathHop> hops,
  AppLocalizations l10n,
) {
  if (hops.isEmpty) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Column(
      children: [
        for (int i = 0; i < hops.length; i++)
          ListEntrance(
            index: i,
            child: _buildTimelineNode(
              context,
              hops[i],
              l10n,
              isLast: i == hops.length - 1,
            ),
          ),
      ],
    ),
  );
}

Widget _buildTimelineNode(
  BuildContext context,
  PathHop hop,
  AppLocalizations l10n, {
  required bool isLast,
}) {
  final scheme = Theme.of(context).colorScheme;
  final hexPrefix = formatPrefix(hop.prefix);
  final locationText = hop.hasLocation
      ? '${hop.position!.latitude.toStringAsFixed(5)}, '
            '${hop.position!.longitude.toStringAsFixed(5)}'
      : l10n.channelPath_noLocationData;

  return IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 48,
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AvatarCircle(name: hop.displayLabel, size: 36),
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: MeshPalette.blueDim,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: scheme.surfaceContainerLow,
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        hop.index.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: MeshPalette.blueLine,
                  ),
                )
              else
                const SizedBox(height: 12),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16, top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hop.displayLabel,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  hexPrefix,
                  style: MeshTheme.mono(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  locationText,
                  style: MeshTheme.mono(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
