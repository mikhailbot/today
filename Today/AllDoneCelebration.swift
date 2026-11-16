import SwiftUI

// A small celebration when the day's last task is ticked off.

extension EnvironmentValues {
    /// Called when the last open task on the day is ticked off.
    @Entry var onAllDone: () -> Void = {}
}

/// A little pill of the slab's colour that pops up at the bottom of the day, its check drawing
/// itself in while a handful of the mark's bars and dots burst out of it like confetti.
struct AllDoneCelebration: View {
    @State private var check = 0.0
    @State private var burst = 0.0
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "circle.fill")
                .font(.body)
                .hidden()
                .overlay {
                    Circle().fill(theme.onSlab)
                    Check(progress: check)
                        .stroke(theme.slab, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                        .padding(5)
                }
            Text("All done")
                .font(.system(.body, design: .rounded, weight: .bold))
        }
        .foregroundStyle(theme.onSlab)
        .padding(.leading, 12)
        .padding(.trailing, 16)
        .padding(.vertical, 10)
        .background(theme.slab.gradient, in: Capsule())
        .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
        .background {
            if !reduceMotion {
                ForEach(Confetti.pieces.indices, id: \.self) { i in
                    Confetti.pieces[i].view(theme: theme, t: burst)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
        .onAppear {
            guard !reduceMotion else { check = 1; return }
            withAnimation(.easeOut(duration: 0.35).delay(0.2)) { check = 1 }
            withAnimation(.linear(duration: 1.3).delay(0.15)) { burst = 1 }
        }
        .sensoryFeedback(.success, trigger: check == 1)
    }
}

/// A tick inside a unit square, drawn up to `progress`.
private struct Check: Shape {
    var progress: Double
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.minY + rect.height * 0.54))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.4, y: rect.minY + rect.height * 0.8))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.1, y: rect.minY + rect.height * 0.2))
        return path.trimmedPath(from: 0, to: progress)
    }
}

/// One of the mark's bars or dots, thrown up out of the pill and falling back as it fades.
private struct Confetti {
    enum Shade { case slab, now, future, accent }
    /// Launch angle in degrees, 0 to the right and -90 straight up.
    let angle: Double
    let speed: Double
    let spin: Double
    let isDot: Bool
    let shade: Shade

    static let pieces: [Confetti] = [
        Confetti(angle: -162, speed: 120, spin: -200, isDot: false, shade: .now),
        Confetti(angle: -148, speed: 165, spin: 260, isDot: true, shade: .future),
        Confetti(angle: -136, speed: 140, spin: -320, isDot: false, shade: .slab),
        Confetti(angle: -122, speed: 185, spin: 180, isDot: false, shade: .future),
        Confetti(angle: -110, speed: 150, spin: -140, isDot: true, shade: .now),
        Confetti(angle: -98, speed: 200, spin: 300, isDot: false, shade: .accent),
        Confetti(angle: -84, speed: 170, spin: -260, isDot: false, shade: .now),
        Confetti(angle: -72, speed: 195, spin: 220, isDot: true, shade: .slab),
        Confetti(angle: -58, speed: 145, spin: -180, isDot: false, shade: .future),
        Confetti(angle: -46, speed: 175, spin: 340, isDot: false, shade: .slab),
        Confetti(angle: -32, speed: 130, spin: -240, isDot: true, shade: .accent),
        Confetti(angle: -18, speed: 115, spin: 200, isDot: false, shade: .now),
    ]

    func view(theme: Theme, t: Double) -> some View {
        let color: AnyShapeStyle = switch shade {
        case .slab: AnyShapeStyle(theme.slab)
        case .now: AnyShapeStyle(.now)
        case .future: AnyShapeStyle(.future)
        case .accent: AnyShapeStyle(.tint)
        }
        return Group {
            if isDot {
                Circle().frame(width: 7, height: 7)
            } else {
                Capsule().frame(width: 14, height: 5)
            }
        }
        .foregroundStyle(color)
        .modifier(Flight(t: t, angle: angle * .pi / 180, speed: speed, spin: spin))
        .accessibilityHidden(true)
    }
}

/// Moves a piece of confetti along a thrown arc as `t` runs from 0 to 1.
private struct Flight: ViewModifier, Animatable {
    var t: Double
    let angle: Double
    let speed: Double
    let spin: Double

    var animatableData: Double {
        get { t }
        set { t = newValue }
    }

    func body(content: Content) -> some View {
        let gravity = 260.0
        // Starts a little out from the pill's middle, so it seems to come off its edge.
        let x = cos(angle) * (40 + speed * t)
        let y = sin(angle) * (10 + speed * t) + 0.5 * gravity * t * t
        content
            .rotationEffect(.degrees(angle * 180 / .pi + spin * t))
            .scaleEffect(t == 0 ? 0 : min(t / 0.12, 1))
            .opacity(t < 0.6 ? 1 : max(0, (1 - t) / 0.4))
            .offset(x: x, y: y)
    }
}
