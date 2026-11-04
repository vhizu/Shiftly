# Shiftly 1.4.1 — build candidate

- Updated lock screen Live Activity layout: no large square image placeholder, compact avatar icon and prominent return-to-work action.
- Dynamic Island expanded timer uses remaining minutes instead of a long hh:mm:ss string.
- Fixed home widget Info.plist bundle identifier.
- Updated main screen break/shift status copy and ring branding.
- GitHub Actions validates version, both extension bundle IDs and compiled Live Activity assets before uploading IPA.

**Important:** Xcode is unavailable in this environment. Build and on-device behavior have NOT been verified. Run GitHub Actions and check the actual signed IPA on iPhone. App Group capabilities may require signing entitlements from GBox. Keep the installed version and back up history until testing is complete.
