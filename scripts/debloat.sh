#!/bin/bash
# OnePlus Nord 3 (CPH2493) Debloat Script
# Removes OEM bloatware via ADB without root
# Safe to run before or after rooting
#
# Usage: ./debloat.sh [--dry-run]
#
# Uses "pm uninstall -k --user 0" which:
# - Removes the app for the current user only
# - Keeps the APK on system partition (reversible)
# - Does NOT require root
# - Can be reversed with: pm install-existing <package>

set -euo pipefail

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

# Verify ADB connection
if ! adb devices | grep -q "device$"; then
    echo "ERROR: No ADB device connected"
    exit 1
fi

# Safe-to-remove bloatware packages
# Excludes: camera, phone dialer, settings, system UI core, NFC core
BLOATWARE=(
    # ColorOS
    "com.coloros.accessibilityassistant"
    "com.coloros.activation"
    "com.coloros.assistantscreen"
    "com.coloros.bootreg"
    "com.coloros.childrenspace"
    "com.coloros.colordirectservice"
    "com.coloros.compass2"
    "com.coloros.floatassistant"
    "com.coloros.lockassistant"
    "com.coloros.ocrscanner"
    "com.coloros.ocs.opencapabilityservice"
    "com.coloros.operationManual"
    "com.coloros.scenemode"
    "com.coloros.smartsidebar"
    "com.coloros.systemclone"
    "com.coloros.translate.engine"
    "com.coloros.video"
    "com.coloros.weather.service"

    # HeyTap
    "com.heytap.accessory"
    "com.heytap.browser"
    "com.heytap.colorfulengine"
    "com.heytap.htms"
    "com.heytap.mcs"
    "com.heytap.mydevices"
    "com.heytap.pictorial"

    # Oplus - telemetry, analytics, bloat
    "com.oplus.aimemory"
    "com.oplus.aiunit"
    "com.oplus.aiwriter"
    "com.oplus.ambient.livealert"
    "com.oplus.appbooster"
    "com.oplus.appsense"
    "com.oplus.athena"
    "com.oplus.atlas"
    "com.oplus.beaconlink"
    "com.oplus.cast"
    "com.oplus.cell.map"
    "com.oplus.cellularqoe"
    "com.oplus.contentportal"
    "com.oplus.cosa"
    "com.oplus.cota"
    "com.oplus.crashbox"
    "com.oplus.deepthinker"
    "com.oplus.dfs"
    "com.oplus.dmp"
    "com.oplus.eid"
    "com.oplus.engineercamera"
    "com.oplus.games"
    "com.oplus.healthservice"
    "com.oplus.keyguard.clock.gallery"
    "com.oplus.keyguard.clock.graffiti"
    "com.oplus.keyguard.clock.magazine"
    "com.oplus.keyguard.personality.clocks"
    "com.oplus.keyguard.style.widgets"
    "com.oplus.linker"
    "com.oplus.melody"
    "com.oplus.metis"
    "com.oplus.multiapp"
    "com.oplus.nas"
    "com.oplus.ndsf"
    "com.oplus.nhs"
    "com.oplus.nwestimate"
    "com.oplus.obrain"
    "com.oplus.olc"
    "com.oplus.onetrace"
    "com.oplus.owkservice"
    "com.oplus.pantanal.ums"
    "com.oplus.plugin"
    "com.oplus.postmanservice"
    "com.oplus.pscanvas"
    # "com.oplus.qualityprotect"     # KEPT: system stability monitor — review before removing
    "com.oplus.riderMode"
    # "com.oplus.safecenter"          # KEPT: battery/storage optimizer UI — review before removing
    "com.oplus.sandbox.runtime"
    # "com.oplus.sau"                 # KEPT: system/app updater — needed for OTA notifications
    # "com.oplus.sauhelper"           # KEPT: system updater helper
    "com.oplus.securepay"
    "com.oplus.securityguard"
    "com.oplus.sense.netprediction"
    "com.oplus.sense.netscore"
    "com.oplus.smartengine"
    "com.oplus.statistics.rom"
    "com.oplus.stdid"
    "com.oplus.stdsp"
    "com.oplus.tai.borderpresearch"
    "com.oplus.tai.wifiqoe"
    "com.oplus.trafficmonitor"
    "com.oplus.upgradeguide"
    "com.oplus.uxdesign"
    "com.oplus.vdc"
    "com.oplus.virtualcomm"
    "com.oplus.virtualcomm2"
    # "com.oplus.wifibackuprestore"   # KEPT: WiFi password backup — useful for migration

    # Other OEM
    "com.nearme.instant.platform"
    "com.oppo.quicksearchbox"

    # Suggested additional removals — uncomment if present on your device
    # The Nord 3 does NOT have an IR blaster, so IR Hub is useless:
    # "com.oplus.irhub"
    # OnePlus Community forum app:
    # "com.oneplus.community"
    # HeyTap app store:
    # "com.heytap.market"
)

echo "OnePlus Nord 3 Debloat Script"
echo "=============================="
echo "Packages to remove: ${#BLOATWARE[@]}"
[[ "$DRY_RUN" == true ]] && echo "MODE: DRY RUN (no changes)"
echo ""

SUCCESS=0
FAILED=0
SKIPPED=0

for pkg in "${BLOATWARE[@]}"; do
    if $DRY_RUN; then
        echo "[DRY RUN] Would remove: $pkg"
        SUCCESS=$((SUCCESS + 1))
    else
        if adb shell pm uninstall -k --user 0 "$pkg" 2>/dev/null | grep -q "Success"; then
            echo "[OK] Removed: $pkg"
            SUCCESS=$((SUCCESS + 1))
        else
            # Check if package exists at all
            if adb shell pm list packages | grep -q "^package:${pkg}$"; then
                echo "[FAIL] Could not remove: $pkg"
                FAILED=$((FAILED + 1))
            else
                echo "[SKIP] Not installed: $pkg"
                SKIPPED=$((SKIPPED + 1))
            fi
        fi
    fi
done

echo ""
echo "Done. Removed: $SUCCESS | Failed: $FAILED | Skipped: $SKIPPED"
echo ""
echo "To reverse any removal:"
echo "  adb shell pm install-existing <package-name>"
