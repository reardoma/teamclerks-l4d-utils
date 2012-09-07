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
    
    if (!Is_Client_Player_Surivor(client))
    {
        if (Get_Survivor_Player_Count() < survivorLimit)
        {
            // Can't just swap to survivor... have to take control of a bot.

            // Get all survivors (bots and players)
            decl survArray[MaxClients];
            new survCount = 0;
            for (new aClient = FIRST_CLIENT; aClient <= MaxClients; aClient++)
            {
                if (Is_Client_Survivor(aClient))
                {
                    survArray[survCount] = aClient;
                    survCount ++;
                }
            }
            // get survivor botcount and save ids
            decl botArray[16];
            new botCount;
            for (new i = 0; i < survCount; i++)
            {
                    if (!IsFakeClient(survArray[i])) continue;
                    botArray[botCount] = survArray[i];
                    botCount++;
            }
            
            // A bot might not be there by here... oh well
            if (botCount == 0)
            {
                ReplyToCommand(client, "Survivor player-limit reached.");
                return Plugin_Continue;
            }

            new flags = GetCommandFlags("sb_takecontrol");
            decl String:survivor[MAX_NAME_LENGTH];
            GetClientName(botArray[0], survivor, MAX_NAME_LENGTH);
            
            // take the first bot
            if (IsClientInGame(botArray[0]) && IsClientInGame(client))
            {
                // Turn this off as a cheat
                SetCommandFlags("sb_takecontrol", flags & ~FCVAR_CHEAT);
                FakeClientCommandEx(client, "sb_takecontrol %s", survivor);
                // Turn this back on as a cheat
                SetCommandFlags("sb_takecontrol", flags | FCVAR_CHEAT);
                
                return Plugin_Handled;
            }
            
            // Oh well, they left or the bot's full...
            return Plugin_Continue;
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
    
    if (!Is_Client_Player_Infected(client))
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
    if (!Is_Client_Player_Spectator(client))
    {
        ChangeClientTeam(client, TEAM_SPECTATOR);
        return Plugin_Handled;
    }
    
    return Plugin_Continue;
}