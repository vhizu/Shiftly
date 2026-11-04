# Shiftly 1.0 — iOS prototype

Native SwiftUI iPhone app: manual work/break timers, configurable break budget, eight-day shift calendar, manually added 12-hour overtime with collision checking, and local history.

## Build from iPhone via GitHub Actions
1. Create a GitHub repository and upload all files, including `.github/workflows/build.yml`.
2. In Actions, run **Build Shiftly IPA** (or push to `main`).
3. Download artifact **Shiftly-unsigned-IPA**; unzip to get `Shiftly-unsigned.ipa`.
4. Sign the unsigned IPA using your own valid certificate in GBox and install it.

No signing certificates are stored in GitHub. The IPA is intentionally unsigned. Bundle ID `com.shiftly.app` is a placeholder; change in `project.yml` if needed for your signing setup.

## Known limitations
- Not yet built or verified on Xcode/macOS in this environment. First GitHub Actions build is the validation step.
- Calendar covers only the user's confirmed purple eight-day cycle (Nov 4, 2026 = first night). Other color phases require confirmation.
- Overtime checks direct overlaps with scheduled shifts and other overtime; it does not yet validate uninterrupted 42-hour rest or back-to-back fatigue rules.
- No Dynamic Island, notifications, widget, salary, leave, notes, reports, or backups yet.
- Timekeeping uses saved timestamps, so elapsed times survive backgrounding. Force quit/OS termination does not automatically close active sessions.
- Local UserDefaults storage is a prototype solution; data may be lost on uninstall.
