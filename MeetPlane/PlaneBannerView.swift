import SwiftUI

/// Animates a [FLAG BANNER] ——— 🤖 assembly from off-screen left to off-screen right.
///
/// The assembly layout (left → right):
///   [ Flag banner text ] ——— rope ——— 🤖
///
/// The robot leads (rightmost), the flag trails (leftmost).
struct PlaneBannerView: View {
    let event: MeetingEvent
    let onComplete: () -> Void

    @State private var isAnimating = false

    private let animationDuration: Double = 10.0
    /// Vertical position as a fraction from the bottom of the screen (0 = bottom, 1 = top).
    private let verticalFraction: CGFloat = 0.38

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                Color.clear  // Transparent fill — mouse events pass through at the NSWindow level.

                planeAssembly
                    // Start off-screen left; animate to off-screen right.
                    .offset(x: isAnimating ? geo.size.width + 500 : -800)
                    .animation(.linear(duration: animationDuration), value: isAnimating)
                    .padding(.bottom, geo.size.height * verticalFraction)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            // Small delay ensures the view is fully laid out before the animation starts.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isAnimating = true
            }
            // Dismiss the overlay window after the animation finishes.
            DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration + 0.4) {
                onComplete()
            }
        }
    }

    // MARK: - Subviews

    /// The complete assembly: flag + rope + plane, moving as one unit.
    private var planeAssembly: some View {
        HStack(spacing: 0) {
            flagBanner

            // Rope connecting the flag to the plane's tail.
            Rectangle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 52, height: 3)
                .shadow(color: .black.opacity(0.3), radius: 1, y: 1)

            // Robot image — faces right (→), matching the direction of travel.
            Image("robot")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
        }
    }

    /// The flag banner that displays the meeting name and start time.
    private var flagBanner: some View {
        ZStack {
            FlagShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.10, green: 0.47, blue: 0.96),
                            Color(red: 0.44, green: 0.19, blue: 0.87)
                        ],
                        startPoint: .topLeading,
                        endPoint:   .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.40), radius: 7, x: 2, y: 3)

            Text(event.bannerText)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
        }
        .frame(width: bannerWidth, height: 54)
    }

    /// Estimates a comfortable banner width from the text length.
    private var bannerWidth: CGFloat {
        let estimated = CGFloat(event.bannerText.count) * 10.5 + 48
        return max(220, min(estimated, 640))
    }
}

// MARK: - Flag Shape

/// A rectangular flag with a wavy bottom edge to suggest fabric movement.
struct FlagShape: Shape {
    var waveAmplitude: CGFloat = 5
    var waveCycles: CGFloat    = 3

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // Top-left → top-right (straight top edge)
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: w, y: 0))
        // Top-right → bottom-right (straight right edge)
        path.addLine(to: CGPoint(x: w, y: h))
        // Bottom-right → bottom-left (wavy bottom edge)
        let steps = 80
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let x = w * (1 - t)
            let y = h + waveAmplitude * sin(t * .pi * 2 * waveCycles)
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Preview

#Preview("Plane Banner") {
    PlaneBannerView(
        event: MeetingEvent(
            id:        "preview",
            title:     "Design Review",
            startTime: Date().addingTimeInterval(5 * 60),
            endTime:   Date().addingTimeInterval(65 * 60),
            meetLink:  nil
        ),
        onComplete: {}
    )
    .frame(width: 1024, height: 400)
    .background(Color.gray.opacity(0.25))
}
