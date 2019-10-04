# Turtles (2)

Contains a collection of functions and classes that make working with turtles
easier, and runners which use those functions.

## Downloading (No FTP Access)

Use the [GitHub Repository Downloader](http://www.computercraft.info/forums2/index.php?/topic/4072-github-repository-downloader/)
to download the entire repository using the following:

```text
pastebin get wPtGKMam github
github tjstretchalot turtles2 ./ .
cd turtles2/turtles2
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
