/**
 * TeamSelect allows a player-client to issue commands to swap teams
 * even when team-switching has reached its limit.
 */

new Handle:gConf = INVALID_HANDLE;
new Handle:fSHS = INVALID_HANDLE;
new Handle:fTOB = INVALID_HANDLE;

static const String: TEAM_SELECT_SURVIVOR[]       = "surv";
static const String: TEAM_SELECT_INFECTED[]       = "inf";
static const String: TEAM_SELECT_SPECTATOR[]      = "spec";

public _TeamSelect_OnPluginStart()
{
    PrepareAllSDKCalls();
    
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
            TC_Debug("Attempting bot takeover...");
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
            
            TC_Debug("Bot exists from which to take control.");

            decl String:survivor[MAX_NAME_LENGTH];
            GetClientName(botArray[0], survivor, MAX_NAME_LENGTH);
            
            // take the first bot
            if (IsClientInGame(botArray[0]) && IsClientInGame(client))
            {
                decl String:clientname[64];
                GetClientName(client, clientname, sizeof(clientname));
                TC_Debug("Moving %s to survivor team.", clientname);
                //have to do this to give control of a survivor bot
                SDKCall(fSHS, botArray[0], client);
                SDKCall(fTOB, client, true);

                TC_Debug("Bot takeover completed.");
                
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

PrepareAllSDKCalls()
{
    gConf = LoadGameConfigFile("left4downtown");
    if(gConf == INVALID_HANDLE)
    {
        TC_Debug("Could not load gamedata/left4downtown.txt");
    }
    
    StartPrepSDKCall(SDKCall_Player);
    PrepSDKCall_SetFromConf(gConf, SDKConf_Signature, "SetHumanSpec");
    PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
    fSHS = EndPrepSDKCall();
    
    StartPrepSDKCall(SDKCall_Player);
    PrepSDKCall_SetFromConf(gConf, SDKConf_Signature, "TakeOverBot");
    PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
    fTOB = EndPrepSDKCall();
}