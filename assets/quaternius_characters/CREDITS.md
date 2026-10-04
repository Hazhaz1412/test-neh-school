# Ultimate Animated Character Pack — Quaternius

Three original FBX models: Casual_Male, Casual_Female and Suit_Male.

- Author: [Quaternius](https://quaternius.com/packs/ultimatedanimatedcharacter.html).
- Author’s distribution and explicit CC0 license: [Animated Characters Pack on OpenGameArt](https://opengameart.org/content/animated-characters-pack).
- [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/).
- Downloaded the archive linked by that author page on 2026-10-04; exact source URL and original file hashes are recorded in `sources.json`. The archive contains no standalone license text; the author’s distribution page is the license evidence.

Source FBX files are unchanged. Godot normalizes their units, reduces the investigators’ oversized heads in a cached runtime mesh, recolors clothing and aliases Idle/Walk/PickUp/Punch to gameplay animation names. The sprint alias uses Walk accelerated by the chase controller; it is not a separate authored running clip. Entities remove the source head at runtime and add a faceless oval, uniform details and a club attached to the hand bone. No external texture is required.
