# Rooting the OnePlus Nord 3 5G (CPH2493) — OxygenOS 16

Guide to rooting the OnePlus Nord 3 5G with Magisk on OxygenOS 16.0.3.500 (EX01 global variant), MediaTek Dimensity 9000 (MT6983). Tested March 2026.

## Device

| Property | Value |
|----------|-------|
| Model | OnePlus Nord 3 5G (CPH2493) |
| Codename | vitamin |
| SoC | MediaTek Dimensity 9000 (mt6983) |
| Android | 16 (SDK 36) |
| OxygenOS | 16.0.3.500 |
| Partitions | A/B (dual slot) |

## Prerequisites

- ADB + fastboot on your computer
- USB data cable (not charge-only)
- Battery > 80%
- OEM unlocking enabled (Settings > Developer Options)
- USB debugging enabled

## 1. Try mtkclient First (Optional)

May allow rooting **without factory reset** by exploiting MediaTek BootROM. Won't work on most Dimensity 9000 revisions (BROM is patched), but worth a shot.

```bash
git clone --depth 1 https://github.com/bkerler/mtkclient.git
cd mtkclient && pip3 install .

# Power off phone, hold Vol Up + Vol Down, connect USB
sudo mtk r boot boot_backup.img
```

If it works, skip to step 4. If not, proceed below.

## 2. Backup Everything

Bootloader unlock **wipes all data**.

```bash
mkdir -p ~/phone-backup
adb pull /sdcard/DCIM/ ~/phone-backup/DCIM/
adb pull /sdcard/Pictures/ ~/phone-backup/Pictures/
adb pull /sdcard/Movies/ ~/phone-backup/Movies/
```

Also back up WhatsApp to Google Drive, verify 2FA cloud sync, and confirm Google account sync is on.

## 3. Get boot.img

OnePlus uses dynamic firmware URLs — no static downloads exist. Use **Oxygen Updater** from the Play Store.

1. Install Oxygen Updater, select your device
2. Settings > Advanced > download the **full** update package (**not incremental**)
3. Pull and extract:

```bash
adb pull /sdcard/<ota-file>.zip ~/phone-backup/ota-full.zip
unzip -o ~/phone-backup/ota-full.zip payload.bin

# Install and run payload-dumper-go (Go version — Python version doesn't work)
go install github.com/ssut/payload-dumper-go@latest
payload-dumper-go -partitions boot -o . payload.bin
```

Save a backup: `cp boot.img ~/phone-backup/stock_boot.img`

## 4. Unlock Bootloader

```bash
adb push boot.img /sdcard/boot.img
adb reboot bootloader
fastboot devices
fastboot flashing unlock
```

**You must confirm on the phone screen** — use volume keys to select "Unlock the bootloader", power to confirm. `fastboot` returns OKAY before you confirm, but the unlock hasn't happened yet.

After reset, the phone may stay in fastboot — run `fastboot reboot`.

Verify after setup:
```bash
adb shell getprop ro.boot.flash.locked    # Should be 0
```

## 5. Install and Patch with Magisk

```bash
curl -L -o /tmp/Magisk.apk $(curl -sL https://api.github.com/repos/topjohnwu/Magisk/releases/latest | grep -o 'https://.*Magisk-v[^"]*\.apk')
adb push ~/phone-backup/stock_boot.img /sdcard/boot.img
adb install /tmp/Magisk.apk
```

On the phone: Magisk > Install > "Select and Patch a File" > select boot.img

```bash
adb pull /sdcard/Download/magisk_patched-*.img /tmp/magisk_patched.img
adb reboot bootloader
fastboot flash boot /tmp/magisk_patched.img
fastboot reboot
```

Verify: `adb shell su -c id` → should show `uid=0(root)`

## 6. Post-Root

**Enable Zygisk** (for hiding root from banking apps):
```bash
adb shell "su -c 'magisk --sqlite \"REPLACE INTO settings(key,value) VALUES(\\\"zygisk\\\",1);\"'"
adb reboot
```

**Disable OTA updates** (they'll break root):
```bash
adb shell su -c "pm disable-user com.oplus.ota"
```

**Add banking apps to DenyList** (after installing them):
```bash
adb shell su -c "magisk --denylist add <package.name>"
```

## 7. Debloat

See [scripts/debloat.sh](scripts/debloat.sh) — removes ~80 ColorOS/HeyTap/Oplus bloatware packages. Safe and reversible.

```bash
./scripts/debloat.sh --dry-run   # Preview
./scripts/debloat.sh             # Execute
```

Note: The Nord 3 does **not** have an IR blaster — remove IR Hub if present.

## Updating OxygenOS Later

Don't use the built-in updater. Re-enable OTA if needed (`pm enable com.oplus.ota`), download full OTA via Oxygen Updater, extract and patch new boot.img, flash via fastboot.

## Rollback

```bash
fastboot flash boot ~/phone-backup/stock_boot.img   # Remove root
fastboot flashing lock                                # Re-lock (another factory reset)
```

## Lessons Learned

1. **mtkclient doesn't work on Dimensity 9000** — BROM exploit is patched
2. **No static firmware download links** — OnePlus uses time-limited URLs, use Oxygen Updater
3. **Download the FULL OTA, not incremental** — incremental uses BROTLI_BSDIFF which no tool extracts
4. **Python `payload_dumper` doesn't work** — use `payload-dumper-go` (Go version)
5. **`fastboot flashing unlock` returns OKAY before you confirm on screen** — always verify with `ro.boot.flash.locked`
6. **OnePlus uses `com.oplus.ota`, not `com.android.updater`**
7. **Custom ROM support is poor** — Dimensity 9000 closed-source blobs, LineageOS archived. Stick with stock + Magisk

## Author

Written by [Claude](https://claude.ai) (Anthropic) while assisting [Daniel Rosehill](https://danielrosehill.com), March 2026.

## License

Public domain. Use however you want.
