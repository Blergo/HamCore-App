import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hamcore/storage/channel_message_store.dart';
import 'package:hamcore/utils/platform_info.dart';
import 'package:hamcore/widgets/app_bar.dart';
import 'package:provider/provider.dart';

import '../connector/hamcore_connector.dart';
import '../l10n/l10n.dart';
import '../services/app_settings_service.dart';
import '../services/ui_view_state_service.dart';
import '../models/channel.dart';
import '../theme/mesh_theme.dart';
import '../utils/dialog_utils.dart';
import '../utils/disconnect_navigation_mixin.dart';
import '../utils/route_transitions.dart';
import '../widgets/list_filter_widget.dart';
import '../widgets/empty_state.dart';
import '../widgets/mesh_ui.dart';
import '../widgets/quick_switch_bar.dart';
import '../widgets/sync_progress_overlay.dart';
import '../widgets/unread_badge.dart';
import '../helpers/gif_helper.dart';
import '../helpers/snack_bar_builder.dart';
import 'channel_chat_screen.dart';
import 'contacts_screen.dart';
import 'map_screen.dart';
import 'settings_screen.dart';

class ChannelsScreen extends StatefulWidget {
  final bool hideBackButton;

  const ChannelsScreen({super.key, this.hideBackButton = false});

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen>
    with DisconnectNavigationMixin {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  ChannelMessageStore get _channelMessageStore => ChannelMessageStore();

  @override
  void initState() {
    super.initState();
    _searchController.text = context
        .read<UiViewStateService>()
        .channelsSearchText;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HamCoreConnector>().getChannels();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    final connector = context.watch<HamCoreConnector>();
    final viewState = context.watch<UiViewStateService>();

    final channelMessageStore = ChannelMessageStore();
    channelMessageStore.setPublicKeyHex = connector.selfPublicKeyHex;

    // Auto-navigate back to scanner if disconnected
    if (!checkConnectionAndNavigate(connector)) {
      return const SizedBox.shrink();
    }

    final allowBack = !connector.isConnected;

    return PopScope(
      canPop: allowBack,
      child: Scaffold(
        appBar: AppBar(
          title: AppBarTitle(context.l10n.channels_title),
          centerTitle: true,
          automaticallyImplyLeading: false,
          bottom: const SyncProgressAppBarBottom(),
          actions: [
            PopupMenuButton(
              // onTap handlers run after the menu route pops, so they must
              // capture the screen's context — not the itemBuilder's menu
              // context, which is deactivated by then.
              itemBuilder: (menuContext) => [
                PopupMenuItem(
                  child: Row(
                    children: [
                      Icon(
                        Icons.logout,
                        color: Theme.of(menuContext).colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Text(menuContext.l10n.common_disconnect),
                    ],
                  ),
                  onTap: () => _disconnect(context),
                ),
                PopupMenuItem(
                  child: Row(
                    children: [
                      const Icon(Icons.settings),
                      const SizedBox(width: 8),
                      Text(menuContext.l10n.settings_title),
                    ],
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  ),
                ),
              ],
              icon: const Icon(Icons.more_vert),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            await context.read<HamCoreConnector>().getChannels(force: true);
          },
          child: () {
            final channels = connector.channels;
            final waitingForFirstChannel =
                connector.isLoadingChannels && channels.isEmpty;

            // Only block the list while the first channel is actively loading.
            // If the initial sync aborts, show cached/partial channels instead
            // of trapping the user behind an idle spinner.
            if (waitingForFirstChannel) {
              return const Center(child: CircularProgressIndicator());
            }

            if (channels.isEmpty) {
              return ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height - 200,
                    child: EmptyState(
                      icon: Icons.tag,
                      title: context.l10n.channels_noChannelsConfigured,
                      action: FilledButton.icon(
                        onPressed: () => _addPublicChannel(context, connector),
                        icon: const Icon(Icons.public),
                        label: Text(context.l10n.channels_addPublicChannel),
                      ),
                    ),
                  ),
                ],
              );
            }

            final filteredChannels = _filterAndSortChannels(
              channels,
              connector,
              viewState,
            );

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: context.l10n.channels_searchChannels,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (viewState.channelsSearchText.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchDebounce?.cancel();
                                _searchDebounce = null;
                                _searchController.clear();
                                context
                                    .read<UiViewStateService>()
                                    .setChannelsSearchText('');
                              },
                            ),
                          _buildFilterButton(viewState),
                        ],
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (value) {
                      _searchDebounce?.cancel();
                      _searchDebounce = Timer(
                        const Duration(milliseconds: 300),
                        () {
                          if (!mounted) return;
                          context
                              .read<UiViewStateService>()
                              .setChannelsSearchText(value);
                        },
                      );
                    },
                  ),
                ),
                Expanded(
                  child: filteredChannels.isEmpty
                      ? LayoutBuilder(
                          builder: (context, constraints) => ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight,
                                ),
                                child: EmptyState(
                                  icon: Icons.search_off,
                                  title: context.l10n.channels_noChannelsFound,
                                ),
                              ),
                            ],
                          ),
                        )
                      : (viewState.channelsSortOption ==
                                ChannelSortOption.manual &&
                            viewState.channelsSearchText.isEmpty)
                      ? ReorderableListView.builder(
                          padding: const EdgeInsets.only(
                            left: 0,
                            right: 0,
                            top: 8,
                            bottom: 88,
                          ),
                          buildDefaultDragHandles: false,
                          itemCount: filteredChannels.length,
                          onReorderItem: (oldIndex, newIndex) {
                            final reordered = List<Channel>.from(
                              filteredChannels,
                            );
                            final item = reordered.removeAt(oldIndex);
                            reordered.insert(newIndex, item);
                            unawaited(
                              connector.setChannelOrder(
                                reordered.map((c) => c.index).toList(),
                              ),
                            );
                          },
                          itemBuilder: (context, index) {
                            final channel = filteredChannels[index];
                            return _buildChannelTile(
                              context,
                              connector,
                              channelMessageStore,
                              channel,
                              showDragHandle: true,
                              dragIndex: index,
                              listIndex: index,
                            );
                          },
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(
                            left: 0,
                            right: 0,
                            top: 8,
                            bottom: 88,
                          ),
                          itemCount: filteredChannels.length,
                          itemBuilder: (context, index) {
                            final channel = filteredChannels[index];
                            return _buildChannelTile(
                              context,
                              connector,
                              channelMessageStore,
                              channel,
                              listIndex: index,
                            );
                          },
                        ),
                ),
              ],
            );
          }(),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddChannelDialog(context),
          tooltip: context.l10n.channels_addChannel,
          child: const Icon(Icons.add),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: QuickSwitchBar(
            selectedIndex: 1,
            onDestinationSelected: (index) =>
                _handleQuickSwitch(index, context),
            contactsUnreadCount: connector.getTotalContactsUnreadCount(),
            channelsUnreadCount: connector.getTotalChannelsUnreadCount(),
          ),
        ),
      ),
    );
  }

  Widget _buildChannelTile(
    BuildContext context,
    HamCoreConnector connector,
    ChannelMessageStore channelMessageStore,
    Channel channel, {
    bool showDragHandle = false,
    int? dragIndex,
    int listIndex = 0,
  }) {
    final unreadCount = connector.getUnreadCountForChannel(channel);
    final isMuted = context.watch<AppSettingsService>().isChannelMuted(
      channel.name,
    );
    final scheme = Theme.of(context).colorScheme;

    // Determine icon and colors based on channel type
    final IconData icon = channel.isPublicChannel ? Icons.public : Icons.tag;
    final Color iconColor = channel.isPublicChannel
        ? MeshPalette.signal
        : MeshPalette.blue;
    // Only flood-routed channels carry a region; show it when one is set.
    final String subtitle = connector.hasChannelRegion(channel.index)
        ? context.l10n.channels_regionSetTo(
            connector.getChannelRegion(channel.index),
          )
        : '';

    // Last message preview
    final messages = connector.getChannelMessages(channel);
    final lastMessage = messages.isNotEmpty ? messages.last : null;
    final lastMessageText = lastMessage?.text ?? '';
    final lastPreview =
        lastMessageText.isNotEmpty &&
            GifHelper.parseGif(lastMessageText) != null
        ? context.l10n.chat_receivedGif
        : lastMessageText;
    final lastTime = lastMessage?.timestamp;

    final channelLabel = channel.name.isEmpty
        ? context.l10n.channels_channelIndex(channel.index)
        : channel.name;

    return ListEntrance(
      key: ValueKey('channel_entrance_${channel.index}'),
      index: dragIndex ?? listIndex,
      child: MeshCard(
        key: ValueKey('channel_${channel.index}'),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        onTap: () {
          HapticFeedback.selectionClick();
          final unread = connector.getUnreadCountForChannelIndex(channel.index);
          connector.markChannelRead(channel.index);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChannelChatScreen(
                channel: channel,
                initialUnreadCount: unread,
              ),
            ),
          );
        },
        onLongPress: () => _showChannelActions(
          this.context,
          connector,
          channelMessageStore,
          channel,
        ),
        onSecondaryTap: PlatformInfo.isDesktop
            ? () => _showChannelActions(
                this.context,
                connector,
                channelMessageStore,
                channel,
              )
            : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AvatarCircle(
              name: channelLabel,
              size: 42,
              color: iconColor,
              icon: icon,
            ),
            const SizedBox(width: 12),
            // Title + subtitle + ch chip
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          channelLabel,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'CH ${channel.index}',
                        style: MeshTheme.mono(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (lastPreview.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      lastPreview,
                      style: MeshTheme.mono(
                        fontSize: 11.5,
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Right side: time + unread badge + muted + drag handle
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (lastTime != null)
                  Text(
                    _relativeTime(lastTime),
                    style: MeshTheme.mono(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isMuted) ...[
                      Icon(
                        Icons.notifications_off,
                        size: 14,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                    ],
                    if (unreadCount > 0) UnreadBadge(count: unreadCount),
                  ],
                ),
              ],
            ),
            if (showDragHandle && dragIndex != null) ...[
              const SizedBox(width: 4),
              ReorderableDragStartListener(
                index: dragIndex,
                // Top-aligned with the "CH n" / time line. Bottom padding keeps
                // a comfortable drag target without pushing the icon down.
                child: Padding(
                  padding: const EdgeInsets.only(left: 8, right: 8, bottom: 16),
                  child: Icon(
                    Icons.drag_handle,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showChannelActions(
    BuildContext context,
    HamCoreConnector connector,
    ChannelMessageStore channelMessageStore,
    Channel channel,
  ) {
    final parentContext = context;
    final settingsService = context.read<AppSettingsService>();
    final isMuted = settingsService.isChannelMuted(channel.name);

    showModalBottomSheet(
      context: parentContext,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(sheetContext.l10n.channels_editChannel),
              onTap: () async {
                Navigator.pop(sheetContext);
                await Future.delayed(const Duration(milliseconds: 100));
                if (parentContext.mounted) {
                  _showEditChannelDialog(parentContext, connector, channel);
                }
              },
            ),
            ListTile(
              leading: Icon(
                isMuted
                    ? Icons.notifications_outlined
                    : Icons.notifications_off_outlined,
              ),
              title: Text(
                isMuted
                    ? sheetContext.l10n.channels_unmuteChannel
                    : sheetContext.l10n.channels_muteChannel,
              ),
              onTap: () async {
                Navigator.pop(sheetContext);
                if (isMuted) {
                  await settingsService.unmuteChannel(channel.name);
                } else {
                  await settingsService.muteChannel(channel.name);
                }
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(sheetContext).colorScheme.error,
              ),
              title: Text(
                sheetContext.l10n.channels_deleteChannel,
                style: TextStyle(
                  color: Theme.of(sheetContext).colorScheme.error,
                ),
              ),
              onTap: () async {
                Navigator.pop(sheetContext);
                await Future.delayed(const Duration(milliseconds: 100));
                if (parentContext.mounted) {
                  _confirmDeleteChannel(
                    parentContext,
                    connector,
                    channelMessageStore,
                    channel,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _handleQuickSwitch(int index, BuildContext context) {
    if (index == 1) return;
    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          buildQuickSwitchRoute(const ContactsScreen(hideBackButton: true)),
        );
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          buildQuickSwitchRoute(const MapScreen(hideBackButton: true)),
        );
        break;
    }
  }

  Future<void> _disconnect(BuildContext context) async {
    final connector = context.read<HamCoreConnector>();
    await showDisconnectDialog(context, connector);
  }

  Widget _buildFilterButton(UiViewStateService viewState) {
    return SortFilterMenu<ChannelSortOption>(
      tooltip: context.l10n.listFilter_tooltip,
      sections: [
        SortFilterMenuSection<ChannelSortOption>(
          title: context.l10n.channels_sortBy,
          options: [
            SortFilterMenuOption<ChannelSortOption>(
              value: ChannelSortOption.manual,
              label: context.l10n.channels_sortManual,
              checked: viewState.channelsSortOption == ChannelSortOption.manual,
            ),
            SortFilterMenuOption<ChannelSortOption>(
              value: ChannelSortOption.name,
              label: context.l10n.channels_sortAZ,
              checked: viewState.channelsSortOption == ChannelSortOption.name,
            ),
            SortFilterMenuOption<ChannelSortOption>(
              value: ChannelSortOption.latestMessages,
              label: context.l10n.channels_sortLatestMessages,
              checked:
                  viewState.channelsSortOption ==
                  ChannelSortOption.latestMessages,
            ),
            SortFilterMenuOption<ChannelSortOption>(
              value: ChannelSortOption.unread,
              label: context.l10n.channels_sortUnread,
              checked: viewState.channelsSortOption == ChannelSortOption.unread,
            ),
          ],
        ),
      ],
      onSelected: (sortOption) {
        viewState.setChannelsSortOption(sortOption);
      },
    );
  }

  List<Channel> _filterAndSortChannels(
    List<Channel> channels,
    HamCoreConnector connector,
    UiViewStateService viewState,
  ) {
    var filtered = channels.where((channel) {
      if (viewState.channelsSearchText.isEmpty) return true;
      final label = _normalizeChannelName(channel);
      return label.toLowerCase().contains(
        viewState.channelsSearchText.toLowerCase(),
      );
    }).toList();

    int compareByName(Channel a, Channel b) {
      final nameA = _normalizeChannelName(a);
      final nameB = _normalizeChannelName(b);
      return nameA.toLowerCase().compareTo(nameB.toLowerCase());
    }

    switch (viewState.channelsSortOption) {
      case ChannelSortOption.manual:
        break;
      case ChannelSortOption.latestMessages:
        filtered.sort((a, b) {
          final aMessages = connector.getChannelMessages(a);
          final bMessages = connector.getChannelMessages(b);
          final aLast = aMessages.isEmpty
              ? DateTime(1970)
              : aMessages.last.timestamp;
          final bLast = bMessages.isEmpty
              ? DateTime(1970)
              : bMessages.last.timestamp;
          final timeCompare = bLast.compareTo(aLast);
          if (timeCompare != 0) return timeCompare;
          return compareByName(a, b);
        });
        break;
      case ChannelSortOption.unread:
        filtered.sort((a, b) {
          final aUnread = connector.getUnreadCountForChannel(a);
          final bUnread = connector.getUnreadCountForChannel(b);
          final unreadCompare = bUnread.compareTo(aUnread);
          if (unreadCompare != 0) return unreadCompare;
          return compareByName(a, b);
        });
        break;
      case ChannelSortOption.name:
        filtered.sort(compareByName);
        break;
    }

    return filtered;
  }

  String _normalizeChannelName(Channel channel) {
    if (channel.name.isEmpty) {
      return 'Channel ${channel.index}'; // Fallback for sorting
    }
    final trimmed = channel.name.trim();
    if (trimmed.startsWith('#') && trimmed.length > 1) {
      return trimmed.substring(1);
    }
    return trimmed;
  }

  void _showAddChannelDialog(BuildContext context) {
    final connector = context.read<HamCoreConnector>();
    final nextIndex = _findNextAvailableIndex(
      connector.channels,
      connector.maxChannels,
    );
    final hasPublicChannel = connector.channels.any((c) => c.isPublicChannel);
    int? selectedOption;
    final hashtagController = TextEditingController();

    showMeshSheet(
      context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          Widget buildOptionCard({
            required int optionIndex,
            required IconData icon,
            required String title,
            required String subtitle,
            bool enabled = true,
          }) {
            final isSelected = selectedOption == optionIndex;
            final cardScheme = Theme.of(sheetContext).colorScheme;
            return MeshCard(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              borderColor: isSelected && enabled ? MeshPalette.blueLine : null,
              color: isSelected && enabled ? MeshPalette.blueBg : null,
              onTap: enabled
                  ? () {
                      setSheetState(() {
                        selectedOption = optionIndex;
                        hashtagController.clear();
                      });
                    }
                  : null,
              child: Row(
                children: [
                  AvatarCircle(
                    name: title,
                    size: 38,
                    color: enabled
                        ? (isSelected
                              ? MeshPalette.blue
                              : cardScheme.onSurfaceVariant)
                        : cardScheme.outline,
                    icon: icon,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: Theme.of(sheetContext).textTheme.bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: enabled ? null : cardScheme.outline,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: Theme.of(sheetContext).textTheme.bodySmall
                              ?.copyWith(
                                color: enabled
                                    ? cardScheme.onSurfaceVariant
                                    : cardScheme.outline,
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (enabled)
                    Icon(
                      Icons.chevron_right,
                      color: isSelected
                          ? MeshPalette.blue
                          : cardScheme.onSurfaceVariant,
                      size: 20,
                    ),
                ],
              ),
            );
          }

          Widget? buildExpandedContent(
            ChannelMessageStore channelMessageStore,
          ) {
            switch (selectedOption) {
              case 0: // Join Public Channel
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            final psk = Channel.parsePskHex(
                              Channel.publicChannelPsk,
                            );
                            Navigator.pop(sheetContext);
                            connector.setChannel(
                              nextIndex,
                              context.l10n.channels_public,
                              psk,
                            );
                            if (context.mounted) {
                              showDismissibleSnackBar(
                                context,
                                content: Text(
                                  context.l10n.channels_publicChannelAdded,
                                ),
                              );
                            }
                          },
                          child: Text(sheetContext.l10n.common_add),
                        ),
                      ),
                    ],
                  ),
                );

              case 1: // Add Channel (name-derived, joins if it already exists)
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: TextField(
                        controller: hashtagController,
                        decoration: InputDecoration(
                          labelText: sheetContext.l10n.channels_enterHashtag,
                          hintText: sheetContext.l10n.channels_hashtagHint,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.tag),
                        ),
                        maxLength: 31,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                var hashtag = hashtagController.text.trim();
                                if (hashtag.isEmpty) {
                                  showDismissibleSnackBar(
                                    context,
                                    content: Text(
                                      sheetContext
                                          .l10n
                                          .channels_enterChannelName,
                                    ),
                                  );
                                  return;
                                }

                                // Normalize hashtag name (remove leading # if present)
                                if (hashtag.startsWith('#')) {
                                  hashtag = hashtag.substring(1);
                                }
                                final channelName = '#$hashtag';
                                final psk = Channel.derivePskFromHashtag(
                                  hashtag,
                                );

                                Navigator.pop(sheetContext);
                                connector.setChannel(
                                  nextIndex,
                                  channelName,
                                  psk,
                                );
                                if (context.mounted) {
                                  showDismissibleSnackBar(
                                    context,
                                    content: Text(
                                      context.l10n.channels_channelAdded(
                                        channelName,
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: Text(sheetContext.l10n.common_add),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );

              default:
                return null;
            }
          }

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.7,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            builder: (_, scrollController) => Column(
              children: [
                BottomSheetHeader(title: sheetContext.l10n.channels_addChannel),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      if (!hasPublicChannel) ...[
                        buildOptionCard(
                          optionIndex: 0,
                          icon: Icons.public,
                          title: sheetContext.l10n.channels_joinPublicChannel,
                          subtitle:
                              sheetContext.l10n.channels_joinPublicChannelDesc,
                        ),
                        if (selectedOption == 0)
                          buildExpandedContent(_channelMessageStore)!,
                      ],
                      buildOptionCard(
                        optionIndex: 1,
                        icon: Icons.tag,
                        title: sheetContext.l10n.channels_joinHashtagChannel,
                        subtitle:
                            sheetContext.l10n.channels_joinHashtagChannelDesc,
                      ),
                      if (selectedOption == 1)
                        buildExpandedContent(_channelMessageStore)!,
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showEditChannelDialog(
    BuildContext context,
    HamCoreConnector connector,
    Channel channel,
  ) {
    final appSettingsService = Provider.of<AppSettingsService>(
      context,
      listen: false,
    );
    final nameController = TextEditingController(text: channel.name);
    bool smazEnabled = connector.isChannelSmazEnabled(channel.index);
    bool cyr2latEnabled = connector.isChannelCyr2LatEnabled(channel.index);
    String? selectedCyr2LatProfileId = connector.getChannelCyr2LatProfileId(
      channel.index,
    );

    showMeshSheet(
      context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (_, scrollController) => Column(
            children: [
              BottomSheetHeader(
                title: sheetContext.l10n.channels_editChannelTitle(
                  channel.index,
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: sheetContext.l10n.channels_channelName,
                        border: const OutlineInputBorder(),
                      ),
                      maxLength: 31,
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(sheetContext.l10n.channels_smazCompression),
                      value: smazEnabled,
                      onChanged: (value) => setSheetState(() {
                        smazEnabled = value;
                        if (smazEnabled) {
                          cyr2latEnabled = false;
                        }
                      }),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        sheetContext.l10n.channels_cyr2latCompression,
                      ),
                      subtitle: Text(
                        sheetContext.l10n.channels_cyr2latCompressionDscr,
                      ),
                      value: cyr2latEnabled,
                      onChanged: (value) => setSheetState(() {
                        cyr2latEnabled = value;
                        if (cyr2latEnabled) {
                          smazEnabled = false;
                        }
                      }),
                    ),
                    if (cyr2latEnabled) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedCyr2LatProfileId,
                          decoration: InputDecoration(
                            labelText: sheetContext
                                .l10n
                                .channels_cyr2latSettingsSubheading,
                            border: const OutlineInputBorder(),
                          ),
                          items: appSettingsService.settings.cyr2latProfiles
                              .map((profile) {
                                return DropdownMenuItem(
                                  value: profile.id,
                                  child: Text(profile.name),
                                );
                              })
                              .toList(),
                          onChanged: (value) => setSheetState(() {
                            selectedCyr2LatProfileId = value;
                          }),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: Text(sheetContext.l10n.common_cancel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          final name = nameController.text.trim();
                          final psk = channel.isPublicChannel
                              ? Channel.parsePskHex(Channel.publicChannelPsk)
                              : Channel.derivePskFromHashtag(name);

                          Navigator.pop(sheetContext);
                          try {
                            await connector.setChannel(
                              channel.index,
                              name,
                              psk,
                            );
                            await connector.setChannelSmazEnabled(
                              channel.index,
                              smazEnabled,
                            );
                            await connector.setChannelCyr2LatEnabled(
                              channel.index,
                              cyr2latEnabled,
                            );
                            await connector.setChannelCyr2LatProfileId(
                              channel.index,
                              selectedCyr2LatProfileId,
                            );
                            if (!context.mounted) return;
                            showDismissibleSnackBar(
                              context,
                              content: Text(
                                context.l10n.channels_channelUpdated(name),
                              ),
                            );
                          } catch (e, st) {
                            debugPrint(st.toString());
                            if (!context.mounted) return;
                            showDismissibleSnackBar(
                              context,
                              content: Text(
                                context.l10n.channels_channelUpdateFailed('$e'),
                              ),
                            );
                          }
                        },
                        child: Text(sheetContext.l10n.common_save),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteChannel(
    BuildContext context,
    HamCoreConnector connector,
    ChannelMessageStore channelMessageStore,
    Channel channel,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.channels_deleteChannel),
        content: Text(
          dialogContext.l10n.channels_deleteChannelConfirm(channel.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(dialogContext.l10n.common_cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await connector.deleteChannel(channel.index);

                await channelMessageStore.clearChannelMessages(channel.index);

                if (!context.mounted) return;

                showDismissibleSnackBar(
                  context,
                  content: Text(
                    context.l10n.channels_channelDeleted(channel.name),
                  ),
                );
              } catch (e, st) {
                if (!context.mounted) return;

                showDismissibleSnackBar(
                  context,
                  content: Text(
                    context.l10n.channels_channelDeleteFailed(channel.name),
                  ),
                );

                // Preserve existing logging (if it was there)
                debugPrint('Failed to delete channel: $e\n$st');
              }
            },
            child: Text(
              dialogContext.l10n.common_delete,
              style: TextStyle(
                color: Theme.of(dialogContext).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addPublicChannel(BuildContext context, HamCoreConnector connector) {
    final psk = Channel.parsePskHex(Channel.publicChannelPsk);
    connector.setChannel(0, context.l10n.channels_public, psk);
    showDismissibleSnackBar(
      context,
      content: Text(context.l10n.channels_publicChannelAdded),
    );
  }

  int _findNextAvailableIndex(List<Channel> channels, int maxChannels) {
    final usedIndices = channels.map((c) => c.index).toSet();
    for (int i = 0; i < maxChannels; i++) {
      if (!usedIndices.contains(i)) return i;
    }
    return 0;
  }

}
