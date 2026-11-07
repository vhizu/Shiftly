# Shiftly 1.11.3 — custom shift schedules

* User-defined repeating day/night/off cycle anchored to a chosen date.
* One-off date changes including vacation and sick leave, without overwriting shift history.
* Extra shifts are kept separate, and overlapping schedule edits are refused.
* Same schedule source drives calendar, automatic shift creation, reminders, next shift and earnings forecast.
* Lock-screen activity aligns total remaining time beneath its label on the right.

Data lives locally. Export your JSON backup before installing a new IPA.

The full XcodeGen project is under `Shiftly`, `Shared`, `ShiftlyLive`, and `ShiftlyHomeWidget`.
GitHub Actions uses `.github/workflows/build.yml`; `Workflow/build.yml` is a visible copy for iOS Files.
