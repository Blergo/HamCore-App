# HamCore

HamCore is a fork of [meshcore-open](https://github.com/zjs81/meshcore-open), the open-source Flutter companion app for MeshCore LoRa mesh networking devices. It pairs with its own HamCore firmware fork, which uses a modified payload and is not backwards compatible with stock MeshCore devices.

## Changelog

Changes specific to this fork, on top of upstream `meshcore-open`.

### v0.01a

- Forked from [zjs81/meshcore-open](https://github.com/zjs81/meshcore-open) at commit `e6cea37`.
- Rebranded the app from MeshCore Open to HamCore: app name, package/bundle identifiers (`com.hamcore.hamcore`), display strings, and docs.
- Renamed the connector/protocol layer and BLE scan prefix from MeshCore to HamCore (`HamCore-`) to match the incompatible HamCore firmware fork; legacy stock-MeshCore device prefixes are no longer scanned for. Also renamed the clipboard/QR contact-sharing URI scheme from `meshcore://` to `hamcore://`.
