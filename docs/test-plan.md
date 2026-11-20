# Test plan

Covers the use cases of [use-cases.md](use-cases.md). Each behaviour is tested once, at the cheapest level that can prove it.

## Levels

| Level | Proves | Runs | Location |
|---|---|---|---|
| Unit | Rules that need no system: homes, displacement, re-identification, naming, layout arithmetic, shortcut and settings parsing, persistence | `make test` | `Tests/WorkspacesTests`, `Tests/MacDesktopTests`, `Tests/MissionControlBannerTests`, `Tests/WorkspaceManagerTests` |
| Contract | The private window-server data still has the shape the app reads. Read-only, against the running system; skipped without a display | `make test` | `SpaceReaderContractTests` |
| Live | Synthetic input really switches desktops and moves a window; Mission Control is detected and the banner shown. Takes over the screen for a few seconds | `make live-test` | `LiveMoveTests`, `LiveOverlayTests` |
| Manual | What only a person or a real system event can trigger: menus, global shortcuts, dialogs, wake, display reconnect, reboot, login | Before a release, after a macOS update | Checklist below |

Rules for placing a test:

- A rule decided in the `Workspaces` domain is unit-tested there and not re-tested through the app.
- The live tests assert the mechanism (window arrives, frame restored, view reachable), not which window is displaced.
- Manual checks cover wiring only: one pass per entry point, not per rule.

## Coverage

| Use case | Behaviour | Level | Test |
|---|---|---|---|
| UC1 | Default name, rename, trim, empty restores default, name kept for a missing desktop | Unit | `WorkspaceNamesTests` |
| UC1 | Names persisted | Unit | `StateStoreTests.testNamesAndPlacementsSurviveARestart` |
| UC1 | Right-click target in the Mission Control bar: labelled or not, collapsed or expanded, fullscreen and mismatched bars excluded | Unit | `DesktopBarLabelsTests` |
| UC1 | Rename dialog from each entry point, menu-bar title and labels update | Manual | M1, M9 |
| UC2 | Desktop numbering, fullscreen Spaces excluded, window count | Unit | `DesktopLayoutTests`, `PlacementBookTests.testWindowCountPerWorkspace` |
| UC2 | Layout read from macOS is coherent | Contract | `SpaceReaderContractTests` |
| UC2 | Menu content and current mark | Manual | M1 |
| UC3 | Steps between desktops, none across displays | Unit | `DesktopLayoutTests` |
| UC3 | Mission Control shortcuts: defaults, disabled, custom | Unit | `MissionControlShortcutsTests` |
| UC3 | Distant desktop reached with the direct shortcut, and left again | Live | `testDistantDesktopIsReachedAndLeftAgain` |
| UC3 | Workspace list shortcut, digit selection | Manual | M2 |
| UC4 | Homed where first seen, user move re-homes, fullscreen ignored | Unit | `PlacementBookTests` |
| UC4 | Only windows on exactly one workspace are tracked | Contract | `testTrackedWindowsSitOnExactlyOneKnownWorkspace` |
| UC5 | Sent window is displaced until it arrives, then at home | Unit | `testSendingAWindowMakesItDisplacedUntilItArrives` |
| UC5 | Window moved to another desktop of the same display | Live | `testWindowMovesToAnotherDesktopAndBack` |
| UC5 | Title-bar click, focused-window shortcut, menu entry | Manual | M3 |
| UC6 | Settling period: starts settled, lasts 60 s, restarts | Unit | `SettlingPeriodTests` |
| UC6 | Move during settling keeps home and home frame; user move afterwards re-homes | Unit | `PlacementBookTests` |
| UC6 | Wake and display reconnect start the settling period; count shown | Manual | M4 |
| UC7 | Window fetched from a hidden desktop, moved across displays, frame restored | Live | `testWindowMovesToAnotherDesktopAndBack` |
| UC7 | Home desktop removed: still displaced | Unit | `testWindowStaysDisplacedWhenItsHomeDesktopWasRemoved` |
| UC7 | Restore command, return to starting desktops, failure report | Manual | M4 |
| UC8 | Accepting the layout clears displacements | Unit | `testKeepingTheCurrentLayoutClearsDisplacements` |
| UC9 | Reboot, app restart, similar and unrelated titles, other app, identical or unreadable titles, new window of a running app, reused window ID | Unit | `WindowReidentificationTests` |
| UC9 | Placements persisted; stale ones dropped; unreadable state set aside | Unit | `StateStoreTests`, `PlacementBookTests` |
| UC9 | Boot session identifier available | Contract | `testBootSessionIsStableWithinABoot` |
| UC9 | Real app restart and reboot | Manual | M5 |
| UC10 | Shortcut parsing, modifiers, invalid input | Unit | `KeyStrokeTests` |
| UC10 | Defaults written at first launch, missing keys, malformed file | Unit | `SettingsTests` |
| UC10 | Invalid or taken shortcut reported in the menu | Manual | M6 |
| UC11 | Rows shown, disabled and invalid shortcuts flagged, glyphs | Unit | `ShortcutsPanelTests`, `KeyStrokeTests` |
| UC11 | Panel opens, button opens `config.json` | Manual | M6 |
| UC12 | Toggle state, app running after login | Manual | M7 |
| UC14 | Label placement per display, long names, stays in place, click-through, readable background | Unit | `WorkspaceBannerTests` |
| UC14 | Bar labels: collapsed and expanded placement, unnamed desktops skipped, long names, mismatched or misplaced bar left unlabelled | Unit | `DesktopBarLabelsTests` |
| UC14 | Opening and closing Mission Control detected; large name and bar labels on screen only in between | Live | `testLabelShowsWhileMissionControlIsOpenAndOnlyThen` |
| UC14 | Name per display, bar labels collapsed and expanded, follows a desktop switch, settings turn them off | Manual | M8 | Name two desktops. Open Mission Control with two displays. Move the pointer to the top to expand the bar. Switch desktop with `ctrl+→`. Click a window thumbnail under the large name, then a labelled desktop. Set `missionControlBanner.desktopLabels`, then `enabled`, to `false`, restarting each time. | Each display shows its workspace name at its centre. The two named desktops are labelled in the bar, collapsed and expanded; the others keep "Desktop N". The large name follows the switch. Clicks reach the thumbnail and the desktop. First setting removes the bar labels only, the second all labels. |
| M9 | In the menu, right-click a desktop, then Control-click another; rename both. Open Mission Control: right-click the large name, an unnamed desktop of the collapsed bar, and a preview of the expanded bar; rename each. Right-click a window thumbnail. | Each dialog is titled with the clicked desktop, opens on that desktop's display, and appears over Mission Control, which stays open. New names show in the menu, the bar and the large name within a second. The right-click on a thumbnail opens no dialog. Plain clicks still switch desktop. |
