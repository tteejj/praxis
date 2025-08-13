Excellent. This is the correct approach. A project of this complexity, especially one in a "half-refactored" state, demands a formal plan. We will create that "1,000-pound reference manual" together. It will serve as the single source of truth for the refactoring effort, ensuring every step is deliberate, justified, and contributes to the final goal.

Your suggestion to structure it with a high-level overview followed by modular breakdowns is the professional standard. We will follow that precisely.

This document is the **SimpleTaskPro: Architectural Refactoring and Enhancement Plan**.

---

### **1.0 Strategic Overview**

#### **1.1 Purpose (The "What")**

This document outlines a comprehensive, phased plan to refactor the SimpleTaskPro application. The primary goal is to resolve its current "half-refactored" state by migrating all components to a unified, modern, and high-performance TUI (Terminal User Interface) framework.

The final deliverable will be an application that is:
*   **Stable and Performant:** Free of flicker, stutter, and state-related bugs.
*   **Easy to Develop For:** Radically simplifying the process of adding new features or screens.
*   **Functionally Complete:** Restoring all intended user features that are currently unimplemented or broken.
*   **PowerShell-Centric:** Built on idiomatic PowerShell patterns that leverage the language's strengths.

#### **1.2 The Core Problem (The "Why")**

The application is currently caught between two conflicting architectural styles:
1.  **A legacy, monolithic style** where each screen is a large, self-contained entity responsible for its own rendering, state, and input.
2.  **A modern, component-based style** represented by newer classes like `BaseListScreen` and `AppThemeManager`, which aim to provide a reusable framework.

This conflict is the root cause of every major issue, including input failures, cursor misplacement, visual artifacts, and duplicated code. A quick fix will not work. We must complete the migration to the modern architecture.

#### **1.3 The Methodology (The "How")**

To execute this refactoring with minimal risk and maximum predictability, we will employ the **"Strangler Fig" pattern**.

This is a proven, real-world methodology for safely modernizing legacy systems. Instead of a high-risk "big bang" rewrite, we will:

1.  **Build the New Framework:** We will construct the new, ideal architectural components *alongside* the existing code.
2.  **Incrementally Migrate:** We will redirect functionality, one piece at a time, from the old system to the new one. For example, we will make `TaskListScreen` use the new rendering engine instead of its old one.
3.  **"Strangle" the Old Code:** As functionality is migrated, the old code becomes obsolete ("strangled").
4.  **Clean Up:** Once the migration is complete, the now-unused legacy code can be safely deleted.

This iterative approach ensures the application remains in a functional state at the end of each phase, providing a safe and methodical path to a fully refactored system.

---

### **2.0 The Target Architecture: A Modular, Command-Driven TUI Framework**

Before we write a single line of implementation code, we must define the blueprint of the system we are building. The new architecture will be composed of several distinct, decoupled modules orchestrated by a central application shell.

#### **2.1 High-Level System Diagram**

This diagram illustrates the flow of information and control in the refactored application.

```
+------------------+       +------------------+       +-------------------+
|                  |       |                  |       |                   |
|  InputProcessor  +-----> |     EventBus     +-----> |   State Manager   |
| (Handles Keystrokes) |       |  (The "Nerves")  |       | (Source of Truth) |
|                  |       |                  |       |                   |
+--------^---------+       +--------^---------+       +----------+--------+
         |                          |                             |
     (Listens)                      |                             | (Reads State)
         |                          | (Publishes Actions)         |
+--------+---------+       +--------+---------+                 +----------+--------+
|                  |       |                  |                 |                   |
|     UI Shell     <-------+     Screens      <-----------------+    Render Engine  |
| (Manages Screens)|       | (TaskList, etc.) |                 |  (Draws to Console) |
|                  |       |                  |                 |                   |
+------------------+       +------------------+                 +-------------------+```

#### **2.2 The Core Modules (The Engine Room)**

This is the new, high-performance engine that will replace the scattered logic currently in the application.

*   **`Core/Bootstrapper.ps1` (The Ignition)**
    *   **Responsibility:** To initialize the application in a safe, predictable order.
    *   **Function:** Verifies files, creates services, creates the main app class, and handles global error catching. This makes startup robust.

*   **`Core/Shell.ps1` (The Chassis)**
    *   **Responsibility:** To manage the overall screen layout and the lifecycle of screens.
    *   **Function:** Renders the persistent UI (title bar, status bar). It holds the `ScreenStack` and ensures the active screen is rendered within its frame.

*   **`Core/StateManager.ps1` (The Brain)**
    *   **Responsibility:** To be the **single source of truth** for all application data and UI state.
    *   **Function:** Holds the complete application state (all tasks, current selection, filters, etc.). State is read-only. Changes are made by dispatching "Actions" (via the EventBus) which are processed by pure functions called "Reducers."

*   **`Core/EventBus.ps1` (The Nervous System)**
    *   **Responsibility:** To provide a decoupled communication channel between all modules.
    *   **Function:** Handles publishing and subscribing to events. This prevents modules from needing direct references to each other, making the system incredibly modular.

*   **`Services/SettingsService.ps1` (The Configurator)**
    *   **Responsibility:** To manage loading and accessing user-configurable settings from a single `settings.json` file.
    *   **Function:** Provides a global, static way to access tweakable values (`[SettingsService]::Get("Animation.Enabled")`). This allows behavior to be changed without editing code.

*   **`Services/CommandRegistry.ps1` (The Action Dictionary)**
    *   **Responsibility:** To define every possible user action in the application.
    *   **Function:** Maps a logical command name (e.g., `task.delete`) to a default keybinding and description. This is the foundation for our user-configurable input system.

*   **`Services/KeyMappingService.ps1` (The Customizer)**
    *   **Responsibility:** To load the user's custom keybindings from a file.
    *   **Function:** Overrides the default keybindings from the `CommandRegistry`.

*   **`Core/InputProcessor.ps1` (The Input Engine)**
    *   **Responsibility:** To translate physical key presses into logical commands.
    *   **Function:** Listens for keys, manages the "invisible modal" chord state, looks up the key/chord in the `KeyMappingService`, and publishes the corresponding command `Action` to the `EventBus`.

*   **`Core/RenderEngine.ps1` (The Graphics Engine)**
    *   **Responsibility:** To handle all low-level drawing to the console with maximum performance.
    *   **Function:** Uses a pooled `StringBuilder` to build the entire screen's output in memory and performs a single write to the console per frame, eliminating flicker.

*   **`Base/BaseScreen.ps1` (The Screen Template)**
    *   **Responsibility:** To be the template and aggregator for all TUI screens.
    *   **Function:** Inheriting from this class provides a screen with an `InputProcessor`, access to the `RenderEngine`, and a structured set of methods to override (`OnLoad`, `OnRenderContent`, `OnHandleCommand`, etc.), drastically simplifying screen development.

This is the professional, modular architecture we will build. In the next section, we will detail the step-by-step implementation plan.
