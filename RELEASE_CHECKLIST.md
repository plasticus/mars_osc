# Pre-Release Checklist

The following features and debug tools must be removed or disabled before building the production release.

## Code Changes Required

### 1. Disable Beta Multipliers
*   **File:** `lib/providers/game_state.dart`
*   **Method:** `_processMissionCompletion`
*   **Action:** Remove the 10x multiplier block.
    ```dart
    // --- BETA TESTING SWITCH ---
    // REMOVE THIS BLOCK BEFORE RELEASE
    reward *= 10;
    amount *= 10;
    // ---------------------------
    ```

### 2. Disable Fast Upgrades/Repairs
*   **File:** `lib/providers/game_state.dart`
*   **Methods:** `getRepairDuration`, `getUpgradeDuration`
*   **Action:** Remove the 0.1x multiplier blocks.

### 3. Disable Fast Mission Duration
*   **File:** `lib/providers/game_state.dart`
*   **Method:** `startMission`
*   **Action:** 
    * Remove the line `factor *= 0.1; // Beta`.
    * Remove the Hard Cap block (`if (rawMinutes > 5.0) rawMinutes = 5.0;`).

### 4. Remove Debug Reset & Complete All
*   **File:** `lib/screens/mission_logs_screen.dart`
*   **Action:** Remove the "DEBUG: RESET PROGRESS" button.
*   **File:** `lib/screens/operations_screen.dart`
*   **Action:** Remove the "BETA: COMPLETE ALL" button at the bottom.

### 5. Adjust Auto-Sell Timer
*   **File:** `lib/providers/game_state.dart`
*   **Method:** `_startMarketLoop`
*   **Action:** Change `Duration(minutes: 1)` to `Duration(hours: 1)` (or whatever the intended release frequency is).

### 6. Disable Manual Refresh (Optional)
*   **File:** `lib/screens/mission_board_screen.dart`
*   **Action:** The "REFRESH" button currently allows unlimited re-rolling of missions. Consider implementing a cooldown or removing it entirely if missions are only meant to regenerate over time.

## Asset Verification

### 7. App Icon
*   **File:** `pubspec.yaml`
*   **Action:** Ensure `flutter_launcher_icons` configuration points to the final production icon and that `flutter pub run flutter_launcher_icons` has been executed.

## Testing
*   Verify no duplicate "Local Scrap Run" or "Local Courier Run" missions appear.
*   Verify "Trade Depot" prices fluctuate correctly.
*   Verify "Shipyard" unlocking logic works (Relay Level dependencies).
