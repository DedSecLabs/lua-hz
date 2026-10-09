# LunaHZ reload sound research

October 8, 2026. LuaHZ 0.2.9 was left unchanged while the user tests it.

## Feature origins

Offer auto-accept and player/vehicle tracking were among the original LunaHZ screenshot/configuration features. Auto-accept watches normal Horizon offer messages and uses user-set price limits for repair, defense, sex and drugs; taxi-call acceptance is also exposed. Autofind repeats /find and optionally /cohort where the character is eligible. Vehicle tracking repeats /trackcar using the user's selected vehicle. These use normal server commands and do not grant access to jobs or hidden locations.

## Static findings

The local LunaHZ 0.14.4 bytecode was parsed without executing it. Its game/reload module exposes a trigger function that:

- Checks that the player is on foot and has a native ped pointer.
- Reads the current weapon slot.
- Writes state value 2 to that slot's native weapon-state field.

The module captures value 2 in its parent function. The offset constants match GTA SA 1.0 US native CWeapon layout: ped weapon array 0x5A0, selected slot byte 0x718, slot stride 0x1C, state field +0x4.

The reachable reload handler contains no /reload command, sound-player API, remote audio URL or audio-file load. No reload audio files were found in the installed LunaHZ resource directory.

## Why sound can follow

GTA's [weapon update implementation](https://github.com/gta-reversed/gta-reversed/blob/master/source/game_sa/Weapon.cpp) processes native reloading state and emits reload audio events at animation/timing points. Its [weapon audio implementation](https://github.com/gta-reversed/gta-reversed/blob/master/source/game_sa/Audio/Entities/AEWeaponAudioEntity.cpp) selects built-in reload sounds for the active weapon type.

The evidence indicates LunaHZ uses the normal game reload pipeline rather than a separate downloaded sound. Hearing those events still depends on the weapon, task/animation and audio state.

This also explains our earlier implementation's limitation: directly calling CWeapon::Reload only fills the magazine; it does not initiate the full animation/audio state. Current LuaHZ 0.2.9 instead delegates to the user's confirmed Horizon /reload 2 animation command, which the user reports has no sound.

## Next implementation candidate

A future native-reload route should validate weapon type, player readiness/on-foot state and ammo conditions, then enter the normal reload state and verify animation, sound and client/server synchronization. Do not add a separate audio file or combine native and server animations blindly.

This research does not claim a live native reload test. LuaHZ 0.2.9 remains the server-command version while its QA is in progress. Private prototype/instruction evidence stays outside the public source tree; this document records the findings in our own words.
