<h1 align="center">
  <br>
  <a href="https://github.com/naomisphere/bengal"><img src="https://github.com/user-attachments/assets/5c678d35-43af-4e3b-8395-34f5bd5afb58" alt="bengal" width="150"></a>
  <br>
  bengal
  <br>
</h1>

<p align="center">
  <a href="./LICENSE">
    <img src="https://img.shields.io/badge/License-MIT-red.svg?logo=swift" alt="license" />
  </a>
</p>

**bengal** is a utility for tinkering with macOS's system authorization database. It allows you to modify the `system.login.console` right and its mechanisms (plugins, MFA, or directory services) that execute during the login process.

 It is intended for general use and developer freedom, allowing you to customize login behavior and inject your own logic without being locked into specific third-party frameworks or vendor-specific deployment screens.

## What it does
Put simple: your own login process, from scratch. Feed your own login flow, and your own UI.
You may add your own logic before the UI, during auth, or after the user logs in.

**bengal** includes an **Authentication Plugin** bundled within (```AuthorizationBundle/```), alongside the user interface of the login screen itself (```AuthorizationBundle/Sources/LoginUI.swift```). ***(login screen UI customization requires using the app for now)***

You may use this tool using the CLI or the [wrapper app](https://github.com/naomisphere/bengal/releases/latest). Prebuilts can be found in the [Releases](https://github.com/naomisphere/bengal/releases/latest) tab.

## Building
```bash
% make help

make <target>

targets:
  all: build cli, plugin and app
  cli: build cli
  plugin: build plugin/auth bundle
  app: build app
  clean: clean cli
  cleanplugin: clean plugin/auth bundle
  cleanapp: clean app
  cleanall: clean all
  help: Show this help message
  ```

## CLI Guide

Some commands require `sudo` as you're working with system databases here. \
You may always use ```bengal help``` for help.

### Basics
* `bengal -print`: show current mechanisms for `system.login.console`.
* `bengal -reset`: revert the login screen to default.
* `bengal -bengal`: apply bengal login UI.
* `bengal -version`: print version.

### Customizing the Flow
You can stack mechanisms at specific stages of the authentication chain:
* `-preLogin`: runs before the login UI appears.
* `-preAuth`: runs between the UI and the primary authentication check.
* `-postAuth`: runs after the system confirms the user's credentials.

**Examples:**
```bash
sudo bengal -bengal
```
^ apply login UI (```BengalLogin:UI```)
```bash
sudo bengal -bengal -preLogin CustomMech:Something -postAuth PostLogin:Setup
```
translates to:
```
Entry: system.login.console
   mechanisms:
      builtin:prelogin
      CustomMech:Something     <-- prelogin
      builtin:policy-banner
      BengalLogin:UI    <-- bengal (replacing loginwindow:login)
      builtin:login-begin
      builtin:reset-password,privileged
      loginwindow:FDESupport,privileged
      builtin:forward-login,privileged
      builtin:auto-login,privileged
      builtin:authenticate,privileged
      PKINITMechanism:auth,privileged
      builtin:login-success
      loginwindow:success
      HomeDirMechanism:login,privileged
      HomeDirMechanism:status
      MCXMechanism:login
      CryptoTokenKit:login
      loginwindow:done
      PostLogin:Setup   <-- postauth
   tries : 10000
   shared : 1
   comment : Login mechanism based rule.  Not for general use, yet.
   class : evaluate-mechanisms
   version : 11
```

## Acknowledgements
bengal's functionality is derived from [`authchanger`](https://github.com/jamf/authchanger) v2.1.0 ([MIT License](./LICENSE)), which set the base for this project.
