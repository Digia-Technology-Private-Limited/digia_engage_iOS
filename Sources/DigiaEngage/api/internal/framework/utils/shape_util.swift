import SwiftUI

struct AnyShape: Shape {
    private let pathBuilder: @Sendable (CGRect) -> Path

    init<S: Shape>(_ shape: S) {
        pathBuilder = { rect in
            shape.path(in: rect)
        }
    }

    func path(in rect: CGRect) -> Path {
        pathBuilder(rect)
    }
}

struct DigiaRoundedRect: Shape {
    let cornerRadius: CornerRadiusProps

    func path(in rect: CGRect) -> Path {
        if cornerRadius.isUniform {
            return RoundedRectangle(cornerRadius: cornerRadius.uniformValue, style: .continuous)
                .path(in: rect)
        }
        let maxR = min(rect.width, rect.height) / 2
        let tl = min(cornerRadius.topLeft,     maxR)
        let tr = min(cornerRadius.topRight,    maxR)
        let br = min(cornerRadius.bottomRight, maxR)
        let bl = min(cornerRadius.bottomLeft,  maxR)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr),  radius: tr, startAngle: .degrees(-90), endAngle: .degrees(0),   clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        path.addArc(center: CGPoint(x: rect.maxX - br, y: rect.maxY - br),  radius: br, startAngle: .degrees(0),   endAngle: .degrees(90),  clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl),  radius: bl, startAngle: .degrees(90),  endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        path.addArc(center: CGPoint(x: rect.minX + tl, y: rect.minY + tl),  radius: tl, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()
        return path
    }
}
