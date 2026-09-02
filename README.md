# Inventory Camera (OpenMW)

Open your inventory with style!

<div align="center">

<img src="media/demo1.gif" alt="demo1">

_Idle animations from [Dynamic Actors](https://www.nexusmods.com/morrowind/mods/54782) and head tracking._

<img src="media/demo2.gif" alt="demo2">

_Equipment updates right away!_

<img src="media/demo3.gif" alt="demo3">

_Drinking animations from [Consuming Animated](https://www.nexusmods.com/morrowind/mods/59069). Third person camera moves back into its position._

<img src="media/demo4.gif" alt="demo4">

_How it feels to use this mod._

| **Available features**                          | **Paused** | **Unpaused** |
| :------------------------------------------------| :----------:| :------------:|
| Smooth camera panning                           | ✅          | ✅            |
| Settings preview                                | ✅          | ✅            |
| Real time equipment updates                     | ✅          | ✅            |
| Animations                                      | ❌          | ✅            |
| Everything else that cannot happen during pause | ❌          | ✅            |

</div>

The mod does not come with inventory unpausing feature - for it you would need to install an separate mod. I personaly prefer [Unpause](https://www.nexusmods.com/morrowind/mods/60018).

## Compatibility

Should be compatible with anything.

Confirmed to be compatible with:[Red Mountain Tremors](https://www.nexusmods.com/morrowind/mods/53637)

- [Rock the Boat](https://www.nexusmods.com/morrowind/mods/59338)
- [Red Mountain Tremors](https://www.nexusmods.com/morrowind/mods/53637)
- [Devilish Alcohol Overhaul](https://www.nexusmods.com/morrowind/mods/55038) version 2.5 or newer
- [Devilish Touch of Madness](https://www.nexusmods.com/morrowind/mods/59337) version 1.9 or newer
- [Consuming Animated](https://www.nexusmods.com/morrowind/mods/59069) - disable "Lock camera perspective" in the settings

## FAQ / Troubleshooting

### The camera snaps a little at the end of the animation

This is a mod conflict on the other mods' side. Basically they might override camera rotation every frame due an oversight in logic - they set it to 0 every time even when they shouldn't do anything. Check "Compatibility" section for any potential culprits.

As a temporary measure you can set each rotation value to 0 one by one to see which one is problematic (usually it's Roll). Then leave them at 0 so that they will stay the same during the camera movement and consistent with the mod that overrides them.

## Recommended Mods

- [Inventory Extender](https://www.nexusmods.com/morrowind/mods/59205) - Along with many wonderful things, this mod removes the paper doll. And seeing both yourself and your paper doll doesn't make much sense to me
- [Unpause](https://www.nexusmods.com/morrowind/mods/60018) - Unpauses your inventory, allowing the game to play animations while you're in the inventory. It's more immersive this way
- [Dynamic Actors](https://www.nexusmods.com/morrowind/mods/54782) and [Dynamic Animations](https://www.nexusmods.com/morrowind/mods/57633) - Enhanced idle animations
- [Consuming Animated](https://www.nexusmods.com/morrowind/mods/59069) - New animations for mundane actions
- [Voice of the Nerevarine](https://www.nexusmods.com/morrowind/mods/59486) - Banter while digging through your luggage

## Credits

**Sosnoviy Bor** - Author  
**ownlyme** - Custom settings renderers ([Super Settings Renderers](https://www.nexusmods.com/morrowind/mods/59673))  
**SorreFalcon** - Custom settings renderers ([Sorre's Custom Renderers](https://www.nexusmods.com/morrowind/mods/59808))
