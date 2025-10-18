# AirPodsRouter

Modern macOS menu bar utility that **auto-routes audio** when Bluetooth headphones (e.g., **AirPods**) connect:

* **Output:** your headphones
* **Input:** **MacBook built-in microphone** (to avoid the quality drop/glitches that happen when the AirPods mic steals the input)
* **Auto-stabilizes** input for a few seconds after connect to prevent HFP flip-backs
* **Optional manual override:** quickly pick another input from the app popover
* **Auto-hide menu icon** when no Bluetooth audio output is connected

> Requires **macOS 15+** (Sequoia/Tahoe), Apple Silicon or Intel.

---

## Why this exists (the problem)

When AirPods (or many BT headsets) connect to macOS, the system may:

* switch **both** output and input to the headset,
* negotiate a telephony profile (HFP), and
* **downgrade output quality** or cause app glitches.

If you actually want **high-quality output** but **Mac’s built-in mic** for input, you end up clicking around in **System Settings → Sound** every time.

BASICALLY as airpods sanity said it:
>You ever wondered, why the audio quality of your beloved AirPods can get as bad as talking to people over some wire that was built during the Apollo missions took place in the 60s? Ask no further, you came to the right place!



---

## What it does (the solution)

AirPodsRouter watches for Bluetooth audio outputs. When one connects:

1. Sets **Default Output** → the headphones
2. Sets **System Output (alerts)** → the headphones
3. Sets **Default Input** → **built-in microphone**
4. **Reasserts** the input briefly (~4 s) to defeat late HFP flips
5. Hides the menu icon when no BT audio device is present

You can still change the input manually from the app popover; manual choice is respected.

---

## Install (from Releases DMG)

1. Download the latest **`AirPodsRouter.dmg`** from the GitHub **Releases** page.
2. Open the DMG → **drag `AirPodsRouter.app` into Applications**.
3. First launch (because this build isn’t notarized):

   * **Recommended:** Control-click `AirPodsRouter.app` → **Open** → **Open**
     (This whitelists the app; future launches are normal.)
   * Or: double-click the app → macOS will block →
     **System Settings → Privacy & Security → “Open Anyway”** → Open.
   * Terminal (advanced):

     ```bash
     xattr -d com.apple.quarantine "/Applications/AirPodsRouter.app"
     ```
4. When asked, allow **Microphone** access (we don’t record audio; the permission is required to control/route input devices).
5. Connect your AirPods. You should see:

   * Output → **AirPods**
   * Input → **MacBook Microphone**
   * Status in the menu bar popover (shows “Stabilizing…” for a few seconds).

> Tip: In the app menu, enable **Launch at Login** if you want it always available.

---

## Uninstall

1. Quit the app from its menu.
2. Delete `/Applications/AirPodsRouter.app`.
3. Optional cleanup of caches/builds (if you built locally):

   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/AirPodsRouter-*
   ```

---

## Usage notes

* The menu icon **auto-hides** when no Bluetooth audio output is present; it reappears when headphones connect.
* Manual input selection in the popover **overrides** the auto-routing until you pick the built-in mic again.
* Works with **any Bluetooth headphones**, not just AirPods.

---

## Troubleshooting

### I see multiple copies in Spotlight

You might have build artifacts or a DMG-staged copy. List all bundles:

```bash
mdfind "kMDItemKind == 'Application' && kMDItemFSName == 'AirPodsRouter.app'"
```

You only need the one in `/Applications`.

### Confirm how many instances are running

```bash
pgrep -lf AirPodsRouter
```

(Should print a single line with the app path.) Kill extras if needed:

```bash
pkill -f AirPodsRouter
```

### Force the desired input again

Open the app popover → choose **MacBook Microphone** (or your preferred input).
The stabilizer will hold it during connect flaps.

### Logs (helpful for debugging)

Open **Console.app**, filter by “AudioRouter”, or run:

```bash
log stream --style compact --predicate 'eventMessage CONTAINS "AudioRouter"'
```

---

## Privacy

* The app never sends audio or device data anywhere.
* Microphone permission is used only to **control** input routing at the OS level.

---

## Build from source (optional)

```bash
# Release build
xcodebuild -scheme AirPodsRouter -configuration Release \
  -destination "generic/platform=macOS" \
  -derivedDataPath build clean build

# Create a DMG (optional)
mkdir -p dist/AirPodsRouter
cp -R build/Build/Products/Release/AirPodsRouter.app dist/AirPodsRouter/
ln -s /Applications dist/AirPodsRouter/Applications
hdiutil create -volname "AirPods Router" \
  -srcfolder dist/AirPodsRouter -ov -format UDZO dist/AirPodsRouter.dmg
```

> Personal-team builds are fine for your own Mac and friends who will use **Open Anyway** once.
> For friction-free installs for everyone, sign + notarize with a **Developer ID** account.

---

## License

Idgaf u can abuse my code lmao

---

## Acknowledgements

* Core Audio HAL (public frameworks)
* Inspiration: the old “AirPodsSanity” idea—updated for modern macOS with a slick, glassy SwiftUI UI.

P.S Im too broke for an apple dev account if someone wants to idk help make this a proper dmg lmk