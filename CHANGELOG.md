# Inventory Camera (OpenMW)

## Local changes (on top of 2.1)

- Hold the left mouse button over empty screen space and drag to swing the camera around the character; scroll there to zoom. See "Mouse Controls" in the settings
- Spotlight: a light hung in front of the character and above their head, plus a post-processing shader (`shaders/inventoryCameraSpotlight.omwfx`) that fades everything outside a pool of light around them (2x their own radius by default) to near black. See "Spotlight" in the settings
- Inventory Extender: the mouse controls sit above its full-screen DragBlocker widget and hand it the mouse events, so its world tooltips, pickups and drops keep working while the camera is up
- Inventory Extender: carry an item out of the inventory and click on the character to use it on them (equip, drink, read...), like dropping it on the vanilla paper doll. Not possible with the vanilla inventory: its drag and drop isn't visible to Lua
- Fixed the camera panning out from a stale pose after an instant (non-smooth) pan-in

## 2.1

- Added Dynamic Camera support (it's 95% there, check the FAQ for details)

## 2.0

- The mod is now completely functional with paused inventory. Unpausers are no longer required, but still highly recommended
- Updated settings
- Switched default Select settings renderers with SuperSelect3 by ownlyme. Now they are clickable
- Fixed camera not changing when opening inventory in third person in combat/magic stance
- Fixed all issues tied to OpenMW Camera builtin lua module

## 1.0

Initial release
