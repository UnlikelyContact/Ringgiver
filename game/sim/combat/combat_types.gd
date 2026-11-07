class_name CombatTypes
extends RefCounted
## Shared enums for the combat simulation. Keep this file small and stable:
## every module depends on it.

enum Stat { MIGHT, SKILL, GRIT, NERVE, WITS }

## Experience tier (concept.md, The band > Experience tiers).
enum Tier { GREEN, BLOODED, VETERAN, CHAMPION }

## Wound states instead of HP (concept.md, Combat > Wounds).
enum Wound { UNHURT, BRUISED, WOUNDED, GRIEVOUS, DOWN }

enum Weapon { SPEAR, BEARDED_AXE, SWORD, LONG_AXE, BOW }

enum Armor { NONE, LEATHER, MAIL }

## Leader shouts (concept.md, Combat > Shouts). NONE means "no new order".
enum Shout { NONE, SHIELD_WALL, HOLD, PUSH, TO_ME, BREAK_THEM, FALL_BACK, SVINFYLKING }

enum Personality { STEADY, RECKLESS, GRIM, BOASTFUL, GREEDY, SUPERSTITIOUS }

## What a man does this round. See Action.
enum ActionKind { BRACE, MOVE, ATTACK, SHOOT, FLEE, IDLE }

## Where an attack comes from relative to the defender's facing.
## Shield covers FRONT and LEFT (front, front-left, left). FRONT_RIGHT gets no
## shield but no flank bonus. RIGHT is the exposed flank. REAR is deadly.
enum Arc { FRONT, FRONT_RIGHT, LEFT, RIGHT, REAR }

enum Terrain { FLAT, MUD, WATER, SLOPE }

## Post-battle fate of a man who went Down.
enum Fate { RECOVERED, MAIMED, DEAD }

const TIER_NAMES := ["green", "blooded", "veteran", "champion"]
const WOUND_NAMES := ["unhurt", "bruised", "wounded", "grievous", "down"]
const SHOUT_NAMES := ["-", "shield wall", "hold", "push", "to me", "break them", "fall back", "svinfylking"]
const STAT_NAMES := ["might", "skill", "grit", "nerve", "wits"]
