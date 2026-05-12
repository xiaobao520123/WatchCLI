import SwiftUI

/// Pixel-art mascot in the spirit of the Claude Code reference image:
/// a chunky orange beetle/bug with two eyes and stubby antennae.
/// Drawn from a tiny bit grid so it stays crisp at any size.
struct PixelMascot: View {
    var pixel: CGFloat = 4
    var color: Color = Theme.accent

    private static let grid: [[Int]] = [
        [0,0,1,0,0,0,0,0,0,1,0,0],
        [0,0,0,1,0,0,0,0,1,0,0,0],
        [0,1,1,1,1,1,1,1,1,1,1,0],
        [1,1,1,1,1,1,1,1,1,1,1,1],
        [1,1,0,0,1,1,1,1,0,0,1,1],
        [1,1,0,0,1,1,1,1,0,0,1,1],
        [1,1,1,1,1,1,1,1,1,1,1,1],
        [1,1,1,1,1,1,1,1,1,1,1,1],
        [0,1,1,1,1,1,1,1,1,1,1,0],
        [0,0,1,0,0,0,0,0,0,1,0,0],
        [0,1,0,0,0,0,0,0,0,0,1,0],
    ]

    var body: some View {
        Canvas { ctx, _ in
            for (r, row) in Self.grid.enumerated() {
                for (c, v) in row.enumerated() where v == 1 {
                    let rect = CGRect(x: CGFloat(c) * pixel,
                                      y: CGFloat(r) * pixel,
                                      width: pixel, height: pixel)
                    ctx.fill(Path(rect), with: .color(color))
                }
            }
        }
        .frame(width: pixel * CGFloat(Self.grid[0].count),
               height: pixel * CGFloat(Self.grid.count))
        .accessibilityHidden(true)
    }
}
