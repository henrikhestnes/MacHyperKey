# MacHyperKey

Turns caps lock, or another key you choose, into a **hyper key**: ⌃⌥⌘ pressed at once, for shortcuts no app uses by default. Swift and AppKit, with no dependencies. Requires macOS 14 or newer.

## Install

```sh
brew install --cask henrikhestnes/tap/machyperkey
```

Update with `brew update` and `brew upgrade --cask machyperkey`. You can also download `MacHyperKey.zip` from the [latest release](https://github.com/henrikhestnes/MacHyperKey/releases/latest) and move **MacHyperKey.app** to **Applications**. The release is signed with a self-signed certificate and not notarized by Apple, so macOS may block it through Gatekeeper.

To build from source instead:

```sh
./scripts/build.sh
cp -R dist.noindex/MacHyperKey.app /Applications/
open /Applications/MacHyperKey.app
```

`./scripts/build.sh --universal` builds for both Apple silicon and Intel.

On first launch, macOS asks for **Accessibility** access, which MacHyperKey needs to add the hyper modifiers to key and mouse events. Enable it in **System Settings → Privacy & Security → Accessibility**. MacHyperKey picks the permission up within two seconds, without a relaunch. Until then the key keeps working as before.

Quit other key remappers that use the same key (such as Hyperkey or Karabiner-Elements rules for caps lock) before using MacHyperKey.

Releases are signed with the same self-signed "MacSnip Release" certificate as MacSnip and MacMiddleClick, so the permission carries over to upgrades. Every build uses the hardened runtime, which stops other processes from injecting code into an app that holds this permission. Builds from source are ad-hoc signed unless that certificate is in your keychain, and macOS treats every ad-hoc rebuild as a new app and silently stops honoring the permission. After rebuilding, remove MacHyperKey from that list (−), add it again, and relaunch.

## Settings

Open MacHyperKey from Finder or Spotlight, or choose **Settings…** from its menu bar icon.

| Setting | Effect |
| --- | --- |
| **Remap physical key to hyper key** | The key that becomes hyper: caps lock, a left or right modifier, tab, `` ` ``, §, esc, or F13–F19 |
| **Remap caps lock to** | When caps lock is not the hyper key, make it esc, delete, tab, return, a modifier, or F13–F19 |
| **Quick press … to execute** | Tapping the hyper key alone (under 0.5 seconds, nothing else pressed) types a key instead. Choose caps lock to keep a way to toggle caps lock |
| **Include shift in hyper key** | Hyper becomes ⌃⌥⇧⌘ |
| **Click, Drag, Move, Scroll** | Also add the hyper modifiers to those mouse events, for hyper-click or hyper-scroll shortcuts in apps and window managers |
| **Open on login** | Start with your Mac. Turned on the first time MacHyperKey runs; it won't turn it back on |
| **Hide menu bar icon** | Run without an icon. Open MacHyperKey again from Finder to show its settings |

## How it works

- The physical key is remapped to F20 with the same `UserKeyMapping` HID property that `hidutil` sets. This happens below the keyboard driver's caps lock handling, so caps lock no longer toggles and has no activation delay. Other `UserKeyMapping` entries are kept.
- A Quartz event tap turns F20 into the hyper key. While it is held, every key event (and the mouse events you choose) gets ⌃⌥⌘ added, and MacHyperKey posts modifier key events when it goes down and up so apps that watch modifier changes see it too.
- The mapping lasts until restart, so MacHyperKey removes it when it quits, including on `kill`. If it crashes, launch it again or restart to get the key back.
- If caps lock is remapped while it is on, MacHyperKey turns it off, since the key can no longer do that (unless quick press is set to caps lock).

The settings and hyper logic live in `MacHyperKeyCore`, which is unit tested.

## Development

```sh
swift build
swift test
```
