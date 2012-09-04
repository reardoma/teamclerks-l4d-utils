/**
 * TeamSelect allows a player-client to issue commands to swap teams
 * even when team-switching has reached its limit.
 */

static const String: TEAM_SELECT_SURVIVOR[]       = "surv";
static const String: TEAM_SELECT_INFECTED[]       = "inf";
static const String: TEAM_SELECT_SPECTATOR[]      = "spec";

public _TeamSelect_OnPluginStart()
{
    AddCommandListenerEx(Attempt_Swap_To_Survivor, TEAM_SELECT_SURVIVOR);
    AddCommandListenerEx(Attempt_Swap_To_Infected, TEAM_SELECT_INFECTED);
    AddCommandListenerEx(Swap_To_Spectator, TEAM_SELECT_SPECTATOR);
}

/**
 * Attempts to swap the given client to the survivor team.
 */
public Action:Attempt_Swap_To_Survivor(client, const String:command[], argc)
{
    new survivorLimit = GetConVarInt(FindConVar("survivor_limit"));
    
    if (!Is_Client_Surivor(client))
    {
        if (Get_Survivor_Player_Count() < survivorLimit)
        {
            ChangeClientTeam(client, TEAM_SURVIVOR);
            return Plugin_Handled;
        }
    
        ReplyToCommand(client, "Survivor player-limit reached.");
    }
    
    return Plugin_Continue;
}

/**
 * Attempts to swap the given client to the infected team.
 */
public Action:Attempt_Swap_To_Infected(client, const String:command[], argc)
{
    new infectedLimit = GetConVarInt(FindConVar("z_max_player_zombies"));
    
    if (!Is_Client_Infected(client))
    {
        if (Get_Infected_Player_Count() < infectedLimit)
        {
            ChangeClientTeam(client, TEAM_INFECTED);
            return Plugin_Handled;
        }
    
        ReplyToCommand(client, "Infected player-limit reached.");
    }
    
    return Plugin_Continue;
}

/**
 * Swaps the given client to the spectators.
 */
public Action:Swap_To_Spectator(client, const String:command[], argc)
{
    if (!Is_Client_Spectator(client))
    {
        ChangeClientTeam(client, TEAM_SPECTATOR);
        return Plugin_Handled;
    }
    
    return Plugin_Continue;
}