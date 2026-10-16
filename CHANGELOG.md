# Changelog

## Unreleased

### New

- **Two new looks: Horde and Alliance.** Horde is blood red and bronze on dark ember, Alliance is royal blue and gold on deep navy. Click the gear button to switch.

## Version 2.1.0

### New

- **Setup guide.** The first time you log in on each Hunter, Rogue or Priest, a short guide explains how SmartAssist works and lets you choose who the macro is aimed at and what it does automatically. It then shows you how to put the macro on your action bar: drag it straight from the guide, or follow the steps to find it in the macro window. Open it again any time with `/smartassist setup` or the button in the settings.
- **Choose where your macro is saved.** Keep it in your character's own macro tab (for example "Player Specific Macros") or in General Macros, shared by all your characters. Change it in the guide or with the Switch button in the settings.
- **Drag the macro from the settings.** The settings window now shows your macro's icon. Drag it onto your action bar, or click it and then click a bar slot.
- **Power Infusion by name, like Misdirection.** In a party, the quick menu lists your damage dealers. Click one and their name goes straight into the macro, so you don't need to set a focus. Save Target's Name still works anywhere.

### Changed

- Updated for patch 12.1.5.
- The button that changes the look is now a gear.
- New Priests no longer start aimed at focus. Pick a player by name instead.
- New characters now save the macro in their own character tab. If you already have the macro in General Macros, it stays there so your action bar button keeps working.

### Fixed

- Tanks from another realm are now set by their full name, so the macro finds them.

## Version 2.0.0

**Mark of the Tank is now SmartAssist.** It covers Power Infusion as well, so it got a name that fits.

### New

- **Priest support: Power Infusion.** Target the player you want and choose **Save Target's Name** in the quick menu, or set the macro to your target, target of target or focus. Priests don't get automatic tank switching, since Power Infusion goes on a damage dealer.
- **Choose your look.** Three looks to pick from: **Workbench** (flat and modern), **Artisan's Ledger** (warm walnut and brass) and **Lixard Classic** (black, grey and gold, with your class color as the accent). Click the sliders button next to the close button to switch. Your choice is saved for each character.
- The quick menu and settings show the name of the player you're pointed at, for example "Focus: Bramblehide", and update when your target or focus changes.

### Changed

- **The command is now `/smartassist`** (it used to be `/mott`).
- The quick menu and the settings window have been redesigned with new fonts and artwork.
- Press Escape to close the settings window.
- Updated for patch 12.1.5.

### Fixed

- Fixed a possible error when showing player names in places where the game hides them.

### Updating from Mark of the Tank

- Your settings start fresh. Settings are saved under the addon's name, so they can't carry across the rename. Your macro keeps its name, so your action bar button keeps working.
- If a **MOTT** folder is still in your AddOns folder after updating, delete it. Running both at once makes them fight over the same macro.

## Version 1.0.1

- Updated for patch 12.0.5.
- Clicking anywhere on a settings row now toggles it, not just the checkbox.

## Version 1.0.0

- First release as Mark of the Tank: Misdirection and Tricks of the Trade macro helper.
