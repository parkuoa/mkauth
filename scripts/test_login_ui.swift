import Cocoa

@main
struct logui_test {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory) // accessory so no info.plist needed

        // let ui = LoginUI(onLogin: { un, pswd in
        let ui = LoginUI(suggestedUser: "user", onLogin: { un, pswd in
            print("--------------------------------------------------")
            print("login UI returned:")
            print("username: \(un)")
            let password_no_i_am_not_stealing_your_password = String(data: pswd, encoding: .utf8) ?? "<invalid data>"
            print("password: \(String(repeating: "*", count: password_no_i_am_not_stealing_your_password.count))")
            print("--------------------------------------------------")
            NSApp.stop(nil)
        }, onAction: { action in
            print("--------------------------------------------------")
            print("login UI action triggered: \(action)")
            print("--------------------------------------------------")
            NSApp.stop(nil)
        })

        print("launching loginUI. Ctrl+C to terminate if something goes wrong")
        ui.show()
        app.run()
    }
}
