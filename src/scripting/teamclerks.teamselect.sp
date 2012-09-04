/**
 */

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#include "teamclerks.helpers/clients.inc"

static const String: TEAM_SELECT_SURVIVOR[]       = "surv";
static const String: TEAM_SELECT_INFECTED[]       = "inf";
static const String: TEAM_SELECT_SPECTATOR[]      = "spec";

public _TeamSelect_OnPluginStart()
{
    AddCommandListener(_TS_OnClientCommandIssued, "say");
    AddCommandListener(_TS_OnClientCommandIssued, "say_team");
}

public Action:_TS_OnClientCommandIssued(client, const String:command[], argc)
{
    if (argc < 1)
    {
        return Plugin_Continue;
    }

    decl String:sayWord[MAX_NAME_LENGTH];
    GetCmdArg(1, sayWord, sizeof(sayWord));
    
    if (StrContains(sayWord, "!", false) != 0)
    {
        // We ONLY allow !-commands
        return Plugin_Continue;
    }
    
    decl String:tokens[32][MAX_NAME_LENGTH];
    ExplodeString(sayWord, " ", tokens, 32, MAX_NAME_LENGTH);
    
    if (StrContains(sayWord, TEAM_SELECT_SURVIVOR, false) == 1)
    {
        return Attempt_Swap_To_Survivor(client);
    }
    else if (StrContains(sayWord, TEAM_SELECT_INFECTED, false) == 1)
    {
        return Attempt_Swap_To_Infected(client);
    }
    else if (StrContains(sayWord, TEAM_SELECT_SPECTATOR, false) == 1)
    {
        return Swap_To_Spectator(client);
    }
    
    return Plugin_Continue;
}

/**
 * Attempts to swap the given client to the survivor team.
 */
Action:Attempt_Swap_To_Survivor(client)
{
    new survivorLimit = GetConVarInt(FindConVar("survivor_limit"));
    
    if (!Is_Client_Surivor(client))
    {
        if (Get_Survivor_Player_Count() < survivorLimit)
        {
            ChangeClientTeam(client, TEAM_SURVIVOR);
            return Plugin_Handled;
        }
    
        PrintToChat(client, "Survivor player-limit reached.");
    }
    
    return Plugin_Continue;
}

/**
 * Attempts to swap the given client to the infected team.
 */
Action:Attempt_Swap_To_Infected(client)
{
    new infectedLimit = GetConVarInt(FindConVar("z_max_player_zombies"));
    
    if (!Is_Client_Infected(client))
    {
        if (Get_Infected_Player_Count() < infectedLimit)
        {
            ChangeClientTeam(client, TEAM_INFECTED);
            return Plugin_Handled;
        }
    
        PrintToChat(client, "Infected player-limit reached.");
    }
    
    return Plugin_Continue;
}

/**
 * Swaps the given client to the spectators.
 */
Action:Swap_To_Spectator(client)
{
    if (!Is_Client_Spectator(client))
    {
        ChangeClientTeam(client, TEAM_SPECTATOR);
        return Plugin_Handled;
    }
    
    return Plugin_Continue;
}