# Mars Orbital Shipping Company (MOSC)

Welcome to the **Mars Orbital Shipping Company (MOSC)** Fleet Manager. This is a Flutter-based simulation game where you take the helm of a budding shipping enterprise on the Red Planet. Manage your fleet, trade resources, and expand your infrastructure to become the premier logistics provider on Mars.

## 🚀 Features

*   **Fleet Management**: Acquire various classes of ships (Mule, Sprinter, Miner, Tanker, Harvester), each with unique capabilities.
*   **Ship Upgrades**: Customize your vessels by upgrading Speed, Cargo Capacity, Fuel, Shield, and AI systems. Reach "Elite" status for special bonuses.
*   **Dynamic Economy**: Mine and trade resources (Ore, Gas, Crystals). Prices fluctuate, so buy low and sell high!
*   **Mission System**: Dispatch ships on procedural contracts ranging from local scrap runs to deep-space rift harvesting.
*   **Base Engineering**: Expand your operations by upgrading key facilities:
    *   **Hangar**: Increase fleet size capacity.
    *   **Deep-Space Relay**: Unlock advanced ship classes and mission types.
    *   **Broadcasting Array**: Increase contract availability and value.
    *   **Neural Server Farm**: Boost fleet AI and travel speeds.
    *   **Trade Depot**: Expand storage and automate resource sales.
    *   **Repair Gantry**: Reduce maintenance costs and repair times.
*   **Prestige System**: End-game progression allowing for infinite scaling of certain stats.
*   **Cloud Sync**: Seamless cross-device play with Firebase Authentication and Firestore cloud saves.
*   **Leaderboards**: Compete against other CEOs for top Net Worth, Cash on Hand, and more.

## 🛠️ Tech Stack

*   **Framework**: [Flutter](https://flutter.dev/) (Dart)
*   **State Management**: [Provider](https://pub.dev/packages/provider)
*   **Backend**: [Firebase](https://firebase.google.com/)
    *   **Authentication**: Google Sign-In & Anonymous
    *   **Database**: Cloud Firestore
*   **Local Storage**: Shared Preferences (for offline caching)

## 📱 Getting Started

### Prerequisites

*   [Flutter SDK](https://docs.flutter.dev/get-started/install) installed.
*   An Android device or emulator (iOS requires additional setup).

### Installation

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/yourusername/mars_osc.git
    cd mars_osc
    ```

2.  **Install dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Firebase Setup:**
    *   Ensure `android/app/google-services.json` is present and configured for your Firebase project.

4.  **Run the app:**
    ```bash
    flutter run
    ```

## 🎮 Game Mechanics

### Resources
*   **Solars (⁂)**: The main currency. Used for ships, upgrades, and maintenance.
*   **Ore**: Basic resource, mined by ships or bought.
*   **Gas**: Volatile resource, requires Tanker class.
*   **Crystals**: Rare and valuable, requires specialized equipment.

### Classes
*   **Mule**: Basic cargo hauler. Reliable and cheap.
*   **Sprinter**: Fast courier ship for time-sensitive data runs.
*   **Miner**: Equipped for heavy ore extraction.
*   **Tanker**: Specialized for gas collection.
*   **Harvester**: Advanced vessel for rift harvesting.

### Offline Progression
Your Trade Depot AI continues to sell accumulated resources while you are away, ensuring you return to a profit.

## 📂 Project Structure

*   `lib/main.dart`: Entry point and app theme.
*   `lib/providers/game_state.dart`: Core game logic, state management, and Firebase integration.
*   `lib/screens/`: UI screens for different game sections (Operations, Engineering, etc.).
*   `lib/models/`: Data models for Ships, Missions, and Templates.
*   `lib/services/`: Helper services for mission generation.

---

*Fly Safe, Commander.*
