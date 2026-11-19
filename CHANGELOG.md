# Changelog

## 1.4.0
- Center the config window title vertically in its header bar.
- Widen the config window so the "Highlight baits when none is applied" option no longer runs into the window edge.
- Show a chat message at login pointing to `/ap`. It can be turned off in the config window.
- The config window can now be moved by dragging it.
- Shorten the sound option label so it no longer runs past the edge of the config window.
- Show the slider labels and values in the same text size as the checkbox options.
- The bait buttons can now also be shown above or to the left of the Fishing button. The checkbox in the config window is replaced by a dropdown; your previous choice is kept.
- Group the options in the config window into General, Button, Fishing and Sound sections.
- Add an option to turn on auto loot while a fishing pole is equipped (off by default). The previous setting is restored on unequip and logout, unless you changed it yourself in the meantime.

## 1.3.1
- While the button is unlocked it stays visible as a grey preview even without a fishing pole, so it can be moved anywhere. Its tooltip then points out how to lock it again.
- Fix the slider knobs in the config window sitting too far right; at 100 % the knob was drawn past the end of the bar and could not be dragged.
- Make the slider bars in the config window slightly lighter so they stand out from the background.

## 1.3.0
- Add a key binding to cast Fishing, set via a button in the config window (left-click and press a key, right-click to clear).
- Add a button size slider and an option to show the baits beside the Fishing button instead of below it.
- Add optional sound adjustment while a fishing pole is equipped, with sliders for effects, music and ambience volume (off by default). Previous volumes are restored on unequip and logout, and a volume you changed yourself in the meantime is kept.
- Add an optional pulsing highlight on the bait buttons while no bait is applied (config window or `/ap glow`, off by default).
- Replace the cooldown swipe on the Fishing button with a small remaining-time text in the corner (red below one minute). The icon stays fully visible and no longer looks unusable, and the black corners are gone.
- Keep bait counts up to date during combat; a bait used up mid-fight is shown greyed out until combat ends.

## 1.2.0
- Add support for the current WoW Forever beta (16001).
- Add compatibility with the modern `C_Item` and `C_Spell` APIs while retaining fallbacks for older clients.
- Fix Fishing and bait buttons when `ActionButtonUseKeyDown` is enabled by registering secure actions for both button-down and button-up clicks.

## 1.1.0
- Fix buttons not responding to clicks in WoW 2.5.5 TBC Anniversary by replacing `RegisterForClicks("AnyUp")` with explicit button registrations compatible with all supported clients.
- Fix fishing pole equip/unequip not updating buttons correctly due to wrong event argument being read in `PLAYER_EQUIPMENT_CHANGED`.

## 1.0.1
- Minor Typo Fix

## 1.0
- Initial release of Angler's Pocket.
- Fishing button appears when a fishing pole is equipped.
- Bait buttons show available baits and apply them to main hand.
- Fishing buff cooldown shown on the Fishing button.
- Simple config window for positioning.
