/*
    Preferences.swift
    mkauth

    Copyright © 2026 naomisphere
    Derived from authchanger 2.1.0 (Copyright © 2017 Joel Rennich).
*/

import Foundation

class Preferences {
    
    // New Hotness -Johan
    // very awesome thanks
    
    let version = "1.0.0"
    static let kDefaultsMech = "defaultMechs"
    static let kDefaultMechs1014And15 = "defaultMechs10-14And10-15"
    static let kDefaultMechs1013 = "defaultMechs10-13"
    let Apply = [
        "impactedEntries": ["system.login.console"],
        "frontMechs": [],
        "endMechs": [],
        "notifyMech": []
    ]
    
    let Reset = [
        "impactedEntries": ["system.login.console"],
        kDefaultsMech : ["builtin:policy-banner", "builtin:prelogin", "loginwindow:login", "builtin:login-begin", "builtin:reset-password,privileged", "loginwindow:FDESupport,privileged", "builtin:forward-login,privileged", "builtin:auto-login,privileged", "builtin:authenticate,privileged", "PKINITMechanism:auth,privileged", "builtin:login-success", "loginwindow:success", "HomeDirMechanism:login,privileged", "HomeDirMechanism:status", "MCXMechanism:login", "CryptoTokenKit:login", "loginwindow:done"],
        kDefaultMechs1014And15 : ["builtin:policy-banner", "loginwindow:login", "builtin:login-begin", "builtin:reset-password,privileged", "loginwindow:FDESupport,privileged", "builtin:forward-login,privileged", "builtin:auto-login,privileged", "builtin:authenticate,privileged", "PKINITMechanism:auth,privileged", "builtin:login-success", "loginwindow:success", "HomeDirMechanism:login,privileged", "HomeDirMechanism:status", "MCXMechanism:login", "CryptoTokenKit:login", "loginwindow:done"],
        kDefaultMechs1013 : ["builtin:policy-banner", "loginwindow:login", "builtin:login-begin", "builtin:reset-password,privileged", "builtin:forward-login,privileged", "builtin:auto-login,privileged", "builtin:authenticate,privileged", "PKINITMechanism:auth,privileged", "builtin:login-success", "loginwindow:success", "loginwindow:FDESupport,privileged", "HomeDirMechanism:login,privileged", "HomeDirMechanism:status", "MCXMechanism:login", "CryptoTokenKit:login", "loginwindow:done"]
    ]
    
    func show_main_help() {
        let help = """
        mkauth v\(self.version)
        based on authchanger v2.1.0

        mkauth is a utility to help you manage the authorization database used by macOS to determine how the login process progresses.
        
        Usage:
            mkauth <command> [options]
            mkauth help <command>
            mkauth <command> --help

        Commands:
            help                  show this help message
            --version             print version
            --reset               reset authdb to default

            --apply                   apply a custom login mechanism
            	--create-privileged   add auxiliary privileged mechanisms
            	--prelogin            set pre-login mechanisms
            	--preauth             set pre-authentication mechanisms
            	--postauth            set post-authentication mechanisms

            --print               print current authorization mechanisms
            --debug               dry run of changes showing what would've happened
            --customrule          manage custom authorization rules
        """
        print(help)
    }
    
    func show_command_help(_ command: String) {
        let cmd = command.lowercased().replacingOccurrences(of: "-", with: "")
        
        switch cmd {
        case "reset":
            print("""
            mkauth --reset
            
            Usage: mkauth --reset [--debug]
            
            Reset authdb to default.
            
            Options:
                --debug    Dry run without making changes
            
            Examples:
                mkauth --reset
                mkauth --reset --debug
            """)
            
        case "apply":
            print("""
            mkauth --apply [mechanism]
            
            Usage: mkauth --apply [<mechanism>] [--debug] [--prelogin <mechs>] [--preauth <mechs>] [--postauth <mechs>] [--create-privileged]
            
            Apply given login mechanism
            
            Options:
                --debug              Dry run without making changes
                --create-privileged  Add auxiliary privileged mechanisms for login
                --prelogin <mechs>   Mechanisms before UI is shown
                --preauth <mechs>    Mechanisms between UI and authentication
                --postauth <mechs>   Mechanisms after authentication
            
            Examples:
                mkauth --apply
                mkauth --apply "customlogin:login"
                mkauth --apply "customlogin:login" --create-privileged
                mkauth --apply "customlogin:login" --prelogin CustomMechanism:Something
            """)
            
        case "print":
            print("""
            mkauth --print
            
            Usage: mkauth --print
            
            Prints the current authorization mechanisms for system.login.console
            
            Example:
                mkauth --print
            """)
            
        case "debug":
            print("""
            mkauth --debug
            
            Usage: mkauth --debug <command>
            
            Performs a dry run of the specified command without making changes.
            
            Examples:
                mkauth --debug --reset
                mkauth --debug --apply --prelogin CustomMechanism:Something
            """)
            
        case "customrule":
            print("""
            mkauth --customrule
            
            Usage:
                mkauth --customrule <rule> print
                mkauth --customrule <rule> mechanisms <mechs...> [--debug]
                mkauth --customrule <rule> rules <rule-name> [--debug]
            
            Manages custom authorization rules.
            """)
            
        case "prelogin":
            print("""
            mkauth --prelogin
            
            Usage: mkauth --prelogin <mechanisms...> [--debug]
            
            Sets mechanisms to be used before the UI is shown.
            
            Examples:
                mkauth --prelogin CustomMechanism:Something
                mkauth --prelogin "CustomAuth:Check" --debug
            """)
            
        case "preauth":
            print("""
            mkauth --preauth
            
            Usage: mkauth --preauth <mechanisms...> [--debug]
            
            Sets mechanisms to be used between login UI and authentication.
            
            Examples:
                mkauth --preauth CustomAuth:Check
                mkauth --preauth "CustomAuth:Check" --debug
            """)
            
        case "postauth":
            print("""
            mkauth --postauth
            
            Usage: mkauth --postauth <mechanisms...> [--debug]
            
            Sets mechanisms to be used after authentication.
            
            Examples:
                mkauth --postauth PostLogin:Setup
                mkauth --postauth "PostLogin:Setup" --debug
            """)
            
        default:
            print("Unknown command: \(command)\n")
            print("Run 'mkauth help' for help")
        }
    }
}