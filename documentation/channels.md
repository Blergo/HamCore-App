# Channels

## Overview

Channels are broadcast group-chat spaces identified by a 16-byte pre-shared key (PSK). Any device with the same channel index and PSK will receive and decode channel messages. Unlike direct messages, channel messages are broadcast to the entire mesh. HamCore firmware transmits channel payloads in plain text (no over-the-air encryption), to stay compliant with amateur radio licensing rules — the PSK is a channel identifier, not a privacy mechanism.

The number of active channels is determined by the firmware (default 40); the device reports its actual limit at login.

## How to Access

QuickSwitchBar tab 1 (middle) from any main screen.

## Channel Types

| Type | Icon | Color | Description |
|---|---|---|---|
| Public | Globe | Green | Fixed well-known PSK; any device can join |
| Hashtag | Hash tag | Blue | PSK derived from the channel name via SHA-256; the same name always derives the same channel, so this doubles as both "create" and "join" |

## Channels List Screen

### What the User Sees

- **Search bar** with live text filtering (300ms debounce)
- **Sort/filter button**
- **Scrollable list of channel cards**, each showing:
  - Type icon with color coding
  - Channel name (or "Channel N" if unnamed)
  - Unread badge (if messages are unread)
  - Drag handle (when manual sort is active)
- **"+" FAB** to add a new channel
- **Overflow menu**: Disconnect, Settings

If no channels exist, an empty state with an "Add Public Channel" shortcut is shown. If a search produces no results, a separate "no results" empty state with a search-off icon is shown.

Pull-to-refresh (swipe down) forces a re-fetch of channels from the device firmware.

### Sorting Options

- **Manual** (default): Drag-and-drop reordering, persisted (drag handles are hidden when a search query is active)
- **A–Z**: Alphabetical
- **Latest messages**: Most recent first
- **Unread**: Most unread first

## Adding a Channel

Tap the "+" FAB to open a dialog with two options:

1. **Join Public Channel** — One tap; uses the well-known public PSK (only shown if no public channel exists)
2. **Add Channel** — Enter a name; PSK is derived from it via SHA-256. Since the same name always derives the same PSK, entering a name either creates a new channel or joins an existing one with that name

## Channel Actions (Long-Press / Right-Click)

| Action | Description |
|---|---|
| Edit | Change name (PSK is re-derived from the new name automatically), SMAZ compression toggle (compresses outgoing messages to allow longer text within the byte limit), or Cyr2Lat encoding toggle (transliterates Cyrillic to Latin for compatibility) |
| Mute / Unmute | Toggle push notification suppression for this channel |
| Delete | Remove the channel from the device (confirmation required) |

## Channel Chat

Tap a channel card to open the channel chat screen.

### App Bar

- Type icon: globe for public channels, tag (#) for hashtag channels
- Channel name
- Subtitle: "{Public|Hashtag} • {N} unread" (e.g., "Public • 3 unread")

### Message Display

- Reverse-scrolling list (newest at bottom)
- **Incoming messages**: Colored avatar with sender's initial (or first emoji if name starts with one; color is deterministic from sender name hash), sender name in primary color, message bubble
- **Outgoing messages**: Primary container color bubble with a small status icon: pending (clock), sent (checkmark), or failed (red error circle)
- Automatic older-message loading on scroll-to-top
- Jump-to-bottom button when scrolled up
- **Pinch-to-zoom**: Two-finger zoom (0.8x–1.8x) and double-tap to reset text size
- **Message tracing mode** (when enabled in App Settings): Each bubble additionally shows path prefix bytes (`via XX,YY,...`), a timestamp, and a repeat count icon

### Message Types in Chat

- **Plain text** with linkified URLs
- **GIFs** (`g:{gifId}`) rendered inline via Giphy CDN
- **Location pins** (`m:{lat},{lon}|{label}|`) shown as tappable location cards
- **Reactions** displayed as emoji pills below target messages

### Replies (Channel Chat Only)

- **Mobile**: Swipe an **incoming** message left to trigger reply (with haptic feedback). You cannot swipe your own outgoing messages. Swipe reply is not available on desktop.
- **All platforms**: Long-press → "Reply"
- Reply banner appears above the input bar with the quoted message (tap X to cancel)
- Sent replies are prefixed `@[{senderName}] {text}`
- Received replies show a bordered quote block inside the bubble; tapping scrolls to the original. Reply previews render GIF thumbnails and location pin icons, not just text.

### Message Path Viewing

- **All platforms**: Long-press (or right-click on desktop) a message bubble → "Path"
- Opens the Channel Message Path Screen (see [Additional Features](additional-features.md))

### Context Actions (Long-Press / Right-Click)

| Action | Availability | Description |
|---|---|---|
| Reply | All messages | Triggers reply mode |
| Path | All messages | Opens message path view |
| Add Reaction | Incoming messages only | Opens emoji picker (cannot react to your own messages) |
| Copy | All messages | Copies text to clipboard |
| Mark as Unread | Incoming messages only | Marks this message and all subsequent incoming messages as unread |
| Delete | All messages | Removes locally (not from mesh) |

## How Channels Differ from Direct Messages

| Aspect | Channels | Direct Messages |
|---|---|---|
| Addressing | Broadcast to all nodes with matching PSK | Point-to-point to a specific contact |
| Sender identity | Plain text prefix in payload | Verified via public key |
| Replies | Supported (swipe or long-press) | Not supported |
| Retry mechanism | No automatic retry | Exponential backoff with path rotation |
