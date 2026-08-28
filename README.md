# HamCore

HamCore is a fork of [meshcore-open](https://github.com/zjs81/meshcore-open), the open-source Flutter companion app for MeshCore LoRa mesh networking devices. It pairs with its own HamCore firmware fork, which uses a modified payload and is not backwards compatible with stock MeshCore devices.

## Changelog

### v0.1.0

Forked from [zjs81/meshcore-open](https://github.com/zjs81/meshcore-open) at commit `e6cea37`.

1. **Branding:** Renamed the app from MeshCore Open to HamCore — app name, package/bundle identifiers (`com.hamcore.hamcore`), display strings, and docs.
2. **Protocol Branding:** Renamed the connector/protocol code and BLE scan prefix from MeshCore to HamCore (`HamCore-`); legacy stock-MeshCore device prefixes are no longer scanned for. Also renamed the clipboard/QR contact-sharing URI scheme from `meshcore://` to `hamcore://`.
3. **License Compliance:** Removed private channels and communities (QR-shared-secret groups) — HamCore firmware no longer encrypts channel payloads over the air, so PSK-based "private" channels gave no real confidentiality. Hashtag channels (SHA-256-derived PSK from the name) are now the general-purpose "Add Channel" action.
4. **Versioning:** App version is now derived from the release build's git tag (`--build-name`/`--build-number` set in CI) instead of the stale `9.5.0` inherited from upstream.
5. **Security:** Replaced the repeater login password prompt with Guest Access / Admin Access buttons. Both are currently disabled since repeater authentication is broken on the firmware side; routing controls (path mode, manage paths) remain available from the same dialog.
6. **Repeat Counting (WIP):** Fixed several bugs in channel message "heard repeats" counting caused by HamCore firmware sending plaintext payloads with a zeroed MAC field instead of encrypting them — raw-packet parsing, duplicate-send miscounting, dedup hash matching, and self-echo dropping. Not yet verified against real repeater hardware.
7. **RF Defaults:** Removed the ability to set path hash mode from both the companion device settings and repeater remote admin settings — HamCore firmware now fixes this at 3 bytes, so it's no longer a configurable option. The "get path.hash.mode" CLI reference is kept for querying the fixed value.
