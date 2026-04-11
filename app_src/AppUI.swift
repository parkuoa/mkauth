//
//  AppUI.swift
//  bengal
//
//  Created by naomisphere on April 7th, 2026.
//  Copyright © 2026 naomisphere. All rights reserved.
//

// here's a guide to understanding this mess
// lui = login UI

// -- login UI preview --
// tag:uimode - select UI mode section
// tag:uipreview - login UI mini-preview
// tag:uipreview_bg - bg media for mini-preview
// tag:uipreview_card - mini-preview login card

// -- settings --
// tag:settings_media - avatar & background settings
// tag:settings_avatar - avatar column
// tag:settings_bg - background column
// tag:settings_bg_scaling - lui bg media scaling options
// tag:settings_clock - clock-related settings
// tag:settings_login_card - login card related settings
// tag:settings_power_buttons - power buttons related settings

import Cocoa

class wrapper_app_ui: NSView {
    private let header_cont = RoundedView()
    private let contentView = RoundedView()
    private let sidepanel = RoundedView()
    private let customizationView = RoundedView()
    private let terminal_cont = RoundedView()
    private let terminal_output_text = NSTextView()
    private let terminal_scroll = NSScrollView()
    
    private let debug_mode_check = ModernCheckbox()
    private var parameterRows: [ParameterRow] = []
    private let rowsStack = NSStackView()
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        app_ui()
        define_terminal()
        
        Executor.shared.onOutput = { [weak self] text in
            self?.append_term_output(text)
        }
        
        Executor.shared.onCompletion = { [weak self] code in
            let _green = NSColor(red: 0.1, green: 0.8, blue: 0.1, alpha: 1.0)
            let status = code == 0 ? "\nsuccess\n" : "\nfailed\n"
            let color = code == 0 ? _green : NSColor.red
            self?.append_term_output(status, color: color)
        }
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    private func app_ui() {
        let padding: CGFloat = 24

        header_cont.backgroundColor = BengalStyle.surface
        header_cont.isDraggable = true
        header_cont.frame = NSRect(x: padding, y: frame.height - 74, width: frame.width - (padding * 2), height: 50)
        header_cont.autoresizingMask = [.width, .minYMargin]
        addSubview(header_cont)
        
        let logoView = NSImageView(frame: NSRect(x: 12, y: 10, width: 30, height: 30))
        let logoPath = Bundle.main.resourcePath! + "/img/logo.png"
        if let img = NSImage(contentsOfFile: logoPath) {
            logoView.image = img
        }
        header_cont.addSubview(logoView)
        
        let titleLabel = NSTextField(labelWithString: "bengal")
        titleLabel.font = BengalFont.bold(size: 22)
        titleLabel.textColor = BengalStyle.text
        titleLabel.sizeToFit()
        titleLabel.frame.origin = CGPoint(x: 52, y: 12)
        header_cont.addSubview(titleLabel)
        
        let versionLabel = NSTextField(labelWithString: "v1.0.0")
        versionLabel.font = BengalFont.light(size: 12)
        versionLabel.textColor = BengalStyle.textMuted
        versionLabel.sizeToFit()
        let vY = (header_cont.frame.height - versionLabel.frame.height) / 2
        versionLabel.frame.origin = CGPoint(x: header_cont.frame.width - versionLabel.frame.width - 16, y: vY)
        versionLabel.autoresizingMask = [.minXMargin, .minYMargin, .maxYMargin]
        header_cont.addSubview(versionLabel)

        contentView.backgroundColor = BengalStyle.surface
        contentView.frame = NSRect(x: padding, y: 180, width: 400, height: max(0, frame.height - 180 - 74 - 12))
        contentView.autoresizingMask = [.height, .maxXMargin]
        addSubview(contentView)
        
        setup_buttons()

        sidepanel.backgroundColor = NSColor.black.withAlphaComponent(0.2)
        sidepanel.frame = NSRect(x: padding + 400 + 16, y: 180, width: max(0, frame.width - 400 - (padding * 2) - 16), height: max(0, frame.height - 180 - 74 - 12))
        sidepanel.autoresizingMask = [.width, .height]
        sidepanel.isHidden = true
        addSubview(sidepanel)
        
        setup_args_param_builder()
        setupCustomizationView()
        
        // TAG:term
        terminal_cont.backgroundColor = BengalStyle.terminal
        terminal_cont.frame = NSRect(x: padding, y: padding, width: frame.width - (padding * 2), height: 140)
        terminal_cont.autoresizingMask = [.width, .maxYMargin]
        addSubview(terminal_cont)
    }
    
    private func setupCustomizationView() {
    let padding: CGFloat = 24
    customizationView.backgroundColor = NSColor.black.withAlphaComponent(0.2)
    customizationView.frame = NSRect(x: padding + 400 + 16, y: 180, width: max(0, frame.width - 400 - (padding * 2) - 16), height: max(0, frame.height - 180 - 74 - 12))
    customizationView.autoresizingMask = [.width, .height]
    customizationView.isHidden = true
    addSubview(customizationView)

    let scroll = NSScrollView(frame: customizationView.bounds.insetBy(dx: 12, dy: 12))
    scroll.drawsBackground = false
    scroll.hasVerticalScroller = true
    scroll.autoresizingMask = [.width, .height]
    
    let stack = NSStackView()
    stack.orientation = .vertical
    stack.spacing = 20
    stack.alignment = .leading
    stack.edgeInsets = NSEdgeInsets(top: 20, left: 10, bottom: 20, right: 10)
    
    scroll.documentView = stack
    stack.translatesAutoresizingMaskIntoConstraints = false
    stack.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor, constant: -20).isActive = true
    customizationView.addSubview(scroll)
    
    // screw this
    DispatchQueue.main.async { [weak self] in
        self?.setupCustomizationContent(stack: stack)
        self?.update_miniprev_bg()
    }
}

private var previewBGView: NSImageView?
private var avatarStatusLabel = NSTextField(labelWithString: "")
private var bgStatusLabel = NSTextField(labelWithString: "")

private func update_miniprev_bg() {
    let settings = BengalSettings.shared
    if let bg = settings.bgPath, let img = NSImage(contentsOfFile: bg) {
        previewBGView?.image = img
    } else {
        previewBGView?.image = nil
    }
    
    switch settings.bgScaling {
    case "fit": previewBGView?.imageScaling = .scaleAxesIndependently
    case "original": previewBGView?.imageScaling = .scaleNone
    case "crop": previewBGView?.imageScaling = .scaleProportionallyUpOrDown
    default: previewBGView?.imageScaling = .scaleProportionallyUpOrDown
    }
    
    // update status labels
    bgStatusLabel.stringValue = settings.bgPath != nil ? URL(fileURLWithPath: settings.bgPath!).lastPathComponent : "No background set"
    avatarStatusLabel.stringValue = settings.avatarPath != nil ? URL(fileURLWithPath: settings.avatarPath!).lastPathComponent : "No avatar set"
}

private func setupCustomizationContent(stack: NSStackView) {
    let settings = BengalSettings.shared

    // tag:uimode
    let modeRow = NSStackView()
    modeRow.orientation = .horizontal
    modeRow.spacing = 20
    stack.addArrangedSubview(modeRow)
    modeRow.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -20).isActive = true
    
    let modeLabel = NSTextField(labelWithString: "UI Mode")
    modeLabel.font = BengalFont.bold(size: 14)
    modeLabel.textColor = .white
    modeRow.addArrangedSubview(modeLabel)
    
    let modeSelector = NSSegmentedControl(labels: ["Default", "Minimalistic"], trackingMode: .selectOne, target: self, action: #selector(uiModeChanged(_:)))
    modeSelector.selectedSegment = settings.uiMode == "minimalistic" ? 1 : 0
    modeRow.addArrangedSubview(modeSelector)
    
    // tag:uipreview
    let previewWrapper = NSView()
    previewWrapper.translatesAutoresizingMaskIntoConstraints = false
    previewWrapper.heightAnchor.constraint(equalToConstant: 140).isActive = true
    stack.addArrangedSubview(previewWrapper)
    previewWrapper.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    
    let previewCont = RoundedView(frame: NSRect(x: 0, y: 0, width: 220, height: 130))
    previewCont.backgroundColor = .black
    previewCont.cornerRadius = 14
    previewCont.translatesAutoresizingMaskIntoConstraints = false
    previewWrapper.addSubview(previewCont)
    
    // tag:uipreview_bg
    let miniBG = NSImageView(frame: previewCont.bounds)
    miniBG.imageScaling = .scaleAxesIndependently
    miniBG.wantsLayer = true
    miniBG.layer?.cornerRadius = 14
    miniBG.layer?.masksToBounds = true
    previewCont.addSubview(miniBG, positioned: .below, relativeTo: nil)
    self.previewBGView = miniBG
    
    NSLayoutConstraint.activate([
        previewCont.centerXAnchor.constraint(equalTo: previewWrapper.centerXAnchor),
        previewCont.centerYAnchor.constraint(equalTo: previewWrapper.centerYAnchor),
        previewCont.widthAnchor.constraint(equalToConstant: 220),
        previewCont.heightAnchor.constraint(equalToConstant: 130)
    ])
    
    // tag:uipreview_card
    let cardMock = RoundedView(frame: NSRect(x: 85, y: 35, width: 50, height: 60))
    cardMock.backgroundColor = NSColor.white.withAlphaComponent(0.2)
    cardMock.cornerRadius = 6
    previewCont.addSubview(cardMock)
    
    let avatarMock = RoundedView(frame: NSRect(x: 15, y: 35, width: 20, height: 20))
    avatarMock.backgroundColor = NSColor.white.withAlphaComponent(0.3)
    avatarMock.cornerRadius = 10
    cardMock.addSubview(avatarMock)
    
    let clockMock = NSTextField(labelWithString: "12:00")
    clockMock.font = NSFont.systemFont(ofSize: 10, weight: .light)
    clockMock.textColor = .white
    clockMock.frame = NSRect(x: 0, y: 105, width: 220, height: 15)
    clockMock.alignment = .center
    previewCont.addSubview(clockMock)
    
    func makeLabel(_ text: String) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.font = BengalFont.bold(size: 11)
        l.textColor = BengalStyle.textMuted
        return l
    }
    
    func makeHeader(_ text: String) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.font = BengalFont.bold(size: 15)
        l.textColor = .white
        return l
    }
    
      //                   \\
     // main settings start \\
    //                       \\

   // looks uglier than i expected

    // tag:settings_media
    let mainRow = NSStackView()
    mainRow.orientation = .horizontal
    mainRow.distribution = .fillEqually
    mainRow.spacing = 20
    stack.addArrangedSubview(mainRow)
    mainRow.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -20).isActive = true
    
    // tag:settings_avatar
    let avatarCol = NSStackView()
    avatarCol.orientation = .vertical
    avatarCol.alignment = .leading
    avatarCol.spacing = 6
    mainRow.addArrangedSubview(avatarCol)
    
    avatarCol.addArrangedSubview(makeLabel("Avatar override"))
    let avatarBtn = ModernButton(frame: NSRect(x: 0, y: 0, width: 140, height: 32))
    avatarBtn.title = "Pick Avatar"
    avatarBtn.action = { [weak self] in self?.pickHeaderFile(type: .avatar) }
    avatarBtn.translatesAutoresizingMaskIntoConstraints = false
    avatarBtn.heightAnchor.constraint(equalToConstant: 32).isActive = true
    avatarCol.addArrangedSubview(avatarBtn)
    avatarBtn.widthAnchor.constraint(equalTo: avatarCol.widthAnchor).isActive = true
    
    avatarStatusLabel.font = NSFont.systemFont(ofSize: 10)
    avatarStatusLabel.textColor = BengalStyle.textMuted.withAlphaComponent(0.7)
    avatarCol.addArrangedSubview(avatarStatusLabel)

    let avatarReset = ModernButton(frame: NSRect(x: 0, y: 0, width: 80, height: 24))
    avatarReset.title = "Reset Avatar"
    avatarReset.action = { [weak self] in
        BengalSettings.shared.avatarPath = nil; BengalSettings.shared.save(); self?.update_miniprev_bg()
    }
    avatarReset.translatesAutoresizingMaskIntoConstraints = false
    avatarReset.heightAnchor.constraint(equalToConstant: 24).isActive = true
    avatarCol.addArrangedSubview(avatarReset)
    
    // tag:settings_bg
    let bgCol = NSStackView()
    bgCol.orientation = .vertical
    bgCol.alignment = .leading
    bgCol.spacing = 6
    mainRow.addArrangedSubview(bgCol)
    
    bgCol.addArrangedSubview(makeLabel("Background media"))
    let bgBtn = ModernButton(frame: NSRect(x: 0, y: 0, width: 140, height: 32))
    bgBtn.title = "Pick Media"
    bgBtn.action = { [weak self] in self?.pickHeaderFile(type: .background) }
    bgBtn.translatesAutoresizingMaskIntoConstraints = false
    bgBtn.heightAnchor.constraint(equalToConstant: 32).isActive = true
    bgCol.addArrangedSubview(bgBtn)
    bgBtn.widthAnchor.constraint(equalTo: bgCol.widthAnchor).isActive = true
    
    bgStatusLabel.font = NSFont.systemFont(ofSize: 10)
    bgStatusLabel.textColor = BengalStyle.textMuted.withAlphaComponent(0.7)
    bgCol.addArrangedSubview(bgStatusLabel)

    let bgReset = ModernButton(frame: NSRect(x: 0, y: 0, width: 80, height: 24))
    bgReset.title = "Reset Background"
    bgReset.action = { [weak self] in
        BengalSettings.shared.bgPath = nil; BengalSettings.shared.save(); self?.update_miniprev_bg()
    }
    bgReset.translatesAutoresizingMaskIntoConstraints = false
    bgReset.heightAnchor.constraint(equalToConstant: 24).isActive = true
    bgCol.addArrangedSubview(bgReset)
    
    // tag:settings_bg_scaling
    stack.addArrangedSubview(makeLabel("Background scaling"))
    let scalingPop = NSPopUpButton(frame: .zero, pullsDown: false)
    scalingPop.addItems(withTitles: ["Scale to Fit", "Original Size", "Crop"])
    scalingPop.target = self
    scalingPop.action = #selector(scalingChanged(_:))
    stack.addArrangedSubview(scalingPop)

    stack.addArrangedSubview(NSBox()) // Spacer

    // tag:settings_clock
    stack.addArrangedSubview(makeHeader("Clock"))
    
    stack.addArrangedSubview(makeLabel("Clock size"))
    let clockSlider = ModernSlider()
    clockSlider.value = Double(settings.clockSize) / 200.0
    clockSlider.onChange = { val in 
        let s = BengalSettings.shared; s.clockSize = Int(val * 200); s.save()
        clockMock.font = NSFont.systemFont(ofSize: 5 + CGFloat(val * 10), weight: .light)
        self.syncToBundle()
    }
    clockSlider.translatesAutoresizingMaskIntoConstraints = false
    stack.addArrangedSubview(clockSlider)
    clockSlider.heightAnchor.constraint(equalToConstant: 24).isActive = true
    clockSlider.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -20).isActive = true

    stack.addArrangedSubview(makeLabel("Clock color / gradient (#hex|#hex)"))
    let clockColorField = ModernTextField(frame: .zero)
    clockColorField.stringValue = settings.clockColor
    clockColorField.translatesAutoresizingMaskIntoConstraints = false
    stack.addArrangedSubview(clockColorField)
    clockColorField.heightAnchor.constraint(equalToConstant: 32).isActive = true
    clockColorField.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -20).isActive = true
    clockColorField.target = self
    clockColorField.action = #selector(clockColorChanged(_:))
    
    stack.addArrangedSubview(makeLabel("Clock gradient angle (0-360)"))
    let clockAngleSlider = ModernSlider()
    clockAngleSlider.value = settings.clockAngle / 360.0
    clockAngleSlider.onChange = { val in
        let s = BengalSettings.shared; s.clockAngle = val * 360.0; s.save()
        self.syncToBundle()
    }
    clockAngleSlider.translatesAutoresizingMaskIntoConstraints = false
    stack.addArrangedSubview(clockAngleSlider)
    clockAngleSlider.heightAnchor.constraint(equalToConstant: 24).isActive = true
    clockAngleSlider.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -20).isActive = true

    // tag:settings_login_card
    stack.addArrangedSubview(makeHeader("Card"))
    
    stack.addArrangedSubview(makeLabel("Card transparency"))
    let cardTransSlider = ModernSlider()
    cardTransSlider.value = settings.cardTransparency
    cardTransSlider.onChange = { val in 
        let s = BengalSettings.shared; s.cardTransparency = val; s.save()
        self.syncToBundle()
    }
    cardTransSlider.translatesAutoresizingMaskIntoConstraints = false
    stack.addArrangedSubview(cardTransSlider)
    cardTransSlider.heightAnchor.constraint(equalToConstant: 24).isActive = true
    cardTransSlider.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -20).isActive = true

    stack.addArrangedSubview(makeLabel("Login button color / gradient"))
    let btnColorField = ModernTextField(frame: .zero)
    btnColorField.stringValue = settings.loginButtonColor
    btnColorField.translatesAutoresizingMaskIntoConstraints = false
    stack.addArrangedSubview(btnColorField)
    btnColorField.heightAnchor.constraint(equalToConstant: 32).isActive = true
    btnColorField.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -20).isActive = true
    btnColorField.target = self
    btnColorField.action = #selector(btnColorChanged(_:))

    stack.addArrangedSubview(makeLabel("Button gradient angle"))
    let btnAngleSlider = ModernSlider()
    btnAngleSlider.value = settings.loginButtonAngle / 360.0
    btnAngleSlider.onChange = { val in
        let s = BengalSettings.shared; s.loginButtonAngle = val * 360.0; s.save()
        self.syncToBundle()
    }
    btnAngleSlider.translatesAutoresizingMaskIntoConstraints = false
    stack.addArrangedSubview(btnAngleSlider)
    btnAngleSlider.heightAnchor.constraint(equalToConstant: 24).isActive = true
    btnAngleSlider.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -20).isActive = true

    // tag:settings_power_buttons
    stack.addArrangedSubview(makeHeader("Power Buttons"))
    
    stack.addArrangedSubview(makeLabel("Buttons transparency (BG)"))
    let powerTransSlider = ModernSlider()
    powerTransSlider.value = settings.powerButtonsTransparency
    powerTransSlider.onChange = { val in 
        let s = BengalSettings.shared; s.powerButtonsTransparency = val; s.save()
        self.syncToBundle()
    }
    powerTransSlider.translatesAutoresizingMaskIntoConstraints = false
    stack.addArrangedSubview(powerTransSlider)
    powerTransSlider.heightAnchor.constraint(equalToConstant: 24).isActive = true
    powerTransSlider.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -20).isActive = true

    // power button bg color
    stack.addArrangedSubview(makeLabel("Background color / gradient"))
    let pbBgColorField = ModernTextField(frame: .zero)
    pbBgColorField.stringValue = settings.powerButtonBGColor
    pbBgColorField.translatesAutoresizingMaskIntoConstraints = false
    stack.addArrangedSubview(pbBgColorField)
    pbBgColorField.heightAnchor.constraint(equalToConstant: 32).isActive = true
    pbBgColorField.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -20).isActive = true
    pbBgColorField.target = self
    pbBgColorField.action = #selector(powerButtonBGColorChanged(_:))

    stack.addArrangedSubview(makeLabel("Background gradient angle"))
    let pbBgAngleSlider = ModernSlider()
    pbBgAngleSlider.value = settings.powerButtonBGAngle / 360.0
    pbBgAngleSlider.onChange = { val in
        let s = BengalSettings.shared; s.powerButtonBGAngle = val * 360.0; s.save()
        self.syncToBundle()
    }
    pbBgAngleSlider.translatesAutoresizingMaskIntoConstraints = false
    stack.addArrangedSubview(pbBgAngleSlider)
    pbBgAngleSlider.heightAnchor.constraint(equalToConstant: 24).isActive = true
    pbBgAngleSlider.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -20).isActive = true

    // power button icon color
    stack.addArrangedSubview(makeLabel("Icon color / gradient"))
    let pbIconColorField = ModernTextField(frame: .zero)
    pbIconColorField.stringValue = settings.powerButtonIconColor
    pbIconColorField.translatesAutoresizingMaskIntoConstraints = false
    stack.addArrangedSubview(pbIconColorField)
    pbIconColorField.heightAnchor.constraint(equalToConstant: 32).isActive = true
    pbIconColorField.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -20).isActive = true
    pbIconColorField.target = self
    pbIconColorField.action = #selector(powerButtonIconColorChanged(_:))

    stack.addArrangedSubview(makeLabel("Icon gradient angle"))
    let pbIconAngleSlider = ModernSlider()
    pbIconAngleSlider.value = settings.powerButtonIconAngle / 360.0
    pbIconAngleSlider.onChange = { val in
        let s = BengalSettings.shared; s.powerButtonIconAngle = val * 360.0; s.save()
        self.syncToBundle()
    }
    pbIconAngleSlider.translatesAutoresizingMaskIntoConstraints = false
    stack.addArrangedSubview(pbIconAngleSlider)
    pbIconAngleSlider.heightAnchor.constraint(equalToConstant: 24).isActive = true
    pbIconAngleSlider.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -20).isActive = true
}

@objc private func uiModeChanged(_ sender: NSSegmentedControl) {
    let s = BengalSettings.shared
    s.uiMode = sender.selectedSegment == 1 ? "minimalistic" : "default"
    s.save()
    self.syncToBundle()
}

@objc private func powerButtonBGColorChanged(_ sender: NSTextField) {
    let s = BengalSettings.shared; s.powerButtonBGColor = sender.stringValue; s.save(); self.syncToBundle()
}

@objc private func powerButtonIconColorChanged(_ sender: NSTextField) {
    let s = BengalSettings.shared; s.powerButtonIconColor = sender.stringValue; s.save(); self.syncToBundle()
}
    
    enum FilePickTarget { case background, avatar }
    private func pickHeaderFile(type: FilePickTarget) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if type == .background {
            panel.allowedFileTypes = ["png", "jpg", "jpeg", "gif", "mp4", "mov"]
        } else {
            panel.allowedFileTypes = ["png", "jpg", "jpeg"]
        }
        
        panel.begin { result in
            if result == .OK, let url = panel.url {
                let s = BengalSettings.shared
                if type == .background {
                    s.bgPath = url.path
                    s.bgType = url.pathExtension.lowercased() == "mp4" || url.pathExtension.lowercased() == "mov" ? "video" : (url.pathExtension.lowercased() == "gif" ? "gif" : "image")
                } else {
                    s.avatarPath = url.path
                }
                s.save()
                self.update_miniprev_bg()
                self.syncToBundle()
            }
        }
    }
    
    @objc private func scalingChanged(_ sender: NSPopUpButton) {
        let s = BengalSettings.shared
        switch sender.titleOfSelectedItem {
        case "Scale to Fit": s.bgScaling = "fit"
        case "Original Size": s.bgScaling = "original"
        case "Crop": s.bgScaling = "crop"
        default: break
        }
        s.save()
        self.update_miniprev_bg()
        self.syncToBundle()
    }

    @objc private func clockColorChanged(_ sender: NSTextField) {
        let s = BengalSettings.shared
        s.clockColor = sender.stringValue
        s.save()
        self.syncToBundle()
    }

    @objc private func btnColorChanged(_ sender: NSTextField) {
        let s = BengalSettings.shared
        s.loginButtonColor = sender.stringValue
        s.save()
        self.syncToBundle()
    }
    
    private func setup_buttons() {
        let btnWidth: CGFloat = 160
        let btnHeight: CGFloat = 40
        let spacing: CGFloat = 12
        
        debug_mode_check.frame = NSRect(x: 24, y: contentView.frame.height - 44, width: 150, height: 24)
        debug_mode_check.title = "Debug Mode"
        contentView.addSubview(debug_mode_check)
        
        let applyBtn = ModernButton(frame: NSRect(x: 24, y: contentView.frame.height - 44 - 52, width: btnWidth, height: btnHeight))
        applyBtn.title = "Login Behavior"
        
        let loginScreenBtn = ModernButton(frame: NSRect(x: 24, y: contentView.frame.height - 44 - 52 - 52, width: btnWidth, height: btnHeight))
        loginScreenBtn.title = "Login Screen"

        applyBtn.action = { [weak self] in
            guard let self = self else { return }
            applyBtn.isToggled.toggle()
            loginScreenBtn.isToggled = false
            self.customizationView.isHidden = true
            self.sidepanel.isHidden = !applyBtn.isToggled
        }
        
        loginScreenBtn.action = { [weak self] in
            guard let self = self else { return }
            loginScreenBtn.isToggled.toggle()
            applyBtn.isToggled = false
            self.sidepanel.isHidden = true
            self.customizationView.isHidden = !loginScreenBtn.isToggled
        }

        contentView.addSubview(applyBtn)
        contentView.addSubview(loginScreenBtn)
        
        let otherActions = [
            ("Print Config", ["-print"], false),
            ("Reset Defaults", ["-reset"], true)
        ]
        
        var currentY: CGFloat = contentView.frame.height - 44 - 52 - 52 - (btnHeight + spacing)
        for (title, baseArgs, needsSudo) in otherActions {
            let btn = ModernButton(frame: NSRect(x: 24, y: currentY, width: btnWidth, height: btnHeight))
            btn.title = title
            btn.action = { [weak self] in self?.run_command(baseArgs: baseArgs, sudo: needsSudo) }
            contentView.addSubview(btn)
            currentY -= btnHeight + spacing
        }
    }
    
    private func setup_args_param_builder() {
        let label = NSTextField(labelWithString: "")
        label.font = BengalFont.bold(size: 13)
        label.textColor = BengalStyle.textMuted
        label.frame = NSRect(x: 20, y: sidepanel.frame.height - 40, width: 200, height: 20)
        sidepanel.addSubview(label)
        
        let scroll = NSScrollView(frame: NSRect(x: 20, y: 60, width: sidepanel.frame.width - 40, height: sidepanel.frame.height - 110))
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autoresizingMask = [.width, .height]
        
        rowsStack.orientation = .vertical
        rowsStack.spacing = 0
        rowsStack.alignment = .leading
        
        scroll.documentView = rowsStack
        rowsStack.translatesAutoresizingMaskIntoConstraints = false
        rowsStack.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor).isActive = true
        
        sidepanel.addSubview(scroll)
        
        let addBtn = ModernButton(frame: NSRect(x: 20, y: 15, width: 100, height: 30))
        addBtn.title = "+ Add Arg"
        addBtn.action = { [weak self] in self?.add_param() }
        sidepanel.addSubview(addBtn)
        
        let resetBtn = ModernButton(frame: NSRect(x: 130, y: 15, width: 80, height: 30))
        resetBtn.title = "Reset"
        resetBtn.action = { [weak self] in self?.resetBuilder() }
        sidepanel.addSubview(resetBtn)
        
        let runBtn = ModernButton(frame: NSRect(x: sidepanel.frame.width - 120, y: 15, width: 100, height: 30))
        runBtn.title = "Apply"
        //runBtn.action = { [weak self] in self?.run_command(baseArgs: ["-bengal"], sudo: true) }
        runBtn.action = { [weak self] in 
            guard let self = self else { return }
            
            // get paths ready
            let resourcePath = Bundle.main.resourcePath ?? ""
            let bundle_source = "\(resourcePath)/login/BengalLogin.bundle"
            let saa_path = "/Library/Security/SecurityAgentPlugins"
            let bundle_plugin_path = "/Library/Security/SecurityAgentPlugins/BengalLogin.bundle"

            if FileManager.default.fileExists(atPath: bundle_plugin_path) {
                append_term_output("AuthBundle already exists\n", color: .white)
                self.run_command(baseArgs: ["-bengal"], sudo: true)
                return
            }
            
            // attempt to copy authbundle > SecurityAgentPlugins
            let script = "do shell script \"cp -rf '\(bundle_source)' '\(saa_path)'\" with administrator privileges"
            let appleScript = NSAppleScript(source: script)
            
            var error: NSDictionary?
            appleScript?.executeAndReturnError(&error)
            
            if let err = error {
                append_term_output("copying AuthBundle failed, please provide your password.\n", color: .red)
            } else {
                append_term_output("copied AuthBundle, calling bengal now.\n", color: .green)
                self.run_command(baseArgs: ["-bengal"], sudo: true)
            }
        }
        sidepanel.addSubview(runBtn)
        runBtn.autoresizingMask = [.minXMargin]
    }
    
    private func add_param() {
        let row = ParameterRow(frame: .zero)
        row.onRemove = { [weak self] in
            guard let self = self else { return }
            self.rowsStack.removeArrangedSubview(row)
            row.removeFromSuperview()
            self.parameterRows.removeAll { $0 === row }
        }
        parameterRows.append(row)
        rowsStack.addArrangedSubview(row)
    }
    
    private func resetBuilder() {
        for row in parameterRows {
            rowsStack.removeArrangedSubview(row)
            row.removeFromSuperview()
        }
        parameterRows.removeAll()
    }
    
    private func run_command(baseArgs: [String], sudo: Bool) {
        var finalArgs = baseArgs
        
        if debug_mode_check.isOn {
            finalArgs.insert("-debug", at: 0)
        }
        
        // get dynamic parameters if applying login config
        if baseArgs.contains("-bengal") {
            for row in parameterRows {
                let key = row.popup.titleOfSelectedItem ?? ""
                let val = row.textField.stringValue.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                if !val.isEmpty {
                    finalArgs.append(key)
                    finalArgs.append(val)
                }
            }
        }
        
        let cmdString = "bengal \(finalArgs.joined(separator: " "))"
        append_term_output("\n> \(sudo ? "sudo " : "")\(cmdString)\n")
        Executor.shared.run(command: "bengal", arguments: finalArgs, asRoot: sudo)
    }
    
    private func define_terminal() {
        terminal_scroll.frame = terminal_cont.bounds.insetBy(dx: 12, dy: 12)
        terminal_scroll.autoresizingMask = [.width, .height]
        terminal_scroll.drawsBackground = false
        terminal_scroll.hasVerticalScroller = true
        
        terminal_output_text.frame = terminal_scroll.bounds
        terminal_output_text.autoresizingMask = [.width]
        terminal_output_text.isEditable = true
        terminal_output_text.isSelectable = true
        terminal_output_text.backgroundColor = .clear
        terminal_output_text.textColor = BengalStyle.text
        terminal_output_text.font = NSFont.userFixedPitchFont(ofSize: 11)
        terminal_output_text.insertionPointColor = BengalStyle.accent
        terminal_output_text.delegate = self
        
        terminal_scroll.documentView = terminal_output_text
        terminal_cont.addSubview(terminal_scroll)

        append_term_output("waiting for I/O (v1.0.0)\n")     // initial output
    }
    
    private func append_term_output(_ text: String, color: NSColor = .white) {
        let attr = NSAttributedString(string: text, attributes: [
            .foregroundColor: color,
            .font: NSFont.userFixedPitchFont(ofSize: 11)!
        ])
        terminal_output_text.textStorage?.append(attr)
        terminal_output_text.scrollToEndOfDocument(nil)
    }

    private func syncToBundle() {
        let s = BengalSettings.shared
        let bundlePath = "/Library/Security/SecurityAgentPlugins/BengalLogin.bundle/Contents/Resources"
        let configDir = ("~/.config/bengal" as NSString).expandingTildeInPath
        let settingsPath = configDir + "/settings.json"
        
        var commands: [String] = []
        
        // -sync settings.json
        commands.append("cp '\(settingsPath)' '\(bundlePath)/settings.json'")
        
        // --sync bg if it exists
        if let bg = s.bgPath, FileManager.default.fileExists(atPath: bg) {
            let ext = (bg as NSString).pathExtension
            commands.append("cp '\(bg)' '\(bundlePath)/login_background.\(ext)'")
        }
        
        // ---sync avatar if it exists
        if let avatar = s.avatarPath, FileManager.default.fileExists(atPath: avatar) {
            let ext = (avatar as NSString).pathExtension
            commands.append("cp '\(avatar)' '\(bundlePath)/login_user_avatar.\(ext)'")
        }
        
        if commands.isEmpty { return }
        
        // join the commands  and do osascript
        let joinedCommands = commands.joined(separator: " && ")
        let script = "do shell script \"\(joinedCommands)\" with administrator privileges"
        
        append_term_output("\n> syncing with AuthBundle (requires sudo)\n")
        append_term_output("you will be prompted to enter your password.\n\n")
        
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", script]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        try? task.run()
        task.waitUntilExit()
        
        if task.terminationStatus == 0 {
            append_term_output("success\n", color: .green)
        } else {
            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorMsg = String(data: errorData, encoding: .utf8) ?? "unkown AppleScript error"
            append_term_output("sync failed: \(errorMsg)\n", color: .red)
        }
    }
}

extension wrapper_app_ui: NSTextViewDelegate {
    func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
        guard let char = replacementString else { return true }
        if char == "\n" || char == "\r" {
            Executor.shared.writeInput("\r")
        } else {
            Executor.shared.writeInput(char)
        }
        return false
    }
}
