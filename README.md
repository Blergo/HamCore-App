# HamCore

HamCore is a fork of [meshcore-open](https://github.com/zjs81/meshcore-open), the open-source Flutter companion app for MeshCore LoRa mesh networking devices. It pairs with its own HamCore firmware fork, which uses a modified payload and is not backwards compatible with stock MeshCore devices.

## Changelog

### v0.1.0

Forked from [zjs81/meshcore-open](https://github.com/zjs81/meshcore-open) at commit `e6cea37`.

1. **Branding:** Renamed the app from MeshCore Open to HamCore — app name, package/bundle identifiers (`com.hamcore.hamcore`), display strings, and docs.
2. **Protocol Branding:** Renamed the connector/protocol code and BLE scan prefix from MeshCore to HamCore (`HamCore-`); legacy stock-MeshCore device prefixes are no longer scanned for. Also renamed the clipboard/QR contact-sharing URI scheme from `meshcore://` to `hamcore://`.
3. **License Compliance:** Removed private channels and communities (QR-shared-secret groups) — HamCore firmware no longer encrypts channel payloads over the air, so PSK-based "private" channels gave no real confidentiality. Hashtag channels (SHA-256-derived PSK from the name) are now the general-purpose "Add Channel" action.
4. **Versioning:** App version is now derived from the release build's git tag (`--build-name`/`--build-number` set in CI) instead of the stale `9.5.0` inherited from upstream.
5. **Security:** Replaced the repeater login password prompt with Guest Access / Admin Access buttons. Guest Access now works — the app still sends `CMD_SEND_LOGIN`, but the old password field is repurposed as a single login-type byte (`0x04` guest / `0x05` admin) that the firmware checks unconditionally for guest, no password involved. Admin Access stays disabled since the firmware doesn't implement admin auth yet (the `0x05` type is wired but always rejected server-side for now). Routing controls (path mode, manage paths) remain available from the same dialog.
6. **Repeat Counting:** Fixed several bugs in channel message "heard repeats" counting caused by HamCore firmware sending plaintext payloads with a zeroed MAC field instead of encrypting them — raw-packet parsing, duplicate-send miscounting, dedup hash matching, and self-echo dropping.
7. **RF Defaults:** Removed the ability to set path hash mode from both the companion device settings and repeater remote admin settings — HamCore firmware now fixes this at 3 bytes, so it's no longer a configurable option. The "get path.hash.mode" CLI reference is kept for querying the fixed value.
8. **Radio Presets:** Replaced the full regional radio preset list (Australia, EU, Russia, USA, etc.) with a single UK 70cm preset (434.150 MHz, 62.5 kHz, SF8, CR 4/5). TX power is no longer part of a preset — it's a per-hardware-variant radio setting the firmware bounds and defaults on its own, not an RF band-plan characteristic.
