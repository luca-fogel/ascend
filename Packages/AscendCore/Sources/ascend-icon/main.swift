import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import AscendDomain

// Renders the app icon at 1024x1024, in the three appearances iOS 26 asks for.
//
//     swift run --package-path Packages/AscendCore ascend-icon <output-directory>
//
// The colours come from `Palette`, the same values the app draws itself with, so the icon cannot
// drift from the interface it represents.
//
// The design is the app's own signature: the progress ring from the character screen, opened at
// the top and carrying a chevron upward through the gap. Ring for progress, chevron for ascent.
//
// Everything is sized for legibility at 40pt, not at 1024. Refactoring UI p213 makes the point
// about favicons: shrinking a detailed mark turns it to mush, so the compromises have to be
// chosen deliberately. That means thick strokes, one idea, and no fine detail — there is no
// gradient inside the chevron and no dot on the ring terminus, both of which looked good at full
// size and vanished at icon size.

let side = 1024.0
let outputDirectory = CommandLine.arguments.count > 1
    ? URL(fileURLWithPath: CommandLine.arguments[1])
    : URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

enum Appearance {
    case light
    case dark
    /// A grayscale mark on transparency. iOS composites its own background and tint behind it.
    case tinted
}

func cgColor(_ hsl: HSL, alpha: Double = 1) -> CGColor {
    let (r, g, b) = hsl.rgb
    return CGColor(srgbRed: r, green: g, blue: b, alpha: alpha)
}

/// Grayscale stand-in for the tinted appearance, keyed off perceived luminance so the ring and
/// the chevron stay distinguishable from each other once colour is gone.
func grey(_ level: Double) -> CGColor {
    CGColor(srgbRed: level, green: level, blue: level, alpha: 1)
}

func render(_ appearance: Appearance) -> CGImage {
    // The alpha choice is a shipping requirement, not a detail. App Store validation rejects a
    // primary iOS icon that carries an alpha channel -- and a context created as RGBA writes one
    // into the PNG even when every pixel is painted opaque. So light and dark are drawn without
    // alpha, and only the tinted variant, which genuinely needs transparency for the system to
    // composite its own plate behind, keeps it.
    let alphaInfo: CGImageAlphaInfo = appearance == .tinted ? .premultipliedLast : .noneSkipLast
    let context = CGContext(data: nil,
                            width: Int(side), height: Int(side),
                            bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: alphaInfo.rawValue)!
    context.interpolationQuality = .high
    context.setShouldAntialias(true)

    let centre = CGPoint(x: side / 2, y: side / 2)

    // MARK: Background
    //
    // Opaque for light and dark, because the primary iOS icon may not carry alpha. Transparent
    // for tinted, where the system draws the plate itself.
    if appearance != .tinted {
        // A near-black navy rather than pure black. The same reasoning as `Palette.canvas`: true
        // black crushes the edges of anything sitting on it, and on an OLED home screen a
        // fully black icon dissolves into the wallpaper.
        let top = appearance == .light ? HSL(228, 0.30, 0.115) : HSL(228, 0.34, 0.075)
        let bottom = appearance == .light ? HSL(214, 0.34, 0.050) : HSL(216, 0.38, 0.028)
        let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  colors: [cgColor(top), cgColor(bottom)] as CFArray,
                                  locations: [0, 1])!
        // The extend options are load-bearing. Without them the area past the end stop is never
        // painted and composites as pure black, which showed up as a hard diagonal edge across
        // the bottom-right corner.
        context.drawLinearGradient(gradient,
                                   start: CGPoint(x: 0, y: side),
                                   end: CGPoint(x: side, y: 0),
                                   options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

        // The ambient glow from `AscendBackground`, anchored off the top-left corner so it reads
        // as light rather than as a placed shape.
        let glow = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                              colors: [cgColor(Palette.accent[500], alpha: 0.30),
                                       cgColor(Palette.accent[500], alpha: 0)] as CFArray,
                              locations: [0, 1])!
        context.drawRadialGradient(glow,
                                   startCenter: CGPoint(x: side * 0.12, y: side * 0.98),
                                   startRadius: 0,
                                   endCenter: CGPoint(x: side * 0.12, y: side * 0.98),
                                   endRadius: side * 0.80,
                                   options: [])
    }

    // MARK: The ring
    //
    // Open at the top, leaving the gap the chevron rises through.
    //
    // Note the angles: in a CoreGraphics bitmap context y increases *upward*, so -90 degrees
    // points down, not up. Writing the gap at -90 put it at the bottom of the icon and left the
    // chevron sitting inside a closed horseshoe instead of breaking out of it.
    let ringRadius = side * 0.315
    let ringWidth = side * 0.100
    let gapDegrees = 74.0
    let start = 90.0 + gapDegrees / 2
    let end = 450.0 - gapDegrees / 2

    context.saveGState()
    context.setLineWidth(ringWidth)
    context.setLineCap(.round)

    let arc = CGMutablePath()
    arc.addArc(center: centre, radius: ringRadius,
               startAngle: start * .pi / 180, endAngle: end * .pi / 180,
               clockwise: false)
    context.addPath(arc)
    context.replacePathWithStrokedPath()
    context.clip()

    switch appearance {
    case .tinted:
        // The ring is the quieter of the two marks once colour is gone.
        context.setFillColor(grey(0.62))
        context.fill(CGRect(x: 0, y: 0, width: side, height: side))
    case .light, .dark:
        // A two-stop gradient across the arc rather than a flat fill, so the ring reads as
        // catching light — brighter where it emerges from the gap, deeper as it comes round.
        let ringGradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      colors: [cgColor(Palette.accent[200]),
                                               cgColor(Palette.accent[400]),
                                               cgColor(Palette.accent[600])] as CFArray,
                                      locations: [0, 0.45, 1])!
        context.drawLinearGradient(ringGradient,
                                   start: CGPoint(x: side * 0.10, y: side * 0.85),
                                   end: CGPoint(x: side * 0.92, y: side * 0.12),
                                   options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }
    context.restoreGState()

    // MARK: The chevron
    //
    // Rises through the ring's gap and stops short of the arc, so the two marks read as one
    // gesture rather than as an arrow trapped in a circle. Deliberately a bare chevron: an arrow
    // with a shaft and head has three parts and loses them all at 40pt.
    let apexY = side * 0.815
    let armY = side * 0.470
    let halfWidth = side * 0.200
    let chevronWidth = side * 0.100

    context.saveGState()
    context.setLineWidth(chevronWidth)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.setStrokeColor(appearance == .tinted ? grey(1.0) : cgColor(Palette.textPrimary))

    let chevron = CGMutablePath()
    chevron.move(to: CGPoint(x: centre.x - halfWidth, y: armY))
    chevron.addLine(to: CGPoint(x: centre.x, y: apexY))
    chevron.addLine(to: CGPoint(x: centre.x + halfWidth, y: armY))
    context.addPath(chevron)
    context.strokePath()
    context.restoreGState()

    return context.makeImage()!
}

func write(_ image: CGImage, to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw NSError(domain: "ascend-icon", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "could not create \(url.lastPathComponent)"])
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "ascend-icon", code: 2,
                      userInfo: [NSLocalizedDescriptionKey: "could not write \(url.lastPathComponent)"])
    }
}

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
for (appearance, name) in [(Appearance.light, "icon-light.png"),
                           (.dark, "icon-dark.png"),
                           (.tinted, "icon-tinted.png")] {
    let url = outputDirectory.appendingPathComponent(name)
    try write(render(appearance), to: url)
    let bytes = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
    print("wrote \(name)  \(bytes ?? 0) bytes")
}
