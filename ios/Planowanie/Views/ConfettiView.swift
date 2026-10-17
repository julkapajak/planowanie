import SwiftUI

/// Krótki wybuch konfetti po odhaczeniu całego dnia.
struct ConfettiView: View {
    private struct Piece {
        var x: CGFloat, vx: CGFloat, vy: CGFloat, spin: CGFloat, w: CGFloat, color: Color
    }

    @State private var start = Date()
    @State private var pieces: [Piece] = (0..<140).map { _ in
        Piece(x: .random(in: -40...40), vx: .random(in: -320...320), vy: .random(in: -900 ... -350),
              spin: .random(in: -8...8), w: .random(in: 6...11), color: Category.allCases.randomElement()!.color)
    }

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t = CGFloat(tl.date.timeIntervalSince(start))
                guard t < 3 else { return }
                for p in pieces {
                    let x = size.width / 2 + p.x + p.vx * t
                    let fall: CGFloat = 900 * t * t
                    let y = size.height * 0.35 + p.vy * t + fall
                    var c = ctx
                    c.opacity = Double(max(0, 1 - t / 3))
                    c.translateBy(x: x, y: y)
                    c.rotate(by: .radians(Double(p.spin * t)))
                    c.fill(Path(CGRect(x: -p.w / 2, y: -p.w / 4, width: p.w, height: p.w / 2)), with: .color(p.color))
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
