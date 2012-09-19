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

// The team list
#define TEAM_SPECTATOR 1
#define TEAM_SURVIVOR  2
#define TEAM_INFECTED  3

/**
 * Determines if the given client is a valid player-client (as opposed to a 
 * bot or AI infected).
 */
stock bool:Is_Valid_Player_Client(client)
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
 * Determines if the given client is a valid client, but NOT a valid player 
 * client, which would mean that the given client is a bot.
 */
stock bool:Is_Valid_Bot_Client(client)
{
    return Is_Valid_Client(client) && !Is_Valid_Player_Client(client);
}

/**
 * Determines if the given client is valid (Must be a bot or a player).
 */
stock bool:Is_Valid_Client(client)
{
    if (client == 0 || 
        !IsClientConnected(client) || 
        !IsClientInGame(client))
    {
        return false;
    }
    return true;
}

/**
 * Determines if the given client is a survivor (allows for bots).
 */
stock bool:Is_Client_Survivor(client)
{
    return Is_Valid_Client(client) && GetClientTeam(client) == TEAM_SURVIVOR;
}

/**
 * Determines if the given client is 1) a valid player-client and 2) a survivor.
 */
stock bool:Is_Client_Player_Survivor(client)
{
    return Is_Valid_Player_Client(client) && GetClientTeam(client) == TEAM_SURVIVOR;
}

/**
 * Returns the number of player-controlled survivors in the game currently.
 * This method does NOT count bots, only humans playing survivors.
 */
stock Get_Survivor_Player_Count()
{
    new survivorPlayerCount = 0;
    for (new client = 1; client <= MaxClients; client++)
    {
        if (Is_Client_Player_Survivor(client))
        {
            survivorPlayerCount ++;
        }
    }
    return survivorPlayerCount;
}

/**
 * Determines if the given client is an infected.
 */
stock bool:Is_Client_Infected(client)
{
    return Is_Valid_Client(client) && GetClientTeam(client) == TEAM_INFECTED;
}

/**
 * Determines if the given client is 1) a valid player-client and 2) an infected.
 */
stock bool:Is_Client_Player_Infected(client)
{
    return Is_Valid_Player_Client(client) && GetClientTeam(client) == TEAM_INFECTED;
}

/**
 * Returns the number of player-controlled infecteds in the game currently.
 * This method does NOT count bots, only humans playing survivors.
 */
stock Get_Infected_Player_Count()
{
    new infectedPlayerCount = 0;
    for (new client = 1; client <= MaxClients; client++)
    {
        if (Is_Client_Player_Infected(client))
        {
            infectedPlayerCount ++;
        }
    }
    return infectedPlayerCount;
}

/**
 * Determines if the given client is 1) a valid player-client and 2) a spectator.
 */
stock bool:Is_Client_Player_Spectator(client)
{
    return Is_Valid_Player_Client(client) && GetClientTeam(client) == TEAM_SPECTATOR;
}

/**
 * Returns the number of spectators in the current game.
 */
stock Get_Spectator_Player_Count()
{
    new spectatorPlayerCount = 0;
    for (new client = 1; client <= MaxClients; client++)
    {
        if (Is_Client_Player_Spectator(client))
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

/**
 * Determines the number of maximum human players for a given team.
 */
stock Get_Team_Max_Humans(team)
{
    new survivorLimit = GetConVarInt(FindConVar("survivor_limit"));
    new infectedLimit = GetConVarInt(FindConVar("z_max_player_zombies"));
    
    if(team == TEAM_SURVIVOR)
    {
        return survivorLimit;
    }
    else if(team == TEAM_INFECTED)
    {
        return infectedLimit;
    }
    
    return -1;
}