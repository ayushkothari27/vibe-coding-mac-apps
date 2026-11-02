import AppKit

enum Phase: Equatable {
    case resting, aiming, rolling, sunk, finished
}

struct HoleCard {
    var par: Int
    var strokes: Int
}

/// A 9-hole round played on the desktop. Owns the course, ball physics and scoring.
@MainActor
final class Game {
    static let holesPerRound = 9
    static let ballRadius: CGFloat = 7
    static let cupRadius: CGFloat = 11
    /// How close to the ball you must press to pick it up.
    static let grabRadius: CGFloat = 40
    static let maxPull: CGFloat = 200
    static let maxSpeed: CGFloat = 2300
    static let maxStrokes = 10
    static let toastLifetime: TimeInterval = 1.8

    // Course
    private(set) var play: CGRect = .zero
    private(set) var dock: CGRect?
    private(set) var windows: [CGRect] = []
    private(set) var walls: [Segment] = []
    private(set) var bunkers: [Bunker] = []

    // Round
    private(set) var hole = 1
    private(set) var par = 3
    private(set) var strokes = 0
    private(set) var cup: CGPoint = .zero
    private(set) var cards: [HoleCard] = []
    private(set) var phase: Phase = .resting
    private(set) var newBest = false

    // Ball
    private(set) var ball: CGPoint = .zero
    private(set) var velocity: CGVector = .zero
    private(set) var trail: [CGPoint] = []
    var aimPoint: CGPoint?

    private(set) var toast: (text: String, at: CGPoint, start: Date)?
    private var sunkAt = Date.distantPast
    private var overCup = false

    var bestToPar: Int? {
        get { UserDefaults.standard.object(forKey: "bestToPar") as? Int }
        set { UserDefaults.standard.set(newValue, forKey: "bestToPar") }
    }

    var holesInOne: Int {
        get { UserDefaults.standard.integer(forKey: "holesInOne") }
        set { UserDefaults.standard.set(newValue, forKey: "holesInOne") }
    }

    var totalToPar: Int { cards.reduce(0) { $0 + $1.strokes - $1.par } }

    var isAnimating: Bool {
        if let toast, Date().timeIntervalSince(toast.start) < Self.toastLifetime + 0.2 { return true }
        return phase == .rolling || phase == .aiming || phase == .sunk
    }

    /// Shot strength from 0 to 1 while aiming.
    var aimPower: CGFloat {
        guard let aimPoint else { return 0 }
        return min(ball.distance(to: aimPoint), Self.maxPull) / Self.maxPull
    }

    // MARK: - Course setup

    /// Playable area is the whole screen below the menu bar. The Dock becomes a bunker.
    func layout(for screen: NSScreen) {
        let frame = screen.frame, visible = screen.visibleFrame
        let menuBar = frame.maxY - visible.maxY
        play = CGRect(x: 0, y: menuBar, width: frame.width, height: frame.height - menuBar)
        let bottom = visible.minY - frame.minY
        let left = visible.minX - frame.minX
        let right = frame.maxX - visible.maxX
        if bottom > 4 {
            dock = CGRect(x: 0, y: frame.height - bottom, width: frame.width, height: bottom)
        } else if left > 4 {
            dock = CGRect(x: 0, y: menuBar, width: left, height: play.height)
        } else if right > 4 {
            dock = CGRect(x: frame.width - right, y: menuBar, width: right, height: play.height)
        } else {
            dock = nil
        }
        windows = []
        rescan()
    }

    /// Re-reads window positions. Returns true if the course changed.
    @discardableResult
    func rescan() -> Bool {
        let rects = CourseScanner.windowRects()
        guard rects != windows || walls.isEmpty else { return false }
        windows = rects
        walls = CourseScanner.walls(windows: rects, play: play)
        // A window dragged onto a resting ball shoves it aside.
        if phase != .rolling { collide(previous: ball) }
        return true
    }

    func newRound() {
        hole = 1
        cards = []
        newBest = false
        toast = nil
        startHole()
    }

    private func startHole() {
        rescan()
        strokes = 0
        velocity = .zero
        trail = []
        aimPoint = nil
        overCup = false
        bunkers = dock.map { [Bunker(rect: $0, oval: false)] } ?? []

        let diagonal = hypot(play.width, play.height)
        var best: (tee: CGPoint, cup: CGPoint)?
        for _ in 0..<400 {
            guard let tee = randomSpot(), let target = randomSpot() else { continue }
            let d = tee.distance(to: target)
            if best == nil || abs(d - 0.45 * diagonal) < abs(best!.tee.distance(to: best!.cup) - 0.45 * diagonal) {
                best = (tee, target)
            }
            if d > 0.3 * diagonal && d < 0.62 * diagonal { break }
        }
        ball = best?.tee ?? CGPoint(x: play.minX + 120, y: play.midY)
        cup = best?.cup ?? CGPoint(x: play.maxX - 120, y: play.midY)

        addSandTrap()
        par = computePar()
        phase = .resting
    }

    /// A point away from walls, sand and the screen edge.
    private func randomSpot() -> CGPoint? {
        let area = play.insetBy(dx: 60, dy: 50)
        guard area.width > 0, area.height > 0 else { return nil }
        let p = CGPoint(x: .random(in: area.minX...area.maxX), y: .random(in: area.minY...area.maxY))
        if bunkers.contains(where: { $0.contains(p) }) { return nil }
        if walls.contains(where: { $0.closestPoint(to: p).distance(to: p) < 24 }) { return nil }
        return p
    }

    /// Drops an oval of sand somewhere near the line from tee to cup.
    private func addSandTrap() {
        let line = cup - ball
        let normal = CGVector(dx: -line.dy, dy: line.dx).normalized
        for _ in 0..<30 {
            let center = ball + line * .random(in: 0.35...0.75) + normal * .random(in: -110...110)
            let size = CGSize(width: .random(in: 120...190), height: .random(in: 60...95))
            let rect = CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2,
                              width: size.width, height: size.height)
            if play.insetBy(dx: 10, dy: 10).contains(rect),
               rect.insetBy(dx: -40, dy: -40).contains(ball) == false,
               rect.insetBy(dx: -40, dy: -40).contains(cup) == false {
                bunkers.append(Bunker(rect: rect, oval: true))
                return
            }
        }
    }

    /// Par grows with distance, plus one if a window blocks the straight line.
    private func computePar() -> Int {
        let ratio = ball.distance(to: cup) / hypot(play.width, play.height)
        var par = ratio < 0.38 ? 2 : ratio < 0.52 ? 3 : 4
        if walls.contains(where: { $0.intersects(ball, cup) }) { par += 1 }
        return par
    }

    // MARK: - Shooting

    func beginAim(at point: CGPoint) -> Bool {
        guard phase == .resting, point.distance(to: ball) <= Self.grabRadius else { return false }
        phase = .aiming
        aimPoint = point
        return true
    }

    /// Slingshot: the ball flies away from where you let go.
    func endAim() {
        guard phase == .aiming, let aimPoint else { return }
        self.aimPoint = nil
        let pull = ball - aimPoint
        guard pull.length >= 6 else {
            phase = .resting
            return
        }
        // A curve gives finer control over short putts.
        let power = pow(min(pull.length, Self.maxPull) / Self.maxPull, 1.35)
        velocity = pull.normalized * (power * Self.maxSpeed)
        strokes += 1
        trail = [ball]
        phase = .rolling
        NSSound(named: "Tink")?.play()
    }

    func cancelAim() {
        guard phase == .aiming else { return }
        aimPoint = nil
        phase = .resting
    }

    // MARK: - Simulation

    func tick(_ dt: Double) {
        switch phase {
        case .rolling:
            step(CGFloat(min(dt, 1.0 / 30)))
        case .sunk where Date().timeIntervalSince(sunkAt) > 1.6:
            nextHole()
        default:
            break
        }
    }

    private func step(_ dt: CGFloat) {
        // Substeps keep a fast ball from tunnelling through a wall.
        let steps = max(1, Int((velocity.length * dt / (Self.ballRadius * 0.5)).rounded(.up)))
        let h = dt / CGFloat(steps)
        for _ in 0..<steps {
            let previous = ball
            ball = ball + velocity * h
            collide(previous: previous)
            if checkCup(h) { return }
        }

        let inSand = bunkers.contains { $0.contains(ball) }
        velocity = velocity * exp(-(inSand ? 5.0 : 0.85) * dt)
        let speed = velocity.length
        let drag = (inSand ? 260 : 45) * dt
        if speed <= drag || speed < 8 {
            velocity = .zero
            if strokes >= Self.maxStrokes {
                showToast("Picked up", at: ball)
                finishHole()
            } else {
                phase = .resting
            }
        } else {
            velocity = velocity * ((speed - drag) / speed)
        }

        if let last = trail.last, last.distance(to: ball) > 6 {
            trail.append(ball)
            if trail.count > 80 { trail.removeFirst(trail.count - 80) }
        }
    }

    /// Pushes the ball out of any wall it overlaps and bounces it.
    private func collide(previous: CGPoint) {
        for wall in walls {
            let closest = wall.closestPoint(to: ball)
            let offset = ball - closest
            let distance = offset.length
            guard distance < Self.ballRadius else { continue }
            var normal = offset.normalized
            if distance < 0.0001 {
                let back = previous - closest
                normal = back.length > 0.0001 ? back.normalized : CGVector(dx: 0, dy: -1)
            }
            ball = closest + normal * Self.ballRadius
            let into = velocity.dot(normal)
            if into < 0 { velocity = velocity - normal * (1.72 * into) }
        }
    }

    /// Returns true if the ball dropped. Fast balls lip out; slow ones near the cup curl in.
    private func checkCup(_ h: CGFloat) -> Bool {
        let distance = ball.distance(to: cup)
        let speed = velocity.length
        if distance < Self.cupRadius {
            if speed < 650 {
                sink()
                return true
            }
            if !overCup {
                velocity = velocity.rotated(by: .random(in: -0.5...0.5)) * 0.8
                showToast("Lip out", at: cup)
            }
            overCup = true
        } else {
            overCup = false
            if distance < Self.cupRadius * 2.4 && speed < 320 {
                velocity = velocity + (cup - ball).normalized * (520 * h)
            }
        }
        return false
    }

    private func sink() {
        ball = cup
        velocity = .zero
        if strokes == 1 { holesInOne += 1 }
        NSSound(named: strokes == 1 ? "Hero" : "Glass")?.play()
        showToast(Self.scoreName(strokes: strokes, par: par), at: cup)
        finishHole()
    }

    private func finishHole() {
        cards.append(HoleCard(par: par, strokes: strokes))
        sunkAt = Date()
        phase = .sunk
    }

    private func nextHole() {
        guard hole < Self.holesPerRound else {
            if bestToPar.map({ totalToPar < $0 }) ?? true {
                newBest = true
                bestToPar = totalToPar
            }
            phase = .finished
            return
        }
        hole += 1
        startHole()
    }

    private func showToast(_ text: String, at point: CGPoint) {
        toast = (text, point, Date())
    }

    // MARK: - Labels

    static func scoreName(strokes: Int, par: Int) -> String {
        if strokes == 1 { return "Hole in one!" }
        switch strokes - par {
        case ...(-3): return "Albatross!"
        case -2: return "Eagle!"
        case -1: return "Birdie!"
        case 0: return "Par"
        case 1: return "Bogey"
        case 2: return "Double bogey"
        default: return "+\(strokes - par)"
        }
    }

    static func formatToPar(_ n: Int) -> String {
        n == 0 ? "E" : n > 0 ? "+\(n)" : "−\(-n)"
    }
}
