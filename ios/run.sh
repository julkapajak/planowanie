#!/bin/bash
# Otwiera projekt w Xcode, buduje aplikację i uruchamia ją na symulatorze iPhone'a.
# Użycie: ios/run.sh            – pierwszy dostępny iPhone
#         ios/run.sh "iPhone 16" – konkretny model
set -euo pipefail
cd "$(dirname "$0")"

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "❌ Terminal nie widzi Xcode. Wpisz raz:"
  echo "   sudo xcode-select -s /Applications/Xcode.app"
  exit 1
fi

echo "📂 Otwieram projekt w Xcode…"
open Planowanie.xcodeproj

UUID_RE='[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}'
if [ $# -gt 0 ]; then
  LINE=$(xcrun simctl list devices available | grep -m1 -F "    $1 (" || true)
else
  LINE=$(xcrun simctl list devices booted | grep -m1 -E '^ +iPhone' || true)
  [ -n "$LINE" ] || LINE=$(xcrun simctl list devices available | grep -m1 -E '^ +iPhone' || true)
fi
if [ -z "$LINE" ]; then
  echo "❌ Nie znalazłem symulatora iPhone'a. W Xcode: Settings → Components → pobierz iOS."
  exit 1
fi
DEVICE=$(echo "$LINE" | grep -oE "$UUID_RE")
NAME=$(echo "$LINE" | sed -E 's/^ +(.*) \([0-9A-F-]{36}\).*/\1/')

echo "📱 Uruchamiam symulator: $NAME"
xcrun simctl boot "$DEVICE" 2>/dev/null || true
open -a Simulator

echo "🔨 Buduję aplikację (pierwszy raz trwa dłużej)…"
xcodebuild -project Planowanie.xcodeproj -scheme Planowanie \
  -destination "id=$DEVICE" -configuration Debug \
  -derivedDataPath build -quiet build

echo "🚀 Instaluję i uruchamiam Planowanie…"
xcrun simctl install "$DEVICE" build/Build/Products/Debug-iphonesimulator/Planowanie.app
xcrun simctl launch "$DEVICE" com.julkapajak.planowanie >/dev/null
echo "✅ Gotowe – aplikacja działa na symulatorze ($NAME)."
