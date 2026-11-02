import AppKit

// All course geometry uses the overlay's coordinates: origin at the top-left of
// the main display, y pointing down. That's the same space CGWindowList uses.

/// A wall: the visible part of one window edge (or a screen edge).
struct Segment {
    var a: CGPoint
    var b: CGPoint

    func closestPoint(to p: CGPoint) -> CGPoint {
        let ab = b - a
        let lengthSquared = ab.dot(ab)
        guard lengthSquared > 0 else { return a }
        let t = max(0, min(1, (p - a).dot(ab) / lengthSquared))
        return a + ab * t
    }

    func intersects(_ p: CGPoint, _ q: CGPoint) -> Bool {
        func cross(_ o: CGPoint, _ u: CGPoint, _ v: CGPoint) -> CGFloat {
            (u.x - o.x) * (v.y - o.y) - (u.y - o.y) * (v.x - o.x)
        }
        let d1 = cross(a, b, p), d2 = cross(a, b, q)
        let d3 = cross(p, q, a), d4 = cross(p, q, b)
        return (d1 > 0) != (d2 > 0) && (d3 > 0) != (d4 > 0)
    }
}

/// Sand: slows the ball down hard. The Dock is one; each hole adds an oval trap.
struct Bunker {
    var rect: CGRect
    var oval: Bool

    func contains(_ p: CGPoint) -> Bool {
        guard oval else { return rect.contains(p) }
        let dx = (p.x - rect.midX) / (rect.width / 2)
        let dy = (p.y - rect.midY) / (rect.height / 2)
        return dx * dx + dy * dy <= 1
    }
}

enum CourseScanner {
    /// Frames of ordinary app windows on screen, front to back.
    /// Reading bounds needs no Screen Recording permission (only titles do).
    static func windowRects() -> [CGRect] {
        guard let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                    kCGNullWindowID) as? [[String: Any]]
        else { return [] }
        let me = ProcessInfo.processInfo.processIdentifier
        return info.compactMap { window in
            guard (window[kCGWindowLayer as String] as? Int) == 0,
                  (window[kCGWindowOwnerPID as String] as? pid_t) != me,
                  (window[kCGWindowAlpha as String] as? Double ?? 1) > 0.05,
                  let bounds = window[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary),
                  rect.width >= 60, rect.height >= 40
            else { return nil }
            return rect
        }
    }

    /// Turns window frames into walls. Only the visible part of each edge counts:
    /// an edge hidden behind a window in front of it isn't a wall.
    static func walls(windows: [CGRect], play: CGRect) -> [Segment] {
        var walls = [
            Segment(a: CGPoint(x: play.minX, y: play.minY), b: CGPoint(x: play.maxX, y: play.minY)),
            Segment(a: CGPoint(x: play.minX, y: play.maxY), b: CGPoint(x: play.maxX, y: play.maxY)),
            Segment(a: CGPoint(x: play.minX, y: play.minY), b: CGPoint(x: play.minX, y: play.maxY)),
            Segment(a: CGPoint(x: play.maxX, y: play.minY), b: CGPoint(x: play.maxX, y: play.maxY)),
        ]
        for (i, rect) in windows.enumerated() {
            let inFront = windows[..<i]
            for y in [rect.minY, rect.maxY] where y > play.minY && y < play.maxY {
                var spans = clip((rect.minX, rect.maxX), to: (play.minX, play.maxX))
                for f in inFront where f.minY < y && y < f.maxY { spans = subtract(spans, (f.minX, f.maxX)) }
                walls += spans.map { Segment(a: CGPoint(x: $0.lo, y: y), b: CGPoint(x: $0.hi, y: y)) }
            }
            for x in [rect.minX, rect.maxX] where x > play.minX && x < play.maxX {
                var spans = clip((rect.minY, rect.maxY), to: (play.minY, play.maxY))
                for f in inFront where f.minX < x && x < f.maxX { spans = subtract(spans, (f.minY, f.maxY)) }
                walls += spans.map { Segment(a: CGPoint(x: x, y: $0.lo), b: CGPoint(x: x, y: $0.hi)) }
            }
        }
        return walls
    }

    typealias Span = (lo: CGFloat, hi: CGFloat)

    private static func clip(_ span: Span, to bounds: Span) -> [Span] {
        let lo = max(span.lo, bounds.lo), hi = min(span.hi, bounds.hi)
        return hi - lo > 2 ? [(lo, hi)] : []
    }

    private static func subtract(_ spans: [Span], _ cut: Span) -> [Span] {
        spans.flatMap { span -> [Span] in
            if cut.hi <= span.lo || cut.lo >= span.hi { return [span] }
            var parts: [Span] = []
            if cut.lo - span.lo > 2 { parts.append((span.lo, cut.lo)) }
            if span.hi - cut.hi > 2 { parts.append((cut.hi, span.hi)) }
            return parts
        }
    }
}

// MARK: - Vector helpers

extension CGPoint {
    static func + (p: CGPoint, v: CGVector) -> CGPoint { CGPoint(x: p.x + v.dx, y: p.y + v.dy) }
    static func - (p: CGPoint, q: CGPoint) -> CGVector { CGVector(dx: p.x - q.x, dy: p.y - q.y) }
    func distance(to p: CGPoint) -> CGFloat { hypot(x - p.x, y - p.y) }
}

extension CGVector {
    var length: CGFloat { hypot(dx, dy) }
    var normalized: CGVector { length > 0 ? self * (1 / length) : .zero }
    func dot(_ v: CGVector) -> CGFloat { dx * v.dx + dy * v.dy }
    func rotated(by angle: CGFloat) -> CGVector {
        CGVector(dx: dx * cos(angle) - dy * sin(angle), dy: dx * sin(angle) + dy * cos(angle))
    }
    static func * (v: CGVector, s: CGFloat) -> CGVector { CGVector(dx: v.dx * s, dy: v.dy * s) }
    static func + (a: CGVector, b: CGVector) -> CGVector { CGVector(dx: a.dx + b.dx, dy: a.dy + b.dy) }
    static func - (a: CGVector, b: CGVector) -> CGVector { CGVector(dx: a.dx - b.dx, dy: a.dy - b.dy) }
}
