# macos-launcher

Minimal macOS SwiftUI launcher for bee.

## Prereqs
- Xcode 15+ (or Swift 5.9 toolchain)
- `beed` running locally (default: http://127.0.0.1:3000)

## Run (Xcode)
1. Open `macos-launcher/Package.swift` in Xcode.
2. Select the `macos-launcher` scheme and run on “My Mac”.

## Run (CLI)
```bash
cd macos-launcher
swift build
swift run macos-launcher
```

## Configure API URL
Set `BEE_API_BASE_URL` if your API is not on the default port:

```bash
BEE_API_BASE_URL="http://127.0.0.1:3000" swift run macos-launcher
```

## Notes
- The launcher sends a request to `/v1/parse` on every keystroke, then calls `/v1/action` with the parsed action + filter.
- Only a trimmed task payload is rendered (summary + status).
