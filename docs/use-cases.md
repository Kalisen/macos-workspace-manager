# Supported use cases

Terms: a **workspace** is a Mission Control desktop that can hold windows (fullscreen Spaces are excluded). A window's **home** is the workspace it belongs to. A window away from its home is **displaced**.

## Workspaces

| ID | Use case | Behaviour |
|---|---|---|
| UC1 | Name a workspace | "Rename Current Desktop…" names the desktop showing on the active display. An empty name restores "Desktop N". Names survive restarts, reboots and display reconnection. |
| UC2 | See where I am | The menu bar shows the current workspace name. The menu lists the workspaces of each display with their window count and marks the current one. |
| UC3 | Go to a workspace | From the menu or the workspace list (`ctrl+alt+space`): pick with the pointer, arrows or digits `1`–`9`. Works across displays. |
| UC14 | See workspace names in Mission Control | While Mission Control is open: each display shows the name of its current workspace in large characters at its centre, and each desktop with a custom name is labelled in the bar at the top — in place of "Desktop N" while the bar is collapsed, across the preview when it is expanded. Labels follow the bar and a desktop switch, disappear on exit, and let clicks through. `missionControlBanner.enabled` turns everything off, `missionControlBanner.desktopLabels` only the bar labels. |

## Windows

| ID | Use case | Behaviour |
|---|---|---|
| UC4 | A window belongs where I put it | A window is homed on the desktop where it is first seen. Moving it to another desktop by any macOS means re-homes it. |
| UC5 | Send a window to a workspace | From the title bar (`alt+shift` + right-click), the focused-window shortcut (`ctrl+alt+shift+space`) or the menu. The window is moved and re-homed; the view stays on the current desktop. |
| UC6 | Notice displaced windows | A desktop change seen within 60 seconds of a wake or display change does not re-home the window. The menu bar shows the displaced count; the menu lists each window with its home. |
| UC7 | Restore displaced windows | `ctrl+alt+r` or the menu moves every displaced window to its home and its home frame, across displays if needed, then returns to the desktops that were showing. Failures are listed with their reason; the other windows are still moved. |
| UC8 | Keep the current layout | Accepts where the windows are now as their homes. |
| UC9 | Keep homes across app restart and reboot | Windows are re-identified by app and title similarity. Windows reopened elsewhere show as displaced. |

## Operating the app

| ID | Use case | Behaviour |
|---|---|---|
| UC10 | Configure shortcuts | `config.json` sets the three shortcuts, the title-bar click modifiers, the title-bar height and the Mission Control banner. Missing keys keep their default; an empty shortcut is disabled; an invalid or taken one is reported in the menu. Applied at launch. |
| UC11 | Look up shortcuts | "Shortcuts…" shows the shortcuts as configured, with a button opening `config.json`. |
| UC12 | Start at login | Menu toggle, offered by the installed app. |
| UC13 | Diagnose | The menu reports missing permissions and configuration problems. `WorkspaceManager --status` prints permissions, desktops, window counts and displaced windows. |

## Not supported

- Windows shown on all desktops, fullscreen windows, minimized windows: not tracked.
- Windows without standard close and minimize buttons: tracked, cannot be moved.
- Labels on unnamed desktops or fullscreen Spaces of the Mission Control bar: they keep the text macOS gives them.
- A home whose desktop was removed: the window stays displaced and is reported on restore.
- Applying configuration changes without restarting the app.
