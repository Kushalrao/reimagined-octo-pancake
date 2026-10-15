import SwiftUI

/// First-launch screen from Figma (Decade-iter, node 306:129, "iPhone 14 Plus - 57"): the CARVAAN wordmark, a
/// "Sign in with Google" button and the data-safety note, on white. Every size, colour and offset comes from the design;
/// the design is 390 pt wide, so everything scales with `s = width / 390`. Coordinates are from the screen's top edge
/// (the design frame includes the status bar), following each layer's Figma constraints: the wordmark is pinned to the
/// top, the button to the vertical centre, the note to the bottom edge.
struct OnboardingScreen: View {
    /// Called when the person taps "Sign in with Google".
    var onSignIn: () -> Void = {}

    var body: some View {
        GeometryReader { geo in
            let s = geo.size.width / 390
            ZStack(alignment: .topLeading) {
                Color.white

                // wordmark (306:132): the same frame as the home header's logo, 337.234 × 54.536 at (25.073, 363.557)
                BundleImage.view("carvaan-logo")
                    .resizable()
                    .frame(width: 337.234 * s, height: 54.536 * s)
                    .offset(x: 25.073 * s, y: 363.557 * s)

                // "Sign in with Google" (306:146): 276 × 57, #15222C, radius 13 (iOS smoothing), centred, 165.5 below the vertical centre;
                // Google "G" 23 × 23 then the label, 10 apart; label Libre Franklin SemiBold 17 / 21, tracking 3 %, uppercase, white
                Button(action: onSignIn) {
                    HStack(spacing: 10 * s) {
                        BundleImage.view("google-g")
                            .resizable()
                            .frame(width: 23 * s, height: 23 * s)
                        Text("Sign in with google")
                            .font(.custom(Self.buttonFont, size: 17 * s))
                            .tracking(0.51 * s)
                            .textCase(.uppercase)
                            .foregroundStyle(.white)
                            .frame(height: 21 * s)
                    }
                    .frame(width: 276 * s, height: 57 * s)
                    .background(Color(hex: 0x15222C))
                    .clipShape(RoundedRectangle(cornerRadius: 13 * s, style: .continuous))
                }
                .buttonStyle(.plain)
                .position(x: geo.size.width / 2, y: geo.size.height / 2 + 165.5 * s)

                // data-safety note (306:149): Light Text Trial Regular 17 / 26, black 60 %, centred, 364 wide, its bottom 49 pt above the screen's bottom edge
                Text("Safety starts with understanding how developers collect and share your data. Data privacy and security practices may vary based on your use, region and age. The developer provided this information and may update it over time.")
                    .font(.custom(StationCard.titleFont, size: 17 * s))
                    .lineSpacing(Self.noteLineSpacing * s)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.black.opacity(0.6))
                    .frame(width: 364 * s)
                    .padding(.bottom, 49 * s)
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .background(Color.white)
        .ignoresSafeArea()
        .preferredColorScheme(.light)
    }

    /// PostScript name of the bundled Resources/LibreFranklin-SemiBold.ttf (Libre Franklin, weight 600, SIL OFL).
    static let buttonFont = "LibreFranklin-SemiBold"
    /// Figma line height 26 minus the font's natural line at 17 pt (hhea 960 − (−240) + 198 over 1000 upm = 23.766).
    static let noteLineSpacing: CGFloat = 26 - 23.766
}

#Preview {
    OnboardingScreen()
}
