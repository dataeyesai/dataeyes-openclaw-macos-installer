# Release Manifest

- Generated at: 2026-03-25 10:23:05 UTC
- Version: 1.0.6
- Build: 7
- Bundle ID: ai.dataeyes.installer
- Minimum macOS: 13.0
- Architectures: arm64 x86_64

## Files

| File | Size | SHA256 |
| --- | --- | --- |
| DataEyes Installer.zip | 4.30 MiB | 1156c5d71baa79be2c50c4b974e0687f170b01044c36f289fa50a6c1f7339051 |
| DataEyes Installer.dmg | 4.60 MiB | 78e8ff7a9b64095fd57fcaa276c51b74a0c82ced5438ae9d649b5090a8bfd71e |
| DataEyes Installer-unsigned.pkg | 4.28 MiB | 1c2b80e4e59c5443a6d59534c0ac2b356df3b97279ba9e3c2ac041baddc0b6e3 |

## Notes

- `.dmg` is the recommended distribution format for end users.
- `.zip` is useful for directly distributing the app bundle.
- The app bundle is built as a universal binary for Apple Silicon and Intel Macs.
- The app bundle is ad-hoc signed to avoid the broken-bundle "damaged" error.
- `.pkg` is currently unsigned unless you rebuild and sign it explicitly.
