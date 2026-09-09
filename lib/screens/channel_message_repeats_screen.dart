import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../connector/hamcore_connector.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n.dart';
import '../models/channel_message.dart';
import '../theme/mesh_theme.dart';
import '../widgets/adaptive_app_bar_title.dart';
import '../widgets/mesh_ui.dart';
import '../widgets/path_hop_timeline.dart';

/// Lists every repeater that echoed an outgoing channel message back, one
/// single-hop timeline per repeater - unlike the incoming-message path
/// screen, there's no single "primary" path here: each observed path is an
/// independent repeater that heard the transmission, all equally relevant.
class ChannelMessageRepeatsScreen extends StatelessWidget {
  final ChannelMessage message;

  const ChannelMessageRepeatsScreen({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Consumer<HamCoreConnector>(
      builder: (context, connector, _) {
        final l10n = context.l10n;
        final hashByteWidth =
            (message.pathHashWidth ?? connector.pathHashByteWidth)
                .clamp(1, 4)
                .toInt();
        final variants = message.pathVariants.isNotEmpty
            ? message.pathVariants
            : (message.pathBytes.isNotEmpty
                  ? [message.pathBytes]
                  : const <Uint8List>[]);

        return Scaffold(
          appBar: AppBar(title: AdaptiveAppBarTitle(l10n.channelRepeats_title)),
          body: SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildSummaryCard(context, l10n),
                const SizedBox(height: 16),
                SectionHeader(
                  l10n.channelRepeats_heardBy,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                ),
                if (variants.isEmpty)
                  _buildNoRepeatsCard(context, l10n)
                else
                  for (final variant in variants) ...[
                    buildHopTimeline(
                      context,
                      buildPathHops(variant, connector, l10n, hashByteWidth),
                      l10n,
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                  ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(BuildContext context, AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    return MeshCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            l10n.channelPath_messageDetails,
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 10),
          _buildDetailRow(
            context,
            l10n.channelPath_senderLabel,
            message.senderName,
            scheme: scheme,
          ),
          _buildDetailRow(
            context,
            l10n.channelPath_repeatsLabel,
            message.repeatCount.toString(),
            scheme: scheme,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    required ColorScheme scheme,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label.toUpperCase(),
              style: MeshTheme.accentLabel(color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildNoRepeatsCard(BuildContext context, AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    return MeshCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(Icons.repeat, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.channelRepeats_none,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
