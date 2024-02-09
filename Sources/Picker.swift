import Foundation

/// Presents a list of options in the terminal for the user to choose from,
/// highlighting the current selection. Blocks until the user makes a selection.
///
/// - Parameter options: An array of options which the user can choose.
/// - Returns: The selected option the user selected.
///
/// ## Example Usage
///
/// ```swift
/// let options = ["Apples", "Bananas", "Oranges", "Grapefruit"]
/// let selection = try choose(options)
/// print("Selection: \(selection)")
/// ```
public func choose(_ options: [String]) throws -> String {
    var picker = Picker()
    return try picker.choose(options)
}

private var originalTerminal: termios?

private func handleSignal(signal: Int32) {
    guard var originalTerminal else { return }
    tcsetattr(STDIN_FILENO, TCSANOW, &originalTerminal)
    exit(signal)
}

/// The `Picker` struct provides an interactive picker for use in the terminal,
/// allowing the user to choose from a list of options. It supports basic
/// customization of the presentation, like changing the indicators and colors.
public struct Picker {
    public var itemIndicator: String = " "
    public var itemColor: Color = .default
    public var selectionIndicator: String = "➜"
    public var selectionColor: Color = .green

    public enum Error: Swift.Error {
        case cursorPositionUnavailable
    }

    public typealias Color = String

    private var initialLine: Int = 0
    private var currentSelection: Int = 0

    private enum ControlCharacter: UnicodeScalar {
        case escape = "\u{1B}"
        case leftBracket = "["
        case upArrow = "A"
        case downArrow = "B"
        case enter = "\u{0A}" // Line Feed
        case carriageReturn = "\u{0D}" // Carriage Return
    }

    /// Initializes a new `Picker` instance with default configurations.
    ///
    /// Use this initializer to create a Picker with default item and selection
    /// indicators, as well as default colors for items and the selection.
    public init() {}

    /// Presents the given options in the terminal and blocks until the user
    /// makes a selection. The user can navigate through the options using the
    /// arrow keys and make a selection by pressing Enter.
    ///
    /// - Parameter options: An array of options which the user can choose.
    /// - Returns: The selected option the user selected.
    ///
    /// ## Example Usage
    ///
    /// ```swift
    /// var picker = Picker()
    /// picker.itemIndicator = "○"
    /// picker.itemColor = .red
    /// picker.selectionIndicator = "●"
    /// picker.selectionColor = .green
    ///
    /// let selection = try picker.choose([
    ///     "Apple",
    ///     "Banana",
    ///     "Orange",
    ///     "Watermelon"
    /// ])
    /// print("Selection: ", selection)
    /// ```
    public mutating func choose(_ options: [String]) throws -> String {
        originalTerminal = nil
        enableNonCanonicalMode()
        defer { restoreTerminalMode() }

        for (index, option) in options.enumerated() {
            printOption(option, at: index)
        }

        guard let currentLine = readCurrentLine() else {
            throw Error.cursorPositionUnavailable
        }

        initialLine = currentLine - options.count
        updateSelection(options)

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

            updateSelection(options)
        }

        return options[currentSelection]
    }

    private func updateSelection(_ options: [String]) {
        for (index, option) in options.enumerated() {
            moveCursor(initialLine + index)
            printOption(option, at: index)
        }
    }

    private func printOption(_ option: String, at index: Int) {
        let resetCode = "\u{1B}[0m"
        if index == currentSelection {
            print("\(selectionColor)\(selectionIndicator) \(option)\(resetCode)")
        } else {
            print("\(itemColor)\(itemIndicator) \(option)\(resetCode)")
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

public extension Picker.Color {
    init(code: UInt8) {
        self.init("\u{1B}[\(code)m")
    }

    static let `default` = Picker.Color(code: 39)
    static let black = Picker.Color(code: 30)
    static let red = Picker.Color(code: 31)
    static let green = Picker.Color(code: 32)
    static let yellow = Picker.Color(code: 93)
    static let blue = Picker.Color(code: 34)
    static let magenta = Picker.Color(code: 35)
    static let cyan = Picker.Color(code: 36)
    static let gray = Picker.Color(code: 37)
    static let darkGray = Picker.Color(code: 90)
    static let white = Picker.Color(code: 97)
}
