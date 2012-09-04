/*
 * ============================================================================
 *
 *  TeamClerks
 *
 *  File:           restartmap.inc
 *  Type:           Helper
 *  Description:    Provides functions for modules to restart the current map.
 *
 *  Copyright (C) 2012 kain <kain@teamclerks.net>
 *
 * ============================================================================
 */

// Don't let the script be included more than once.
#if defined _teamclerks_helper_restartmap
  #endinput
#endif
#define _teamclerks_helper_restartmap

public Action:timerRestartMap(Handle:timer)
{
    RestartMapNow();
}

stock RestartMapIn(Float:seconds)
{
    CreateTimer(seconds, timerRestartMap, _, TIMER_FLAG_NO_MAPCHANGE);
    PrintToChatAll("[SM] Map will restart in %f seconds.", seconds);
}

stock RestartMapNow()
{
    // Create a buffer for the current map name
    decl String:currentMap[256];
    // Set the buffer to the current map name
    GetCurrentMap(currentMap, 256);
    // Run 'changelevel' as if RCON to the current map name
    ServerCommand("changelevel %s", currentMap);
}