# DashIDE 🚀

DashIDE is a fully functional, self-contained mobile IDE built with Flutter. It is designed to let you write code, manage version control, and compile cross-platform applications directly from your tablet or phone without needing a local toolchain.

## ✨ Features

* **Advanced Code Editor:** Multi-tab support, syntax highlighting (Atom One Dark, Dracula, etc.), code formatting, intelligent autocomplete suggestions, and quick-insert snippet toolbars.
* **Workspace Explorer:** Full file tree management with the ability to create, delete, and navigate directories and files seamlessly.
* **Git Source Control:** 
  * Real-time "dirty" file tracking with visual `M` (Modified) badges.
  * Direct integration with GitHub's Git API for atomic, multi-file commits.
  * Target repository switcher (auto-provisions missing repositories on the fly).
* **Cloud CI/CD Compilation:** Bypasses mobile OS restrictions by dispatching builds to GitHub Actions. Supports compiling:
  * Android (ARM64 & ARMv7 APKs)
  * Linux Desktop
  * Windows Desktop
  * macOS Desktop
* **Remote SSH Terminal:** An integrated, persistent `dartssh2` terminal dock to connect to remote Linux servers, VPSs, or Raspberry Pis directly from the IDE.

## 🛠️ Setup & Usage

1. Open **DashIDE**.
2. Tap the **Build** (Rocket) icon or navigate to the Settings dial.
3. Enter a **GitHub Personal Access Token (PAT)** with `repo` and `workflow` scopes.
4. Specify your target repository (e.g., `YourUsername/DashIDE`). If it doesn't exist, DashIDE will create it for you and inject the CI workflow.
5. Write your code, hit **Commit & Push** in the Source Control panel, and dispatch a build to compile your app in the cloud!

## 📜 License

This project is licensed under the **GNU General Public License v3.0 (GPLv3)**. See the `LICENSE` file for full details.
