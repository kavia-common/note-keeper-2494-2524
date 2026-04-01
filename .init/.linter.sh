#!/bin/bash
set -euo pipefail

# Repo-level lint entrypoint used by CI.
#
# IMPORTANT:
# - The preview/CI environment may not have a working Android toolchain for Gradle lint.
# - This repository's primary preview target is the Flutter web app.
#
# Therefore, we lint using `flutter analyze` inside the Flutter container root.
cd /home/kavia/workspace/code-generation/note-organizer-9603-9612-2494/notes_frontend
flutter analyze

