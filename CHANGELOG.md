# Changelog

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
