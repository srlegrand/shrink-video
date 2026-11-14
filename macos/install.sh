#!/bin/bash
# Installs shrink-video on macOS and adds a "Shrink Video" Quick Action to the
# right-click menu of video files in Finder (current user only, no sudo).
#
#   ./install.sh               install
#   ./install.sh --uninstall   remove everything again
#   ./install.sh --pkg-root D  stage the files under D for pkgbuild (used by CI)
#
# Also works without a checkout:
#   curl -fsSL https://raw.githubusercontent.com/srlegrand/shrink-video/main/macos/install.sh | bash
set -eu

RAW="https://raw.githubusercontent.com/srlegrand/shrink-video/main"
PKG_ID="io.github.srlegrand.shrink-video"
WORKFLOW="Shrink Video.workflow"
HERE=""
[[ -n ${BASH_SOURCE[0]-} ]] && HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

USER_BIN="$HOME/.local/bin/shrink-video"
USER_SERVICES="$HOME/Library/Services"
SYS_BIN="/usr/local/bin/shrink-video"       # where the .pkg installer puts things
SYS_SERVICES="/Library/Services"

# Copies (or downloads) the shrink-video script to $1.
put_script() {
    mkdir -p "$(dirname "$1")"
    if [[ -n $HERE && -f $HERE/../linux/shrink-video ]]; then
        cp "$HERE/../linux/shrink-video" "$1"
    else
        curl -fsSL "$RAW/linux/shrink-video" -o "$1"
    fi
    chmod 755 "$1"
}

# Writes the Quick Action bundle into the Services folder $1.
put_workflow() {
    local dir="$1/$WORKFLOW/Contents"
    rm -rf "$1/$WORKFLOW"
    mkdir -p "$dir"

    cat > "$dir/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSServices</key>
	<array>
		<dict>
			<key>NSBackgroundColorName</key>
			<string>background</string>
			<key>NSIconName</key>
			<string>NSActionTemplate</string>
			<key>NSMenuItem</key>
			<dict>
				<key>default</key>
				<string>Shrink Video</string>
			</dict>
			<key>NSMessage</key>
			<string>runWorkflowAsService</string>
			<key>NSRequiredContext</key>
			<dict>
				<key>NSApplicationIdentifier</key>
				<string>com.apple.finder</string>
			</dict>
			<key>NSSendFileTypes</key>
			<array>
				<string>public.movie</string>
			</array>
		</dict>
	</array>
</dict>
</plist>
PLIST

    cat > "$dir/document.wflow" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>AMApplicationBuild</key>
	<string>523</string>
	<key>AMApplicationVersion</key>
	<string>2.10</string>
	<key>AMDocumentVersion</key>
	<string>2</string>
	<key>actions</key>
	<array>
		<dict>
			<key>action</key>
			<dict>
				<key>AMAccepts</key>
				<dict>
					<key>Container</key>
					<string>List</string>
					<key>Optional</key>
					<true/>
					<key>Types</key>
					<array>
						<string>com.apple.cocoa.string</string>
					</array>
				</dict>
				<key>AMActionVersion</key>
				<string>2.0.3</string>
				<key>AMApplication</key>
				<array>
					<string>Automator</string>
				</array>
				<key>AMParameterProperties</key>
				<dict>
					<key>COMMAND_STRING</key>
					<dict/>
					<key>CheckedForUserDefaultShell</key>
					<dict/>
					<key>inputMethod</key>
					<dict/>
					<key>shell</key>
					<dict/>
					<key>source</key>
					<dict/>
				</dict>
				<key>AMProvides</key>
				<dict>
					<key>Container</key>
					<string>List</string>
					<key>Types</key>
					<array>
						<string>com.apple.cocoa.string</string>
					</array>
				</dict>
				<key>ActionBundlePath</key>
				<string>/System/Library/Automator/Run Shell Script.action</string>
				<key>ActionName</key>
				<string>Run Shell Script</string>
				<key>ActionParameters</key>
				<dict>
					<key>COMMAND_STRING</key>
					<string>for b in "$HOME/.local/bin/shrink-video" /usr/local/bin/shrink-video; do
    if [ -x "$b" ]; then exec "$b" --gui --ask "$@"; fi
done
osascript -e 'display alert "Shrink Video" message "shrink-video is not installed correctly. Please run the installer again."'</string>
					<key>CheckedForUserDefaultShell</key>
					<true/>
					<key>inputMethod</key>
					<integer>1</integer>
					<key>shell</key>
					<string>/bin/bash</string>
					<key>source</key>
					<string></string>
				</dict>
				<key>BundleIdentifier</key>
				<string>com.apple.RunShellScript</string>
				<key>CFBundleVersion</key>
				<string>2.0.3</string>
				<key>CanShowSelectedItemsWhenRun</key>
				<false/>
				<key>CanShowWhenRun</key>
				<true/>
				<key>Category</key>
				<array>
					<string>AMCategoryUtilities</string>
				</array>
				<key>Class Name</key>
				<string>RunShellScriptAction</string>
				<key>InputUUID</key>
				<string>6C1E3A0B-5D0A-4E0F-9A53-1B8E6C5B7F01</string>
				<key>Keywords</key>
				<array>
					<string>Shell</string>
					<string>Script</string>
					<string>Command</string>
					<string>Run</string>
					<string>Unix</string>
				</array>
				<key>OutputUUID</key>
				<string>0E6C4B57-2B43-4C8E-8E0D-7C0D2A1F9B02</string>
				<key>UUID</key>
				<string>B7B4D5C2-93F1-4B7C-A1C4-3E5F6A7D8C03</string>
				<key>UnlocalizedApplications</key>
				<array>
					<string>Automator</string>
				</array>
				<key>arguments</key>
				<dict>
					<key>0</key>
					<dict>
						<key>default value</key>
						<integer>0</integer>
						<key>name</key>
						<string>inputMethod</string>
						<key>required</key>
						<string>0</string>
						<key>type</key>
						<string>0</string>
						<key>uuid</key>
						<string>0</string>
					</dict>
					<key>1</key>
					<dict>
						<key>default value</key>
						<false/>
						<key>name</key>
						<string>CheckedForUserDefaultShell</string>
						<key>required</key>
						<string>0</string>
						<key>type</key>
						<string>0</string>
						<key>uuid</key>
						<string>1</string>
					</dict>
					<key>2</key>
					<dict>
						<key>default value</key>
						<string></string>
						<key>name</key>
						<string>source</string>
						<key>required</key>
						<string>0</string>
						<key>type</key>
						<string>0</string>
						<key>uuid</key>
						<string>2</string>
					</dict>
					<key>3</key>
					<dict>
						<key>default value</key>
						<string></string>
						<key>name</key>
						<string>COMMAND_STRING</string>
						<key>required</key>
						<string>0</string>
						<key>type</key>
						<string>0</string>
						<key>uuid</key>
						<string>3</string>
					</dict>
					<key>4</key>
					<dict>
						<key>default value</key>
						<string>/bin/sh</string>
						<key>name</key>
						<string>shell</string>
						<key>required</key>
						<string>0</string>
						<key>type</key>
						<string>0</string>
						<key>uuid</key>
						<string>4</string>
					</dict>
				</dict>
				<key>isViewVisible</key>
				<integer>1</integer>
				<key>location</key>
				<string>309.000000:253.000000</string>
				<key>nibPath</key>
				<string>/System/Library/Automator/Run Shell Script.action/Contents/Resources/Base.lproj/main.nib</string>
			</dict>
			<key>isViewVisible</key>
			<integer>1</integer>
		</dict>
	</array>
	<key>connectors</key>
	<dict/>
	<key>workflowMetaData</key>
	<dict>
		<key>applicationBundleIDsByPath</key>
		<dict/>
		<key>applicationPaths</key>
		<array/>
		<key>inputTypeIdentifier</key>
		<string>com.apple.Automator.fileSystemObject.movie</string>
		<key>outputTypeIdentifier</key>
		<string>com.apple.Automator.nothing</string>
		<key>presentationMode</key>
		<integer>15</integer>
		<key>processesInput</key>
		<integer>0</integer>
		<key>serviceApplicationBundleID</key>
		<string>com.apple.finder</string>
		<key>serviceApplicationPath</key>
		<string>/System/Library/CoreServices/Finder.app</string>
		<key>serviceInputTypeIdentifier</key>
		<string>com.apple.Automator.fileSystemObject.movie</string>
		<key>serviceOutputTypeIdentifier</key>
		<string>com.apple.Automator.nothing</string>
		<key>serviceProcessesInput</key>
		<integer>0</integer>
		<key>systemImageName</key>
		<string>NSActionTemplate</string>
		<key>useAutomaticInputType</key>
		<integer>0</integer>
		<key>workflowTypeIdentifier</key>
		<string>com.apple.Automator.servicesMenu</string>
	</dict>
</dict>
</plist>
PLIST
}

refresh_services() { /System/Library/CoreServices/pbs -update 2>/dev/null || true; }

case ${1-} in
    --pkg-root)
        [[ -n ${2-} ]] || { echo "Usage: install.sh --pkg-root DIR" >&2; exit 2; }
        put_script "$2$SYS_BIN"
        put_workflow "$2$SYS_SERVICES"
        echo "Staged in $2"
        exit 0 ;;
    --uninstall)
        rm -f "$USER_BIN"
        rm -rf "$USER_SERVICES/$WORKFLOW"
        if [[ -e $SYS_BIN || -e "$SYS_SERVICES/$WORKFLOW" ]]; then
            echo "Removing the system-wide copy installed by the .pkg (needs your password)..."
            sudo rm -rf "$SYS_BIN" "$SYS_SERVICES/$WORKFLOW"
            sudo pkgutil --forget "$PKG_ID" >/dev/null 2>&1 || true
        fi
        refresh_services
        echo "Removed."
        exit 0 ;;
    "") ;;
    *)  echo "Usage: install.sh [--uninstall]" >&2; exit 2 ;;
esac

[[ $(uname -s) == Darwin ]] || { echo "This installer is for macOS. On Linux use linux/install.sh." >&2; exit 1; }

put_script "$USER_BIN"
echo "Installed $USER_BIN"
put_workflow "$USER_SERVICES"
echo "Added the Finder Quick Action"
refresh_services

if ! PATH="/opt/homebrew/bin:/usr/local/bin:/opt/local/bin:$PATH" command -v ffmpeg >/dev/null; then
    echo
    echo "ffmpeg is not installed yet - it is required."
    if command -v brew >/dev/null; then
        echo "Install it with:   brew install ffmpeg"
    else
        echo "Install Homebrew from https://brew.sh, then run:   brew install ffmpeg"
    fi
fi

echo
echo "Done. Right-click a video in Finder and choose Quick Actions > Shrink Video."
echo "(If it is not listed: System Settings > General > Login Items & Extensions >"
echo " Finder, and switch on \"Shrink Video\".)"
