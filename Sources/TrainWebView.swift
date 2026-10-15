import SwiftUI
import WebKit
import UniformTypeIdentifiers

/// One shared, pre-warmed web view for the train stage. Creating it (and loading the page) at app
/// launch means the WebKit process, three.js and the scene are already up by the time the card appears.
final class TrainWebViewHost: NSObject, ObservableObject, WKNavigationDelegate, WKScriptMessageHandler {
    static let scheme = "app"

    /// One host per card. At most `maxLive` are kept: each is a WebKit process running a WebGL scene, so with many
    /// cards the ones that have scrolled out of view (inactive) are dropped, least recently used first, and rebuilt
    /// when they scroll back in. Visible cards are never dropped.
    static let maxLive = 4
    private static var hosts: [String: TrainWebViewHost] = [:]
    private static var order: [String] = []   // ids, least recently used first
    static func host(id: String) -> TrainWebViewHost {
        order.removeAll { $0 == id }; order.append(id)
        if let h = hosts[id] { return h }
        while hosts.count >= maxLive, let victim = order.first(where: { hosts[$0]?.active == false && $0 != id }) {
            hosts[victim]?.webView.removeFromSuperview()
            hosts[victim] = nil; order.removeAll { $0 == victim }
        }
        let h = TrainWebViewHost(); hosts[id] = h; return h
    }

    let webView: WKWebView
    /// True once the page has drawn its first frame; the card shows a pre-rendered frame until then.
    @Published private(set) var isReady = false
    private var loaded = false
    private(set) var active = true
    private var phase: DayPhase = .day
    private var station = false
    private var livery = "red"
    private var warmed = false

    override init() {
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(BundleSchemeHandler(), forURLScheme: Self.scheme)
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 320, height: 380), configuration: config)
        super.init()
        config.userContentController.add(self, name: "ready")
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.allowsBackForwardNavigationGestures = false
        webView.allowsLinkPreview = false
        webView.navigationDelegate = self
        webView.alpha = 0   // revealed by the page's "ready" message, once the first frame is drawn
    }

    /// Call as early as possible (app init) with the phase the card will show.
    func warm(phase: DayPhase, station: Bool, livery: String = "red") {
        guard !warmed else { return }
        warmed = true
        load(phase: phase, station: station, livery: livery)
    }

    private func load(phase: DayPhase, station: Bool, livery: String) {
        self.phase = phase
        self.station = station
        self.livery = livery
        loaded = false
        isReady = false
        webView.alpha = 0
        webView.load(URLRequest(url: URL(string: "\(Self.scheme)://card/index.html?phase=\(phase.rawValue)&station=\(station ? 1 : 0)&livery=\(livery)")!))
    }

    func setVariant(phase: DayPhase, station: Bool, livery: String) {
        if !warmed { warm(phase: phase, station: station, livery: livery); return }
        guard phase != self.phase || station != self.station || livery != self.livery else { return }
        load(phase: phase, station: station, livery: livery)
    }

    func setActive(_ value: Bool) {
        guard value != active else { return }
        active = value
        apply()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loaded = true
        apply()
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "ready" else { return }
        webView.alpha = 1
        isReady = true
    }

    private func apply() {
        guard loaded else { return }
        webView.evaluateJavaScript("window.setPaused && window.setPaused(\(active ? "false" : "true"))")
    }
}

/// SwiftUI wrapper around the shared host. `isActive` pauses the render loop off-screen / in the background;
/// `phase` and `isStation` reach the page as `?phase=…&station=…` (a change reloads it).
struct TrainWebView: UIViewRepresentable {
    let id: String
    var isActive: Bool = true
    var phase: DayPhase = .day
    var isStation: Bool = false
    var livery: String = "red"

    func makeUIView(context: Context) -> WKWebView {
        let host = TrainWebViewHost.host(id: id)
        host.setVariant(phase: phase, station: isStation, livery: livery)
        return host.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        let host = TrainWebViewHost.host(id: id)
        host.setVariant(phase: phase, station: isStation, livery: livery)
        host.setActive(isActive)
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: ()) {}
}

/// Maps `app://card/<path>` to files inside the bundled `web/` folder, with proper MIME types.
final class BundleSchemeHandler: NSObject, WKURLSchemeHandler {
    private let root = Bundle.main.resourceURL!.appendingPathComponent("web", isDirectory: true)

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url else { return }
        let path = url.path.isEmpty || url.path == "/" ? "/index.html" : url.path
        let fileURL = root.appendingPathComponent(String(path.dropFirst()))

        guard let data = try? Data(contentsOf: fileURL) else {
            task.didFailWithError(NSError(domain: NSURLErrorDomain, code: NSURLErrorFileDoesNotExist))
            return
        }
        let mime: String
        switch fileURL.pathExtension.lowercased() {
        case "html": mime = "text/html"
        case "js", "mjs": mime = "text/javascript"
        case "css": mime = "text/css"
        case "woff2": mime = "font/woff2"
        case "woff": mime = "font/woff"
        case "json": mime = "application/json"
        default: mime = UTType(filenameExtension: fileURL.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        }
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1",
                                       headerFields: ["Content-Type": "\(mime); charset=utf-8",
                                                      "Content-Length": "\(data.count)",
                                                      "Access-Control-Allow-Origin": "*"])!
        task.didReceive(response)
        task.didReceive(data)
        task.didFinish()
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}
}
