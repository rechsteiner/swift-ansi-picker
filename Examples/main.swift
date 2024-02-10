import Foundation
import Picker

do {
    print()
    print("Choose your favorite fruit:")

    let _ = try choose(["Apple", "Banana", "Orange", "Watermelon"])

    print()
    print("⏵ Choose your favorite fruit:")

    var picker = Picker()
    picker.itemIndicator = "  ○"
    picker.itemColor = .darkGray
    picker.selectionIndicator = "  ●"
    picker.selectionColor = .cyan

    let selection = try picker.choose(["Apple", "Banana", "Orange", "Watermelon"])

    print()
    print("Selection: ", selection)
} catch {
    print("Error: ", error)
}
