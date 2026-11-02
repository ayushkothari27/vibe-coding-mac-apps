import AppKit

/// Transparent full-screen panel that floats over everything, including the Dock.
final class OverlayPanel: NSPanel {
    init(frame: CGRect) {
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Draws the course on top of your desktop and turns drags near the ball into shots.
/// Clicks pass through to your windows everywhere except right around the ball.
final class GameView: NSView {
    let game: Game
    var onClose: (() -> Void)?

    private var link: CADisplayLink?
    private var lastFrame: CFTimeInterval = 0
    private var lastScan: CFTimeInterval = 0
    private var hovering = false

    init(game: Game, frame: CGRect) {
        self.game = game
        super.init(frame: frame)
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    func start() {
        guard link == nil else { return }
        lastFrame = 0
        link = displayLink(target: self, selector: #selector(tick(_:)))
        link?.add(to: .main, forMode: .common)
        needsDisplay = true
    }

    func stop() {
        link?.invalidate()
        link = nil
    }

    @objc private func tick(_ link: CADisplayLink) {
        let now = link.timestamp
        let dt = lastFrame == 0 ? 1.0 / 60 : now - lastFrame
        lastFrame = now

        var dirty = false
        if now - lastScan > 0.15 {
            lastScan = now
            dirty = game.rescan()
        }
        let before = game.phase
        game.tick(dt)
        dirty = dirty || game.phase != before || game.isAnimating
        if updateMouseCapture() { dirty = true }
        if hovering { dirty = true } // keeps the grab ring pulsing
        if dirty { needsDisplay = true }
    }

    /// Lets clicks through unless the cursor is on the ball (or the scorecard).
    /// Returns true if the hover state changed.
    private func updateMouseCapture() -> Bool {
        guard let window else { return false }
        let mouse = NSEvent.mouseLocation
        let point = CGPoint(x: mouse.x - window.frame.minX, y: window.frame.maxY - mouse.y)
        let wants: Bool
        switch game.phase {
        case .aiming: wants = true
        case .resting: wants = point.distance(to: game.ball) <= Game.grabRadius
        case .finished: wants = cardRect.contains(point)
        default: wants = false
        }
        if window.ignoresMouseEvents == wants { window.ignoresMouseEvents = !wants }
        guard wants != hovering else { return false }
        hovering = wants
        return true
    }

    // MARK: - Input

    override func mouseDown(with event: NSEvent) {
        window?.makeKey()
        let point = convert(event.locationInWindow, from: nil)
        if game.phase == .finished {
            if cardRect.contains(point) { game.newRound() }
        } else {
            _ = game.beginAim(at: point)
        }
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard game.phase == .aiming else { return }
        game.aimPoint = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        game.endAim()
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // esc
            if game.phase == .aiming { game.cancelAim() } else { onClose?() }
            needsDisplay = true
        } else {
            super.keyDown(with: event)
        }
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.set()
        dirtyRect.fill()

        drawBunkers()
        drawWalls()
        drawCup()
        drawTrail()
        if game.phase == .aiming { drawAim() }
        if game.phase != .sunk && game.phase != .finished { drawBall() }
        drawToast()
        drawHUD()
        if game.phase == .finished { drawScorecard() }
    }

    private func drawWalls() {
        let path = NSBezierPath()
        for wall in game.walls {
            path.move(to: wall.a)
            path.line(to: wall.b)
        }
        path.lineWidth = 2
        path.lineCapStyle = .round
        Theme.green.withAlphaComponent(0.55).setStroke()
        path.stroke()
    }

    private func drawBunkers() {
        for bunker in game.bunkers {
            let path = bunker.oval
                ? NSBezierPath(ovalIn: bunker.rect)
                : NSBezierPath(roundedRect: bunker.rect, xRadius: 10, yRadius: 10)
            Theme.yellow.withAlphaComponent(bunker.oval ? 0.30 : 0.16).setFill()
            path.fill()
            path.lineWidth = 1.5
            path.setLineDash([4, 4], count: 2, phase: 0)
            Theme.yellow.withAlphaComponent(0.6).setStroke()
            path.stroke()
        }
    }

    private func drawCup() {
        let cup = game.cup, r = Game.cupRadius
        // Flag: a pole rising from the cup with a pennant showing the hole number.
        let top = CGPoint(x: cup.x, y: cup.y - 46)
        let pole = NSBezierPath()
        pole.move(to: cup)
        pole.line(to: top)
        pole.lineWidth = 2
        Theme.text.withAlphaComponent(0.9).setStroke()
        pole.stroke()

        let flag = NSBezierPath()
        flag.move(to: top)
        flag.line(to: CGPoint(x: top.x + 30, y: top.y + 9))
        flag.line(to: CGPoint(x: top.x, y: top.y + 18))
        flag.close()
        Theme.orange.setFill()
        flag.fill()
        drawText("\(game.hole)", font: Theme.body(10, .bold), color: Theme.text,
                 center: CGPoint(x: top.x + 10, y: top.y + 9))

        let hole = NSBezierPath(ovalIn: CGRect(x: cup.x - r, y: cup.y - r * 0.8, width: r * 2, height: r * 1.6))
        NSColor.black.withAlphaComponent(0.85).setFill()
        hole.fill()
        hole.lineWidth = 1.5
        Theme.text.withAlphaComponent(0.45).setStroke()
        hole.stroke()
    }

    private func drawTrail() {
        let points = game.trail + (game.phase == .rolling ? [game.ball] : [])
        guard points.count > 1 else { return }
        for i in 1..<points.count {
            let path = NSBezierPath()
            path.move(to: points[i - 1])
            path.line(to: points[i])
            path.lineWidth = 3
            path.lineCapStyle = .round
            NSColor.white.withAlphaComponent(0.35 * CGFloat(i) / CGFloat(points.count)).setStroke()
            path.stroke()
        }
    }

    private func drawAim() {
        guard let aim = game.aimPoint else { return }
        let ball = game.ball
        let power = game.aimPower
        let pull = ball - aim
        guard pull.length > 4 else { return }
        let color = power < 0.5
            ? Theme.green.blended(withFraction: power * 2, of: Theme.yellow)!
            : Theme.yellow.blended(withFraction: (power - 0.5) * 2, of: Theme.orange)!

        // Rubber band back to the cursor.
        let band = NSBezierPath()
        band.move(to: ball)
        band.line(to: ball + pull.normalized * -(power * Game.maxPull))
        band.lineWidth = 1.5
        NSColor.white.withAlphaComponent(0.35).setStroke()
        band.stroke()

        // Dotted shot line in the direction the ball will travel.
        let direction = pull.normalized
        let length = 30 + power * 240
        var t: CGFloat = 16
        color.setFill()
        while t < length {
            let p = ball + direction * t
            let size = 5 - 2.5 * (t / length)
            NSBezierPath(ovalIn: CGRect(x: p.x - size / 2, y: p.y - size / 2, width: size, height: size)).fill()
            t += 12
        }

        drawText("\(Int((power * 100).rounded()))%", font: Theme.body(12, .bold), color: color,
                 center: CGPoint(x: ball.x, y: ball.y + 26))
    }

    private func drawBall() {
        let p = game.ball, r = Game.ballRadius
        if hovering && game.phase == .resting {
            let pulse = 0.5 + 0.5 * sin(CACurrentMediaTime() * 5)
            let ringR = r + 7 + 3 * pulse
            let ring = NSBezierPath(ovalIn: CGRect(x: p.x - ringR, y: p.y - ringR, width: ringR * 2, height: ringR * 2))
            ring.lineWidth = 2
            Theme.text.withAlphaComponent(0.35 + 0.3 * pulse).setStroke()
            ring.stroke()
        }
        NSColor.black.withAlphaComponent(0.35).setFill()
        NSBezierPath(ovalIn: CGRect(x: p.x - r + 1.5, y: p.y - r + 2.5, width: r * 2, height: r * 2)).fill()
        NSColor.white.setFill()
        NSBezierPath(ovalIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)).fill()
        NSColor.black.withAlphaComponent(0.12).setFill()
        NSBezierPath(ovalIn: CGRect(x: p.x - 1, y: p.y - 1, width: r, height: r)).fill()
    }

    private func drawToast() {
        guard let toast = game.toast else { return }
        let age = Date().timeIntervalSince(toast.start)
        guard age < Game.toastLifetime else { return }
        let alpha = CGFloat(min(1, (Game.toastLifetime - age) / 0.5))
        let rise = CGFloat(age) * 18
        drawText(toast.text, font: Theme.accent(30), color: Theme.text.withAlphaComponent(alpha),
                 center: CGPoint(x: toast.at.x, y: toast.at.y - 72 - rise), shadow: true)
    }

    private func drawHUD() {
        let total = game.cards.isEmpty ? "–" : Game.formatToPar(game.totalToPar)
        let parts: [(String, String)] = [
            ("HOLE", "\(game.hole)/\(Game.holesPerRound)"),
            ("PAR", "\(game.par)"),
            ("STROKES", "\(game.strokes)"),
            ("TOTAL", total),
        ]
        let label = Theme.body(10, .medium), value = Theme.body(14, .bold)
        let line = NSMutableAttributedString()
        for (i, part) in parts.enumerated() {
            if i > 0 { line.append(NSAttributedString(string: "    ")) }
            line.append(NSAttributedString(string: part.0 + "  ", attributes: [.font: label, .foregroundColor: Theme.muted]))
            line.append(NSAttributedString(string: part.1, attributes: [.font: value, .foregroundColor: Theme.text]))
        }
        let size = line.size()
        let pill = CGRect(x: game.play.midX - size.width / 2 - 18, y: game.play.minY + 10,
                          width: size.width + 36, height: size.height + 14)
        let path = NSBezierPath(roundedRect: pill, xRadius: pill.height / 2, yRadius: pill.height / 2)
        Theme.bg.withAlphaComponent(0.9).setFill()
        path.fill()
        path.lineWidth = 1
        NSColor.white.withAlphaComponent(0.1).setStroke()
        path.stroke()
        line.draw(at: CGPoint(x: pill.minX + 18, y: pill.minY + 7))

        if game.hole == 1 && game.strokes == 0 && game.phase != .finished {
            drawText("Drag back from the ball and let go  ·  move windows to reshape the course  ·  esc to quit",
                     font: Theme.body(12), color: Theme.text.withAlphaComponent(0.85),
                     center: CGPoint(x: pill.midX, y: pill.maxY + 18), shadow: true)
        }
    }

    private var cardRect: CGRect {
        let size = CGSize(width: 480, height: 290)
        return CGRect(x: game.play.midX - size.width / 2, y: game.play.midY - size.height / 2,
                      width: size.width, height: size.height)
    }

    private func drawScorecard() {
        let card = cardRect
        let path = NSBezierPath(roundedRect: card, xRadius: 20, yRadius: 20)
        Theme.bg.withAlphaComponent(0.96).setFill()
        path.fill()
        NSGraphicsContext.saveGraphicsState()
        path.addClip()
        let glow = NSGradient(colors: [Theme.indigo.withAlphaComponent(0.35), Theme.indigo.withAlphaComponent(0)])
        glow?.draw(fromCenter: CGPoint(x: card.maxX - 40, y: card.minY + 20), radius: 0,
                   toCenter: CGPoint(x: card.maxX - 40, y: card.minY + 20), radius: 220, options: [])
        NSGraphicsContext.restoreGraphicsState()
        path.lineWidth = 1
        NSColor.white.withAlphaComponent(hovering ? 0.25 : 0.1).setStroke()
        path.stroke()

        drawText("Round complete", font: Theme.display(28), color: Theme.text,
                 center: CGPoint(x: card.midX, y: card.minY + 44))
        let strokes = game.cards.reduce(0) { $0 + $1.strokes }
        let toPar = game.totalToPar
        let toParColor = toPar < 0 ? Theme.green : toPar == 0 ? Theme.text : Theme.orange
        drawText("\(strokes) strokes  ·  \(Game.formatToPar(toPar))", font: Theme.accent(20), color: toParColor,
                 center: CGPoint(x: card.midX, y: card.minY + 82))

        // One cell per hole: number, strokes, par.
        let cellWidth: CGFloat = 44
        let startX = card.midX - cellWidth * CGFloat(game.cards.count) / 2
        for (i, hole) in game.cards.enumerated() {
            let x = startX + cellWidth * (CGFloat(i) + 0.5)
            let diff = hole.strokes - hole.par
            let color = diff < 0 ? Theme.green : diff == 0 ? Theme.text : Theme.orange
            drawText("\(i + 1)", font: Theme.body(10, .medium), color: Theme.muted, center: CGPoint(x: x, y: card.minY + 124))
            drawText("\(hole.strokes)", font: Theme.body(20, .bold), color: color, center: CGPoint(x: x, y: card.minY + 148))
            drawText("par \(hole.par)", font: Theme.body(9), color: Theme.muted, center: CGPoint(x: x, y: card.minY + 172))
        }

        let best = game.newBest ? "New best round!" : game.bestToPar.map { "Best round: \(Game.formatToPar($0))" } ?? ""
        drawText(best, font: Theme.body(13, .medium), color: game.newBest ? Theme.yellow : Theme.muted,
                 center: CGPoint(x: card.midX, y: card.minY + 212))
        drawText("Click to play again  ·  esc to close", font: Theme.body(12), color: Theme.text.withAlphaComponent(0.7),
                 center: CGPoint(x: card.midX, y: card.maxY - 34))
    }

    private func drawText(_ text: String, font: NSFont, color: NSColor, center: CGPoint, shadow: Bool = false) {
        var attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        if shadow {
            let s = NSShadow()
            s.shadowColor = NSColor.black.withAlphaComponent(0.8)
            s.shadowBlurRadius = 6
            s.shadowOffset = .zero
            attributes[.shadow] = s
        }
        let string = NSAttributedString(string: text, attributes: attributes)
        let size = string.size()
        string.draw(at: CGPoint(x: center.x - size.width / 2, y: center.y - size.height / 2))
    }
}
