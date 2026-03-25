import SwiftUI

enum DigiaDividerAxis {
    case horizontal
    case vertical
}

@MainActor
struct DigiaDividerView: View {
    let axis: DigiaDividerAxis
    let size: CGFloat
    let thickness: CGFloat
    let indent: CGFloat
    let endIndent: CGFloat
    let color: Color
    let gradient: DividerGradientProps?
    let strokeCap: CGLineCap
    let dashPattern: [CGFloat]
    let minLength: CGFloat?
    let maxLength: CGFloat?
    let showsFallbackLength: Bool
    let payload: RenderPayload

    var body: some View {
        GeometryReader { proxy in
            let strokeStyle = StrokeStyle(
                lineWidth: thickness,
                lineCap: strokeCap,
                dash: dashPattern
            )

            ZStack {
                if let gradient, let resolved = resolvedGradient(gradient, size: proxy.size) {
                    DividerLineShape(axis: axis).stroke(resolved, style: strokeStyle)
                } else {
                    DividerLineShape(axis: axis).stroke(color, style: strokeStyle)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(
            minWidth: axis == .horizontal ? minLength : size,
            idealWidth: axis == .horizontal ? nil : size,
            maxWidth: axis == .horizontal ? maxLength : size,
            minHeight: axis == .vertical ? minLength : size,
            idealHeight: axis == .vertical ? nil : size,
            maxHeight: axis == .vertical ? maxLength : size,
            alignment: .center
        )
        .padding(paddingInsets)
        .frame(
            minWidth: axis == .horizontal && showsFallbackLength ? 1 : nil,
            minHeight: axis == .vertical && showsFallbackLength ? 1 : nil
        )
    }

    private var paddingInsets: EdgeInsets {
        switch axis {
        case .horizontal:
            return EdgeInsets(top: 0, leading: indent, bottom: 0, trailing: endIndent)
        case .vertical:
            return EdgeInsets(top: indent, leading: 0, bottom: endIndent, trailing: 0)
        }
    }

    private func resolvedGradient(
        _ gradient: DividerGradientProps,
        size: CGSize
    ) -> AnyShapeStyle? {
        let stops = gradientStops(for: gradient)
        guard !stops.isEmpty else { return nil }

        switch gradient.type?.lowercased() {
        case "linear":
            return AnyShapeStyle(
                LinearGradient(
                    gradient: Gradient(stops: stops),
                    startPoint: To.unitPoint(gradient.begin) ?? .leading,
                    endPoint: To.unitPoint(gradient.end) ?? .trailing
                )
            )
        case "angular":
            let shortestSide = max(min(size.width, size.height), thickness)
            return AnyShapeStyle(
                RadialGradient(
                    gradient: Gradient(stops: stops),
                    center: To.unitPoint(gradient.center) ?? .center,
                    startRadius: 0,
                    endRadius: shortestSide * CGFloat(gradient.radius ?? 0.5)
                )
            )
        default:
            return nil
        }
    }

    private func gradientStops(for gradient: DividerGradientProps) -> [Gradient.Stop] {
        let resolved = gradient.colorList?.compactMap { stop -> (Color, Double?)? in
            guard let color = payload.resolveColor(stop.color) else { return nil }
            return (color, stop.stop)
        } ?? []

        guard !resolved.isEmpty else { return [] }

        let hasLocations = resolved.contains { $0.1 != nil }
        return resolved.enumerated().map { index, item in
            let location: CGFloat
            if hasLocations {
                location = CGFloat(item.1 ?? (Double(index) / Double(max(resolved.count - 1, 1))))
            } else {
                location = CGFloat(index) / CGFloat(max(resolved.count - 1, 1))
            }
            return Gradient.Stop(color: item.0, location: location)
        }
    }
}

private struct DividerLineShape: Shape {
    let axis: DigiaDividerAxis

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch axis {
        case .horizontal:
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        case .vertical:
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        }
        return path
    }
}

enum DividerLineStyle {
    case solid
    case dotted
    case dashed
    case dashDotted

    init?(_ value: String?) {
        switch value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "solid":
            self = .solid
        case "dotted":
            self = .dotted
        case "dashed":
            self = .dashed
        case "dashdotted", "dash-dotted", "dash_dotted":
            self = .dashDotted
        default:
            return nil
        }
    }
}

struct DividerStrokeConfiguration: Equatable {
    let strokeCap: CGLineCap
    let dashPattern: [CGFloat]

    static func resolve(
        props: StyledDividerProps,
        thickness: CGFloat
    ) -> DividerStrokeConfiguration {
        let effectiveThickness = max(thickness, 1)
        let cap = To.strokeCap(props.strokeCap)

        if let lineStyle = DividerLineStyle(props.lineStyle) {
            switch lineStyle {
            case .solid:
                return DividerStrokeConfiguration(strokeCap: cap, dashPattern: [])
            case .dashed:
                return DividerStrokeConfiguration(
                    strokeCap: cap,
                    dashPattern: [5 * effectiveThickness, 2 * effectiveThickness]
                )
            case .dotted:
                return DividerStrokeConfiguration(
                    strokeCap: cap,
                    dashPattern: [effectiveThickness, effectiveThickness]
                )
            case .dashDotted:
                return DividerStrokeConfiguration(
                    strokeCap: cap,
                    dashPattern: [
                        3 * effectiveThickness,
                        effectiveThickness,
                        effectiveThickness,
                        effectiveThickness,
                    ]
                )
            }
        }

        let customDash = (props.dashPattern ?? []).map { CGFloat($0) }
        switch props.borderPattern?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "dashed":
            return DividerStrokeConfiguration(
                strokeCap: cap,
                dashPattern: customDash.isEmpty ? [3, 3] : customDash
            )
        case "dotted":
            return DividerStrokeConfiguration(
                strokeCap: cap,
                dashPattern: customDash.isEmpty ? [effectiveThickness, effectiveThickness] : customDash
            )
        default:
            return DividerStrokeConfiguration(strokeCap: cap, dashPattern: [])
        }
    }
}
