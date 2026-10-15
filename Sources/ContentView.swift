import SwiftUI

/// Time of day shown on the card. Same windows as the web page.
enum DayPhase: String {
    case day, evening, sunset, night

    /// Day until 16:30, evening until 17:45, sunset until 18:45, night until 06:00, local time.
    static func at(_ date: Date) -> DayPhase {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        let hour = Double(parts.hour ?? 0) + Double(parts.minute ?? 0) / 60
        if hour >= 18.75 || hour < 6 { return .night }
        if hour >= 17.75 { return .sunset }
        return hour >= 16.5 ? .evening : .day
    }
}

/// The cards on screen: one per train livery we have (web/index.html LIVERIES), each named after an Indian station.
/// All share the same time-of-day scene (`DayPhase.at`). The first few web views are pre-warmed at launch (see StationCardApp).
enum Cards {
    static let all: [(id: String, phase: DayPhase, livery: String, title: String, code: String)] = [
        ("red",           DayPhase.at(Date()), "red",           "Mysuru\nJunction",       "MYS"),
        ("blue",          DayPhase.at(Date()), "blue",          "Howrah\nJunction",       "HWH"),
        ("icfblue",       DayPhase.at(Date()), "icfblue",       "Lucknow\nCharbagh",      "LKO"),
        ("utkrisht",      DayPhase.at(Date()), "utkrisht",      "Madurai\nJunction",      "MDU"),
        ("brick",         DayPhase.at(Date()), "brick",         "Jaipur\nJunction",       "JP"),
        ("rajdhani",      DayPhase.at(Date()), "rajdhani",      "New Delhi\nStation",     "NDLS"),
        ("shatabdi",      DayPhase.at(Date()), "shatabdi",      "Chandigarh\nJunction",   "CDG"),
        ("garibrath",     DayPhase.at(Date()), "garibrath",     "Patna\nJunction",        "PNBE"),
        ("duronto",       DayPhase.at(Date()), "duronto",       "Nagpur\nJunction",       "NGP"),
        ("janshatabdi",   DayPhase.at(Date()), "janshatabdi",   "Kota\nJunction",         "KOTA"),
        ("deendayalu",    DayPhase.at(Date()), "deendayalu",    "Gorakhpur\nJunction",    "GKP"),
        ("mahamana",      DayPhase.at(Date()), "mahamana",      "Varanasi\nJunction",     "BSB"),
        ("lhbred",        DayPhase.at(Date()), "lhbred",        "Mumbai\nCentral",        "MMCT"),
        ("lhbdeendayalu", DayPhase.at(Date()), "lhbdeendayalu", "Bhopal\nJunction",       "BPL"),
        ("lhbblue",       DayPhase.at(Date()), "lhbblue",       "Agra\nCantt",            "AGC"),
        ("gatimaan",      DayPhase.at(Date()), "gatimaan",      "Jhansi\nJunction",       "JHS"),
        ("humsafar",      DayPhase.at(Date()), "humsafar",      "Guwahati\nStation",      "GHY"),
        ("tejas",         DayPhase.at(Date()), "tejas",         "Madgaon\nJunction",      "MAO"),
        ("antyodaya",     DayPhase.at(Date()), "antyodaya",     "Ernakulam\nJunction",    "ERS"),
        ("uday",          DayPhase.at(Date()), "uday",          "Vijayawada\nJunction",   "BZA"),
        ("doubledecker",  DayPhase.at(Date()), "doubledecker",  "Ahmedabad\nJunction",    "ADI"),
        ("garibrathlhb",  DayPhase.at(Date()), "garibrathlhb",  "Jodhpur\nJunction",      "JU"),
        ("vistadome",     DayPhase.at(Date()), "vistadome",     "Visakhapatnam\nStation", "VSKP"),
        ("amritbharat",   DayPhase.at(Date()), "amritbharat",   "Darbhanga\nJunction",    "DBG"),
    ]
}

struct ContentView: View {
    var body: some View { HomeScreen() }
}

/// The earlier stacked-cards layout, kept for reference.
struct CardsListView: View {
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(Cards.all, id: \.id) { card in
                        StationCard(id: card.id, title: card.title, code: card.code,
                                    width: geo.size.width - 26,          // 13 pt clear on each side
                                    isActive: scenePhase == .active,
                                    phase: card.phase, livery: card.livery)
                    }
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 16)
            }
            .background(Color(red: 0xF7 / 255, green: 0xF7 / 255, blue: 0xF5 / 255).ignoresSafeArea())
        }
        .preferredColorScheme(.light)
    }
}

/// The card is native: rounded panel, soft shadow, title in Inter.
/// The train is a transparent web layer behind the title, filling the bottom 200/400 of the card edge to edge.
/// The card scales with `width` (design size 320 × 380) so the scene keeps the same composition on any screen.
/// `isActive` pauses the render loop when the card is off-screen or the app is in the background.
/// `phase` picks the scene lighting; only `.night` darkens the card itself.
struct StationCard: View {
    let id: String
    let title: String
    /// station code engraved on the arch's crown plaque (e.g. "MYS")
    var code: String = ""
    var width: CGFloat = 320
    var isActive: Bool = true
    var phase: DayPhase = .day
    var isStation: Bool = false
    var livery: String = "red"

    @State private var isVisible = false
    @ObservedObject private var host: TrainWebViewHost

    init(id: String, title: String, code: String = "", width: CGFloat = 320, isActive: Bool = true, phase: DayPhase = .day, livery: String = "red", isStation: Bool = false) {
        self.id = id; self.title = title; self.code = code; self.width = width; self.isActive = isActive; self.phase = phase; self.livery = livery; self.isStation = isStation
        _host = ObservedObject(wrappedValue: TrainWebViewHost.host(id: id))
    }

    static let designSize = CGSize(width: 320, height: 400)
    static let designStageHeight: CGFloat = 200   // web/index.html .stage: full card width, 200/320 tall (the scene at 0.8 × its original scale)
    static let nightBackground = Color(red: 0x2C / 255, green: 0x0D / 255, blue: 0x10 / 255)   // #2C0D10
    /// PostScript name of the bundled serif (Resources/LightTextTrial-Regular.otf); Light / Bold are bundled too.
    static let titleFont = "BusinessSerifTrial-TextRegular"
    /// Stone arch (Resources/arch-<phase>@3x.png, rendered from station-card/arch.html): 94% of the card width,
    /// centred, touching the top edge; it sits behind the train stage (the scene overlaps its capitals).
    static let archSize = CGSize(width: 301, height: 301 * 1001 / 1056)
    static let plaqueCenterY: CGFloat = archSize.height * 38 / 1001     // crown plaque centre, from the asset
    static let titleCenterY: CGFloat = archSize.height * 0.51          // title block centred in the opening (mock)

    private var scale: CGFloat { width / Self.designSize.width }
    private var height: CGFloat { Self.designSize.height * scale }
    private var stageHeight: CGFloat { Self.designStageHeight * scale }
    private var isNight: Bool { phase == .night }

    var body: some View {
        ZStack(alignment: .top) {
            // stone arch backdrop; the train scene runs in front of it
            if let arch = UIImage(named: "arch-\(phase.rawValue)") {
                Image(uiImage: arch).resizable()
                    .frame(width: Self.archSize.width * scale, height: Self.archSize.height * scale)
                    // faint shadow on the card behind the arch, cast down-right by the render's key light (upper-left, in front)
                    .shadow(color: .black.opacity(isNight ? 0.25 : 0.10), radius: 8 * scale, x: 4 * scale, y: 7 * scale)
            }
            Text(code)
                .font(.custom("Inter", size: 10 * scale).weight(.medium))
                .tracking(1.4 * scale)
                .foregroundStyle(isNight ? Color(red: 0xB4 / 255, green: 0xB9 / 255, blue: 0xC8 / 255) : Color(red: 0x6E / 255, green: 0x6E / 255, blue: 0x6E / 255))
                .frame(height: 20 * scale)
                .padding(.top, (Self.plaqueCenterY - 10) * scale)
            TrainWebView(id: id, isActive: isActive && isVisible, phase: phase, isStation: isStation, livery: livery)
            // the scene's own first frame, pre-rendered, shown until the live page has drawn one
            if !host.isReady, !isStation, let placeholder = UIImage(named: "placeholder-\(phase.rawValue)") {
                VStack { Spacer(); Image(uiImage: placeholder).resizable().frame(width: width, height: stageHeight) }
                    .frame(width: width, height: height)
                    .transition(.opacity)
            }
            Text(title)
                .font(.custom(StationCard.titleFont, size: 26 * scale))   // Light Text Trial (Business Serif), Regular weight
                .lineSpacing(5 * scale)
                .multilineTextAlignment(.center)
                .foregroundStyle(isNight ? Color.white : Color(red: 0x11 / 255, green: 0x11 / 255, blue: 0x11 / 255))
                .frame(height: 70 * scale)                 // two lines, block centred in the arch opening
                .padding(.top, (Self.titleCenterY - 35) * scale)
        }
        .frame(width: width, height: height)
        .background(isNight ? Self.nightBackground : Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 28 * scale, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 1, y: 1)
        .shadow(color: .black.opacity(0.05), radius: 12, y: 8)
        .animation(.easeOut(duration: 0.25), value: host.isReady)
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
    }
}

#Preview {
    ContentView()
}
