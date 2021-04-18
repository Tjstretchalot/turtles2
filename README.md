# Turtles (2)

Contains a collection of functions and classes that make working with turtles
easier, and runners which use those functions.

## Support

This modpack has been tested on CC: Tweaked and CC: Restitched Updated. However,
the software is provided as-is without any warranty. See LICENSE.md for more details.
## User Features

- Restart-friendly: all programs provided can handle restarts at any time,
which can happen due to manual user intervention, the turtles chunk being
unloaded, and the server be restarted. This means these turtles are very
single-player friendly! In order for this to work, either fuel usage needs
to be enabled or the turtle needs to be covered by a GPS and have a wireless
modem. If neither of these things are true, the turtle will still attempt
to recover but it may fail.
- Complete A* pathfinding: the turtle will intelligently decide how to go
between locations, saving fuel and improving versatility. This works by
an informed breadth-first search
- Automatic refueling: all programs provided can handle fuel usage enabled or
disabled. It's strongly recommended to enable fuel usage as it's the easiest
way to ensure the turtles will be able to recover from restarts.
- Well documented: The programs provided explain where to place the turtle
and what to do prior to starting.

## User Issues

- Downloading is somewhat of a pain (see Downloading below), due to the github
API limits. Luckily, for singleplayer or anytime you have access to the servers
files it is much easier. Furthermore, there are workarounds for servers.
- Most programs rely on the day and time and will not work correctly if those
are disabled.

## Provided Programs

- **Tree farm** - handles oak trees, allowing you to farm wood and apples. If
  the wood is burned into charcoal, this results in a significant surplus in
  fuel for turtles. Checks each tree once per day.
- **Wheat farm** - a simple 9x9 wheat farm which is checked every 30 minutes,
  depositing seeds and wheat in separate chests and has a chest to get fuel
  from.
- **Generic farm** - Stacked 9x9 farms all managed by a single turtle. Each farm
  is on its own 30 minute timer for being checked. Has a simple config file to
  specify the seed on each layer. Supports wheat, carrots, potatoes, melons,
  pumpkins, and beetroot. Works optimally at 9 or 10 stacked farms.
- **Small mushroom farm** - easily farm an 18x18 small mushroom farm with any
  distribution of red and brown mushrooms. 36 planted mushrooms, checked every
  hour.
- **Mining** - with very little setup, mine all resources between layers 7 and
  50 in a chunk, spiraling chunk by chunk outward.
- **Vein** - quickly set the turtle up to mine out all of a given resource which
  is contiguous next to the turtle. Often useful for deconstructing large
  structures or acquiring obsidian.

Plus other more specific programs (e.g., automations for feeding the Gourmaryllis
plant in Botania, or the crafting recipe for wheat dough in Create).

## Technical Features

In general, this library gives you enough to focus on bigger, more impressive
projects, such as massive farms, complex mining techniques, construction
projects, or multi-turtle programs. These things are impossible without a way
to handle restarts, and painful without pathfinding.

- Redux-style stores: with a little change from how you're used to working with
turtles, you too can get restart-friendly programs. Essentially, you maintain
two tables, one of which is guarranteed to be persistent through restarts and
the other of which may be lost at any time. Instead of modifying the persistent
table directly, you specify actions which are dispatched to the store, and
reducers which take an action and the persistent state and return the new
persistent state. It's like https://redux.js.org/basics/data-flow but without
the listeners.
- An "ores" api is provided, which allows you to recursively search adjacent
tiles for any blocks which match a predicate. For example, mine an entire coal
vein with relative ease. This is also used for a tree farm that's provided that
can handle arbitrarily shaped trees, i.e., big oak trees, without making any
assumptions about how they spawn.
- A "paths" api is provided to calculate paths given either all pathable blocks
or all unpathable blocks. "path_utils" makes using these paths with the store
easy.
- A "gps_locate" api is provided, allowing you to fetch direction as well as
location using the GPS api and some fuel.
- A "home" api is included which uses the gps_locate API to persistently store
where the turtle started and which direction he was facing. "path_utils" allows
you to use this to translate between absolute (GPS) coordinates and relative
coordinates, incorporating the fact that "south" in absolute coordinates may be
different than "south" in relative coordinates. (Relative to where the turtle
was initialized).
- A "farm" api is included to easily create any manner of arbitrarily complex
farms.

## Downloading (No FTP Access)

Use [gitget v2](http://www.computercraft.info/forums2/index.php?/topic/17387-gitget-version-2-release/)
to download the entire repository using the following:

```text
pastebin get W5ZkVYSi gitget
gitget tjstretchalot turtles2 master turtles2/
cd turtles2/
tests/hello.lua
```

Be aware that this method is limited to 60 files per hour which is not very
many. You may need to copy files over ftp / locally / download the zip. At
the very least, using this method, you should use a disk and copy files from
that disk around to all your turtles.

As a note, you will need more than one floppy disk on the default settings.
This is somewhat painful, so I'd recommend increasing the floppy disk size
to at least 1MB to avoid this (ComputerCraft.cfg)

## Downloading (FTP Access)

Suppose the save for your world is located at saves/CC. First, download the
repository locally (GitHub -> Clone or Download -> Download ZIP). Ensure the
repository is extracted.

Place a turtle. Type "id" to get the id of the turtle (i.e., this is computer
#1 means that 1 is the id).

Using FTP (or file explorer), create the folder saves/CC/computer/1/ where
instead of "1" you use the id that you just got. In that folder, copy the
turtles2 folder that you downloaded from GitHub. Thus you have

saves/CC/computer/1/turtles2/tests/hello.lua

You can verify the installation by opening the turtle, and typing

```text
cd turtles2
tests/hello.lua
```

To which you should see potentially some text and then

```text
tests/hello.lua completed
```
