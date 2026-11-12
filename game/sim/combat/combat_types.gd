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

## What a man is for in a formation: a shield-bearer in the line, a spearman
## who fights over a shield-bearer's shoulder from the second rank, or a
## missile man (bow) who stands off behind.
enum Role { SHIELD, SPEAR, MISSILE }

enum Armor { NONE, LEATHER, MAIL }

## Leader shouts (concept.md, Combat > Shouts). NONE means "no new order".
enum Shout { NONE, SHIELD_WALL, HOLD, PUSH, TO_ME, BREAK_THEM, FALL_BACK, SVINFYLKING, TAUNT }

enum Personality { STEADY, RECKLESS, GRIM, BOASTFUL, GREEDY, SUPERSTITIOUS }

## What a man does this round. See Action.
enum ActionKind { BRACE, MOVE, ATTACK, SHOOT, FLEE, IDLE }

## Where an attack comes from relative to the defender's facing.
## Shield covers FRONT and LEFT (front, front-left, left). FRONT_RIGHT gets no
## shield but no flank bonus. RIGHT is the exposed flank. REAR is deadly.
enum Arc { FRONT, FRONT_RIGHT, LEFT, RIGHT, REAR }

## Ground under a cell (BattleGrid, Field). WATER, TREE, ROCK, FENCE and
## BUILDING cannot be stood on (BattleGrid.blocks). FORD is shallow water:
## passable, costs breath like MUD, and a man standing in it locks shields
## with nobody. BRIDGE and DOOR are passable flat ground (a stream's
## crossing, a hall's doorway). SLOPE is high ground: a line standing on it
## pushes harder (Push.group_strength). SEA and RAIL are the ship fight's
## alone (Scenario.build_deck), so no other field ever holds them: SEA is
## open water round and between the hulls, which nobody stands in and a
## man thrown into goes overboard (Push, Battle); RAIL is the gunwale
## strake along a deck's edge, flat planking to stand on.
enum Terrain { FLAT, MUD, WATER, SLOPE, TREE, ROCK, FENCE, BUILDING, FORD, BRIDGE, DOOR, SEA, RAIL }

## Post-battle fate of a man who went Down.
enum Fate { RECOVERED, MAIMED, DEAD }

const TIER_NAMES := ["green", "blooded", "veteran", "champion"]
const WOUND_NAMES := ["unhurt", "bruised", "wounded", "grievous", "down"]
const SHOUT_NAMES := ["-", "shield wall", "hold", "push", "to me", "break them", "fall back", "svinfylking", "taunt"]
const STAT_NAMES := ["might", "skill", "grit", "nerve", "wits"]
const ROLE_NAMES := ["shield", "spear", "bow"]
const TERRAIN_NAMES := ["flat", "mud", "water", "slope", "tree", "rock", "fence", "building", "ford", "bridge", "door", "sea", "rail"]
