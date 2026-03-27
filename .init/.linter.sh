#!/bin/bash
cd /home/kavia/workspace/code-generation/note-keeper-2494-2524/ios_frontend
./gradlew lint
LINT_EXIT_CODE=$?
if [ $LINT_EXIT_CODE -ne 0 ]; then
   exit 1
fi

