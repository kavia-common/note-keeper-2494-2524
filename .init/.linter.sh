#!/bin/bash
set -euo pipefail

# Repo-level lint entrypoint used by CI.
# This workspace contains:
# - ios_frontend: native iOS (Xcode) project (no gradlew)
# - flutter_frontend: Flutter project (Android tooling under android/gradlew)
#
# So we run Android lint from the Flutter project.
cd /home/kavia/workspace/code-generation/note-keeper-2494-2524/flutter_frontend/android
./gradlew lint

