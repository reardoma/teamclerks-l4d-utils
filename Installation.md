# Prerequisites #
teamclerks-l4d-utils requires the same prerequisites that the standard Rotoblin project requires:
  * [MetaMod:Source 1.9.0](http://www.metamodsource.net) (or higher)
  * [SourceMod 1.4.0](http://http://www.sourcemod.net/downloads.php) (or higher)
  * [SDK Hooks 2.1.0](http://forums.alliedmods.net/showthread.php?t=106748)
  * [Stripper 1.2.2](http://www.bailopan.net/stripper/)
  * Left4Downtown 0.4.2.0 (included in the release)

# Introduction #
Installing the teamclerks-l4d-utils is very simple and straight-forward. It is important to know exactly what the teamclerks-l4d-utils package includes so that you are not surprised in the case where you get more than you expected.

At present, the package includes the following plugins and modules:
  * **1v1** - A module designed to support 1v1 play in L4D (hunters do 33 damage per pounce and are immediately killed when landing a pounce; hunters may not wallkick or they will be slain and an announcement will display)
  * **Skeet Practice** - A module designed to support honing l4d survivor skills; either deadstopping or skeeting (hunters are healed to full when they take non-lethal damage; hunter remaining health is displayed to any survivor who gets pounced; hunters are slain after pouncing a player and respawned quickly)
  * **Witch Announce** - A module designed to show players how much health a witch had remaining after an unsuccessful crown attempt and shows players who preformed the crown successfully.
  * **Tank Announce** - A plugin originally written by Griffin and Blade which I have forked to fix a few errors and make the announcement more reliable.
  * **Rotoblin** - A plugin originally written by Mr. Zero, modded by Jackpf, and now forked by me to add a few quality of life code changes as well as fix a few minor bugs. Additionally, I have added more game modes than the basic 4 included in Rotoblin (no health items except health kits upon leaving safe room, for instance).
  * **L4DReady** - A plugin originally written by Downtown1, modded by Jackpf, and now forked by me to add a few quality of life code changes as well as fix a few minor bugs.
  * **L4DScores** - A plugin written by Downtown1 that I have left unchanged. Originally, I thought that I needed to update this plugin to get it working on Windows, but I have come to find that this is impossible.

# Instructions #
  * Download the latest stable release (.zip)
  * Move the release to your server's left4dead directory (this is the folder that has 'addons' and 'cfg' directories).
  * Unzip the contents (they are packaged such that you may be prompted to overwrite files on disk; I suggest making backups of these files before overwriting them).

# Verification #
Check to see that TeamClerks plugin is registered correctly with SourceMod:
  * Issue the command "sm plugins list" from your server console
  * You should see (note: '#' is going to be whatever number corresponding to the order in which the plugin was loaded and the version will be whatever is the version downloaded):
`# "TeamClerks" (0.1.4) by kain`

That's it! All of the included plugins in the pack should be usable now!

# IMPORTANT #
If you are running your SRCDS on a Windows machine, you will need to remove L4DScores. Unfortunately, due to differences between the Linux and Windows server binaries, L4DScores requires hooks to functions that only exist on the Linux server binaries (they are inlined on Windows).

Everything should continue running fine on Windows, but the scores-manager as well as team rotations (ABABA, etc) will not work. This really only means that the winning team will always start the next chapter as survivors and that the scores you see at the end of a round are correct.

Also, I believe that there is an auto-team-balance function built into L4D, so there is a chance that from chapter to chapter players will be auto-balanced, but you can use L4DReady's `!spec`, `!surv`, and `!inf` to choose the correct team.