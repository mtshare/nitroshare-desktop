#!/bin/bash
#
# Build a universal (Apple silicon + Intel) NitroShare disk image that can be
# shared with other Macs. The official Qt build is used instead of Homebrew's,
# since it is universal and runs on older macOS releases.
#
# The app is signed ad-hoc: on first launch users must allow it in
# System Settings > Privacy & Security > "Open Anyway".
#
# Usage: scripts/release-macos.sh
# Environment: QT_VERSION (default 6.11.2), BUILD_DIR (default build-release)

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="${BUILD_DIR:-$ROOT/build-release}"
QT_VERSION="${QT_VERSION:-6.11.2}"
QT_DIR="$BUILD/qt/$QT_VERSION/macos"
CMAKE_BUILD="$BUILD/cmake"
APP="$CMAKE_BUILD/out/NitroShare.app"

# Download the official Qt (only qtbase is needed) if it isn't there yet
if [ ! -d "$QT_DIR" ]; then
    echo "==> Installing Qt $QT_VERSION"
    python3 -m venv "$BUILD/.venv"
    "$BUILD/.venv/bin/pip" install --quiet aqtinstall
    # Run from the build directory, where aqt writes its log
    (cd "$BUILD" && .venv/bin/aqt install-qt mac desktop "$QT_VERSION" clang_64 -O qt)
fi

echo "==> Configuring"
cmake -S "$ROOT" -B "$CMAKE_BUILD" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_PREFIX_PATH="$QT_DIR" \
    -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64"

echo "==> Building"
# Start from an empty bundle so nothing stale ends up in the release
rm -rf "$CMAKE_BUILD/out"
cmake --build "$CMAKE_BUILD" -j "$(sysctl -n hw.ncpu)"

echo "==> Checking the bundle"
MIN_OS="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$APP/Contents/Info.plist")"
problems=0
while IFS= read -r file; do
    # grep -q would stop reading early, making the pipe fail with pipefail
    file -b "$file" | grep "Mach-O" >/dev/null || continue
    name="${file#$APP/}"
    archs="$(lipo -archs "$file")"
    if [[ "$archs" != *arm64* || "$archs" != *x86_64* ]]; then
        echo "not universal ($archs): $name"
        problems=1
    fi
    minos="$(otool -l "$file" | awk '/minos/ { print $2; exit }')"
    if [ -n "$minos" ] && [ "$(printf '%s\n%s\n' "$minos" "$MIN_OS" | sort -V | tail -1)" != "$MIN_OS" ]; then
        echo "requires macOS $minos (app minimum is $MIN_OS): $name"
        problems=1
    fi
    if otool -L "$file" | grep "/opt/homebrew\|/usr/local/opt" >/dev/null; then
        echo "links a library outside the bundle: $name"
        problems=1
    fi
    # System paths (e.g. /usr/lib/swift, added by swiftc) exist on every Mac
    if otool -l "$file" | awk '/LC_RPATH/ { getline; getline; print $2 }' | grep -v "^/usr/lib/\|^/System/" | grep "^/" >/dev/null; then
        echo "has an absolute RPATH: $name"
        problems=1
    fi
done < <(find "$APP" -type f \( -perm -u+x -o -name "*.dylib" -o -name "*.so" \))
codesign --verify --deep --strict "$APP" || problems=1
if [ "$problems" -ne 0 ]; then
    echo "The bundle has problems, see above." >&2
    exit 1
fi

echo "==> Creating the disk image"
cat > "$CMAKE_BUILD/out/Leggimi - Read Me.txt" <<'EOF'
NitroShare

1. Drag NitroShare into the Applications folder.
2. Open it. macOS will say it can't verify the developer: click "Done".
3. Open System Settings > Privacy & Security, scroll down and click
   "Open Anyway" next to NitroShare, then confirm.
4. When NitroShare asks to find devices on your local network, click "Allow".

---

1. Trascina NitroShare nella cartella Applicazioni.
2. Aprila. macOS dirà che non può verificare lo sviluppatore: fai clic su "Fine".
3. Apri Impostazioni di Sistema > Privacy e sicurezza, scorri in basso e fai
   clic su "Apri comunque" accanto a NitroShare, poi conferma.
4. Quando NitroShare chiede di trovare dispositivi sulla rete locale, fai clic
   su "Consenti".
EOF
cmake --build "$CMAKE_BUILD" --target dmg

# Older disk images may still be in the build directory
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
DMG="$CMAKE_BUILD/nitroshare-$VERSION-macos.dmg"
cp "$DMG" "$BUILD/"
echo "==> Done: $BUILD/$(basename "$DMG") (macOS $MIN_OS or later, Apple silicon and Intel)"
