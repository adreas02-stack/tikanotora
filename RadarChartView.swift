import SwiftUI

struct RadarDataPoint {
    let label: String
    let value: Double
}

/// Απλό γράφημα «αράχνη» (radar/spider) φτιαγμένο με Path — δείχνει πού πάει
/// ο χρόνος, μία γωνία ανά κατηγορία.
struct RadarChartView: View {
    let points: [RadarDataPoint]
    let maxValue: Double

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = size / 2 - 28
            let n = points.count

            ZStack {
                ForEach(1...4, id: \.self) { ring in
                    polygon(center: center, radius: radius * CGFloat(ring) / 4, sides: n)
                        .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                }
                ForEach(0..<n, id: \.self) { i in
                    Path { path in
                        path.move(to: center)
                        path.addLine(to: point(center: center, radius: radius, index: i, total: n))
                    }
                    .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                }
                dataPolygon(center: center, radius: radius)
                    .fill(Color.accentColor.opacity(0.35))
                dataPolygon(center: center, radius: radius)
                    .stroke(Color.accentColor, lineWidth: 2)

                ForEach(points.indices, id: \.self) { i in
                    let p = point(center: center, radius: radius + 18, index: i, total: n)
                    Text(points[i].label)
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                        .frame(width: 76)
                        .position(p)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func point(center: CGPoint, radius: CGFloat, index: Int, total: Int) -> CGPoint {
        guard total > 0 else { return center }
        let angle = (CGFloat(index) / CGFloat(total)) * 2 * .pi - .pi / 2
        return CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
    }

    private func polygon(center: CGPoint, radius: CGFloat, sides: Int) -> Path {
        var path = Path()
        guard sides >= 3 else { return path }
        for i in 0..<sides {
            let p = point(center: center, radius: radius, index: i, total: sides)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        return path
    }

    private func dataPolygon(center: CGPoint, radius: CGFloat) -> Path {
        var path = Path()
        let n = points.count
        guard n >= 3 else { return path }
        for i in 0..<n {
            let ratio = maxValue > 0 ? min(points[i].value / maxValue, 1) : 0
            let p = point(center: center, radius: radius * CGFloat(ratio), index: i, total: n)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        return path
    }
}
