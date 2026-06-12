import SwiftUI

/// Pixel-art Copilot mascot extracted from a live `copilot` CLI session
/// (the real binary's splash screen renders this in box-drawing chars):
///
///     ╭─╮╭─╮
///     ╰─╯╰─╯       ← antennae / ears
///     █ ▘▝ █       ← face with eyes (alternates: ╴╶, two-dot, blink)
///      ▔▔▔▔        ← mouth
///
/// Rendered in monospaced text so it sits perfectly inside our terminal
/// banners. Animates the eyes through three frames the way the real CLI
/// blinks while loading.
struct CopilotMascot: View {
    @State private var frame = 0
    let lineHeight: CGFloat
    let color: Color
    var animated: Bool = true

    init(lineHeight: CGFloat = 9, color: Color = Theme.copilot, animated: Bool = true) {
        self.lineHeight = lineHeight; self.color = color; self.animated = animated
    }

    private static let frames: [String] = [
        "█ ▘▝ █",  // eyes up
        "█ ╴╶ █",  // mid
        "█    █",  // closed
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("╭─╮╭─╮")
            Text("╰─╯╰─╯")
            Text(Self.frames[frame])
            Text(" ▔▔▔▔ ")
        }
        .font(.system(size: lineHeight, weight: .regular, design: .monospaced))
        .foregroundStyle(color)
        .onAppear {
            guard animated else { return }
            Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true) { _ in
                Task { @MainActor in
                    frame = (frame + 1) % Self.frames.count
                }
            }
        }
    }
}

#Preview { CopilotMascot().padding().background(Theme.background) }
