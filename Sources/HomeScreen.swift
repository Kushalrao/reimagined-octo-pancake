import SwiftUI

/// Home screen from Figma (Decade-iter, node 171:218). Every size, colour and offset comes from the design;
/// the design is 390 pt wide, so everything scales with `s = width / 390` and stays proportional on any phone.
/// Coordinates are from the screen's top edge (the design frame includes the status bar), the card is anchored to the bottom.
struct HomeScreen: View {
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geo in
            let s = geo.size.width / 390
            let cardTop = Self.cardOrigin(in: geo.size, s: s)
            let cardH = Self.cardWidth(s) * StationCard.designSize.height / StationCard.designSize.width
            ScrollView(.vertical) {
            ZStack(alignment: .topLeading) {
                Color(hex: 0xF7F7F5)

                // header: CARVAAN logo centred, accessibility button at the right (171:275)
                ZStack {
                    BundleImage.view("carvaan-logo")
                        .resizable()
                        .frame(width: 155.167 * s, height: 25.093 * s)
                        .position(x: (182 - 0.42) * s, y: (8 + 25.093 / 2) * s)
                    Button {} label: {
                        Image(systemName: "figure.stand")
                            .font(.system(size: 23 * s, weight: .bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 13 * s)
                            .padding(.vertical, 7 * s)
                            .background(Color.white)
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.08), radius: 32 * s, y: 2 * s)
                    }
                    .buttonStyle(.plain)
                    .position(x: (182 + 157.5) * s, y: 20.5 * s)
                }
                .frame(width: 364 * s, height: 41 * s)
                .offset(x: 13 * s, y: 65 * s)

                // 3 × 2 tile grid (171:256): 360.667 × 177 at (15, 121), gaps 11 × 13
                ForEach(0..<HomeTile.all.count, id: \.self) { i in
                    HomeTileView(tile: HomeTile.all[i], s: s)
                        .frame(width: Self.tileSize.width * s, height: Self.tileSize.height * s)
                        .offset(Self.tileOrigin(i, s: s))
                }

                // the station cards, one below the other: the first sits where Figma puts it (374 wide, 76 above the
                // screen's bottom edge, 171:219), the rest follow with the same 16 pt gap as the cards list; off-screen cards pause.
                LazyVStack(spacing: Self.cardGap * s) {
                    ForEach(Cards.all, id: \.id) { card in
                        StationCard(id: card.id, title: card.title, code: card.code, width: Self.cardWidth(s),
                                    isActive: scenePhase == .active, phase: card.phase, livery: card.livery)
                    }
                }
                .frame(width: Self.cardWidth(s))
                .offset(cardTop)
            }
            .frame(width: geo.size.width,
                   height: cardTop.height + CGFloat(Cards.all.count) * cardH + CGFloat(Cards.all.count - 1) * Self.cardGap * s + 76 * s)
            }
            .background(Color(hex: 0xF7F7F5))
        }
        .ignoresSafeArea()
        .preferredColorScheme(.light)
    }

    // grid geometry from Figma
    static let tileSize = CGSize(width: (360.667 - 2 * 11) / 3, height: (177 - 13) / 2)
    static func tileOrigin(_ i: Int, s: CGFloat) -> CGSize {
        let col = CGFloat(i % 3), row = CGFloat(i / 3)
        return CGSize(width: (15 + col * (tileSize.width + 11)) * s, height: (121 + row * (tileSize.height + 13)) * s)
    }
    // card geometry: Figma width, our card's own aspect, anchored 76 pt above the bottom edge
    static func cardWidth(_ s: CGFloat) -> CGFloat { 374 * s }
    static let cardGap: CGFloat = 16
    static func cardOrigin(in size: CGSize, s: CGFloat) -> CGSize {
        let w = cardWidth(s), h = w * StationCard.designSize.height / StationCard.designSize.width
        return CGSize(width: (size.width - w) / 2, height: size.height - 76 * s - h)
    }
}

/// One grid tile: image name, its frame, its centre offset from the tile centre, label (all from Figma).
struct HomeTile {
    let image: String
    let size: CGSize
    let offset: CGSize
    let label: String
    /// Only the first tile crops its image: the image is scaled to this size and shifted inside the frame.
    var crop: (size: CGSize, offset: CGSize)? = nil

    static let all: [HomeTile] = [
        HomeTile(image: "tile-seat-1", size: CGSize(width: 34, height: 37), offset: CGSize(width: -0.44, height: -12.5), label: "Seat",
                 crop: (CGSize(width: 34 * 1.5926, height: 37 * 1.4828), CGSize(width: -34 * 0.2963, height: -37 * 0.2414))),
        HomeTile(image: "tile-seat-2", size: CGSize(width: 53, height: 53), offset: CGSize(width: 0.06, height: -11.5), label: "Seat"),
        HomeTile(image: "tile-live",   size: CGSize(width: 55, height: 55), offset: CGSize(width: 0.06, height: -12.5), label: "Live"),
        HomeTile(image: "tile-seat-4", size: CGSize(width: 55, height: 55), offset: CGSize(width: 0.06, height: -10.5), label: "Seat"),
        HomeTile(image: "tile-seat-5", size: CGSize(width: 49, height: 49), offset: CGSize(width: 0.06, height: -11.5), label: "Seat"),
        HomeTile(image: "tile-seat-6", size: CGSize(width: 56, height: 56), offset: CGSize(width: 0.56, height: -12),   label: "Seat"),
    ]
}

struct HomeTileView: View {
    let tile: HomeTile
    let s: CGFloat

    var body: some View {
        Button {} label: {
            GeometryReader { g in
                ZStack(alignment: .topLeading) {
                    Color(hex: 0xFAFAF8)
                    Group {
                        if let crop = tile.crop {
                            BundleImage.view(tile.image).resizable()
                                .frame(width: crop.size.width * s, height: crop.size.height * s)
                                .offset(x: crop.offset.width * s, y: crop.offset.height * s)
                                .frame(width: tile.size.width * s, height: tile.size.height * s, alignment: .topLeading)
                                .clipped()
                        } else {
                            BundleImage.view(tile.image).resizable()
                                .frame(width: tile.size.width * s, height: tile.size.height * s)
                        }
                    }
                    .position(x: g.size.width / 2 + tile.offset.width * s, y: g.size.height / 2 + tile.offset.height * s)
                    // label: Light Text Trial Regular 17 / 25, #424242, its top 32 pt above the tile's bottom edge
                    Text(tile.label)
                        .font(.custom(StationCard.titleFont, size: 17 * s))
                        .foregroundStyle(Color(hex: 0x424242))
                        .frame(height: 25 * s)
                        .frame(width: g.size.width)
                        .offset(x: -0.44 * s, y: g.size.height - 32 * s)
                }
            }
        }
        .buttonStyle(.plain)
        .clipShape(RoundedRectangle(cornerRadius: 27 * s, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 52 * s, y: 2 * s)
    }
}

/// Resolves a bundled image whether it lives in the asset catalog or as a loose file in the bundle.
enum BundleImage {
    static func load(_ name: String) -> UIImage? {
        if let img = UIImage(named: name) { return img }
        for ext in ["png", "jpg", "pdf"] {
            if let url = Bundle.main.url(forResource: name, withExtension: ext), let img = UIImage(contentsOfFile: url.path) { return img }
        }
        #if DEBUG
        print("BundleImage: '\(name)' not found")
        #endif
        return nil
    }
    static func view(_ name: String) -> Image {
        load(name).map { Image(uiImage: $0) } ?? Image(systemName: "questionmark.square.dashed")
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

#Preview {
    HomeScreen()
}
