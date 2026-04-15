# DigiaEngageSample

Sample iOS app for the `DigiaEngage` Swift package.

## Run

- Open `DigiaEngageSample.xcodeproj` (the app depends on the Swift package at the repo root via **File → Add Package**-style local reference `..`).
- Select the `DigiaEngageSample` scheme
- Run on an iOS 16+ simulator

## Config

Update `DigiaEngageSampleApp.swift` with a valid API key if you need to hit real config.
The sample app now initializes the SDK from `DigiaSampleRootView`, so startup failures are surfaced in-app instead of being silently dropped.
