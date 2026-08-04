pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.services
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string stateDir: FileUtils.trimFileProtocol(Directories.state)
    readonly property string srcPath: `${root.stateDir}/user/generated/stylix-colors.json`
    readonly property string dstPath: `${root.stateDir}/user/generated/colors.json`

    readonly property string reloadCmd:
        `quickshell -c ii ipc call theme applyTheme 2>/dev/null || true`

    // write to tmp then rename, reload chained to the write
    function syncStylixColors() {
        Quickshell.execDetached(["bash", "-c",
            `tmp="${root.dstPath}.tmp.$$" && cp "${root.srcPath}" "$tmp" && mv -f "$tmp" "${root.dstPath}" && ${root.reloadCmd} || true`
        ])
    }

    function syncColors() {
        if (!Config.ready) return
        const type = Config.options.appearance.palette.type
        if (type === "stylix") {
            root.syncStylixColors()
        } else {
            const mode = Appearance.m3colors.darkmode ? "dark" : "light"
            // switchwall.sh already reloads after writing so no timer here
            Quickshell.execDetached(["bash", "-c",
                `${Directories.wallpaperSwitchScriptPath} --noswitch --mode ${mode} --type ${type} 2>/dev/null || true`
            ])
        }
    }

    // Watch palette type changes (QuickConfig sets this)
    Connections {
        target: Config.ready ? Config.options.appearance?.palette : null
        function onTypeChanged() {
            root.syncColors()
        }
    }

    // Auto-sync when wallpaper changes
    Connections {
        target: Config.ready ? Config.options.background : null
        function onWallpaperPathChanged() {
            root.syncColors()
        }
    }

    // Sync on startup
    function initIfReady() {
        if (!Config.ready) return
        root.syncColors()
    }

    Connections {
        target: Config
        function onReadyChanged() {
            root.initIfReady()
        }
    }
}
