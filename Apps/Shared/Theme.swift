import SwiftUI

/// Color palette inspired by the user's reference screenshot of the
/// Claude Code CLI: warm amber accent on near-black background, with a
/// cool cyan secondary for prompts and links.
public enum Theme {
    public static let background = Color(red: 0.06, green: 0.06, blue: 0.07) // #0F0F12
    public static let surface    = Color(red: 0.10, green: 0.10, blue: 0.12)
    public static let accent     = Color(red: 1.00, green: 0.48, blue: 0.24) // #FF7A3D
    public static let prompt     = Color(red: 0.49, green: 0.83, blue: 0.99) // #7DD3FC
    public static let muted      = Color(red: 0.61, green: 0.64, blue: 0.69) // #9CA3AF
    public static let textPrimary = Color(red: 0.93, green: 0.93, blue: 0.94)

    /// Monospaced font tuned for small screens. Uses the system mono so it
    /// inherits Dynamic Type sizes on watchOS / iOS.
    public static func mono(_ style: Font.TextStyle = .body) -> Font {
        .system(style, design: .monospaced)
    }
}
