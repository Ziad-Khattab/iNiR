import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import Qt5Compat.GraphicalEffects

MouseArea {
    id: root
    required property SystemTrayItem item
    property var trayParent: null  // Reference to SysTray for closing other menus
    property bool targetMenuOpen: false

    signal menuOpened(qsWindow: var)
    signal menuClosed()

    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
    implicitWidth: 18
    implicitHeight: 18
    onPressed: (event) => {
        switch (event.button) {
        case Qt.LeftButton: {
            // Native path: SNI Activate -> xembedsniproxy -> exact XEmbed window.
            // Instance-accurate for multi-instance Wine apps (e.g. multiple
            // phBot clients); do NOT fuzzy-match toplevels here — all Wine
            // windows share one appId, so that restores the wrong window.
            item.activate();
            // Learn icon->character identity (the restored window becomes
            // active and its title carries the character name)
            TrayService.learnIdentity(item);
            break;
        }
        case Qt.MiddleButton:
            // Middle click: try secondary activate (useful for some apps)
            item.secondaryActivate();
            break;
        case Qt.RightButton:
            if (item.hasMenu) {
                // Close other tray menus first
                if (trayParent) trayParent.closeAllTrayMenus();
                menu.open();
            }
            break;
        }
        event.accepted = true;
    }
    onEntered: {
        if (!item) return;
        root.updateTooltip();
    }

    // Reactive tooltip: re-read SNI properties whenever the app (or Wine's
    // xembedsniproxy) pushes a change over D-Bus — e.g. phBot updating the
    // tray tooltip after a character logs in. Pure binding, no polling.
    function updateTooltip() {
        const tooltipTitle = item?.tooltipTitle ?? "";
        const title = item?.title ?? "";
        const tooltipDescription = item?.tooltipDescription ?? "";

        const learned = TrayService.identityFor(item);
        let text = learned.length > 0 ? ("phBot — " + learned)
                : (tooltipTitle.length > 0 ? tooltipTitle
                : (title.length > 0 ? title : ""));
        if (text.length === 0) { tooltip.text = ""; return; }
        if (!learned && tooltipDescription.length > 0) text += " • " + tooltipDescription;
        tooltip.text = text;
    }

    Connections {
        target: root.item
        function onTooltipTitleChanged() { root.updateTooltip(); }
        function onTooltipDescriptionChanged() { root.updateTooltip(); }
        function onTitleChanged() { root.updateTooltip(); }
    }

    Connections {
        // Refresh tooltip when a click-learned identity arrives
        target: TrayService
        function onTrayIdentitiesChanged() { root.updateTooltip(); }
    }

    // Listen for close signal from parent tray
    Connections {
        target: root.trayParent
        enabled: root.trayParent !== null
        function onCloseAllTrayMenus() {
            if (menu.active && menu.item) {
                menu.item.close();
            }
        }
    }

    Loader {
        id: menu
        function open() {
            menu.active = true;
        }
        active: false
        sourceComponent: SysTrayMenu {
            Component.onCompleted: this.open();
            trayItemMenuHandle: root.item.menu
            anchorHovered: root.containsMouse
            anchor {
                item: root
                edges: (Config.options?.bar?.vertical ?? false)
                    ? ((Config.options?.bar?.bottom ?? false) ? Edges.Left : Edges.Right)
                    : ((Config.options?.bar?.bottom ?? false) ? Edges.Top : Edges.Bottom)
                gravity: (Config.options?.bar?.vertical ?? false)
                    ? ((Config.options?.bar?.bottom ?? false) ? Edges.Left : Edges.Right)
                    : ((Config.options?.bar?.bottom ?? false) ? Edges.Top : Edges.Bottom)
                adjustment: (Config.options?.bar?.vertical ?? false)
                    ? PopupAdjustment.SlideY : PopupAdjustment.SlideX
            }
            onMenuOpened: (window) => root.menuOpened(window);
            onMenuClosed: {
                root.menuClosed();
                menu.active = false;
            }
        }
    }

    IconImage {
        id: trayIcon
        visible: !(Config.options?.bar?.tray?.monochromeIcons ?? false)
        source: root.item?.icon ?? ""
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
    }

    Loader {
        active: Config.options?.bar?.tray?.monochromeIcons ?? false
        anchors.centerIn: parent
        width: root.width
        height: root.height
        sourceComponent: Item {
            IconImage {
                id: tintedIcon
                visible: false
                anchors.fill: parent
                source: root.item?.icon ?? ""
            }
            Desaturate {
                id: desaturatedIcon
                visible: false
                anchors.fill: parent
                source: tintedIcon
                desaturation: 0.8
            }
            ColorOverlay {
                anchors.fill: desaturatedIcon
                source: desaturatedIcon
                color: ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.9)
            }
        }
    }

    PopupToolTip {
        id: tooltip
        extraVisibleCondition: root.containsMouse
        alternativeVisibleCondition: extraVisibleCondition
        anchorEdges: (Config.options?.bar?.vertical ?? false)
            ? ((Config.options?.bar?.bottom ?? false) ? Edges.Left : Edges.Right)
            : ((Config.options?.bar?.bottom ?? false) ? Edges.Top : Edges.Bottom)
    }

}
