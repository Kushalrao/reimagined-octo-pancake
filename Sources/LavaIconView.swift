import SwiftUI
import UIKit

/// Shows a `.lava` icon clip (see LavaClip). It sits on its first frame (the poster) and plays the clip once,
/// from the start, every time `play` changes, the way Airbnb's tab icons play their entry/selected clips.
/// Honours Reduce Motion by staying on the poster. If the clip is missing the view stays empty.
struct LavaIconView: UIViewRepresentable {
    let name: String
    var play: Int = 0

    func makeUIView(context: Context) -> LavaIconUIView {
        let v = LavaIconUIView()
        v.clip = LavaClip.named(name)
        v.lastPlay = play
        return v
    }

    func updateUIView(_ v: LavaIconUIView, context: Context) {
        if v.lastPlay != play { v.lastPlay = play; v.playOnce() }
    }

    static func dismantleUIView(_ v: LavaIconUIView, coordinator: ()) { v.stop() }
}

final class LavaIconUIView: UIView {
    var clip: LavaClip? { didSet { show(0) } }
    var lastPlay = 0
    private var link: CADisplayLink?
    private var start: CFTimeInterval = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        layer.contentsGravity = .resizeAspect
        layer.magnificationFilter = .linear
        layer.minificationFilter = .trilinear
    }
    required init?(coder: NSCoder) { fatalError() }

    private func show(_ i: Int) {
        guard let clip, !clip.frames.isEmpty else { layer.contents = nil; return }
        layer.contents = clip.frames[max(0, min(i, clip.frames.count - 1))]
    }

    func playOnce() {
        guard let clip, clip.frames.count > 1, !UIAccessibility.isReduceMotionEnabled else { return }
        stop()
        start = CACurrentMediaTime()
        let l = CADisplayLink(target: self, selector: #selector(tick))
        l.preferredFrameRateRange = CAFrameRateRange(minimum: Float(clip.fps), maximum: 120, preferred: Float(clip.fps))
        l.add(to: .main, forMode: .common)
        link = l
        show(0)
    }

    @objc private func tick(_ l: CADisplayLink) {
        guard let clip else { stop(); return }
        let i = Int((l.targetTimestamp - start) * Double(clip.fps))
        if i >= clip.frames.count { stop(); show(0); return }       // a full turn ends where it began: back on the poster
        show(i)
    }

    func stop() { link?.invalidate(); link = nil }
}
