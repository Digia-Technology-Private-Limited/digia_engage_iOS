# DigiaEngage iOS

Dynamic in-app experience SDK for iOS.

## Requirements

- Xcode 16+
- iOS 16+
- Swift 6

## Swift Package Manager

```swift
dependencies: [
    .package(
        url: "https://github.com/Digia-Technology-Private-Limited/digia_engage_ios.git",
        from: "1.0.0-beta.1"
    ),
]
```

Then add `"DigiaEngage"` as a target dependency.

## CocoaPods

```ruby
pod 'DigiaEngage', '1.0.0-beta.1'
```

## Usage

```swift
import DigiaEngage

try await Digia.initialize(
    config: DigiaConfig(apiKey: "YOUR_API_KEY")
)
```

## Sample App

The sample app lives in `SampleApp/`. To run it locally:

```bash
cd SampleApp
pod install
open DigiaEngageSample.xcworkspace
```

---

Built with ❤️ by the Digia team
