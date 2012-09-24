/**
 * TeamSelect allows a player-client to issue commands to swap teams
 * even when team-switching has reached its limit.
 */

// Don't let the script be included more than once.
#if defined _teamclerks_teamselect
  #endinput
#endif
#define _teamclerks_teamselect

static const String: TEAM_SELECT_SURV[]           = "surv";
static const String: TEAM_SELECT_SURVIVOR[]       = "survivor";
static const String: TEAM_SELECT_INF[]            = "inf";
static const String: TEAM_SELECT_INFECTED[]       = "infected";
static const String: TEAM_SELECT_SPEC[]           = "spec";
static const String: TEAM_SELECT_SPECTATOR[]      = "spectator";

public _TeamSelect_OnPluginStart()
{    
    AddCommandListenerEx(Attempt_Swap_To_Survivor, TEAM_SELECT_SURV);
    AddCommandListenerEx(Attempt_Swap_To_Survivor, TEAM_SELECT_SURVIVOR);
    AddCommandListenerEx(Attempt_Swap_To_Infected, TEAM_SELECT_INF);
    AddCommandListenerEx(Attempt_Swap_To_Infected, TEAM_SELECT_INFECTED);
    AddCommandListenerEx(Swap_To_Spectator, TEAM_SELECT_SPEC);
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
    }
    else if (freeSurvivorSlots <= 0)
    {
        PrintToChat(client, "[SM] Survivor team is full.");
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
            if (!IsPlayerAlive(client))
            {
                // This is kind of dirty, but it will continue the loop even
                // the client got a dead survivor and try to find a living
                // one; if there are no living ones, then the player is stuck
                // playing the dead one.
                localClientTeam = TEAM_SPECTATOR;
            }
            i++;
        }
        SetCommandFlags("sb_takecontrol", flags);
        
        // They MAY have swapped out to spawn in a bot infected... kill that bot.
        for (i = 1; i < MaxClients; i++)
        {
            if (Is_Client_Infected(i) && !Is_Valid_Player_Client(i))
            {
                // This is a bot infected.
                ForcePlayerSuicide(i);
            }
        }
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

        // They MAY have swapped out to spawn in a bot infected... kill that bot.
        for (new i = 1; i < MaxClients; i++)
        {
            if (Is_Client_Infected(i) && !Is_Valid_Player_Client(i))
            {
                // This is a bot infected.
                ForcePlayerSuicide(i);
            }
        }
        
        return Plugin_Handled;
    }
    
    return Plugin_Continue;
}