# DigiaEngage iOS

[![Swift Package Index](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FDigia-Technology-Private-Limited%2Fdigia_engage_ios%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/Digia-Technology-Private-Limited/digia_engage_ios)
[![Swift Package Index](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FDigia-Technology-Private-Limited%2Fdigia_engage_ios%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/Digia-Technology-Private-Limited/digia_engage_ios)
[![License: BSL 1.1](https://img.shields.io/badge/License-BSL%201.1-blue.svg)](LICENSE)

Digia Engage is an iOS SDK for rendering server-driven, Digia-managed experiences inside host applications. It provides dynamic page rendering, slots, overlays, dialogs, toasts, action execution, and cached image loading for SwiftUI-based integrations.

## Requirements

| | Minimum |
|---|---|
| iOS | 16.0 |
| Swift | 5.10 |
| Xcode | 16.0 |

## Installation

### Swift Package Manager

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(
        url: "https://github.com/Digia-Technology-Private-Limited/digia_engage_ios.git",
        from: "1.0.0-beta.1"
    ),
]
```

Then add `DigiaEngage` as a target dependency:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "DigiaEngage", package: "digia_engage_ios"),
    ]
)
```

Or add it directly in Xcode via **File → Add Package Dependencies** and enter the repository URL.

### CocoaPods

Add to your `Podfile`:

```ruby
pod 'DigiaEngage', '~> 1.0.0-beta.1'
```

Then run:

```bash
pod install
```

## Usage

### Initialize the SDK

```swift
import DigiaEngage

try await Digia.initialize(
    config: DigiaConfig(apiKey: "YOUR_API_KEY")
)
```

### Render an experience

```swift
import DigiaEngage
import SwiftUI

struct ContentView: View {
    var body: some View {
        DigiaHost(experienceId: "your-experience-id")
    }
}
```

### Render a slot

```swift
DigiaSlot(slotId: "hero-banner")
```

### Present an in-app experience

```swift
DigiaScreen(screenId: "onboarding")
```

## Architecture

DigiaEngage renders JSON-defined UI trees at runtime using a SwiftUI widget system. Key components:

- **`Digia`** — SDK entry point for initialization and plugin registration
- **`DigiaHost`** — SwiftUI view that renders a full Digia experience
- **`DigiaSlot`** — SwiftUI view for rendering a named slot within a host screen
- **`DigiaScreen`** — Presents a Digia-managed screen modally
- **`DigiaCEPPlugin`** — Protocol for integrating customer engagement platforms (CleverTap, MoEngage, etc.)

## Plugins

Digia Engage has a plugin architecture for CEP integrations. Register plugins after initialization:

```swift
Digia.register(YourCEPPlugin())
```

Available plugins:
- [DigiaEngageCleverTap](https://github.com/Digia-Technology-Private-Limited/digia_engage_clevertap_ios)

## Sample App

A sample app is included in `SampleApp/`. To run it locally:

```bash
cd SampleApp
pod install
open DigiaEngageSample.xcworkspace
```

## License

[BSL 1.1](LICENSE) — Business Source License 1.1. Source available; production use requires a license from Digia Technology.

---

Built with ❤️ by the [Digia](https://digia.tech) team
