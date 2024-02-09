import Foundation

do {
    print("Choose your favorite fruit:")
    let option = try choose([
        "Apple",
        "Banana",
        "Orange",
        "Watermelon"
    ])
    print("You chose: ", option)

    print("Choose your favorite fruit:")

    var config = PickerConfiguration()
    config.itemIndicator = "○"
    config.itemColor = .red
    config.selectionIndicator = "●"
    config.selectionColor = .green

    let fruit = try choose([
        "Apple",
        "Banana",
        "Orange",
        "Watermelon"
    ], config: config)
    print("You chose: ", fruit)
} catch {
    print("error: ", error)
}
