# Swift ANSI Picker

This is a simple tool for adding interactive selection to CLI
applications, designed to use with ANSI-supported terminals. This is a
pretty small and focused package, with no third-party
dependencies. I'm not planning on extending its functionality
significantly, so if you need further customization, feel free to copy
the code into your project and modify it as necessary. Alternatively,
look into using a more feature-full package like
[ConsoleKit](https://github.com/vapor/console-kit).

https://github.com/rechsteiner/swift-ansi-picker/assets/1238984/94eeac6c-75c7-4c66-9410-bc6a4b14a50f

## Usage

### Basic usage

```swift
import Picker

try choose(["Apple", "Banana", "Orange", "Watermelon"])
```

```
➜ Apple
  Banana
  Orange
  Watermelon
```

### Customization

```swift
var picker = Picker()
picker.itemIndicator = "  ○"
picker.itemColor = .darkGray
picker.selectionIndicator = "  ●"
picker.selectionColor = .cyan

print("⏵ Choose your favorite fruit:")
print(try picker.choose(["Apple", "Banana", "Orange", "Watermelon"]))
```

```
⏵ Choose your favorite fruit:
  ● Apple
  ○ Banana
  ○ Orange
  ○ Watermelon
```

## Installation

Add swift-ansi-picker to your Package.swift file:

```swift
.package(url: "https://github.com/rechsteiner/swift-ansi-picker.git", .exact(from: "0.0.1"))
```

## Contributions

While I'm not planning on extending its functionality significantly,
contributions for bug fixes and minor improvements are very
welcome. Please use GitHub Issues to report bugs or suggest
enhancements.

## License

Swift ANSI Picker is available under the MIT license. See the
[LICENSE](/LICENSE) file for more info.
