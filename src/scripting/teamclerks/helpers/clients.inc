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

// The team list
#define L4D_TEAM_SPECTATOR 1
#define L4D_TEAM_SURVIVOR  2
#define L4D_TEAM_INFECTED  3

// Don't let the script be included more than once.
#if defined _teamclerks_helper_clients
  #endinput
#endif
#define _teamclerks_helper_clients

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
    return Is_Valid_Client(client) && GetClientTeam(client) == L4D_TEAM_SURVIVOR;
}

/**
 * Determines if the given client is 1) a valid player-client and 2) a survivor.
 */
stock bool:Is_Client_Player_Surivor(client)
{
    return Is_Valid_Player_Client(client) && GetClientTeam(client) == L4D_TEAM_SURVIVOR;
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
        if (Is_Client_Player_Surivor(client))
        {
            survivorPlayerCount ++;
        }
    }
    return survivorPlayerCount;
}

/**
 * Determines if the given client is 1) a valid player-client and 2) an infected.
 */
stock bool:Is_Client_Player_Infected(client)
{
    return Is_Valid_Player_Client(client) && GetClientTeam(client) == L4D_TEAM_INFECTED;
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
    return Is_Valid_Player_Client(client) && GetClientTeam(client) == L4D_TEAM_SPECTATOR;
}

/**
 * Returns the number of spectators in the current game.
 */
stock Get_Spectator_Player_Count()
{
    new spectatorPlayerCount = 0;
    for (new client = FIRST_CLIENT; client <= MaxClients; client++)
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
 * Determines if the client is in-game and not a bot and not spec
 */
stock bool:Is_Client_Player_Non_Spec(client)
{
    return IsClientInGame(client) && 
           !IsFakeClient(client) && 
           ((GetClientTeam(client) == L4D_TEAM_SURVIVOR || 
             GetClientTeam(client) == L4D_TEAM_INFECTED));
}

/**
 * Determines the number of maximum human players for a given team.
 */
stock Get_Team_Max_Humans(team)
{
    if(team == L4D_TEAM_SURVIVOR)
    {
        return GetConVarInt(FindConVar("survivor_limit"));
    }
    else if(team == L4D_TEAM_INFECTED)
    {
        return GetConVarInt(FindConVar("z_max_player_zombies"));
    }
    
    return -1;
}

/**
 * Determines the number of humans on a given team.
 */
stock Get_Team_Human_Count(team)
{
    new humans = 0;
    
    new i;
    for(i = 1; i < (MaxClients + 1); i++)
    {
        if(Is_Client_Player_Non_Spec(i) && GetClientTeam(i) == team)
        {
            humans++;
        }
    }
    
    return humans;
}