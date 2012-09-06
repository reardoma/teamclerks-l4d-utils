/*
 * ============================================================================
 *
 *  TeamClerks
 *
 *  File:           clients.inc
 *  Type:           Helper
 *  Description:    Provides client functions for modules
 *
 *  Copyright (C) 2012 kain <kain@teamclerks.net>
 *
 * ============================================================================
 */

// Don't let the script be included more than once.
#if defined _teamclerks_helper_clients
  #endinput
#endif
#define _teamclerks_helper_clients

/**
 * Determines if the given client is a valid player-client (as opposed to a 
 * bot or AI infected).
 */
stock bool:Is_Valid_Client(client)
{
    if (client == 0 || 
        !IsClientConnected(client) || 
        IsFakeClient(client) || 
        !IsClientInGame(client))
    {
        return false;
    }
    return true;
}

/**
 * Determines if the given client is 1) a valid player-client and 2) a survivor.
 */
stock bool:Is_Client_Surivor(client)
{
    return Is_Valid_Client(client) && GetClientTeam(client) == TEAM_SURVIVOR;
}

/**
 * Returns the number of player-controlled survivors in the game currently.
 * This method does NOT count bots, only humans playing survivors.
 */
stock Get_Survivor_Player_Count()
{
    new survivorPlayerCount = 0;
    for (new client = FIRST_CLIENT; client <= MaxClients; client++)
    {
        if (Is_Client_Surivor(client))
        {
            survivorPlayerCount ++;
        }
    }
    return survivorPlayerCount;
}

/**
 * Determines if the given client is 1) a valid player-client and 2) an infected.
 */
stock bool:Is_Client_Infected(client)
{
    return Is_Valid_Client(client) && GetClientTeam(client) == TEAM_INFECTED;
}

/**
 * Returns the number of player-controlled infecteds in the game currently.
 * This method does NOT count bots, only humans playing survivors.
 */
stock Get_Infected_Player_Count()
{
    new infectedPlayerCount = 0;
    for (new client = FIRST_CLIENT; client <= MaxClients; client++)
    {
        if (Is_Client_Infected(client))
        {
            infectedPlayerCount ++;
        }
    }
    return infectedPlayerCount;
}

/**
 * Determines if the given client is 1) a valid player-client and 2) a spectator.
 */
stock bool:Is_Client_Spectator(client)
{
    return Is_Valid_Client(client) && GetClientTeam(client) == TEAM_SPECTATOR;
}

/**
 * Returns the number of spectators in the current game.
 */
stock Get_Spectator_Player_Count()
{
    new spectatorPlayerCount = 0;
    for (new client = FIRST_CLIENT; client <= MaxClients; client++)
    {
        if (Is_Client_Spectator(client))
        {
            spectatorPlayerCount ++;
        }
    }
    return spectatorPlayerCount;
}

/**
 * Determines whether there are any valid player-clients in the server (infected,
 * survivor, or spectator).
 */
stock bool:Server_Has_Player_Clients()
{
    return (Get_Spectator_Player_Count() +
            Get_Survivor_Player_Count() + 
            Get_Infected_Player_Count()) > 0;
}