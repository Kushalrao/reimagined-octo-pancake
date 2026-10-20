import Foundation
import CoreGraphics
import ImageIO
import Compression

/// Decoder for the `.lava` icon-animation container (Airbnb's format, reverse-engineered in
/// ~/airbnbIcons/iconstrials/AIRBNB-ICON-TECH.md; our files are made by lava-encode.py there).
///
/// RIFF "LAVA" chunks:
///   ANIM  u8 version, then 24-bit LE ints: width, height, cellSize, maxAtlasSize, fps, …
///   IMG   4-byte format tag + encoded image (PNG here). Image 0 = keyframe, image 1+ = atlases of changed cells.
///   SIMG  optional poster (ignored: frame 0 is our poster).
///   FRAM  u8 0, u24 frameCount, raw DEFLATE of records: "K" u24 image → draw whole image;
///         "D" u24 count, count × 16 bytes (u8 flag, u24 image, u24 srcCell, u24 wCells, u24 hCells, u24 destCell).
/// Every frame is complete, so each one is composed once into a CGImage up front and playback is just swapping images.
final class LavaClip {
    let width: Int
    let height: Int
    let fps: Int
    let frames: [CGImage]

    private static var cache: [String: LavaClip] = [:]

    /// Loads and decodes `<name>.lava` from the bundle once; later calls return the same clip.
    static func named(_ name: String) -> LavaClip? {
        if let c = cache[name] { return c }
        guard let url = Bundle.main.url(forResource: name, withExtension: "lava"),
              let data = try? Data(contentsOf: url), let clip = LavaClip(data: data) else { return nil }
        cache[name] = clip
        return clip
    }

    init?(data: Data) {
        let b = [UInt8](data)
        func tag(_ o: Int) -> String { String(bytes: b[o..<o + 4], encoding: .ascii) ?? "" }
        func u24(_ a: [UInt8], _ o: Int) -> Int { Int(a[o]) | Int(a[o + 1]) << 8 | Int(a[o + 2]) << 16 }
        func u32(_ o: Int) -> Int { Int(b[o]) | Int(b[o + 1]) << 8 | Int(b[o + 2]) << 16 | Int(b[o + 3]) << 24 }
        guard b.count > 12, tag(0) == "RIFF", tag(8) == "LAVA" else { return nil }

        var w = 0, h = 0, cell = 16, fps = 30
        var images: [CGImage] = []
        var records: [UInt8] = []
        var pos = 12
        while pos + 8 <= b.count {
            let id = tag(pos), size = u32(pos + 4)
            let body = Array(b[(pos + 8)..<min(pos + 8 + size, b.count)])
            pos += 8 + size + (size & 1)
            switch id {
            case "ANIM":
                var f: [Int] = []; var i = 1
                while i + 3 <= body.count { f.append(u24(body, i)); i += 3 }
                if f.count >= 5 { w = f[0]; h = f[1]; cell = f[2]; fps = f[4] }
            case "IMG ":
                guard let src = CGImageSourceCreateWithData(Data(body[4...]) as CFData, nil),
                      let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
                images.append(img)
            case "FRAM":
                records = LavaClip.inflateRaw(Array(body[4...]))
            default: break
            }
        }
        guard w > 0, h > 0, !images.isEmpty, !records.isEmpty else { return nil }
        width = w; height = h; self.fps = max(fps, 1)

        // compose every frame from scratch, exactly like the reference player's compose pass
        let cols = (w + cell - 1) / cell
        let space = CGColorSpaceCreateDeviceRGB()
        var out: [CGImage] = []
        var i = 0
        while i < records.count {
            guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
            ctx.clear(CGRect(x: 0, y: 0, width: w, height: h))
            let rec = records[i]; i += 1
            if rec == 0x4B {                                           // "K": whole image
                let idx = u24(records, i); i += 3
                if idx < images.count { ctx.draw(images[idx], in: CGRect(x: 0, y: 0, width: w, height: h)) }
            } else if rec == 0x44 {                                    // "D": patch list
                let count = u24(records, i); i += 3
                for _ in 0..<count {
                    let idx = u24(records, i + 1), src = u24(records, i + 4), wc = u24(records, i + 7), hc = u24(records, i + 10), dst = u24(records, i + 13)
                    i += 16
                    guard idx < images.count else { continue }
                    let atlas = images[idx], atlasCols = atlas.width / cell
                    let sx = (src % atlasCols) * cell, sy = (src / atlasCols) * cell
                    let dx = (dst % cols) * cell, dy = (dst / cols) * cell
                    let pw = wc * cell, ph = hc * cell
                    guard let piece = atlas.cropping(to: CGRect(x: sx, y: sy, width: pw, height: ph)) else { continue }
                    let dest = CGRect(x: dx, y: h - dy - ph, width: pw, height: ph)    // CG origin is bottom-left
                    ctx.clear(dest)
                    ctx.draw(piece, in: dest)
                }
            } else { return nil }
            guard let img = ctx.makeImage() else { return nil }
            out.append(img)
        }
        guard !out.isEmpty else { return nil }
        frames = out
    }

    /// Raw DEFLATE (no zlib header), which is what Compression's ZLIB algorithm decodes.
    private static func inflateRaw(_ input: [UInt8]) -> [UInt8] {
        var capacity = max(input.count * 8, 1 << 16)
        while capacity <= 1 << 26 {
            var dst = [UInt8](repeating: 0, count: capacity)
            let n = input.withUnsafeBufferPointer { src in
                dst.withUnsafeMutableBufferPointer { d in
                    compression_decode_buffer(d.baseAddress!, capacity, src.baseAddress!, input.count, nil, COMPRESSION_ZLIB)
                }
            }
            if n < capacity { return Array(dst[0..<n]) }
            capacity *= 4                                              // output filled the buffer: it may be truncated, retry bigger
        }
        return []
    }
}
