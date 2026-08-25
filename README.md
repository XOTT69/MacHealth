# 🏥 MacHealth v2.0 — Повна діагностика Apple пристроїв

![macOS](https://img.shields.io/badge/macOS-13.0+-blue?logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.9-orange?logo=swift)
![License](https://img.shields.io/badge/license-MIT-green)
![Price](https://img.shields.io/badge/price-FREE-brightgreen)

**Безкоштовний мультиінструмент для діагностики та управління MacBook і iPhone**

---

## ✨ Можливості

### 📊 Dashboard (Панель керування)
- Реальний час: CPU, RAM, температура, батарея
- Загальна оцінка здоров'я системи
- Швидкий огляд всіх компонентів

### 💻 Mac Діагностика
- 🔋 Батарея — здоров'я, цикли, температура, напруга, рекомендації
- 💻 CPU — модель, ядра, навантаження в реальному часі
- 🎮 GPU — модель, Metal, кількість ядер
- 🧠 RAM — використання, тип, тиск пам'яті
- 💾 SSD — SMART статус, використання, файлова система
- 🖥 Дисплей — роздільна здатність, Retina
- ⚙️ Процеси — топ-процеси по CPU/RAM, PID

### 📱 iPhone Діагностика
- Модель, серійний номер, IMEI
- iOS версія, статус активації
- Батарея та пам'ять
- Підтримка через libimobiledevice

### 🌐 Мережеві інструменти
- 📡 Wi-Fi аналіз (SSID, сигнал, канал, швидкість)
- 🏎️ Speed Test (завантаження/вивантаження/ping)
- 🔍 Ping будь-якого хоста
- 📋 Сканер локальної мережі (ARP scan)
- 🌍 Зовнішня IP-адреса

### 🔌 USB Monitor
- Автоматичне виявлення USB пристроїв
- VID/PID, серійний номер, швидкість, виробник

### 🧪 Hardware тести
- 💾 Швидкість запису/читання диска
- 🌐 Мережева затримка
- 🔍 DNS швидкість
- 🧠 Пропускна здатність RAM

### 📋 Звіти
- Генерація повного текстового звіту
- Збереження у файл або копіювання в буфер

---

## 📥 Встановлення

1. Завантажте `MacHealth.zip` з [Releases](../../releases)
2. Розпакуйте
3. Перемістіть `MacHealth.app` в «Програми»

### ⚠️ Перший запуск

```bash
xattr -cr /Applications/MacHealth.app
```

Або: ПКМ на програмі → «Відкрити» → «Відкрити»

### Розробка та збірка з вихідного коду

Потрібен повний **Xcode 15.4 або новіший** (самих Command Line Tools недостатньо для SwiftUI-макросів).

```bash
git clone https://github.com/XOTT69/MacHealth.git
cd MacHealth
open MacHealth.xcodeproj
```

У Xcode виберіть схему `MacHealth` і натисніть **Run**. У CI застосунок збирається автоматично після push у `main` або за тегом `v*`.

### 📱 Для iPhone діагностики

```bash
brew install libimobiledevice
```

---

## 🏗 Технології

- SwiftUI (macOS 13+)
- IOKit, sysctl, system_profiler
- Apple80211 framework (Wi-Fi)
- libimobiledevice (iPhone)
- GitHub Actions (автоматична збірка)

---

## 📄 Ліцензія

MIT — вільне використання та модифікація.

---

**Зроблено з ❤️ в Україні 🇺🇦**
