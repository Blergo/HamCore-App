# HamCore

HamCore is a fork of [meshcore-open](https://github.com/zjs81/meshcore-open), the open-source Flutter companion app for MeshCore LoRa mesh networking devices. It pairs with its own HamCore firmware fork, which uses a modified payload and is not backwards compatible with stock MeshCore devices.

## Changelog

Changes specific to this fork, on top of upstream `meshcore-open`.

### v0.01a

- Forked from [zjs81/meshcore-open](https://github.com/zjs81/meshcore-open) at commit `e6cea37`.
- Rebranded the app from MeshCore Open to HamCore: app name, package/bundle identifiers (`com.hamcore.hamcore`), display strings, and docs.
- Renamed the connector/protocol layer and BLE scan prefix from MeshCore to HamCore (`HamCore-`) to match the incompatible HamCore firmware fork; legacy stock-MeshCore device prefixes are no longer scanned for. Also renamed the clipboard/QR contact-sharing URI scheme from `meshcore://` to `hamcore://`.
- Simplified channels down to just public and hashtag types, dropping private channels and communities (QR-shared-secret groups). HamCore firmware no longer encrypts channel payloads over the air (required for amateur radio licensing compliance), so PSK-based "private" channels no longer gave any real confidentiality — keeping them would have misled users into thinking they had privacy they didn't. The hashtag-channel flow (SHA-256-derived PSK from the name) is now the general-purpose "Add Channel" action, since it already doubles as both create and join.
