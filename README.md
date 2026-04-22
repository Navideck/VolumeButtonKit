# VolumeButtonKit

`VolumeButtonKit` is a native iOS Swift package for listening to hardware volume button events and controlling system volume behavior.

## Features

- Detect volume button press and release events.
- Optional suppression of the system volume HUD by using an offscreen `MPVolumeView`.
- Read and set current output volume.
- Restore baseline volume after button interactions.

## Requirements

- iOS 13.0+
- Swift 5.9+
- Xcode 15+

## Installation (SPM)

In Xcode, add the package dependency:

```text
https://github.com/Navideck/VolumeButtonKit.git
```

Or in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Navideck/VolumeButtonKit.git", branch: "main")
]
```

## Usage

```swift
import VolumeButtonKit

let listener = VolumeButtonListener()
listener.showsVolumeUi = false
listener.volumeButtonPressed = { button in
    print("Pressed:", button == .up ? "up" : "down")
}
listener.volumeButtonReleased = { button in
    print("Released:", button == .up ? "up" : "down")
}

try listener.startListening()
```

## Notes

- Internally this package activates an audio session and listens for system volume change notifications.
- While listening, button presses restore the baseline volume captured at listener start (or after explicit `setVolume` calls while active).
