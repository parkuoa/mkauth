//
//  LoginUI.swift
//  bengal
//
//  Created by naomisphere on April 7th, 2026.
//  Copyright © 2026 naomisphere. All rights reserved.
//

// use tag search ('tag:TAGNAME') to find related code
// tag:fontloader - font loader
// tag:userprofile - user profile elements
// tag:loginwindowm - main login window definition
// tag:loginuim - main login ui
// tag:clock - clock-related
// tag:loginhandler - login perform (authentication handler)

// LOGIN CARD
// tag:logincard - main login card
// tag:avatarsection - avatar frame
// tag:usersilhouette - 'default' avatar silhouette
// tag:userinfosection - user info section (user, pswd, etc)
// tag:loginbutton - the login button
// tag:spinner - the login spinner triggered on login button press
// tag:{usernamefield,passwordfield} - username, password fields respectively

// MINIMALISTIC MODE
// tag:min_avatar_section - minimalistic mode avatar frame
// tag:min_username_section - minimalistic mode username section
// tag:min_form_section - password, login button
// tag:min_{usernamefield,passwordfield} - min. mode username, passwords fields respectively

// POWER
// tag:powerbutton - shutdown button in ui
// tag:powerbuttons - power buttons (shutdown, restart, sleep)

import Cocoa
import CoreText
import AVFoundation

// tag:fontloader
enum font_loader {
    static func regFonts() {
        bundle_log("registering fonts...")
        let names = ["Comfortaa-Bold.ttf", "Comfortaa-Light.ttf", "Comfortaa-Regular.ttf"]
        
        // Use the bundle resource URL if possible (correct way for plugin)
        let bundle = Bundle(for: LoginUI.self)
        let resourceURL = bundle.resourceURL
        bundle_log("bundle resource path: \(resourceURL?.path ?? "nil")")

        let candidates: [URL] = [
            resourceURL,
            // fallbacks
            URL(fileURLWithPath: "/Library/Security/SecurityAgentPlugins/BengalLogin.bundle/Contents/Resources"),
            URL(fileURLWithPath: "/tmp/Resources"),
        ].compactMap { $0 }

        for name in names {
            var found = false
            for dir in candidates {
                let url = dir.appendingPathComponent(name)
                if FileManager.default.fileExists(atPath: url.path) {
                    bundle_log("registering font: \(name) from \(url.path)")
                    var error: Unmanaged<CFError>?
                    if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                        bundle_log("failed to register font \(name): \(error?.takeRetainedValue().localizedDescription ?? "unknown error")")
                    } else {
                        found = true
                    }
                    break
                }
            }
            if !found {
                bundle_log("WARNING: Font \(name) not found in candidates.")
            }
        }
    }

    static func light(size: CGFloat) -> NSFont {
        NSFont(name: "Comfortaa-Light", size: size) ?? NSFont.systemFont(ofSize: size, weight: .light)
    }
    static func regular(size: CGFloat) -> NSFont {
        NSFont(name: "Comfortaa-Regular", size: size) ?? NSFont.systemFont(ofSize: size, weight: .regular)
    }
    static func bold(size: CGFloat) -> NSFont {
        NSFont(name: "Comfortaa-Bold", size: size) ?? NSFont.systemFont(ofSize: size, weight: .bold)
    }
}

// tag:userprofile
func fetch_and_cache_avatar(for username: String) -> NSImage? {
    let configDir = ("~/.config/bengal" as NSString).expandingTildeInPath
    let iconPath  = configDir + "/usericon.jpg"

    // return cached version IF recent (lt 5min old)
    if let attr = try? FileManager.default.attributesOfItem(atPath: iconPath),
       let mod  = attr[.modificationDate] as? Date,
       Date().timeIntervalSince(mod) < 300,
       let img  = NSImage(contentsOfFile: iconPath) {
        return img
    }

    // get profile picture for user via dscl
    // it works. its staying this way.
    let task   = Process()
    let pipe   = Pipe()
    let pipe2  = Pipe()
    task.launchPath  = "/bin/bash"
    task.arguments   = ["-c",
        "dscl . -read /Users/\(username) JPEGPhoto 2>/dev/null | tail -1 | xxd -r -p > \(iconPath)"]
    task.standardOutput = pipe
    task.standardError  = pipe2
    try? task.run()
    task.waitUntilExit()

    if let img = NSImage(contentsOfFile: iconPath), img.size.width > 0 {
        return img
    }
    return nil
}

extension NSColor {
    convenience init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}

func parseGradient(from string: String, angle: Double) -> NSGradient? {
    let parts = string.split(separator: "|")
    if parts.count >= 2 {
        let c1 = NSColor(hex: String(parts[0]))
        let c2 = NSColor(hex: String(parts[1]))
        return NSGradient(starting: c1, ending: c2)
    } else if parts.count == 1 {
        let c = NSColor(hex: String(parts[0]))
        return NSGradient(starting: c, ending: c)
    }
    return nil
}

class BengalButton: NSView {
    var title: String = "Sign In" { didSet { needsDisplay = true } }
    var action: (() -> Void)?
    var isEnabled: Bool = true { didSet {
        needsDisplay = true
        alphaValue = isEnabled ? 1.0 : 0.5
    }}

    private var isPressed = false
    private var isHovered = false

    override func awakeFromNib() { super.awakeFromNib(); setup() }
    override init(frame frameRect: NSRect) { super.init(frame: frameRect); setup() }
    required init?(coder: NSCoder) { super.init(coder: coder); setup() }

    private func setup() {
        wantsLayer = true
        let ta = NSTrackingArea(rect: bounds,
                                 options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                 owner: self, userInfo: nil)
        addTrackingArea(ta)
    }

    override func draw(_ dirtyRect: NSRect) {
        let r        = bounds.insetBy(dx: 0.5, dy: 0.5)
        let radius: CGFloat = 10
        let path     = NSBezierPath(roundedRect: r, xRadius: radius, yRadius: radius)

        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.saveGState()
        path.addClip()

        let grad = parseGradient(from: BengalSettings.shared.loginButtonColor, angle: BengalSettings.shared.loginButtonAngle)
        if let g = grad {
            g.draw(in: r, angle: CGFloat(BengalSettings.shared.loginButtonAngle))
        } else {
            let topColor = NSColor(calibratedRed: 0.32, green: 0.52, blue: 0.96, alpha: 1)
            let botColor = NSColor(calibratedRed: 0.22, green: 0.40, blue: 0.84, alpha: 1)
            NSGradient(starting: topColor, ending: botColor)?.draw(in: r, angle: 270)
        }

        let highlightPath = NSBezierPath(roundedRect: NSRect(x: r.minX + 1, y: r.midY,
                                                               width: r.width - 2, height: r.height/2 - 1),
                                          xRadius: radius - 1, yRadius: radius - 1)
        NSColor.white.withAlphaComponent(0.08).setFill()
        highlightPath.fill()

        ctx.restoreGState()


        NSColor.white.withAlphaComponent(0.18).setStroke()
        path.lineWidth = 1
        path.stroke()

        // tag:title
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font_loader.bold(size: 15),
            .foregroundColor: NSColor.white,
        ]
        let str   = title as NSString
        let size  = str.size(withAttributes: attrs)
        let x     = (bounds.width  - size.width)  / 2
        let y     = (bounds.height - size.height) / 2
        str.draw(at: NSPoint(x: x, y: y), withAttributes: attrs)
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        isPressed = true; needsDisplay = true
    }
    override func mouseUp(with event: NSEvent) {
        guard isEnabled else { return }
        isPressed = false; needsDisplay = true
        let loc = convert(event.locationInWindow, from: nil)
        if bounds.contains(loc) { action?() }
    }
    override var acceptsFirstResponder: Bool { true }
}

enum ArrowStyle { case circular, squared }
enum ArrowDirection { case left, right }

class ModernArrowButton: NSView {
    var action: (() -> Void)?
    var isHovered = false { didSet { needsDisplay = true } }
    var isPressed = false { didSet { needsDisplay = true } }
    var style: ArrowStyle = .circular
    var direction: ArrowDirection = .right
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    private func setup() {
        wantsLayer = true
        let ta = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(ta)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        let r = bounds.insetBy(dx: 1, dy: 1)
        let path: NSBezierPath
        if style == .circular {
            path = NSBezierPath(ovalIn: r)
            if isHovered || isPressed {
                NSColor.white.withAlphaComponent(isPressed ? 0.3 : 0.15).setFill()
                path.fill()
            }
            NSColor.white.withAlphaComponent(0.25).setStroke()
            path.lineWidth = 1.2
            path.stroke()
        } else {
            path = NSBezierPath(roundedRect: r, xRadius: 7, yRadius: 7)
            NSColor.white.withAlphaComponent(isPressed ? 0.15 : (isHovered ? 0.12 : 0.08)).setFill()
            path.fill()
            NSColor.white.withAlphaComponent(0.15).setStroke()
            path.lineWidth = 1
            path.stroke()
        }
        
        let arrowPath = NSBezierPath()
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let size: CGFloat = style == .circular ? 6 : 8
        
        if direction == .right {
            arrowPath.move(to: NSPoint(x: center.x - size/2, y: center.y - size))
            arrowPath.line(to: NSPoint(x: center.x + size/2, y: center.y))
            arrowPath.line(to: NSPoint(x: center.x - size/2, y: center.y + size))
        } else {
            arrowPath.move(to: NSPoint(x: center.x + size/2, y: center.y - size))
            arrowPath.line(to: NSPoint(x: center.x - size/2, y: center.y))
            arrowPath.line(to: NSPoint(x: center.x + size/2, y: center.y + size))
        }
        
        NSColor.white.withAlphaComponent(0.8).setStroke()
        arrowPath.lineWidth = 2
        arrowPath.lineCapStyle = .round
        arrowPath.lineJoinStyle = .round
        arrowPath.stroke()
    }
    
    override func mouseDown(with event: NSEvent) { isPressed = true }
    override func mouseUp(with event: NSEvent) {
        isPressed = false
        if bounds.contains(convert(event.locationInWindow, from: nil)) { action?() }
    }
    override func mouseEntered(with event: NSEvent) { isHovered = true }
    override func mouseExited(with event: NSEvent) { isHovered = false }
}

// tag:powerbutton
class PowerButton: NSView {
    var symbol: String = "⏻" // shush
    var action: (() -> Void)?
    var backgroundTransparency: CGFloat?
    var bgColorString: String = "#FFFFFF|#FFFFFF"
    var bgAngle: Double = 270.0
    var iconColorString: String = "#FFFFFF"
    var iconAngle: Double = 270.0
    
    private var isHovered = false
    private var isPressed = false
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        wantsLayer = true
        let ta = NSTrackingArea(rect: bounds,
                                 options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                 owner: self, userInfo: nil)
        addTrackingArea(ta)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        let r = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: r, xRadius: 8, yRadius: 8)
        
        let transparency = backgroundTransparency ?? 0.06
        
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.saveGState()
        path.addClip()
        
        let grad = parseGradient(from: bgColorString, angle: bgAngle)
        if let g = grad {
            g.draw(in: r, angle: CGFloat(bgAngle))
        } else {
            NSColor.white.withAlphaComponent(transparency).setFill()
            path.fill()
        }
        
        // overlay for hover/press
        if isPressed {
            NSColor.black.withAlphaComponent(0.15).setFill(); path.fill()
        } else if isHovered {
            NSColor.white.withAlphaComponent(0.1).setFill(); path.fill()
        }
        
        // transparency logic for bg..
        ctx.setBlendMode(.destinationIn)
        NSColor.white.withAlphaComponent(transparency).setFill(); path.fill()
        ctx.setBlendMode(.normal)
        
        ctx.restoreGState()

        if transparency > 0 {
            let borderColor = isHovered 
                ? NSColor.white.withAlphaComponent(0.2 * transparency)
                : NSColor.white.withAlphaComponent(0.1 * transparency)
            borderColor.setStroke()
            path.lineWidth = 1
            path.stroke()
        }

        // icon rendering
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let str = symbol as NSString
        let size = str.size(withAttributes: attrs)
        let drawPoint = NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2)
        
        ctx.saveGState()
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        str.draw(at: drawPoint, withAttributes: attrs)
        
        ctx.setBlendMode(.sourceIn)
        if let iconGrad = parseGradient(from: iconColorString, angle: iconAngle) {
            iconGrad.draw(in: bounds, angle: CGFloat(iconAngle))
        } else {
            NSColor.white.setFill(); bounds.fill()
        }
        ctx.endTransparencyLayer()
        ctx.restoreGState()
    }
    
    override func mouseDown(with event: NSEvent) {
        isPressed = true
        needsDisplay = true
    }
    
    override func mouseUp(with event: NSEvent) {
        isPressed = false
        needsDisplay = true
        let loc = convert(event.locationInWindow, from: nil)
        if bounds.contains(loc) {
            action?()
        }
    }
    
    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        needsDisplay = true
    }
    
    override func mouseExited(with event: NSEvent) {
        isHovered = false
        needsDisplay = true
    }
}

class UsernameContainerView: NSView {
    var onMouseEntered: (() -> Void)?
    var onMouseExited: (() -> Void)?
    
    override func mouseEntered(with event: NSEvent) {
        onMouseEntered?()
    }
    
    override func mouseExited(with event: NSEvent) {
        onMouseExited?()
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        let area = NSTrackingArea(rect: bounds, 
                                   options: [.mouseEnteredAndExited, .activeAlways], 
                                   owner: self, 
                                   userInfo: nil)
        addTrackingArea(area)
    }
}

class GradientLabel: NSTextField {
    var gradientString: String = "#FFFFFF"
    var gradientAngle: Double = 270.0

    override func draw(_ dirtyRect: NSRect) {
        if let grad = parseGradient(from: gradientString, angle: gradientAngle) {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font ?? NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.white
            ]
            let str = stringValue as NSString
            let size = str.size(withAttributes: attrs)
            let drawPoint = NSPoint(x: (bounds.width - size.width)/2, y: (bounds.height - size.height)/2)

            guard let ctx = NSGraphicsContext.current?.cgContext else { return }
            ctx.saveGState()

            // start transparency layer to isolate masking effect
            ctx.beginTransparencyLayer(auxiliaryInfo: nil)
            
            // draw the text
            str.draw(at: drawPoint, withAttributes: attrs)
            
            // apply gradient only to text using sourceIn
            ctx.setBlendMode(.sourceIn)
            grad.draw(in: bounds, angle: CGFloat(gradientAngle))
            
            // composite it back
            ctx.endTransparencyLayer()
            
            ctx.restoreGState()
        } else {
            super.draw(dirtyRect)
        }
    }
}


class FieldBackground: NSView {
    var isFocused = false { didSet { needsDisplay = true } }

    override func draw(_ dirtyRect: NSRect) {
        let r    = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: r, xRadius: 7, yRadius: 7)

        NSColor.white.withAlphaComponent(isFocused ? 0.11 : 0.07).setFill()
        path.fill()

        let borderColor = isFocused
            ? NSColor(calibratedRed: 0.32, green: 0.52, blue: 0.96, alpha: 0.7)
            : NSColor.white.withAlphaComponent(0.15)
        borderColor.setStroke()
        path.lineWidth = 1
        path.stroke()
    }
}


class SmallArrowButton: NSView {
    var action: (() -> Void)?
    var direction: ArrowDirection = .right
    var isHovered = false { didSet { needsDisplay = true } }
    var isPressed = false { didSet { needsDisplay = true } }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        let ta = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(ta)
    }
    required init?(coder: NSCoder) { super.init(coder: coder) }
    
    override func draw(_ dirtyRect: NSRect) {
        let r = bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(ovalIn: r)
        
        if isHovered || isPressed {
            NSColor.white.withAlphaComponent(isPressed ? 0.3 : 0.15).setFill()
            path.fill()
        }
        NSColor.white.withAlphaComponent(0.25).setStroke()
        path.lineWidth = 1.2
        path.stroke()
        
        let arrowPath = NSBezierPath()
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let size: CGFloat = 6
        
        if direction == .right {
            arrowPath.move(to: NSPoint(x: center.x - size/2, y: center.y - size))
            arrowPath.line(to: NSPoint(x: center.x + size/2, y: center.y))
            arrowPath.line(to: NSPoint(x: center.x - size/2, y: center.y + size))
        } else {
            arrowPath.move(to: NSPoint(x: center.x + size/2, y: center.y - size))
            arrowPath.line(to: NSPoint(x: center.x - size/2, y: center.y))
            arrowPath.line(to: NSPoint(x: center.x + size/2, y: center.y + size))
        }
        
        NSColor.white.withAlphaComponent(0.8).setStroke()
        arrowPath.lineWidth = 1.5
        arrowPath.lineCapStyle = .round
        arrowPath.lineJoinStyle = .round
        arrowPath.stroke()
    }
    
    override func mouseDown(with event: NSEvent) { isPressed = true }
    override func mouseUp(with event: NSEvent) {
        isPressed = false
        if bounds.contains(convert(event.locationInWindow, from: nil)) { action?() }
    }
    override func mouseEntered(with event: NSEvent) { isHovered = true }
    override func mouseExited(with event: NSEvent) { isHovered = false }
}


// tag:loginwindowm
class LoginWindow: NSWindow {
    override var canBecomeKey:  Bool { true }
    override var canBecomeMain: Bool { true }
}


// tag:loginuim
class LoginUI: NSObject, NSWindowDelegate, NSTextFieldDelegate {

    var window: NSWindow!
    var username_field: NSTextField!
    var password_field: NSSecureTextField!
    var onLogin: ((String, Data) -> Void)?
    var onAction: ((String) -> Void)?
    var errorLabel: NSTextField!
    var loginButton: BengalButton!
    var clockLabel: NSTextField!
    var dateLabel: NSTextField!
    var clockTimer: Timer?
    var container: NSView!
    var spinner: NSProgressIndicator!
    var user_avatar_image: NSImageView!
    var userBgFields: [NSTextField: FieldBackground] = [:]
    var powerButtonsY: CGFloat = 0
    var isAnimatingUsername = false
    
    // tag:powerbuttons
    var shutdownButton: PowerButton!
    var restartButton: PowerButton!
    var sleepButton: PowerButton!
    
    var usernameLabel: NSTextField!
    var usernameEditArrow: SmallArrowButton!
    var usernameBackArrow: SmallArrowButton!
    var minimalisticLoginButton: ModernArrowButton!
    var usernameContainer: NSView!
    var formContainer: NSView! // container for fields and login button
    
    var overlay: ConfirmationOverlay?
    var settings: BengalSettings = BengalSettings.shared
    var playerLooper: AVPlayerLooper?
    var playerLayer: AVSampleBufferDisplayLayer? // or just AVPlayerLayer
    var queuePlayer: AVQueuePlayer?


    // username hint drawn above the card
    var suggestedUser: String

    init(suggestedUser: String, onLogin: @escaping (String, Data) -> Void, onAction: @escaping (String) -> Void) {
        bundle_log("LoginUI.init started.")
        self.suggestedUser = suggestedUser
        self.onLogin = onLogin
        self.onAction = onAction
        super.init()
        font_loader.regFonts()

        bundle_log("calculating screen rect...")
        let mainDisplay = CGMainDisplayID()
        let rect = CGDisplayBounds(mainDisplay)
        let screenRect = NSRect(x: rect.origin.x, y: rect.origin.y, width: rect.size.width, height: rect.size.height)
        bundle_log("screen rect: \(screenRect)")
        
        bundle_log("Creating window...")
        window = LoginWindow(contentRect: screenRect,
                             styleMask: .borderless,
                             backing: .buffered,
                             defer: false)
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
        window.backgroundColor = .black
        window.isOpaque = true
        window.canBecomeVisibleWithoutLogin = true
        window.delegate = self
        
        bundle_log("performing UI setup")
        self.setupUI()
        self.startClock()
        bundle_log("LoginUI.init finished.")
    }

    deinit { clockTimer?.invalidate() }

    // build the fullscreen UI
    func setupUI() {
    let W = window.frame.width
    let H = window.frame.height

    let root = NSView(frame: NSRect(x: 0, y: 0, width: W, height: H))
    root.wantsLayer = true

    // tag:background
    bundle_log("attempt to set up background")
    
    // prioritize media "login_background.*" (synced by app)
    // fallback to path declared in settings if not found
    var effectiveBgType = settings.bgType
    var effectiveBgPath: String?
    
    if let bundleBg = findBundleResource(prefix: "login_background") {
        effectiveBgPath = bundleBg
        bundle_log("Using bundle background: \(bundleBg)")
        // get media type from file extension
        let ext = (bundleBg as NSString).pathExtension.lowercased()
        if ext == "mp4" || ext == "mov" {
            effectiveBgType = "video"
        } else if ext == "gif" {
            effectiveBgType = "gif"
        } else {
            effectiveBgType = "image"
        }
    } else if let sBg = settings.bgPath, FileManager.default.fileExists(atPath: sBg) {
        effectiveBgPath = sBg
        bundle_log("using background from settings: \(sBg)")
    }

    if let bgPath = effectiveBgPath {
        bundle_log("loading background from: \(bgPath) [Type: \(effectiveBgType)]")
        setupComplexBackground(in: root, path: bgPath, type: effectiveBgType)
    } else {
        bundle_log("failed. Using default gradient background instead.")
        // default bg: dark gradient
        let bg = CAGradientLayer()
        bg.frame  = root.bounds
        bg.colors = [
            NSColor(calibratedRed: 0.04, green: 0.04, blue: 0.08, alpha: 1).cgColor,
            NSColor(calibratedRed: 0.08, green: 0.10, blue: 0.16, alpha: 1).cgColor,
        ]
        bg.startPoint = CGPoint(x: 0.3, y: 1)
        bg.endPoint   = CGPoint(x: 0.7, y: 0)
        root.layer?.addSublayer(bg)
    }

    // subtle grid / noise overlay
    let noiseView = NoiseView(frame: root.bounds)
    root.addSubview(noiseView)

    // radial glow behind card
    let glowSize: CGFloat = 600
    let glow = NSView(frame: NSRect(x: W/2 - glowSize/2, y: H/2 - glowSize/2 - 40,
                                     width: glowSize, height: glowSize))
    glow.wantsLayer = true
    let glowLayer        = CAGradientLayer()
    glowLayer.frame      = CGRect(origin: .zero, size: glow.frame.size)
    glowLayer.type       = .radial
    glowLayer.colors     = [
        NSColor(calibratedRed: 0.2, green: 0.35, blue: 0.9, alpha: 0.12).cgColor,
        NSColor.clear.cgColor,
    ]
    glowLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
    glowLayer.endPoint   = CGPoint(x: 1.0, y: 1.0)
    glow.layer?.addSublayer(glowLayer)
    root.addSubview(glow)

    // tag:clock
    let clock = GradientLabel(labelWithString: "")
    clock.gradientString = settings.clockColor
    clock.gradientAngle = settings.clockAngle
    clock.font      = font_loader.light(size: CGFloat(settings.clockSize))
    clock.alignment = .center
    clock.frame     = NSRect(x: 0, y: H - CGFloat(settings.clockSize + 70), width: W, height: CGFloat(settings.clockSize + 15))
    root.addSubview(clock)
    clockLabel = clock

    let date = GradientLabel(labelWithString: "")
    date.gradientString = settings.clockColor
    date.gradientAngle = settings.clockAngle
    date.font      = font_loader.light(size: 17)
    date.alignment = .center
    date.frame     = NSRect(x: 0, y: clockLabel.frame.minY - 28, width: W, height: 24)
    root.addSubview(date)
    dateLabel = date

    if settings.uiMode == "minimalistic" {
        buildMinimalisticUI(root: root)
    } else {
        // login card
        let cardW: CGFloat = 420
        let cardH: CGFloat = 460
        let cardX = W / 2 - cardW / 2
        let cardY = H / 2 - cardH / 2 - 20

        let card = GlassCard(frame: NSRect(x: cardX, y: cardY, width: cardW, height: cardH))
        card.backgroundTransparency = CGFloat(settings.cardTransparency)
        container = card
        root.addSubview(container)

        buildCard(cardW: cardW, cardH: cardH)
    }
    
    // power buttons positioning
    var powerButtonsY: CGFloat

    if settings.uiMode == "minimalistic" {
        powerButtonsY = (H/2 - 40) - 40
    } else {
        powerButtonsY = container.frame.minY - 40
    }

    setupPowerButtons(in: root, centerY: powerButtonsY)

    window.contentView = root
    window.makeKeyAndOrderFront(nil)
    window.makeFirstResponder(password_field)
}

func buildMinimalisticUI(root: NSView) {
    let W = root.frame.width
    let H = root.frame.height
    
    // transparent container for everything
    container = NSView(frame: root.bounds)
    root.addSubview(container)
    
    let centerX = W / 2
    let centerY = H / 2
    
    // tag:min_avatar_section
    let avatarSize: CGFloat = 100
    let avatarBg = NSView(frame: NSRect(x: centerX - avatarSize/2, y: centerY + 60, width: avatarSize, height: avatarSize))
    avatarBg.wantsLayer = true
    avatarBg.layer?.cornerRadius = avatarSize / 2
    avatarBg.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.07).cgColor
    avatarBg.layer?.borderWidth = 1.5
    avatarBg.layer?.borderColor = NSColor.white.withAlphaComponent(0.2).cgColor
    container.addSubview(avatarBg)
    
    user_avatar_image = NSImageView(frame: avatarBg.bounds)
    user_avatar_image.imageScaling = .scaleProportionallyUpOrDown
    user_avatar_image.wantsLayer = true
    user_avatar_image.layer?.cornerRadius = avatarSize / 2
    user_avatar_image.layer?.masksToBounds = true
    avatarBg.addSubview(user_avatar_image)
    
    let silhouette = SilhouetteView(frame: avatarBg.bounds)
    avatarBg.addSubview(silhouette)

    var effectiveAvatarPath: String?
    if let bundleAvatar = findBundleResource(prefix: "login_user_avatar") {
        effectiveAvatarPath = bundleAvatar
    } else if let sAvatar = settings.avatarPath, FileManager.default.fileExists(atPath: sAvatar) {
        effectiveAvatarPath = sAvatar
    }

    if let avatarPath = effectiveAvatarPath, let img = NSImage(contentsOfFile: avatarPath) {
        user_avatar_image.image = img
        silhouette.isHidden = true
    } else {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            let img = fetch_and_cache_avatar(for: self.suggestedUser)
            DispatchQueue.main.async {
                if let img = img {
                    self.user_avatar_image.image = img
                    silhouette.isHidden = true
                }
            }
        }
    }
    
    // tag:min_username_section
    let displayName = suggestedUser == "_securityagent" ? "Welcome" : suggestedUser
    usernameContainer = UsernameContainerView(frame: NSRect(x: centerX - 150, y: centerY + 20, width: 300, height: 30))
    container.addSubview(usernameContainer)
    
    usernameLabel = NSTextField(labelWithString: displayName)
    usernameLabel.font = font_loader.bold(size: 18)
    usernameLabel.textColor = .white
    usernameLabel.alignment = .center
    usernameLabel.frame = usernameContainer.bounds
    usernameContainer.addSubview(usernameLabel)
    
    let textWidth = (displayName as NSString).size(withAttributes: [.font: usernameLabel.font!]).width
    let arrowY = usernameLabel.frame.origin.y + (usernameLabel.frame.height - 20) / 2
    usernameEditArrow = SmallArrowButton(frame: NSRect(x: usernameContainer.bounds.midX + textWidth/2 + 8, y: 10, width: 20, height: 20))
    usernameEditArrow.direction = .right
    usernameEditArrow.alphaValue = 0
    usernameEditArrow.action = { [weak self] in self?.toggleUsernameField(true) }
    usernameContainer.addSubview(usernameEditArrow)
    
   // Add tracking for username hover
    if let container = usernameContainer as? UsernameContainerView {
        container.onMouseEntered = { [weak self] in
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                self?.usernameEditArrow?.animator().alphaValue = 1
            }
        }
        container.onMouseExited = { [weak self] in
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                self?.usernameEditArrow?.animator().alphaValue = 0
            }
        }
    }
    
    // tag:min_form_section
    let fieldW: CGFloat = 240
    let fieldH: CGFloat = 42
    let btnH: CGFloat = 42
    let spacing: CGFloat = 10
    
    formContainer = NSView(frame: NSRect(x: centerX - (fieldW + spacing + btnH)/2, y: centerY - 40, width: fieldW + spacing + btnH, height: 100))
    container.addSubview(formContainer)
    
    // tag:min_usernamefield
    let userBg = FieldBackground(frame: NSRect(x: 0, y: 50, width: fieldW, height: fieldH))
    userBg.isHidden = true
    userBg.alphaValue = 0
    formContainer.addSubview(userBg)
    
    username_field = NSTextField(frame: NSRect(x: 12, y: (fieldH-17)/2, width: fieldW - 24, height: 17))
    username_field.placeholderString = "Username"
    username_field.stringValue = suggestedUser == "_securityagent" ? "" : suggestedUser
    username_field.font = font_loader.regular(size: 14)
    username_field.isBordered = false
    username_field.drawsBackground = false
    username_field.focusRingType = .none
    username_field.textColor = .white
    username_field.delegate = self
    styleFieldCell(username_field)
    userBg.addSubview(username_field)
    userBgFields[username_field] = userBg
    
    usernameBackArrow = SmallArrowButton(frame: NSRect(x: formContainer.frame.minX - 35, y: formContainer.frame.midY + 25 - 10, width: 20, height: 20))
    usernameBackArrow.direction = .left
    usernameBackArrow.alphaValue = 0
    usernameBackArrow.isHidden = true
    usernameBackArrow.action = { [weak self] in self?.toggleUsernameField(false) }
    container.addSubview(usernameBackArrow)
    
    // tag:min_passwordfield
    let passBg = FieldBackground(frame: NSRect(x: 0, y: 0, width: fieldW, height: fieldH))
    formContainer.addSubview(passBg)
    
    password_field = NSSecureTextField(frame: NSRect(x: 12, y: (fieldH-17)/2, width: fieldW - 24, height: 17))
    password_field.placeholderString = "••••••••"
    password_field.font = font_loader.regular(size: 14)
    password_field.isBordered = false
    password_field.drawsBackground = false
    password_field.focusRingType = .none
    password_field.textColor = .white
    password_field.delegate = self
    styleFieldCell(password_field)
    passBg.addSubview(password_field)
    userBgFields[password_field] = passBg
    
    minimalisticLoginButton = ModernArrowButton(frame: NSRect(x: fieldW + spacing, y: 0, width: btnH, height: btnH))
    minimalisticLoginButton.style = .squared
    minimalisticLoginButton.direction = .right
    minimalisticLoginButton.action = { [weak self] in self?.performLogin() }
    formContainer.addSubview(minimalisticLoginButton)
    
    // error text
    errorLabel = NSTextField(labelWithString: "")
    errorLabel.font = font_loader.regular(size: 12)
    errorLabel.textColor = NSColor(calibratedRed: 1.0, green: 0.42, blue: 0.42, alpha: 1)
    errorLabel.alignment = .center
    errorLabel.frame = NSRect(x: 0, y: -25, width: formContainer.frame.width, height: 16)
    errorLabel.isHidden = true
    formContainer.addSubview(errorLabel)
    
    // login spinner
    spinner = NSProgressIndicator(frame: NSRect(x: minimalisticLoginButton.frame.midX - 11, y: minimalisticLoginButton.frame.midY - 11, width: 22, height: 22))
    spinner.style = .spinning
    spinner.controlSize = .regular
    spinner.isDisplayedWhenStopped = false
    spinner.appearance = NSAppearance(named: .darkAqua)
    formContainer.addSubview(spinner)
}

func toggleUsernameField(_ show: Bool) {
    guard let userBg = userBgFields[username_field] else { return }
    guard !isAnimatingUsername else { return }
    
    isAnimatingUsername = true
    
    if show {
        usernameBackArrow.frame.origin.x = formContainer.frame.origin.x - 35
        usernameBackArrow.frame.origin.y = formContainer.frame.origin.y + 50 + (42 - 20) / 2
        container.addSubview(usernameBackArrow)
    }
    
    let duration: TimeInterval = 0.3
    
    if show {
        usernameLabel.animator().alphaValue = 0
        usernameEditArrow.isHidden = true
        usernameEditArrow.animator().alphaValue = 0
        userBg.isHidden = false
        userBg.animator().alphaValue = 1
        usernameBackArrow.isHidden = false
        usernameBackArrow.animator().alphaValue = 1
        
        var newFrame = formContainer.frame
        newFrame.origin.y -= 25
        formContainer.animator().setFrameOrigin(newFrame.origin)
        
        let fieldHeight: CGFloat = 42
        let arrowHeight: CGFloat = 20
        let offset1: CGFloat = 50
        let offset2: CGFloat = (fieldHeight - arrowHeight) / 2
        let offset3: CGFloat = 25
        
        var arrowFrame = usernameBackArrow.frame
        let newY = formContainer.frame.origin.y + offset1 + offset2 - offset3
        arrowFrame.origin.y = newY
        usernameBackArrow.animator().setFrameOrigin(arrowFrame.origin)
        
        shutdownButton.animator().frame.origin.y -= 25
        restartButton.animator().frame.origin.y -= 25
        sleepButton.animator().frame.origin.y -= 25
        
    } else {
        usernameLabel.animator().alphaValue = 1
        usernameEditArrow.isHidden = false
        userBg.animator().alphaValue = 0
        usernameBackArrow.animator().alphaValue = 0
        
        var newFrame = formContainer.frame
        newFrame.origin.y += 25
        formContainer.animator().setFrameOrigin(newFrame.origin)
        
        shutdownButton.animator().frame.origin.y += 25
        restartButton.animator().frame.origin.y += 25
        sleepButton.animator().frame.origin.y += 25
        
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            userBg.isHidden = true
            self.usernameBackArrow.isHidden = true
            self.usernameEditArrow.isHidden = false
            self.isAnimatingUsername = false
        }
    }
    
    if show {
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            self.window.makeFirstResponder(self.username_field)
            self.usernameEditArrow.isHidden = true
            self.isAnimatingUsername = false
        }
    } else {
        if !show {
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                self.isAnimatingUsername = false
            }
        }
    }
}

/*
override func mouseEntered(with event: NSEvent) {
    if let info = event.userData as? [String: String], info["id"] == "usernameLabel" {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            usernameEditArrow?.animator().alphaValue = 1
        }
    }
}

override func mouseExited(with event: NSEvent) {
    if let info = event.userData as? [String: String], info["id"] == "usernameLabel" {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            usernameEditArrow?.animator().alphaValue = 0
        }
    }
}
*/

    // set up power buttons below the card -
    func setupPowerButtons(in rootView: NSView, centerY: CGFloat) {
    let buttonSize: CGFloat = 42
    let spacing: CGFloat = 16
    let totalWidth = (buttonSize * 3) + (spacing * 2)
    let startX = (rootView.frame.width - totalWidth) / 2
    let buttonY = centerY - buttonSize / 2
    
    shutdownButton = PowerButton(frame: NSRect(x: startX, y: buttonY, width: buttonSize, height: buttonSize))
    updatePowerButtonStyle(shutdownButton)
    shutdownButton.symbol = "⏻"
    shutdownButton.action = { [weak self] in
        self?.confirmAndExecute("Shut Down", actionId: "shutdown")
    }
    rootView.addSubview(shutdownButton)
    
    // restart button
    restartButton = PowerButton(frame: NSRect(x: startX + buttonSize + spacing, y: buttonY, width: buttonSize, height: buttonSize))
    updatePowerButtonStyle(restartButton)
    restartButton.symbol = "↻"
    restartButton.action = { [weak self] in
        self?.confirmAndExecute("Restart", actionId: "restart")
    }
    rootView.addSubview(restartButton)
    
    // sleep button
    sleepButton = PowerButton(frame: NSRect(x: startX + (buttonSize + spacing) * 2, y: buttonY, width: buttonSize, height: buttonSize))
    updatePowerButtonStyle(sleepButton)
    sleepButton.symbol = "☾"
    sleepButton.action = { [weak self] in
        self?.confirmAndExecute("Sleep", actionId: "sleep")
    }
    rootView.addSubview(sleepButton)
}

private func updatePowerButtonStyle(_ btn: PowerButton) {
    btn.backgroundTransparency = CGFloat(settings.powerButtonsTransparency)
    btn.bgColorString = settings.powerButtonBGColor
    btn.bgAngle = settings.powerButtonBGAngle
    btn.iconColorString = settings.powerButtonIconColor
    btn.iconAngle = settings.powerButtonIconAngle
}
    
    // confirmation dialog for "heavier" actions
    func confirmAndExecute(_ action: String, actionId: String) {
        if overlay != nil { return }
        
        let newOverlay = ConfirmationOverlay(frame: window.contentView?.bounds ?? .zero)
        newOverlay.autoresizingMask = [.width, .height]
        
        newOverlay.onConfirm = { [weak self] in
            self?.onAction?(actionId)
            self?.dismissOverlay()
        }
        
        newOverlay.onCancel = { [weak self] in
            self?.dismissOverlay()
        }
        
        newOverlay.show(
            title: "\(action)?",
            info: "Are you sure you want to \(action.lowercased()) your Mac?",
            confirmTitle: action
        )
        
        window.contentView?.addSubview(newOverlay)
        self.overlay = newOverlay
        
        // fade in
        newOverlay.alphaValue = 0
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            newOverlay.animator().alphaValue = 1
        }
    }
    
    private func dismissOverlay() {
        guard let ov = overlay else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            ov.animator().alphaValue = 0
        }) {
            ov.removeFromSuperview()
            self.overlay = nil
        }
    }
    
    // execute system command
    func executeCommand(_ command: String) {
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", command]
        try? task.run()
    }

    func close() {
        window.orderOut(nil)
        window.close()
    }

    // build contents inside the card
    func buildCard(cardW: CGFloat, cardH: CGFloat) {
        // use relative positioning from top for consistency
        var currentY = cardH - 28 // start with top padding
        
        // tag:avatarsection
        let avatarSize: CGFloat = 82
        let avatarX = (cardW - avatarSize) / 2
        currentY -= avatarSize
        
        let avatarBg = NSView(frame: NSRect(x: avatarX, y: currentY, width: avatarSize, height: avatarSize))
        avatarBg.wantsLayer = true
        avatarBg.layer?.cornerRadius = avatarSize / 2
        avatarBg.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.07).cgColor
        avatarBg.layer?.borderWidth = 1.5
        avatarBg.layer?.borderColor = NSColor.white.withAlphaComponent(0.2).cgColor
        container.addSubview(avatarBg)
        
        user_avatar_image = NSImageView(frame: NSRect(x: 0, y: 0, width: avatarSize, height: avatarSize))
        user_avatar_image.imageScaling = .scaleProportionallyUpOrDown
        user_avatar_image.wantsLayer = true
        user_avatar_image.layer?.cornerRadius = avatarSize / 2
        user_avatar_image.layer?.masksToBounds = true
        avatarBg.addSubview(user_avatar_image)
        
        let silhouette = SilhouetteView(frame: NSRect(x: 0, y: 0, width: avatarSize, height: avatarSize))
        avatarBg.addSubview(silhouette)
        
        // tag:avataroverride
        // Prioritize bundle resource "login_user_avatar.*"
        var effectiveAvatarPath: String?
        if let bundleAvatar = findBundleResource(prefix: "login_user_avatar") {
            effectiveAvatarPath = bundleAvatar
            bundle_log("using bundle avatar: \(bundleAvatar)")
        } else if let sAvatar = settings.avatarPath, FileManager.default.fileExists(atPath: sAvatar) {
            effectiveAvatarPath = sAvatar
            bundle_log("using avatar from settings: \(sAvatar)")
        }

        if let avatarPath = effectiveAvatarPath, let img = NSImage(contentsOfFile: avatarPath) {
            user_avatar_image.image = img
            silhouette.isHidden = true
        } else {
            DispatchQueue.global(qos: .background).async { [weak self] in
                guard let self = self else { return }
                let img = fetch_and_cache_avatar(for: self.suggestedUser)
                DispatchQueue.main.async {
                    if let img = img {
                        self.user_avatar_image.image = img
                        silhouette.isHidden = true
                    }
                }
            }
        }
        
        currentY -= 20 // spacing after avatar
        
        // tag:userdetectionfix
        // Use suggested user if available, otherwise fallback
        let displayName = suggestedUser == "_securityagent" ? "Welcome" : suggestedUser
        let name_label = NSTextField(labelWithString: displayName)
        name_label.font = font_loader.bold(size: 16)
        name_label.textColor = .white
        name_label.alignment = .center
        name_label.frame = NSRect(x: 0, y: currentY - 22, width: cardW, height: 22)
        container.addSubview(name_label)
        currentY -= 22
        
        let help_label = NSTextField(labelWithString: "Enter your password to unlock")
        help_label.font = font_loader.light(size: 12)
        help_label.textColor = NSColor.white.withAlphaComponent(0.45)
        help_label.alignment = .center
        help_label.frame = NSRect(x: 0, y: currentY - 18, width: cardW, height: 18)
        container.addSubview(help_label)
        currentY -= 28 // space before form fields
        
        // -- Form Fields Configuration
        let fieldW: CGFloat = cardW - 72
        let fieldX: CGFloat = 36
        let fieldH: CGFloat = 46
        let labelHeight: CGFloat = 14
        let labelSpacing: CGFloat = 4
        let fieldSpacing: CGFloat = 16
        let textFieldHeight: CGFloat = 17
        let textFieldYOffset = (fieldH - textFieldHeight) / 2
        
        // tag:usernamefield
        currentY -= (labelHeight + labelSpacing)
        
        let username_title_label = makeFieldLabel("Username", frame: NSRect(x: fieldX, y: currentY, width: 100, height: labelHeight))
        container.addSubview(username_title_label)
        
        currentY -= fieldH
        
        let userBg = FieldBackground(frame: NSRect(x: fieldX, y: currentY, width: fieldW, height: fieldH))
        container.addSubview(userBg)
        
        username_field = NSTextField(frame: NSRect(x: 14, y: textFieldYOffset, width: fieldW - 28, height: textFieldHeight))
        username_field.placeholderString = suggestedUser == "_securityagent" ? "Username" : suggestedUser
        username_field.stringValue = suggestedUser == "_securityagent" ? "" : suggestedUser
        username_field.font = font_loader.regular(size: 14)
        username_field.isBordered = false
        username_field.drawsBackground = false
        username_field.focusRingType = .none
        username_field.textColor = .white
        username_field.delegate = self
        username_field.alignment = .left
        username_field.lineBreakMode = .byTruncatingTail
        username_field.cell?.truncatesLastVisibleLine = true
        styleFieldCell(username_field)
        userBg.addSubview(username_field)
        userBgFields[username_field] = userBg
        
        // tag:passwordfield
        currentY -= fieldSpacing
        currentY -= (labelHeight + labelSpacing)
        
        let passLabel = makeFieldLabel("Password", frame: NSRect(x: fieldX, y: currentY, width: 100, height: labelHeight))
        container.addSubview(passLabel)
        
        currentY -= fieldH
        
        let passBg = FieldBackground(frame: NSRect(x: fieldX, y: currentY, width: fieldW, height: fieldH))
        container.addSubview(passBg)
        
        password_field = NSSecureTextField(frame: NSRect(x: 14, y: textFieldYOffset, width: fieldW - 28, height: textFieldHeight))
        password_field.placeholderString = "••••••••"
        password_field.font = font_loader.regular(size: 14)
        password_field.isBordered = false
        password_field.drawsBackground = false
        password_field.focusRingType = .none
        password_field.textColor = .white
        password_field.delegate = self
        password_field.alignment = .left
        password_field.lineBreakMode = .byTruncatingTail
        styleFieldCell(password_field)
        passBg.addSubview(password_field)
        userBgFields[password_field] = passBg
        
        // tag:errorlabel
        currentY -= 16
        
        errorLabel = NSTextField(labelWithString: "")
        errorLabel.font = font_loader.regular(size: 12)
        errorLabel.textColor = NSColor(calibratedRed: 1.0, green: 0.42, blue: 0.42, alpha: 1)
        errorLabel.alignment = .center
        errorLabel.frame = NSRect(x: 0, y: currentY - 16, width: cardW, height: 16)
        errorLabel.isHidden = true
        container.addSubview(errorLabel)
        currentY -= 16
        
        // tag:loginbutton
        currentY -= 24 // space above button
        
        loginButton = BengalButton(frame: NSRect(x: fieldX, y: currentY - 46, width: fieldW, height: 46))
        loginButton.title = "Sign In"
        loginButton.action = { [weak self] in self?.performLogin() }
        container.addSubview(loginButton)
        
        // tag:buttonspinner tag:spinner tag:loginspinner
        spinner = NSProgressIndicator(frame: NSRect(x: cardW / 2 - 11, y: loginButton.frame.midY - 11, width: 22, height: 22))
        spinner.style = .spinning
        spinner.controlSize = .regular
        spinner.isDisplayedWhenStopped = false
        spinner.appearance = NSAppearance(named: .darkAqua)
        container.addSubview(spinner)

        let bottomPadding: CGFloat = 28
    }

    private func makeFieldLabel(_ text: String, frame: NSRect) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.font      = font_loader.light(size: 10)
        l.textColor = NSColor.white.withAlphaComponent(0.4)
        l.frame     = frame
        return l
    }

    private func styleFieldCell(_ field: NSTextField) {
        // make placeholder text be lighter
        if let cell = field.cell as? NSTextFieldCell {
            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.white.withAlphaComponent(0.3),
                .font: font_loader.light(size: 14),
            ]
            cell.placeholderAttributedString = NSAttributedString(string: field.placeholderString ?? "", attributes: attrs)
        }
    }

    // -- Clock
    // tag:clock
    func startClock() {
        updateClock()
        clockTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateClock()
        }
    }

    func updateClock() {
        let now = Date()
        let tf  = DateFormatter(); tf.dateFormat = "h:mm"
        let df  = DateFormatter(); df.dateFormat = "EEEE, MMMM d"
        clockLabel.stringValue = tf.string(from: now)
        dateLabel.stringValue  = df.string(from: now)
    }

    func show() {
        bundle_log("show() called. ordering window front")
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        bundle_log("window should be visible now.")
    }

    func controlTextDidBeginEditing(_ obj: Notification) {
        if let field = obj.object as? NSTextField,
           let bg    = userBgFields[field] {
            bg.isFocused = true
        }
    }
    func controlTextDidEndEditing(_ obj: Notification) {
        if let field = obj.object as? NSTextField,
           let bg    = userBgFields[field] {
            bg.isFocused = false
        }
    }

    // handle enter key
    func control(_ control: NSControl, textView: NSTextView, doCommandBy sel: Selector) -> Bool {
        if sel == #selector(NSResponder.insertNewline(_:)) {
            if control == username_field  { window.makeFirstResponder(password_field) }
            else if control == password_field { performLogin() }
            return true
        }
        return false
    }

    // -- login action
    // tag:loginhandler tag:loginaction tag:login tag:performlogin
    
    // credential validation is NOT done by OpenDirectory here.
    // there seems to be issues with it here. instead, credentials are passed
    // directly to the auth engine and macOS' builtin:authenticate mechanism
    // does the credential validation.

    func performLogin() {
        let username = username_field.stringValue.trimmingCharacters(in: .whitespaces)
        let password = password_field.stringValue

        guard !username.isEmpty, !password.isEmpty else {
            showError("Please enter your username and password.")
            shakeCard()
            return
        }

        setLoading(true)

        // pass credentials to auth engine
        // authenticate will be called and deny login if credentials are wrong
        let passwordData = password.data(using: .utf8) ?? Data()
        onLogin?(username, passwordData)
    }

    // tag:buggy
    private func setLoading(_ on: Bool) {
        if settings.uiMode == "minimalistic" {
            minimalisticLoginButton.isHidden = on
            if on { spinner.startAnimation(nil) }
            else { spinner.stopAnimation(nil) }
        } else {
            loginButton.isEnabled = !on
            loginButton.title     = on ? "" : "Sign In"
            if on { spinner.startAnimation(nil) }
            else  { spinner.stopAnimation(nil)  }
        }
        errorLabel.isHidden   = true
    }

    func showError(_ message: String) {
        setLoading(false)
        errorLabel.stringValue = message
        errorLabel.isHidden    = false
        errorLabel.alphaValue  = 0
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            errorLabel.animator().alphaValue = 1
        }
    }

    func shakeCard() {
        guard let layer = container.layer else { return }
        let anim = CAKeyframeAnimation(keyPath: "transform.translation.x")
        anim.timingFunction = CAMediaTimingFunction(name: .linear)
        anim.duration       = 0.45
        anim.values         = [0, -14, 14, -10, 10, -6, 6, -3, 3, 0]
        layer.add(anim, forKey: "shake")
    }

    private func setupComplexBackground(in root: NSView, path: String, type: String? = nil) {
        let bgType = type ?? settings.bgType
        bundle_log("setupComplexBackground path: \(path) type: \(bgType)")
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor.black.cgColor
        
        // fallback flag
        var success = false

        do {
            if bgType == "video" {
                bundle_log("attempting video playback")
                let asset = AVURLAsset(url: URL(fileURLWithPath: path))
                let item = AVPlayerItem(asset: asset)
                queuePlayer = AVQueuePlayer(playerItem: item)
                playerLooper = AVPlayerLooper(player: queuePlayer!, templateItem: item)
                let layer = AVPlayerLayer(player: queuePlayer)
                applyScaling(to: layer, frame: root.bounds)
                root.layer?.addSublayer(layer)
                queuePlayer?.play()
                success = true
                bundle_log("video playback success.")
            } else {
                bundle_log("attempting image/gif load")
                let iv = NSImageView(frame: root.bounds)
                if let img = NSImage(contentsOfFile: path), img.size.width > 0 {
                    iv.image = img
                    bundle_log("media file loaded successfully, size: \(img.size)")
                    success = true
                } else {
                    bundle_log("failed. NSImage(contentsOfFile:) returned nil or empty for path: \(path)")
                }
                
                if success {
                    iv.wantsLayer = true
                    switch settings.bgScaling {
                    case "fit": iv.imageScaling = .scaleAxesIndependently
                    case "crop": 
                        iv.imageScaling = .scaleProportionallyUpOrDown
                        iv.layer?.contentsGravity = .resizeAspectFill
                    case "original": 
                        iv.imageScaling = .scaleNone
                        iv.layer?.contentsGravity = .center
                    default:
                        iv.imageScaling = .scaleProportionallyUpOrDown
                        iv.layer?.contentsGravity = .resizeAspectFill
                    }
                    iv.autoresizingMask = [.width, .height]
                    root.addSubview(iv)
                }
            }
        } catch {
            bundle_log("unrecoverable error in setupComplexBackground: \(error)")
        }

        if !success {
            bundle_log("loading background failed, defaulting to gradient.")
            let bg = CAGradientLayer()
            bg.frame  = root.bounds
            bg.colors = [
                NSColor(calibratedRed: 0.04, green: 0.04, blue: 0.08, alpha: 1).cgColor,
                NSColor(calibratedRed: 0.08, green: 0.10, blue: 0.16, alpha: 1).cgColor,
            ]
            root.layer?.addSublayer(bg)
        }
    }
    
    private func applyScaling(to layer: AVPlayerLayer, frame: CGRect) {
        layer.frame = frame
        switch settings.bgScaling {
        case "fit": layer.videoGravity = .resize
        case "crop": layer.videoGravity = .resizeAspectFill
        case "original": layer.videoGravity = .resizeAspect
        default: layer.videoGravity = .resizeAspectFill
        }
    }

    private func findBundleResource(prefix: String) -> String? {
        let bundle = Bundle(for: LoginUI.self)
        guard let resourcePath = bundle.resourcePath else { return nil }
        
        let fm = FileManager.default
        do {
            let items = try fm.contentsOfDirectory(atPath: resourcePath)
            if let found = items.first(where: { $0.lowercased().hasPrefix(prefix.lowercased()) }) {
                return (resourcePath as NSString).appendingPathComponent(found)
            }
        } catch {
            bundle_log("failed while searching bundle resources for \(prefix): \(error)")
        }
        return nil
    }
}

// tag:card tag:logincard
class GlassCard: NSView {
    var backgroundTransparency: CGFloat = 0.06 { 
        didSet { 
            needsDisplay = true
            blurView?.layer?.opacity = Float(backgroundTransparency)
            layer?.backgroundColor = NSColor.white.withAlphaComponent(backgroundTransparency).cgColor
            layer?.borderWidth = backgroundTransparency > 0 ? 1 : 0
        } 
    }
    private var blurView: NSVisualEffectView?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius   = 20
        layer?.masksToBounds  = true
        layer?.borderWidth    = 1
        layer?.borderColor    = NSColor.white.withAlphaComponent(0.12).cgColor
        layer?.backgroundColor = NSColor.white.withAlphaComponent(backgroundTransparency).cgColor

        // blur using NSVisualEffectView underneath
        let blur = NSVisualEffectView(frame: bounds)
        blur.autoresizingMask = [.width, .height]
        blur.material         = .hudWindow
        blur.blendingMode     = .behindWindow
        blur.state            = .active
        blur.appearance       = NSAppearance(named: .darkAqua)
        addSubview(blur, positioned: .below, relativeTo: nil)
        self.blurView = blur
    }
    required init?(coder: NSCoder) { super.init(coder: coder) }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds, xRadius: 20, yRadius: 20)
        NSColor.white.withAlphaComponent(backgroundTransparency).setFill()
        path.fill()
    }
}

// tag:usersilhouette
class SilhouetteView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let cx = bounds.midX
        let cy = bounds.midY
        let r  = min(bounds.width, bounds.height) / 2

        NSColor.white.withAlphaComponent(0.35).setFill()

        // head circle
        let headR:  CGFloat = r * 0.34
        let headCY: CGFloat = cy + r * 0.18
        NSBezierPath(ovalIn: NSRect(x: cx - headR, y: headCY - headR,
                                     width: headR * 2, height: headR * 2)).fill()

        // body arc
        let bodyPath = NSBezierPath()
        let bodyR:  CGFloat = r * 0.60
        let bodyCY: CGFloat = cy - r * 0.40
        bodyPath.appendArc(withCenter: NSPoint(x: cx, y: bodyCY),
                            radius: bodyR,
                            startAngle: 0, endAngle: 180)
        bodyPath.close()
        bodyPath.fill()
    }
}

class NoiseView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        // lightweight "noise" using small dots
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.018).cgColor)
        var x: CGFloat = 0
        while x < bounds.width {
            var y: CGFloat = 0
            while y < bounds.height {
                // pseudo-random skip
                let skip = ((Int(x) * 1373 + Int(y) * 97) % 5) != 0
                if !skip { ctx.fill(CGRect(x: x, y: y, width: 1, height: 1)) }
                y += 3
            }
            x += 3
        }
    }
}

// tag:confirmationoverlay
class ConfirmationOverlay: NSView {
    var onConfirm: (() -> Void)?
    var onCancel: (() -> Void)?
    
    private let card = GlassCard(frame: .zero)
    private let titleLabel = NSTextField(labelWithString: "")
    private let infoLabel = NSTextField(labelWithString: "")
    private var confirmBtn: BengalButton!
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.45).cgColor
        
        let cardW: CGFloat = 360
        let cardH: CGFloat = 200
        card.frame = NSRect(x: (bounds.width - cardW) / 2, y: (bounds.height - cardH) / 2 + 40, width: cardW, height: cardH)
        card.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin, .maxYMargin]
        addSubview(card)
        
        titleLabel.font = font_loader.bold(size: 20)
        titleLabel.textColor = .white
        titleLabel.alignment = .center
        titleLabel.isEditable = false
        titleLabel.isBordered = false
        titleLabel.drawsBackground = false
        titleLabel.frame = NSRect(x: 20, y: cardH - 55, width: cardW - 40, height: 30)
        card.addSubview(titleLabel)
        
        infoLabel.font = font_loader.light(size: 14)
        infoLabel.textColor = NSColor.white.withAlphaComponent(0.65)
        infoLabel.alignment = .center
        infoLabel.isEditable = false
        infoLabel.isBordered = false
        infoLabel.drawsBackground = false
        infoLabel.frame = NSRect(x: 30, y: cardH - 100, width: cardW - 60, height: 40)
        infoLabel.cell?.wraps = true
        card.addSubview(infoLabel)
        
        let btnW: CGFloat = 135
        let btnH: CGFloat = 40
        
        let cancelBtn = BengalButton(frame: NSRect(x: 30, y: 30, width: btnW, height: btnH))
        cancelBtn.title = "Cancel"
        cancelBtn.action = { [weak self] in self?.onCancel?() }
        card.addSubview(cancelBtn)
        
        confirmBtn = BengalButton(frame: NSRect(x: cardW - btnW - 30, y: 30, width: btnW, height: btnH))
        confirmBtn.action = { [weak self] in self?.onConfirm?() }
        card.addSubview(confirmBtn)
    }
    
    func show(title: String, info: String, confirmTitle: String) {
        titleLabel.stringValue = title
        infoLabel.stringValue = info
        confirmBtn.title = confirmTitle
    }
    
    override func mouseDown(with event: NSEvent) {
        // background click cancels
        let loc = convert(event.locationInWindow, from: nil)
        if !card.frame.contains(loc) {
            onCancel?()
        }
    }
}