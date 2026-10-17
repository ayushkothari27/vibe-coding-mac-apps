import AppKit
import Observation
import SwiftUI

/// A floating panel that takes keyboard input without activating the app,
/// so whatever you were working in stays frontmost.
final class FloatingPanel: NSPanel {
    var onCancel: (() -> Void)?
    /// Where the panel goes for a given size. Re-applied on every resize, so the
    /// panel stays put as its content grows or shrinks.
    private var placement: ((NSSize) -> NSPoint)?

    func place(_ placement: @escaping (NSSize) -> NSPoint) {
        self.placement = placement
        setFrame(frame, display: true)
    }

    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        super.setFrame(placed(frameRect), display: flag)
    }

    override func setFrame(_ frameRect: NSRect, display displayFlag: Bool, animate animateFlag: Bool) {
        super.setFrame(placed(frameRect), display: displayFlag, animate: animateFlag)
    }

    private func placed(_ rect: NSRect) -> NSRect {
        guard let placement else { return rect }
        return NSRect(origin: placement(rect.size), size: rect.size)
    }

    init<Content: View>(_ content: Content) {
        super.init(contentRect: .zero, styleMask: [.nonactivatingPanel, .borderless],
                   backing: .buffered, defer: false)
        isMovableByWindowBackground = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        appearance = NSAppearance(named: .darkAqua)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true

        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        let host = NSHostingView(rootView: content
            .background(ThemeBackground())
            .clipShape(shape)
            .overlay(shape.strokeBorder(Theme.border)))
        // Track the content's size, so the panel shrinks as loops are closed.
        host.sizingOptions = [.minSize, .maxSize]
        contentView = host
        setContentSize(host.fittingSize)
    }

    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
        close()
    }
}

struct CaptureView: View {
    let loops: LoopStore
    let onSubmit: (String) -> Void
    private let text = Box("")
    private let hovered = Box<UUID?>(nil)
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Park a \(Text("loop").font(Theme.accent(24)).foregroundStyle(Theme.yellow))")
                    .font(Theme.display(24))
                    .foregroundStyle(Theme.text)
                Spacer()
                Text("↩ park  ·  esc close")
                    .font(Theme.body(11))
                    .foregroundStyle(Theme.muted)
            }

            TextField("", text: Bindable(text).value,
                      prompt: Text("What's still nagging you?").foregroundStyle(Theme.muted))
                .textFieldStyle(.plain)
                .font(Theme.body(16))
                .foregroundStyle(Theme.text)
                .focused($focused)
                .onSubmit { onSubmit(text.value) }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(focused ? Theme.orange : Theme.border, lineWidth: 1))

            if loops.open.isEmpty {
                Text("Mind clear.")
                    .font(Theme.body(12))
                    .foregroundStyle(Theme.muted)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("STILL OPEN · \(loops.open.count)")
                        .font(Theme.body(10, .semibold))
                        .tracking(1.2)
                        .foregroundStyle(Theme.muted)
                    // No ScrollView: the panel sizes itself to fit, which a ScrollView defeats.
                    ForEach(loops.open.prefix(8)) { loop in
                        LoopRow(loop: loop, hovered: hovered,
                                onClose: { withAnimation(.easeOut(duration: 0.2)) { loops.close(loop.id) } },
                                onDelete: { withAnimation(.easeOut(duration: 0.2)) { loops.delete(loop.id) } })
                            .transition(.opacity.combined(with: .move(edge: .leading)))
                    }
                    if loops.open.count > 8 {
                        Text("+\(loops.open.count - 8) more in the menu bar")
                            .font(Theme.body(11))
                            .foregroundStyle(Theme.muted)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 20)
        .frame(width: 480)
        .onAppear { focused = true }
    }
}

/// A todo-style card: round check on the left, delete on hover.
struct LoopRow: View {
    let loop: OpenLoop
    let hovered: Box<UUID?>
    let onClose: () -> Void
    let onDelete: () -> Void

    var body: some View {
        let isHovered = hovered.value == loop.id
        HStack(spacing: 12) {
            Button(action: onClose) {
                Circle()
                    .strokeBorder(isHovered ? Theme.green : Theme.borderHover, lineWidth: 1.5)
                    .background(Circle().fill(isHovered ? Theme.green.opacity(0.12) : .clear))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .help("Close this loop")

            VStack(alignment: .leading, spacing: 2) {
                Text(loop.text)
                    .font(Theme.body(14, .medium))
                    .foregroundStyle(Theme.text)
                    .lineLimit(2)
                Text(loop.created.formatted(.relative(presentation: .named)))
                    .font(Theme.body(11))
                    .foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 0)

            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                    .frame(width: 22, height: 22)
                    .background(Theme.surfaceHover, in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1 : 0)
            .help("Delete")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(isHovered ? Theme.surfaceHover : Theme.surface, in: RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(isHovered ? Theme.borderHover : Theme.border))
        .contentShape(RoundedRectangle(cornerRadius: 13))
        .onHover { inside in
            if inside { hovered.value = loop.id } else if hovered.value == loop.id { hovered.value = nil }
        }
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }
}

struct ToastView: View {
    let title: String
    let accent: String
    let subtitle: String
    let loops: [OpenLoop]
    let onClose: (UUID) -> Void
    let onDismiss: () -> Void
    private let closed = Box<Set<UUID>>([])

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(title) \(Text(accent).font(Theme.accent(18)).foregroundStyle(Theme.yellow))")
                        .font(Theme.display(18))
                        .foregroundStyle(Theme.text)
                    Text(subtitle)
                        .font(Theme.body(11))
                        .foregroundStyle(Theme.muted)
                }
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                        .frame(width: 22, height: 22)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            ForEach(loops) { loop in
                let done = closed.value.contains(loop.id)
                Button {
                    closed.value.insert(loop.id)
                    onClose(loop.id)
                } label: {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .strokeBorder(done ? Theme.green : Theme.borderHover, lineWidth: 1.5)
                                .background(Circle().fill(done ? Theme.green : .clear))
                            if done {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(width: 16, height: 16)
                        Text(loop.text)
                            .font(Theme.body(13, .medium))
                            .strikethrough(done, color: Theme.muted)
                            .foregroundStyle(done ? Theme.muted : Theme.text)
                            .lineLimit(2)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 11))
                    .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Theme.border))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .animation(.easeOut(duration: 0.15), value: done)
            }
        }
        .padding(16)
        .frame(width: 340)
    }
}
