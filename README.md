# Shiftly 1.13.0 — payslip-accurate payroll and UI polish

* User-defined repeating day/night/off cycle anchored to a chosen date.
* One-off date changes including vacation and sick leave, without overwriting shift history.
* Extra shifts are kept separate, and overlapping schedule edits are refused.
* Same schedule source drives calendar, automatic shift creation, reminders, next shift and earnings forecast.
* Lock-screen activity aligns total remaining time beneath its label on the right.

Data lives locally. Export your JSON backup before installing a new IPA.

The full XcodeGen project is under `Shiftly`, `Shared`, `ShiftlyLive`, and `ShiftlyHomeWidget`.
GitHub Actions uses `.github/workflows/build.yml`; `Workflow/build.yml` is a visible copy for iOS Files.


## Shiftly 1.12.0
- Календарь: подработки в стеклянной карточке с предпросмотром и проверкой конфликтов; редактор цикла внизу.
- Зарплата: календарь заработка с пометками «факт» и «план», суммами по датам и защитой от двойного учёта.
- Рабочие заметки: свободный ввод оборудования, четыре категории, поиск и редактирование.
- Напоминания: отдельные переключатели конца перерыва, лимита и незавершённого перерыва.
- Операторша: дополнительные контекстные офлайн-реплики, без анимационных слоёв.
- Бэкапы: сохраняется совместимость со старой моделью ShiftData и существующими JSON.

## Shiftly 1.13.0 — Salary and payslip
- Payroll hours are separated from the 12-hour shift duration. Default: 11 paid hours per full shift and 7 paid night hours per full night shift; smoke/lunch timers are NOT subtracted again.
- Wage baseline from October 2026 payslip: 544.09 ₽/h, night multiplier 1.40, hazardous-work supplement 4%.
- Estimated variable premium paid next month, actual premium input, advance forecast for 1–15, actual advance input, taxable meals, downtime, actual withholding override.
- Salary amounts and monthly overrides are stored in the same backward-compatible ShiftData JSON and restored on backup import.
- Tax, overtime coefficient and advance forecast are estimates until more pay slips confirm payroll rules.
- Do not overwrite `main` until the dev/1.11 GitHub Actions build and iPhone checks succeed.
