import SwiftUI

struct DigiaDeterminateLinearBar: View {
    let progress: CGFloat
    let width: CGFloat?
    let thickness: CGFloat
    let radius: CGFloat
    let tint: Color
    let background: Color
    let reversed: Bool
    let animate: Bool

    @State private var displayedProgress: CGFloat = 0

    var body: some View {
        resolvedTrack(width: width, thickness: thickness) { availableWidth in
            ZStack(alignment: reversed ? .trailing : .leading) {
                RoundedRectangle(cornerRadius: radius)
                    .fill(background)
                    .frame(width: availableWidth, height: thickness)
                RoundedRectangle(cornerRadius: radius)
                    .fill(tint)
                    .frame(width: availableWidth * displayedProgress, height: thickness)
            }
            .frame(width: availableWidth, height: thickness)
            .clipShape(RoundedRectangle(cornerRadius: radius))
        }
        .onAppear {
            updateProgress()
        }
        .onChange(of: progress, initial: false) { _, _ in
            updateProgress()
        }
    }

    private func updateProgress() {
        if animate {
            withAnimation(.linear(duration: 0.3)) {
                displayedProgress = progress
            }
        } else {
            displayedProgress = progress
        }
    }
}

struct DigiaIndeterminateLinearBar: View {
    let width: CGFloat?
    let thickness: CGFloat
    let radius: CGFloat
    let tint: Color
    let background: Color
    let reversed: Bool

    @State private var phase: CGFloat = -0.4

    var body: some View {
        resolvedTrack(width: width, thickness: thickness) { availableWidth in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: radius)
                    .fill(background)
                    .frame(width: availableWidth, height: thickness)

                RoundedRectangle(cornerRadius: radius)
                    .fill(tint)
                    .frame(width: max(availableWidth * 0.35, thickness * 2), height: thickness)
                    .offset(x: (reversed ? -1 : 1) * phase * availableWidth)
            }
            .frame(width: availableWidth, height: thickness, alignment: .leading)
            .clipShape(RoundedRectangle(cornerRadius: radius))
        }
        .onAppear {
            withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                phase = 1.2
            }
        }
    }
}

@ViewBuilder
private func resolvedTrack<Content: View>(
    width: CGFloat?,
    thickness: CGFloat,
    @ViewBuilder content: @escaping (CGFloat) -> Content
) -> some View {
    if let width {
        content(width)
            .frame(width: width, height: thickness, alignment: .leading)
    } else {
        GeometryReader { proxy in
            let availableWidth = max(proxy.size.width, 0)
            content(availableWidth)
                .frame(width: availableWidth, height: thickness, alignment: .leading)
        }
        .frame(maxWidth: .infinity, minHeight: thickness, maxHeight: thickness, alignment: .leading)
    }
}

struct DigiaDeterminateCircularBar: View {
    let progress: CGFloat
    let size: CGFloat
    let thickness: CGFloat
    let tint: Color
    let background: Color
    let animate: Bool

    @State private var displayedProgress: CGFloat = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(background, lineWidth: thickness)

            Circle()
                .trim(from: 0, to: displayedProgress)
                .stroke(
                    tint,
                    style: StrokeStyle(lineWidth: thickness, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
        .onAppear {
            updateProgress()
        }
        .onChange(of: progress, initial: false) { _, _ in
            updateProgress()
        }
    }

    private func updateProgress() {
        if animate {
            withAnimation(.linear(duration: 0.3)) {
                displayedProgress = progress
            }
        } else {
            displayedProgress = progress
        }
    }
}

struct DigiaIndeterminateCircularBar: View {
    let size: CGFloat
    let thickness: CGFloat
    let tint: Color
    let background: Color

    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(background, lineWidth: thickness)

            Circle()
                .trim(from: 0.05, to: 0.72)
                .stroke(
                    tint,
                    style: StrokeStyle(lineWidth: thickness, lineCap: .round)
                )
                .rotationEffect(.degrees(rotation))
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}
