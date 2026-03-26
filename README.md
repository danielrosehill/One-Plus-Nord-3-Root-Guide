# Rooting the OnePlus Nord 3 5G (CPH2493) on OxygenOS 16

A step-by-step guide to rooting the OnePlus Nord 3 5G with Magisk, tested on OxygenOS 16.0.3.500 (EX01 global variant) with the MediaTek Dimensity 9000 (MT6983).

Written March 2026. If you're reading this much later, some details may have changed.

## Device Details

| Property | Value |
|----------|-------|
| Model | OnePlus Nord 3 5G (CPH2493) |
| Codename | vitamin |
| SoC | MediaTek Dimensity 9000 (mt6983) |
| Android | 16 (SDK 36) |
| OxygenOS | 16.0.3.500 |
| Kernel | 5.10.236-android12-9 |
| Partitions | A/B (dual slot) |

## Overview

The recommended path is **Magisk systemless root on stock OxygenOS**. This keeps the OS intact and just patches the boot image.

**What you get with root:**
- Full bloatware removal (not just user-level uninstall)
- Call recording via Magisk modules (BCR, Oplus Call Recorder)
- System-wide audio routing (ViPER4Android)
- Magisk module ecosystem
- Full system access

**What it costs:**
- One factory reset (bootloader unlock requirement)
- Orange "unlocked" warning at boot (cosmetic only)
- Need to re-patch boot after OTA updates (manual process)

## Table of Contents

1. [mtkclient — Worth Trying First](#1-mtkclient--worth-trying-first)
2. [Prerequisites](#2-prerequisites)
3. [Backup](#3-backup)
4. [Getting boot.img](#4-getting-bootimg)
5. [Unlocking the Bootloader](#5-unlocking-the-bootloader)
6. [Patching and Flashing with Magisk](#6-patching-and-flashing-with-magisk)
7. [Post-Root Setup](#7-post-root-setup)
8. [ADB Debloat](#8-adb-debloat)
9. [Keeping Root Safe](#9-keeping-root-safe)
10. [Updating OxygenOS Without Losing Root](#10-updating-oxygenos-without-losing-root)
11. [Rollback](#11-rollback)
12. [Lessons Learned](#12-lessons-learned)

---

## 1. mtkclient — Worth Trying First

[mtkclient](https://github.com/bkerler/mtkclient) exploits MediaTek BootROM vulnerabilities to read/write partitions without unlocking the bootloader. If it works, you can root **without a factory reset**.

```bash
# Install from source (not on PyPI)
git clone --depth 1 https://github.com/bkerler/mtkclient.git
cd mtkclient && pip3 install .

# Power off phone completely
# Hold Volume Up + Volume Down simultaneously
# While holding both buttons, connect USB cable
# If BROM mode is detected:
sudo mtk r boot boot_backup.img
```

**On our device (Dimensity 9000 / MT6983), this did not work.** The phone never entered BROM mode — the exploit is patched on this SoC revision. This is expected for newer MediaTek chips. No harm done.

If mtkclient works for you, you can skip the bootloader unlock and jump straight to [patching with Magisk](#6-patching-and-flashing-with-magisk).

---

## 2. Prerequisites

- ADB and fastboot installed on your computer
- A reliable USB data cable (not charge-only)
- Battery above 80%
- OEM unlocking enabled: **Settings > Developer Options > OEM unlocking**
- USB debugging enabled: **Settings > Developer Options > USB debugging**
- A few hours of uninterrupted time

Verify ADB works:
```bash
adb devices
# Should show your device serial
```

---

## 3. Backup

**Bootloader unlock wipes everything.** Back up before proceeding.

```bash
# Create backup directory
mkdir -p ~/phone-backup

# Pull media
adb pull /sdcard/DCIM/ ~/phone-backup/DCIM/
adb pull /sdcard/Pictures/ ~/phone-backup/Pictures/
adb pull /sdcard/Movies/ ~/phone-backup/Movies/

# Save system settings for reference
adb shell settings list system > ~/phone-backup/settings-system.txt
adb shell settings list secure > ~/phone-backup/settings-secure.txt
adb shell settings list global > ~/phone-backup/settings-global.txt
```

Also:
- **WhatsApp**: Back up to Google Drive (Settings > Chats > Chat backup)
- **2FA apps**: Ensure cloud backup is enabled
- **Google account sync**: Verify it's on (contacts, calendars, Chrome data will auto-restore)

Most Play Store apps (typically 90%+) auto-restore when you sign into the same Google account after reset.

---

## 4. Getting boot.img

You need the stock `boot.img` for your exact OxygenOS build to patch with Magisk.

### The problem

OnePlus now uses **dynamic, time-limited download URLs** for firmware. There are no static download links for OxygenOS 16 firmware. The old XDA OTA repos have been taken down. Firmware archive sites don't have OxygenOS 16 for the Nord 3 yet.

### What works: Oxygen Updater

1. Install **[Oxygen Updater](https://play.google.com/store/apps/details?id=com.arjanvlek.oxygenupdater)** from the Play Store
2. Select your device (OnePlus Nord 3 / Global)
3. Go to **Settings > Advanced** and look for the option to download the **full update package**
4. Download it

**IMPORTANT: Make sure you get the FULL OTA, not an incremental one.** Incremental OTAs only contain diffs and you cannot extract boot.img from them.

### Extracting boot.img

Pull the OTA to your computer:
```bash
adb pull /sdcard/<ota-filename>.zip ~/phone-backup/ota-full.zip
```

Extract `payload.bin`:
```bash
unzip -o ~/phone-backup/ota-full.zip payload.bin
```

Extract `boot.img` using **payload-dumper-go** (the Go version):
```bash
# Install
go install github.com/ssut/payload-dumper-go@latest

# Extract just the boot partition
payload-dumper-go -partitions boot -o . payload.bin
```

Result: `boot.img` (should be ~64 MB for this device).

### Tool compatibility

| Tool | Full OTA? | Incremental OTA? |
|------|-----------|------------------|
| **payload-dumper-go** (Go) | **Works** | No — "Unhandled operation type: BROTLI_BSDIFF" |
| **payload_dumper** (Python, v0.3.0) | No — "Unsupported type = 10" | No |

The Python `payload_dumper` does not work for OxygenOS 16 OTAs at all. Use the Go version.

### Save a backup copy

```bash
cp boot.img ~/phone-backup/stock_boot.img
```

You'll need this if you ever want to unroot or if something goes wrong.

---

## 5. Unlocking the Bootloader

Push the boot.img to the phone (you'll need it after the reset):
```bash
adb push boot.img /sdcard/boot.img
```

**This wipes all data. Make sure your backups are complete.**

```bash
adb reboot bootloader
# Wait for FASTBOOT MODE screen

fastboot devices
# Verify device is detected

fastboot flashing unlock
```

### Important gotcha

`fastboot flashing unlock` may return `OKAY` immediately, but **the bootloader is not actually unlocked yet**. You must **confirm on the phone screen**:

1. Use **Volume keys** to highlight "Unlock the bootloader"
2. Press **Power** to confirm
3. Phone will factory reset and reboot

After the reset, the phone may stay on the FASTBOOT MODE screen. If so:
```bash
fastboot reboot
```

### Verifying the unlock

After the phone boots and you complete minimal setup (re-enable Developer Options + USB debugging):

```bash
adb shell getprop ro.boot.flash.locked
# Should return: 0

adb shell getprop ro.boot.verifiedbootstate
# Should return: orange
```

If `flash.locked` is still `1`, the on-screen confirmation didn't happen. Try again.

---

## 6. Patching and Flashing with Magisk

### Install Magisk

Download the latest Magisk APK and install it:
```bash
# Find latest release URL
curl -sL https://api.github.com/repos/topjohnwu/Magisk/releases/latest | grep "browser_download_url.*Magisk-v.*\.apk"

# Download and install
curl -L -o /tmp/Magisk.apk <url-from-above>
adb install /tmp/Magisk.apk
```

If boot.img was wiped by the factory reset, push it again:
```bash
adb push ~/phone-backup/stock_boot.img /sdcard/boot.img
```

### Patch boot.img

1. Open **Magisk** app on the phone
2. Tap **Install** (next to "Magisk" at the top)
3. Select **"Select and Patch a File"**
4. Navigate to internal storage, select **boot.img**
5. Wait for "All done!"

### Flash the patched boot

```bash
# Pull the patched image
adb pull /sdcard/Download/magisk_patched-*.img /tmp/magisk_patched.img

# Flash it
adb reboot bootloader
fastboot flash boot /tmp/magisk_patched.img
fastboot reboot
```

### Verify root

```bash
adb shell su -c id
# Should show: uid=0(root) gid=0(root) groups=0(root) context=u:r:magisk:s0
```

---

## 7. Post-Root Setup

### Enable Zygisk

Zygisk is needed for DenyList (hiding root from banking apps):

```bash
adb shell "su -c 'magisk --sqlite \"REPLACE INTO settings(key,value) VALUES(\\\"zygisk\\\",1);\"'"
adb reboot
```

Or: Magisk app > Settings > Enable Zygisk > Reboot.

### Configure DenyList

Add banking/payment apps that detect root. Apps must be installed first.

```bash
adb shell su -c "magisk --denylist add <package.name>"
```

Or: Magisk app > Settings > Configure DenyList > search and toggle.

---

## 8. ADB Debloat

The OnePlus Nord 3 comes with 100+ OEM bloatware packages (ColorOS, HeyTap, Oplus telemetry). You can remove most of them without root using ADB:

```bash
adb shell pm uninstall -k --user 0 <package.name>
```

This is **safe and reversible** — it only removes the app for the current user, keeps the APK on the system partition. Reverse with:
```bash
adb shell pm install-existing <package.name>
```

See [debloat.sh](scripts/debloat.sh) for a ready-to-run script targeting 89 known bloatware packages. Run with `--dry-run` first to preview.

**Note:** If you did a factory reset for bootloader unlock, you'll need to run the debloat again — the reset restores all bloatware.

### What NOT to remove

The debloat script already excludes these, but for reference — do not remove:
- Phone dialer, SMS, contacts
- Camera app
- Settings, System UI
- NFC / Bluetooth / WiFi core services
- Google Play Services / framework
- Fingerprint service
- Battery/power management

### Packages that resist removal

About 9-10 packages are system-protected and can't be removed even with `pm uninstall --user 0`. With root, you could force-remove them, but they're mostly harmless background services.

---

## 9. Keeping Root Safe

### What breaks root

| Threat | Prevention |
|--------|------------|
| Auto OTA updates | Disable `com.oplus.ota`: `adb shell su -c "pm disable-user com.oplus.ota"` |
| Manual OTA via Settings | Don't tap "Install" on update notifications |
| Factory reset | Would need to re-flash patched boot |

### What does NOT break root

- Installing/updating apps from Play Store
- Signing into OnePlus/Google accounts
- Installing Magisk modules
- Normal reboots
- Any phone settings changes

### Re-enabling OTA when you want it

```bash
adb shell su -c "pm enable com.oplus.ota"
```

---

## 10. Updating OxygenOS Without Losing Root

Don't use the built-in updater. Manual process:

1. Re-enable OTA service if needed
2. Download **full** OTA via Oxygen Updater (not incremental!)
3. Extract new `boot.img` with `payload-dumper-go`
4. Patch with Magisk app
5. Flash patched boot via fastboot
6. Reboot — updated and still rooted

**Alternative**: Use Magisk's "Install to Inactive Slot (After OTA)" feature:
1. Let the OTA download and install normally (writes to inactive slot)
2. **Before rebooting**, open Magisk > Install > "Install to Inactive Slot (After OTA)"
3. Reboot — both update and root applied

---

## 11. Rollback

### Remove root (keep unlocked bootloader)
```bash
fastboot flash boot ~/phone-backup/stock_boot.img
fastboot reboot
```

### Re-lock bootloader (triggers another factory reset)
```bash
fastboot flashing lock
```

### Module causing bootloop
- Boot into safe mode (hold Vol Down during boot after logo)
- Magisk auto-disables modules in safe mode
- Remove the bad module, reboot normally

---

## 12. Lessons Learned

Things we discovered that aren't well-documented elsewhere:

1. **mtkclient doesn't work on the Dimensity 9000 (MT6983)** — BROM exploit is patched on current revisions. Don't waste time on it.

2. **OnePlus firmware has no static download links** — they use dynamic, time-limited URLs. Oxygen Updater app is the only reliable way to get OTA packages.

3. **Always download the FULL OTA, not incremental** — Oxygen Updater defaults to incremental. Incremental OTAs use BROTLI_BSDIFF compression that no extraction tool currently handles.

4. **The Python `payload_dumper` doesn't work for OxygenOS 16** — it fails with "Unsupported type = 10". Use `payload-dumper-go` (the Go version) instead.

5. **`fastboot flashing unlock` lies** — it returns OKAY even before you confirm on the phone screen. Always verify with `adb shell getprop ro.boot.flash.locked` after reboot.

6. **OnePlus uses `com.oplus.ota` for updates, not `com.android.updater`** — the standard Android updater package doesn't exist on this device.

7. **Custom ROM support is poor for this device** — Dimensity 9000 has closed-source MediaTek blobs. LineageOS was archived. Stick with stock OxygenOS + Magisk.

---

## Resources

- [XDA: Root Nord 3 with Magisk without TWRP](https://xdaforums.com/t/guide-root-magisk-how-to-root-ace-2v-nord-3-with-magisk-without-twrp.4612209/)
- [XDA: OnePlus Nord 3 OTA Repo](https://xdaforums.com/t/oneplus-nord-3-rom-ota-oxygen-os-repo-of-oxygen-os-otas-and-rollback-packages.4680532/)
- [XDA: OnePlus Nord 3 / Ace 2V Forum](https://xdaforums.com/f/oneplus-nord-3-ace-2v.12781/)
- [Magisk GitHub](https://github.com/topjohnwu/Magisk)
- [mtkclient GitHub](https://github.com/bkerler/mtkclient)
- [payload-dumper-go GitHub](https://github.com/ssut/payload-dumper-go)
- [Oxygen Updater](https://oxygenupdater.com/)

## Author

Written by [Daniel Rosehill](https://danielrosehill.com) with the assistance of Claude (Anthropic), March 2026.

## License

This guide is public domain. Use it however you want.
