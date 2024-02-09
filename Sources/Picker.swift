import Foundation

/// Presents a list of options in the terminal for the user to choose
/// from, highlighting the current selection based on the provided
/// configuration. Blocks until the user makes a selection.
///
/// - Parameters:
///   - options: An array of `String` representing the options from
///     which the user can choose.
///   - config: An optional `PickerConfiguration` object to customize
///     the appearance of the picker. Includes colors and indicators for
///     selected and unselected items. Defaults to `.default` if not
///     provided.
///
/// - Returns: A `String` representing the user's selected option.
///
/// ## Example Usage
///
/// ```swift
/// let options = ["Apples", "Bananas", "Oranges", "Grapefruit"]
///
/// // Using default configuration
/// let selection = try choose(options)
/// print("Selection: \(selection)")
///
/// // Using custom configuration
/// var config = PickerConfiguration()
/// config.itemIndicator = "->"
/// config.itemColor = .cyan
/// config.selectionIndicator = "➜"
/// config.selectionColor = .green
///
/// let selection = try choose(options, config: config)
/// print("Selection: \(selection)")
/// ```
///
/// This function allows for basic customization of the picker's
/// appearance, including the color and symbols used to indicate the
/// current selection and other items.
public func choose(
    _ options: [String],
    config: PickerConfiguration = .default
) throws -> String {
    var picker = Picker(options: options, config: config)
    return try picker.choose()
}

enum PickerError: Swift.Error {
    case cursorPositionUnavailable
}

public struct PickerConfiguration {
    public typealias Color = String

    var itemIndicator: String = " "
    var itemColor: Color = .default
    var selectionIndicator: String = "➜"
    var selectionColor: Color = .green

    public static let `default` = PickerConfiguration()
}

public extension PickerConfiguration.Color {
    init(code: UInt8) {
        self.init("\u{1B}[\(code)m")
    }

    static let `default` = PickerConfiguration.Color(code: 39)
    static let black = PickerConfiguration.Color(code: 30)
    static let red = PickerConfiguration.Color(code: 31)
    static let green = PickerConfiguration.Color(code: 32)
    static let yellow = PickerConfiguration.Color(code: 93)
    static let blue = PickerConfiguration.Color(code: 34)
    static let magenta = PickerConfiguration.Color(code: 35)
    static let cyan = PickerConfiguration.Color(code: 36)
    static let gray = PickerConfiguration.Color(code: 37)
    static let darkGray = PickerConfiguration.Color(code: 90)
    static let white = PickerConfiguration.Color(code: 97)
}

private var originalTerminal: termios?

private func handleSignal(signal: Int32) {
    guard var originalTerminal else { return }
    tcsetattr(STDIN_FILENO, TCSANOW, &originalTerminal)
    exit(signal)
}

private struct Picker {
    private let options: [String]
    private let config: PickerConfiguration
    private var initialLine: Int = 0
    private var currentSelection: Int = 0

    enum ControlCharacter: UnicodeScalar {
        case escape = "\u{1B}"
        case leftBracket = "["
        case upArrow = "A"
        case downArrow = "B"
        case enter = "\u{0A}" // Line Feed
        case carriageReturn = "\u{0D}" // Carriage Return
    }

    init(options: [String], config: PickerConfiguration) {
        self.options = options
        self.config = config
    }

    mutating func choose() throws -> String {
        originalTerminal = nil
        enableNonCanonicalMode()
        defer { restoreTerminalMode() }

        for (index, option) in options.enumerated() {
            printOption(option, at: index)
        }

        guard let currentLine = readCurrentLine() else {
            throw PickerError.cursorPositionUnavailable
        }

        initialLine = currentLine - options.count
        updateSelection()

        loop: while true {
            let key = readControlCharacter()

            switch key {
            case .escape:
                let bracket = readControlCharacter()
                if bracket == .leftBracket {
                    let direction = readControlCharacter()
                    switch direction {
                    case .upArrow:
                        currentSelection = max(0, currentSelection - 1)
                    case .downArrow:
                        currentSelection = min(options.count - 1, currentSelection + 1)
                    default:
                        continue
                    }
                }

            case .enter, .carriageReturn:
                break loop

            default:
                continue
            }

            updateSelection()
        }

        return options[currentSelection]
    }

    private func updateSelection() {
        for (index, option) in options.enumerated() {
            moveCursor(initialLine + index)
            printOption(option, at: index)
        }
    }

    private func printOption(_ option: String, at index: Int) {
        let resetColor = "\u{1B}[0m"
        if index == currentSelection {
            print("\(config.selectionColor)\(config.selectionIndicator) \(option)\(resetColor)")
        } else {
            print("\(config.itemColor)\(config.itemIndicator) \(option)\(resetColor)")
        }
    }

    // Read single control character from stdin. Returns nil for unknown characters.
    private func readControlCharacter() -> ControlCharacter? {
        var key: UInt8 = 0
        let result = read(STDIN_FILENO, &key, 1)
        guard result == 1 else { return nil }

        let unicodeScalar = UnicodeScalar(key)
        let controlCharacter = ControlCharacter(rawValue: unicodeScalar)
        return controlCharacter
    }

    private func moveCursor(_ line: Int) {
        // ANSI escape code to move the cursor. Column is set to 1 to start
        // from the beginning of the line.
        let escapeCode = "\u{1B}[\(line);1H"

        // Print the escape code to standard output to move the cursor in the terminal.
        print(escapeCode, terminator: "")
        // Ensure the output is immediately flushed to the terminal.
        fflush(stdout)
    }

    private func enableNonCanonicalMode() {
        // Switch standard input to non-canonical mode to read the response immediately.
        var terminal = termios()
        tcgetattr(STDIN_FILENO, &terminal)
        // Save the current termios to restore later
        originalTerminal = terminal
        terminal.c_lflag &= ~UInt(ECHO | ICANON)
        tcsetattr(STDIN_FILENO, TCSANOW, &terminal)

        // Setup a signal handler that resets the terminal mode when
        // receiving SIGINT (ctrl-c).
        signal(SIGINT, handleSignal)
    }

    private func restoreTerminalMode() {
        // Restore the original terminal settings.
        guard var originalTerminal else { return }
        tcsetattr(STDIN_FILENO, TCSANOW, &originalTerminal)
    }

    private func readCurrentLine() -> Int? {
        // Flush any pending output to ensure the terminal is up-to-date.
        fflush(stdout)

        // Request the cursor position from the terminal.
        print("\u{1B}[6n", terminator: "")
        fflush(stdout)

        // Read the response from the terminal (e.g., "\ESC[12;40R")
        var response = ""
        var key: UInt8 = 0
        let endCharacter: Character = "R"

        while key != endCharacter.asciiValue {
            read(STDIN_FILENO, &key, 1)
            response.append(Character(UnicodeScalar(key)))
        }

        // Parse the response (e.g. \u{1B}[12;40R) to extract the row number.
        if let range = response.range(of: "\u{1B}[", options: .backwards),
           let semicolonRange = response.range(of: ";", options: [], range: range.upperBound..<response.endIndex) {
            let rowString = response[range.upperBound..<semicolonRange.lowerBound]
            return Int(rowString)
        }

        return nil
    }
}
