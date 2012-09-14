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
    new maxSurvivorSlots = Get_Team_Max_Humans(2);
    new survivorUsedSlots = Get_Team_Human_Count(2);
    new freeSurvivorSlots = (maxSurvivorSlots - survivorUsedSlots);
    //debug
    //PrintToChatAll("Number of Survivor Slots %d.\nNumber of Survivor Players %d.\nNumber of Free Slots %d.", maxSurvivorSlots, survivorUsedSlots, freeSurvivorSlots);
    
    if (GetClientTeam(client) == 2)         //if client is survivor
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
        new bot;
        
        for(bot = 1; 
            bot < (MaxClients + 1) && (!IsClientConnected(bot) || !IsFakeClient(bot) || (GetClientTeam(bot) != L4D_TEAM_SURVIVOR));
            bot++) {}
        
        if(bot == (MaxClients + 1))
        {           
            new String:newCommand[] = "sb_add";
            new flags = GetCommandFlags(newCommand);
            SetCommandFlags(newCommand, flags & ~FCVAR_CHEAT);
            
            ServerCommand("sb_add");
            
            SetCommandFlags(newCommand, flags);
        }
        CreateTimer(0.1, Survivor_Take_Control, client, TIMER_FLAG_NO_MAPCHANGE);
    }
    return Plugin_Handled;
}

public Action:Survivor_Take_Control(Handle:timer, any:client)
{
        new localClientTeam = GetClientTeam(client);
        new String:command[] = "sb_takecontrol";
        new flags = GetCommandFlags(command);
        SetCommandFlags(command, flags & ~FCVAR_CHEAT);
        new String:botNames[][] = { "teengirl", "manager", "namvet", "biker" };
        
        new i = 0;
        while((localClientTeam != L4D_TEAM_SURVIVOR) && i < 4)
        {
            FakeClientCommand(client, "sb_takecontrol %s", botNames[i]);
            localClientTeam = GetClientTeam(client);
            i++;
        }
        SetCommandFlags(command, flags);
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