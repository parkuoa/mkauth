/*
    main.swift
    mkauth
  
    Copyright © 2026 parkuoa
    Derived from authchanger 2.1.0 (Copyright © 2017 Joel Rennich).
*/

import Foundation
import Security.AuthorizationDB

let preferences = Preferences()
let authdb = authorizationdb()

var err = OSStatus.init(0)

// New Hotness - Johan
// as always

// full arguments list as single string
let args = CommandLine.arguments
let stdArgs = args.map { $0.trimmingCharacters(in: .whitespaces).uppercased() }
let argString = stdArgs.joined(separator: " ")

func hasArg(_ arg: String) -> Bool {
    stdArgs.contains(arg.uppercased())
}

func argValue(_ arg: String) -> String? {
    let argArray = args.map { $0.uppercased() }
    guard let index = argArray.firstIndex(of: arg.uppercased()), index + 1 < args.count else {
        return nil
    }
    return args[index + 1]
}

// noarg / help / --help
let help_wanted = args.count == 1 || stdArgs.contains("HELP") || stdArgs.contains("--HELP")

if help_wanted {
    // check for "mkauth help [cmd]"
    if args.count >= 3 && args[1].lowercased() == "help" {
        preferences.show_command_help(args[2])
    }
    // "mkauth [cmd] --help" or "mkauth [cmd] help"
    else if args.count >= 3 && (stdArgs.contains("--HELP") || stdArgs.contains("HELP")) {
        preferences.show_command_help(args[1])
    }
    else {
        preferences.show_main_help()
    }
    exit(0)
}

// version / -version
if argString.contains("VERSION") {
    print("v" + preferences.version)
    exit(0)
}

extension Array where Element: Equatable {
    @discardableResult
    mutating func appendIfNotContains(_ element: Element) -> (appended: Bool, memberAfterAppend: Element) {
        if !contains(element) {
            append(element)
            return (true, element)
        }
        return (false, element)
    }
}

func getImpactedEntries(arguments: [String]) -> [String]{
    var impactedEntries: [String] = []
    for arg in arguments[1...] {
        
        switch(arg.uppercased()){
            
        // All of these parameters edit the same entry
        case "--APPLY",
             "--PRELOGIN",
             "--PREAUTH",
             "--POSTAUTH":
            let domains = preferences.Apply["impactedEntries"] ?? []
            for domain in domains {
                impactedEntries.appendIfNotContains(domain)
            }
        case "--RESET",
             "--PRINT":
            let domains = preferences.Reset["impactedEntries"] ?? []
            for domain in domains {
                impactedEntries.appendIfNotContains(domain)
            }
        case "--CUSTOMRULE":
            let argArrayCap = (CommandLine.arguments).map{$0.uppercased()}
            let argIndex = argArrayCap.firstIndex(of: "--CUSTOMRULE")
            if let argIndex = argIndex, argIndex + 1 < CommandLine.arguments.count {
                impactedEntries.appendIfNotContains((CommandLine.arguments)[argIndex + 1])
            }
        default:
            break
        }
    }
    return impactedEntries
}

/* we need to keep track of the mechs we add so we can safely and easily
manage them later */

// this variable stores the metadata prefix for our custom mechs
private let customMechPrefix = "external:"

func extMechIDComment(_ line: String) -> Bool {
    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.hasPrefix(customMechPrefix) {
        return true
    }
    let segments = trimmed.split(separator: "|")
    guard segments.count >= 2 else {
        return false
    }
    return segments.allSatisfy { segment in
        let part = segment.trimmingCharacters(in: .whitespacesAndNewlines)
        return part.contains(":") && !part.contains(" ")
    }
}

func parseManagedMechanisms(from comment: String?) -> [String] {
    guard let comment = comment else { return [] }
    for line in comment.split(separator: "\n") {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if extMechIDComment(trimmed) {
            let payload: Substring
            if trimmed.hasPrefix(customMechPrefix) {
                payload = trimmed.dropFirst(customMechPrefix.count)
            } else {
                payload = trimmed[trimmed.startIndex...]
            }
            return payload.split(separator: "|").map(String.init)
        }
    }
    return []
}

/* append ourselves as a comment */
func AddCustomIdentifier(existingComment: String?, managedMechs: [String]) -> String {
    let preservedLines = (existingComment ?? "").split(separator: "\n", omittingEmptySubsequences: false).map(String.init).filter { line in
        !extMechIDComment(line)
    }
    let baseComment = preservedLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    guard !managedMechs.isEmpty else {
        return baseComment
    }
    let metadataLine = customMechPrefix + managedMechs.joined(separator: "|")
    if baseComment.isEmpty {
        return metadataLine
    }
    return baseComment + "\n" + metadataLine
}

func defaultMechanismAddition(editingConfiguration: [String: [String: AnyObject]], mechDict: [String: [String]], notify: Bool = false) -> [String: [String: AnyObject]] {
        
    var tmpEditingConfiguration = editingConfiguration
    
    for impactedMech in (mechDict["impactedEntries"]! as [String]) {
        
        let tmpEditingConfigurationMech = editingConfiguration[impactedMech]
        var editingMech = tmpEditingConfigurationMech?["mechanisms"] as! [String]
        
        var increment = 1
        if #available(macOS 10.16, *) {
            increment = 2
        }
        
        /* now manage and get rid of our custom mechs */
        let previousManaged = parseManagedMechanisms(from: tmpEditingConfigurationMech?["comment"] as? String)
        
        editingMech.removeAll { mech in
            if mech == "loginwindow:login" {
                return true
            }
            return previousManaged.contains(mech)
        }
        
        // adding the front mechanisms in the preferred order
        // preferred: UI -> PowerControl -> CreateUser
        let frontMechs = mechDict["frontMechs"]! as [String]
        for (index, addingMech) in frontMechs.enumerated() {
            editingMech.insert(addingMech, at: increment + index)
        }
        
        // adding the notify mechanism if specified
        if notify {
            if let additionIndex = editingMech.firstIndex(of: "builtin:login-begin") {
                for addingMech in (mechDict["notifyMech"]! as [String]).reversed() {
                    if !editingMech.contains(addingMech) {
                        editingMech.insert(addingMech, at: additionIndex)
                    }
                }
            }
        }
        
        // appending the rear mechanisms
        for addingMech in mechDict["endMechs"]! {
            if !editingMech.contains(addingMech) {
                editingMech.append(addingMech)
            }
        }
        
        // rebuild the edited master authdb
        if var updatedEntry = tmpEditingConfigurationMech {
            updatedEntry["mechanisms"] = editingMech as AnyObject
            updatedEntry["comment"] = AddCustomIdentifier(existingComment: updatedEntry["comment"] as? String, managedMechs: frontMechs) as AnyObject
            tmpEditingConfiguration[impactedMech] = updatedEntry
        } else {
            tmpEditingConfiguration[impactedMech] = tmpEditingConfigurationMech
        }
    }
    return tmpEditingConfiguration
}

func authorizationDBPrettyPrint(authDBConfiguration: [String: [String: AnyObject]]){
    for authDBEntryKey in authDBConfiguration.keys {
        print("Entry: " + authDBEntryKey)
        let entryProperty = authDBConfiguration[authDBEntryKey]
        
        for EntryPropertyKey in (authDBConfiguration[authDBEntryKey]?.keys)! {
            
            if EntryPropertyKey == "mechanisms" || EntryPropertyKey == "rule"{
                let entryMechs = entryProperty?[EntryPropertyKey]
                print("   \(EntryPropertyKey):")
                for mechName in entryMechs as! [String]{
                    print("      \(mechName)")
                }
            } else if EntryPropertyKey == "comment", let comment = entryProperty?[EntryPropertyKey] as? String {
                let commentLines = comment.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
                if let first = commentLines.first {
                    print("   comment : \(first)")
                } else {
                    print("   comment :")
                }
                for line in commentLines.dropFirst() {
                    print("   \(line)")
                }
            } else {
                print("   " + EntryPropertyKey + " : \(entryProperty![EntryPropertyKey]!)")
            }
        }
        print()
    }
}

// Getting the current configuration of the machine for the preferences necessary
let currentConfiguration = authdb.getBatch(getArray: getImpactedEntries(arguments: CommandLine.arguments))

// Making a copy of the configuraiton to edit
var editingConfiguration = currentConfiguration as [String: [String: AnyObject]]

    if hasArg("--RESET") {
        let entryKey = ((preferences.Reset)["impactedEntries"]! as [String])[0]
        if var updatedEntry = editingConfiguration[entryKey] {
            if #available(macOS 10.16, *) {
                updatedEntry["mechanisms"] = (preferences.Reset)[Preferences.kDefaultsMech] as AnyObject
            } else {
                updatedEntry["mechanisms"] = (preferences.Reset)[Preferences.kDefaultMechs1014And15] as AnyObject
            }
            updatedEntry["comment"] = AddCustomIdentifier(existingComment: updatedEntry["comment"] as? String, managedMechs: []) as AnyObject
            editingConfiguration[entryKey] = updatedEntry
        }
    }

if hasArg("--APPLY") {
    let defaultFront = preferences.Apply["frontMechs"] ?? []
    let applyMechanism = argValue("--APPLY") ?? defaultFront.first
    guard let applyMechanism = applyMechanism, !applyMechanism.isEmpty else {
        print("failed: --apply missing mechanism string")
        exit(1)
    }
    var customMechDict = preferences.Apply
    customMechDict["frontMechs"] = [applyMechanism]

    if hasArg("--CREATE-PRIVILEGED") {
        /* use same prefix as mech to apply */
        let prefix = applyMechanism.split(separator: ":").first.map(String.init) ?? applyMechanism
        customMechDict["frontMechs"]!.append(contentsOf: ["\(prefix):PowerControl,privileged", "\(prefix):CreateUser,privileged"])
    }

    editingConfiguration = defaultMechanismAddition(editingConfiguration: editingConfiguration, mechDict: customMechDict, notify: false)
}

// getting all mechanisms from the parameters given in
// this code is dirty..... -Johan
var preLoginMechs:[String] = [], preAuthMechs:[String] = [], postAuthMechs:[String] = [], customRuleMechs:[String] = []
if hasArg("--PRELOGIN") || hasArg("--PREAUTH") || hasArg("--POSTAUTH") || hasArg("--CUSTOMRULE") {
    let argArrayCap = (CommandLine.arguments).map{$0.uppercased()}
    var i = 1
    while i < argArrayCap.count {
        if argArrayCap[i] == "--PRELOGIN" {
            i += 1
            if i >= argArrayCap.count{break}
            while !(argArrayCap[i]).hasPrefix("-"){
                preLoginMechs.append((CommandLine.arguments)[i])
                i += 1
                if i >= argArrayCap.count{break}
            }
            i -= 1
        }
        if argArrayCap[i] == "--PREAUTH" {
            i += 1
            if i >= argArrayCap.count{break}
            while !(argArrayCap[i]).hasPrefix("-"){
                preAuthMechs.append((CommandLine.arguments)[i])
                i += 1
                if i >= argArrayCap.count{break}
            }
            i -= 1
        }
        if argArrayCap[i] == "--POSTAUTH" {
            i += 1
            if i >= argArrayCap.count{break}
            while !(argArrayCap[i]).hasPrefix("-"){
                postAuthMechs.append((CommandLine.arguments)[i])
                i += 1
                if i >= argArrayCap.count{break}
            }
            i -= 1
        }
        if argArrayCap[i] == "--CUSTOMRULE" {
            i += 1
            if i >= argArrayCap.count{break}
            while !(argArrayCap[i]).hasPrefix("-"){
                customRuleMechs.append((CommandLine.arguments)[i])
                i += 1
                if i >= argArrayCap.count{break}
            }
            i -= 1
        }
        i += 1
    }
}

// reversing the pre and post mech lists for addition
preLoginMechs.reverse()
preAuthMechs.reverse()
postAuthMechs.reverse()


if hasArg("--PRELOGIN") {
    var tmpEditingConfigurationMech = editingConfiguration["system.login.console"]
    var editingMech = tmpEditingConfigurationMech?["mechanisms"] as! [String]
    for mech in preLoginMechs {
        editingMech.insert(mech, at: 1)
    }
    tmpEditingConfigurationMech?["mechanisms"] = editingMech as AnyObject
    editingConfiguration["system.login.console"] = tmpEditingConfigurationMech
}

if hasArg("--PREAUTH") {
    var tmpEditingConfigurationMech = editingConfiguration["system.login.console"]
    var editingMech = tmpEditingConfigurationMech?["mechanisms"] as! [String]
    let additionIndex = editingMech.firstIndex(of: "builtin:login-begin")!
    for mech in preAuthMechs {
        editingMech.insert(mech, at: additionIndex)
    }
    tmpEditingConfigurationMech?["mechanisms"] = editingMech as AnyObject
    editingConfiguration["system.login.console"] = tmpEditingConfigurationMech
}

if hasArg("--POSTAUTH") {
    var tmpEditingConfigurationMech = editingConfiguration["system.login.console"]
    var editingMech = tmpEditingConfigurationMech?["mechanisms"] as! [String]
    let additionIndex = editingMech.count
    for mech in postAuthMechs {
        editingMech.insert(mech, at: additionIndex)
    }
    tmpEditingConfigurationMech?["mechanisms"] = editingMech as AnyObject
    editingConfiguration["system.login.console"] = tmpEditingConfigurationMech
}

if hasArg("--CUSTOMRULE") {
    
    let customRuleName = customRuleMechs.remove(at: 0)
    var tmpEditingConfigurationMech = editingConfiguration[customRuleName]
    
    if hasArg("--PRINT") {
        authorizationDBPrettyPrint(authDBConfiguration: [customRuleName: (currentConfiguration[customRuleName] ?? nil)!])
        exit(0)
    } else if !hasArg("--DEBUG") {
        print("Previous Rule for reference:\n")
        authorizationDBPrettyPrint(authDBConfiguration: currentConfiguration)
    }
    if !(customRuleMechs.count >= 1) {
        print("More parameters necessary, please see -help documentation")
        exit(1)
    }
    let customKeyName = customRuleMechs.remove(at: 0)
    switch customKeyName {
    case "mechanisms":
        tmpEditingConfigurationMech?["mechanisms"] = customRuleMechs as AnyObject
        tmpEditingConfigurationMech?["class"] = "evaluate-mechanisms" as AnyObject
        tmpEditingConfigurationMech?["rule"] = nil
    case "rules":
        tmpEditingConfigurationMech?["rule"] = customRuleMechs as AnyObject
        tmpEditingConfigurationMech?["class"] = "rule" as AnyObject
        tmpEditingConfigurationMech?["mechanisms"] = nil
    default:
        break
    }
    
    editingConfiguration[customRuleName] = tmpEditingConfigurationMech
}


// print version and quit if asked
if hasArg("--PRINT") {
    authorizationDBPrettyPrint(authDBConfiguration: currentConfiguration)
    exit(0)
}

if hasArg("--DEBUG") {
    authorizationDBPrettyPrint(authDBConfiguration: editingConfiguration)
    exit(0)
} else {
    // writing everything back
    authdb.setBatch(setArray: editingConfiguration)
}
