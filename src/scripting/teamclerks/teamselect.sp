/**
 * TeamSelect allows a player-client to issue commands to swap teams
 * even when team-switching has reached its limit.
 */

// Don't let the script be included more than once.
#if defined _teamclerks_teamselect
  #endinput
#endif
#define _teamclerks_teamselect

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
    new maxSurvivorSlots = Get_Team_Max_Humans(TEAM_SURVIVOR);
    new survivorUsedSlots = Get_Survivor_Player_Count();
    new freeSurvivorSlots = (maxSurvivorSlots - survivorUsedSlots);

    if (GetClientTeam(client) == TEAM_SURVIVOR)
    {
        PrintToChat(client, "[SM] You are already on the Survivor team.");
        return Plugin_Handled;
    }
    if (freeSurvivorSlots <= 0)
    {
        PrintToChat(client, "[SM] Survivor team is full.");
        return Plugin_Handled;
    }
    else
    {
        new localClientTeam = GetClientTeam(client);
        new flags = GetCommandFlags("sb_takecontrol");
        SetCommandFlags("sb_takecontrol", flags & ~FCVAR_CHEAT);
        new String:botNames[][] = { "teengirl", "manager", "namvet", "biker" };
        
        new i = 0;
        while((localClientTeam != TEAM_SURVIVOR) && i < 4)
        {
            FakeClientCommand(client, "sb_takecontrol %s", botNames[i]);
            localClientTeam = GetClientTeam(client);
            i++;
        }
        SetCommandFlags("sb_takecontrol", flags);
    }
    return Plugin_Handled;
}

/**
 * Attempts to swap the given client to the infected team.
 */
public Action:Attempt_Swap_To_Infected(client, const String:command[], argc)
{
    new infectedLimit = GetConVarInt(FindConVar("z_max_player_zombies"));
    
    if (!Is_Client_Player_Infected(client))
    {
        if (Get_Infected_Player_Count() < infectedLimit)
        {
            decl String:clientname[64];
            GetClientName(client, clientname, sizeof(clientname));
            TC_Debug("Moving %s to infected team.", clientname);
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
    if (!Is_Client_Player_Spectator(client))
    {
        decl String:clientname[64];
        GetClientName(client, clientname, sizeof(clientname));
        TC_Debug("Moving %s to spectator team.", clientname);
        ChangeClientTeam(client, TEAM_SPECTATOR);
        return Plugin_Handled;
    }
    
    return Plugin_Continue;
}