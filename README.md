# 📿 Bead Tracker

An elegant, offline-first Flutter application designed for spiritual practitioners and meditators to track Japa (mantra repetition) counts using traditional prayer beads (*malas*).

---

## 🌟 Key Features

- **24-Hour Interactive Mantra Counter (`/counter` — Primary Tab)**:
  - **Tactile Bead Chanting Surface**: Large interactive touch ring displaying live bead progress ($0 \rightarrow 108$) with haptic tap feedback.
  - **Automated Mala Completion**: Hitting 108 mantras automatically resets the bead counter to 0, increments today's completed malas by 1, and saves a practice session to the database.
  - **Live Multi-Screen Synchronization**: Completed malas instantly sync across the Dashboard (`/home`), Calendar Heatmap (`/calendar`), and Goal statistics.
  - **24-Hour Day Cycle**: Automatic midnight-to-midnight (12:00 AM – 12:00 AM) date rollover handling.
  - **Quick Safeguards**: `-1 Bead` button to rectify accidental double taps and `Reset Mala` button for current round.
  - **Real-Time Progress Summary**: Live tracking of today's completed malas, total mantras chanted today, and daily goal progress.

- **Practice Dashboard (`/home`)**:
  - **Animated Progress Ring**: Real-time visualization of cumulative mantras completed towards the total lifetime goal.
  - **Daily & Monthly Goal Cards**: Detailed progress metrics and completion percentages with linear progress bars.
  - **Consecutive Day Streak Counter**: Dynamic streak tracking to encourage daily consistency.
  - **Completion Prediction Engine**: Intelligent forecasting of estimated completion dates based on historical daily practice averages.
  - **7-Day Trend Chart**: Interactive line chart powered by `fl_chart` with touch tooltips displaying daily mantra repetitions.
  - **Quick Session Logging**: Bottom sheet modal with instant quick-add buttons (+1, +4, +8 Malas), custom counts, and optional journal notes.

- **Practice History & Calendar (`/calendar`)**:
  - **Visual Heatmap Calendar**: Color-coded calendar cells indicating days where practice was logged and whether daily goals were achieved.
  - **Detailed Session Logs**: Chronological breakdown of individual sessions logged for any selected day.
  - **Edit & Delete Sessions**: Easily modify session counts, update reflection notes, or remove entries.

- **Configuration & Settings (`/settings`)**:
  - **Bi-directional Goal Customization**: Set Daily, Monthly, and Total targets in either Mala rounds or Mantra repetitions with automatic 1:108 synchronization.
  - **Starting Count Offset**: Add a manual count offset in mantras to account for practice history accumulated prior to using the app.
  - **Theme Preferences**: Seamless toggle between sleek Dark Mode (default) and Light Mode.
  - **Local Backup & Restore**: Export all logs and configurations to a local JSON file in your Downloads folder and restore anytime with integrity checks.
  - **Reset Data**: Safe wipe and restore to default configurations.

---

## 📐 The Core Ratio

In traditional mantra meditation practices:
$$\mathbf{1\ Mala\ Round = 108\ Mantra\ Repetitions}$$

- **Goals & Offsets**: Stored internally in **Mantras** (`dailyGoal: 216`, `monthlyGoal: 5,400`, `totalGoal: 150,000`).
- **Sessions & Daily Logs**: Tracked and entered in **Malas** (`count: 1`, `count: 4`, etc.).
- **Total Calculation**: $\text{Total Mantras} = (\text{Total Malas} \times 108) + \text{Total Offset}$

---

## 🛠️ Tech Stack

| Layer | Technology |
| :--- | :--- |
| **Framework** | [Flutter](https://flutter.dev) (v3.44+) |
| **Language** | [Dart](https://dart.dev) (v3.12+ / SDK `^3.11.5`) |
| **State Management** | [Flutter Riverpod](https://pub.dev/packages/flutter_riverpod) (v2.6+) |
| **Routing** | [GoRouter](https://pub.dev/packages/go_router) with persistent Shell navigation |
| **Local Database** | [Isar NoSQL](https://isar.dev) embedded database |
| **Visualizations** | [fl_chart](https://pub.dev/packages/fl_chart) & [table_calendar](https://pub.dev/packages/table_calendar) |
| **Typography & Theme** | [Google Fonts](https://pub.dev/packages/google_fonts) (Inter) & Material 3 |
| **File Utilities** | [file_picker](https://pub.dev/packages/file_picker) & [file_saver](https://pub.dev/packages/file_saver) |

---

## 🏗️ Architecture & Project Structure

The project follows a clean **Layered Feature Architecture** with reactive state management:

```
lib/
├── main.dart                  # App bootstrap, ProviderScope, and theme root
├── models/                    # Isar collections and embedded models
│   ├── daily_entry.dart       # DailyEntry collection & embedded Session model
│   └── user_settings.dart     # UserSettings collection (goals, offset, theme)
├── services/                  # Low-level service implementations
│   └── database_service.dart  # Isar database lifecycle & schema registration
├── repositories/              # Data access abstraction layer
│   └── bead_repository.dart   # CRUD transactions, date normalization & backup/restore
├── providers/                 # Riverpod state notifiers and selectors
│   ├── bead_provider.dart     # State notifiers, streak logic, and calculated metrics
│   └── counter_provider.dart  # Active 0-108 bead counter state and midnight rollover
├── routes/                    # Declarative application routing
│   └── app_router.dart        # GoRouter configuration with ShellRoute (/counter, /home, /calendar, /settings)
├── theme/                     # Design tokens and themes
│   └── app_theme.dart         # Material 3 Dark & Light themes with saffron accent (#FF9E3D)
├── widgets/                   # Reusable UI components
│   ├── progress_ring.dart     # Animated radial progress painter
│   ├── add_entry_sheet.dart   # Modal sheet for logging sessions
│   └── edit_entry_sheet.dart  # Modal sheet for updating/deleting sessions
└── screens/                   # Page screens
    ├── main_navigation.dart   # Persistent navigation shell (Counter, Home, Calendar, Settings)
    ├── counter/               # 24-hour interactive bead tapping counter
    ├── home/                  # Dashboard screen with cards and trend chart
    ├── calendar/              # Heatmap calendar and daily session list
    └── settings/              # Goal settings, backup/restore, and reset
```

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`>= 3.11.5`)
- A supported target device, simulator, or desktop runner (Android, iOS, Windows, macOS, Linux, or Web).

### Installation & Run

1. **Clone the repository**:
   ```bash
   git clone https://github.com/pandya-dwip/bead_tracker.git
   cd bead_tracker
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **(Optional) Run code generator**:
   If modifying Isar models, regenerate code using:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. **Run the application**:
   ```bash
   flutter run
   ```

---

## 🧪 Testing & Analysis

- **Run unit tests**:
  ```bash
  flutter test
  ```
- **Run static analyzer**:
  ```bash
  flutter analyze
  ```

---

## 🔒 Privacy & Offline First

Bead Tracker is **100% offline-first**. Your meditation logs, personal journal reflections, and configurations are stored securely on your local device using an embedded Isar database. No data is sent to external servers or cloud services. You can create and manage your own backups at any time via the **Settings** screen.
