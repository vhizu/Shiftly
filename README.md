# Shiftly 1.4.0 — Operator Edition 💜

Полный проект SwiftUI для iPhone (iOS 17+) с исходниками, ассетами маскота, Live Activity, Dynamic Island, домашним виджетом и GitHub Actions для сборки unsigned IPA.

## Что нового
Автоматический график смен; напоминания за час и 15 минут; круговой таймер; кнопка завершения перекура в Live Activity; домашний виджет; статистика; редактирование смен/перерывов; журнал оборудования; экспорт CSV; резервные копии JSON.

## Сборка
Скопируйте содержимое папки проекта в корень GitHub репозитория, закоммитьте и запустите workflow `Build Shiftly 1.4 IPA` в Actions. GitHub Actions использует macOS, XcodeGen и xcodebuild.

## Важное ограничение
Нужна подпись с App Group `group.com.shiftly.app` для взаимодействия приложения и расширений. Не все варианты sideload-подписи через GBox поддерживают App Groups. Синтаксис Swift проверен, но компиляция Xcode и работа на iPhone не подтверждены. Подробнее в BUILD_STATUS.md.
