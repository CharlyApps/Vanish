#!/bin/zsh
# Builds Vanish.app into the project root. Drag it to /Applications.
set -e
cd "$(dirname "$0")"

swift build -c release

APP=Vanish.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/Vanish "$APP/Contents/MacOS/"

if [[ -f icon.png ]]; then
    rm -rf icon.iconset && mkdir icon.iconset
    for s in 16 32 128 256 512; do
        sips -z $s $s icon.png --out icon.iconset/icon_${s}x${s}.png >/dev/null
        sips -z $((s*2)) $((s*2)) icon.png --out icon.iconset/icon_${s}x${s}@2x.png >/dev/null
    done
    mkdir -p "$APP/Contents/Resources"
    iconutil -c icns icon.iconset -o "$APP/Contents/Resources/Vanish.icns"
    rm -rf icon.iconset
fi

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key><string>Vanish</string>
	<key>CFBundleIconFile</key><string>Vanish</string>
	<key>CFBundleIdentifier</key><string>com.bastida.vanish</string>
	<key>CFBundleName</key><string>Vanish</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>1.0</string>
	<key>CFBundleVersion</key><string>1</string>
	<key>LSMinimumSystemVersion</key><string>14.0</string>
	<key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
EOF

codesign --force -s - "$APP"
echo "Built $APP — drag it to /Applications."
