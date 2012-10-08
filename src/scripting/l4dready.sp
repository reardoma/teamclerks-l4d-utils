/**
 * L4D RUP, modded by Jackpf.
 *  Changes:
 *      Spectators no longer need to ready up, and are displayed at the bottom of the panel, controlled by a cvar.
 *      The league notice is defined by a cvar.
 *      The live countdown interval is defined by a cvar.
 *      (dev) No round restart after ready, controlled by a cvar.
 *      Various code optimisations.
 *      Support for ?v? cfgs.
*/

#if defined _l4do_included
 #endinput
#endif
#define _l4do_included

#include <sourcemod>

/**
 * @brief Called whenever ZombieManager::SpawnTank(Vector&,QAngle&) is invoked
 * @remarks Not invoked if z_spawn tank is used and it gives a ghosted/dead player tank
 *
 * @param vector    Vector coordinate where tank is spawned
 * @param qangle    QAngle where tank will be facing
 * @return      Pl_Handled to block tank from spawning, Pl_Continue otherwise.
 */
forward Action:L4D_OnSpawnTank(const Float:vector[3], const Float:qangle[3]);

/**
 * @brief Called whenever ZombieManager::SpawnWitch(Vector&,QAngle&) is invoked
 *
 * @param vector    Vector coordinate where witch is spawned
 * @param qangle    QAngle where witch will be facing
 * @return      Pl_Handled to block witch from spawning, Pl_Continue otherwise.
 */
forward Action:L4D_OnSpawnWitch(const Float:vector[3], const Float:qangle[3]);

/**
 * @brief Called whenever CDirector::OnFirstSurvivorLeftSafeArea
 * @remarks A versus round is started when survivors leave the safe room, or force started
 *          after 90 seconds regardless.
 * 
 * @param client  the survivor that left the safe area first
 * 
 * @return      Pl_Handled to block round from being started, Pl_Continue otherwise.
 */
forward Action:L4D_OnFirstSurvivorLeftSafeArea(client);

/**
 * @brief Get the team scores for the current map
 * @remarks The campaign scores are not set until the end of round 2,
 *           use L4D_GetCampaignScores to get them earlier.
 *
 * @deprecated This function can be called through SDKTools using CTerrorGameRules,
 *          and so you should switch off to using SDKTools instead of this native.
 * 
 * @param logical_team  0 for A, 1 for B
 * @param campaign_score  true to get campaign score instead of map score
 * @return      the logical team's map score 
 *                      or -1 if the team hasn't played the round yet,
 *                or the team's campaign score if campaign_score = true
 */
native L4D_GetTeamScore(logical_team, campaign_score=false);

/**
 * @brief Restarts the round, switching the map if necessary
 * @remarks Set the map to the current map to restart the round
 * 
 * @param map  the mapname it should go to after the round restarts
 * @return     1 always
 */
native L4D_RestartScenarioFromVote(const String:map[]);

/**
 * @brief Removes lobby reservation from a server
 * @remarks Sets the reservation cookie to 0,
 *           it is safe to call this even if it's unreserved.
 */
native L4D_LobbyUnreserve();

/**
 * @brief Checks if the server is currently reserved for a lobby
 * @remarks Server is automatically unreserved if it hibernates or
 *          if all players leave.
 *
 * @deprecated This will always return false on L4D2 or on Linux.
 *
 * @return     true if reserved, false if not reserved
 */
native bool:L4D_LobbyIsReserved();

/*
Makes the extension required by the plugins, undefine REQUIRE_EXTENSIONS
if you want to use it optionally before including this .inc file
*/
public Extension:__ext_geoip = 
{
    name = "Left 4 Downtown",
    file = "left4downtown.ext",
#if defined AUTOLOAD_EXTENSIONS
    autoload = 1,
#else
    autoload = 0,
#endif
#if defined REQUIRE_EXTENSIONS
    required = 1,
#else
    required = 0,
#endif
};

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

/*
* PROGRAMMING CREDITS:
* Could not do this without Fyren at all, it was his original code chunk 
*   that got me started (especially turning off directors and freezing players).
*   Thanks to him for answering all of my silly coding questions too.
* 
* TESTING CREDITS:
* 
* Biggest #1 thanks goes out to Fission for always being there since the beginning
* even when this plugin was barely working.
*/

#define READY_DEBUG 0
#define READY_DEBUG_LOG 0

#define READY_VERSION "0.23.TC"
//#define READY_LIVE_COUNTDOWN 0 //5
#define READY_UNREADY_HINT_PERIOD 10.0
#define READY_LIST_PANEL_LIFETIME 10
#define READY_RESTART_ROUND_DELAY 5.0
#define READY_RESTART_MAP_DELAY 2.0

#define READY_VERSION_REQUIRED_SOURCEMOD "1.3.1"
#define READY_VERSION_REQUIRED_SOURCEMOD_NONDEV 1 //1 dont allow -dev version, 0 ignore -dev version
#define READY_VERSION_REQUIRED_LEFT4DOWNTOWN "0.3.1"

#define L4D_TEAM_SURVIVORS 2
#define L4D_TEAM_INFECTED 3
#define L4D_TEAM_SPECTATE 1

//stuff from rotoblin report status
#define REPORT_STATUS_MAX_MSG_LENGTH 1024

#define HEALTH_BONUS_FIX 1

#if HEALTH_BONUS_FIX

#define EBLOCK_DEBUG READY_DEBUG

#define EBLOCK_BONUS_UPDATE_DELAY 0.01

#define EBLOCK_VERSION "0.1.2"

#if EBLOCK_DEBUG
#define EBLOCK_BONUS_HEALTH_BUFFER 10.0
#else
#define EBLOCK_BONUS_HEALTH_BUFFER 1.0
#endif

#define EBLOCK_USE_DELAYED_UPDATES 0
#define LEAGUE_ADD_NOTICE 1

new bool:painPillHolders[256];
#endif

/*
* TEST - should be fixed: the "error more than 1 witch spawned in a single round"
*  keeps being printed
* even though there isnt an extra witch being spawned or w/e
*/

new bool:readyMode; //currently waiting for players to ready up?

new goingLive; //0 = not going live, 1 or higher = seconds until match starts

new bool:votesUnblocked;
new insideCampaignRestart; //0=normal play, 1 or 2=programatically restarting round
new bool:isCampaignBeingRestarted;

new forcedStart;
new readyStatus[MAXPLAYERS + 1];

//new bool:menuInterrupted[MAXPLAYERS + 1];
new Handle:menuPanel = INVALID_HANDLE;

new Handle:liveTimer;
new bool:unreadyTimerExists;

new Handle:cvarEnforceReady = INVALID_HANDLE;
//new Handle:cvarReadyCompetition = INVALID_HANDLE;
new Handle:cvarReadyMinimum = INVALID_HANDLE;
new Handle:cvarReadyHalves = INVALID_HANDLE;
new Handle:cvarReadyServerCfg = INVALID_HANDLE;
new Handle:cvarReadySpectatorRUP = INVALID_HANDLE;
new Handle:cvarReadyRestartRound = INVALID_HANDLE;
new Handle:cvarReadyLeagueNotice = INVALID_HANDLE;
new Handle:cvarReadyLiveCountdown = INVALID_HANDLE;
new Handle:cvarReadySearchKeyDisable = INVALID_HANDLE;
new Handle:cvarSearchKey = INVALID_HANDLE;

//new way of readying up?
new Handle:cvarReadyUpStyle = INVALID_HANDLE;

new Handle:cvarReadyCommonLimit = INVALID_HANDLE;
new Handle:cvarReadyMegaMobSize = INVALID_HANDLE;
new Handle:cvarReadyAllBotTeam  = INVALID_HANDLE;

new Handle:fwdOnReadyRoundRestarted = INVALID_HANDLE;

new hookedPlayerHurt; //if we hooked player_hurt event?

new pauseBetweenHalves; //should we ready up before starting the 2nd round or go live right away
new bool:isSecondRound;

new bool:isMapRestartPending;

//stuff from zack_netinfo
static          bool:   g_bCooldown[MAXPLAYERS + 1];
//
//fix spec calling !reready
static          bool:   g_bIsSpectating[MAXPLAYERS + 1];

//cooldown for sm_reready, and cvar handle to disable reready
static          bool:   g_bCooldownReready                  = false;
static          bool:   g_bAllowReready                     = true;
static          Handle:cvarAllowReready                     = INVALID_HANDLE;

//workaround for the spec/inf bug
static          bool:infectedSpectator[MAXPLAYERS + 1];
static          g_iSpectatePenalty                          = 7;
static          g_iSpectatePenaltyCounter[MAXPLAYERS + 1];
static          Handle:cvarSpectatePenalty                  = INVALID_HANDLE;
//stuff from griffins rup edit
static          g_iRespecCooldownTime                       = 60;
static          g_iLastRespecced[MAXPLAYERS + 1];
//stuff from rotoblin report status
static  const           MAX_CONVAR_NAME_LENGTH                          = 64;
static  const           CVAR_ARRAY_BLOCK                                = 2;
static  const           FIRST_CVAR_IN_ARRAY                             = 0;
static          Handle: g_aConVarArray                                  = INVALID_HANDLE;
static          bool:   g_bIsArraySetup                                 = false;

static  const   Float:  CACHE_RESULT_TIME                               = 5.0;
static          bool:   g_bIsResultCached                               = false;
static          String: g_sResultCache[REPORT_STATUS_MAX_MSG_LENGTH]    = "";

public Plugin:myinfo =
{
    name = "L4D Ready Up",
    author = "Downtown1, modded by Jackpf",
    description = "Force Players to Ready Up Before Beginning Match",
    version = READY_VERSION,
    url = "http://forums.alliedmods.net/showthread.php?t=84086"
};

public OnPluginStart()
{
    LoadTranslations("common.phrases");
    
    //case-insensitive handling of ready,unready,notready
    RegConsoleCmd("say", Command_Say);
    RegConsoleCmd("say_team", Command_Say);

    RegConsoleCmd("sm_ready", readyUp);
    RegConsoleCmd("sm_unready", readyDown);
    RegConsoleCmd("sm_notready", readyDown); //alias for people who are bad at reading instructions
    
    RegConsoleCmd("sm_rates", ratesCommand);    //Prints net information about players
    RegConsoleCmd("zack_netinfo", ratesCommand);    //Some people...
    
    RegConsoleCmd("sm_sur", Join_Survivor);
    RegConsoleCmd("sm_inf", Join_Infected);
    RegConsoleCmd("sm_survivor", Join_Survivor);
    RegConsoleCmd("sm_infected", Join_Infected);
    
    //block all voting if we're enforcing ready mode
    //we only temporarily allow votes to fake restart the campaign
    RegConsoleCmd("callvote", callVote);
    
    RegConsoleCmd("sm_spec", Command_Spectate);
    RegConsoleCmd("sm_spectate", Command_Spectate);
    RegConsoleCmd("spectate", Command_Spectate);
    RegConsoleCmd("sm_respec", Respec_Client);
    RegConsoleCmd("sm_respectate", Respec_Client);
    
    #if READY_DEBUG
    RegConsoleCmd("unfreezeme1", Command_Unfreezeme1);  
    RegConsoleCmd("unfreezeme2", Command_Unfreezeme2);  
    RegConsoleCmd("unfreezeme3", Command_Unfreezeme3);  
    RegConsoleCmd("unfreezeme4", Command_Unfreezeme4);
    
    RegConsoleCmd("sm_printclients", printClients);
    
    RegConsoleCmd("sm_votestart", SendVoteRestartStarted);
    RegConsoleCmd("sm_votepass", SendVoteRestartPassed);
    
    RegConsoleCmd("sm_whoready", readyWho);
    
    RegConsoleCmd("sm_drawready", readyDraw);
    
    RegConsoleCmd("sm_dumpentities", Command_DumpEntities);
    RegConsoleCmd("sm_dumpgamerules", Command_DumpGameRules);
    RegConsoleCmd("sm_scanproperties", Command_ScanProperties);
    
    RegAdminCmd("sm_begin", compReady, ADMFLAG_BAN, "sm_begin");
    #endif
    
    RegAdminCmd("sm_restartmap", CommandRestartMap, ADMFLAG_CHANGEMAP, "sm_restartmap - changelevels to the current map");
    RegAdminCmd("sm_restartround", FakeRestartVoteCampaign, ADMFLAG_CHANGEMAP, "sm_restartround - executes a restart campaign vote and makes everyone votes yes");
    
    RegAdminCmd("sm_abort", compAbort, ADMFLAG_BAN, "sm_abort");
    RegAdminCmd("sm_forcestart", compStart, ADMFLAG_BAN, "sm_forcestart");
    RegAdminCmd("sm_unreready", Command_Unreready, ADMFLAG_BAN, "sm_unreready - cancel an active sm_reready");
    //sm_switch
    RegAdminCmd("sm_switch", Switch_Client, ADMFLAG_BAN, "sm_switch <player1> <player2> - switch A to B's team, and B to A's team.");
    
    HookEvent("round_start", eventRSLiveCallback);
    HookEvent("round_end", eventRoundEndCallback);
    
    HookEvent("player_bot_replace", eventPlayerBotReplaceCallback);
    HookEvent("bot_player_replace", eventBotPlayerReplaceCallback);
    HookEvent("player_team", eventPlayerTeamCallback);
    
    HookEvent("player_spawn", eventSpawnReadyCallback);
    HookEvent("tank_spawn", Event_TankSpawn);
    HookEvent("witch_spawn", Event_WitchSpawn);
    HookEvent("player_left_start_area", Event_PlayerLeftStartArea);
    
    #if READY_DEBUG
    HookEvent("vote_started", eventVoteStarted);
    HookEvent("vote_passed", eventVotePassed);
    HookEvent("vote_ended", eventVoteEnded);
    
    new Handle:NoBosses = FindConVar("director_no_bosses");
    HookConVarChange(NoBosses, ConVarChange_DirectorNoBosses);
    #endif
    
    
    fwdOnReadyRoundRestarted = CreateGlobalForward("OnReadyRoundRestarted", ET_Event);
    
    CreateConVar("l4d_ready_version", READY_VERSION, "Version of the ready up plugin.", FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_NOTIFY);
    cvarEnforceReady = CreateConVar("l4d_ready_enabled", "1", "Make players ready up before a match begins", FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_NOTIFY);
    //cvarReadyCompetition = CreateConVar("l4d_ready_competition", "0", "Disable all plugins but a few competition-allowed ones", FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_NOTIFY);
    cvarReadyHalves = CreateConVar("l4d_ready_both_halves", "0", "Make players ready up both during the first and second rounds of a map", FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_NOTIFY);
    cvarReadyMinimum = CreateConVar("l4d_ready_minimum_players", "8", "Minimum # of players before we can ready up", FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_NOTIFY);
    cvarReadyServerCfg = CreateConVar("l4d_ready_server_cfg", "", "Config to execute when the map is changed (to exec after server.cfg).", FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_NOTIFY);
    cvarReadySearchKeyDisable = CreateConVar("l4d_ready_search_key_disable", "0", "Automatically disable plugin if sv_search_key is blank", FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_NOTIFY);
    cvarReadyLeagueNotice = CreateConVar("l4d_ready_league_notice", "", "League notice displayed on RUP panel", FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_NOTIFY);
    cvarReadyLiveCountdown = CreateConVar("l4d_ready_live_countdown", "0", "Countdown timer to begin the round", FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_NOTIFY);
    cvarReadySpectatorRUP = CreateConVar("l4d_ready_spectator_rup", "0", "Whether or not spectators have to ready up", FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_NOTIFY);
    cvarReadyRestartRound = CreateConVar("l4d_ready_restart_round", "1", "Whether or not to restart the campaign after readying up (dev)", FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_NOTIFY);
    cvarReadyCommonLimit = CreateConVar("l4d_ready_common_limit", "30", "z_common_limit value after rup", FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_NOTIFY);
    cvarReadyMegaMobSize = CreateConVar("l4d_ready_mega_mob_size", "30", "z_mega_mob_size value after rup", FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_NOTIFY);
    cvarReadyAllBotTeam = CreateConVar("l4d_ready_all_bot_team", "0", "sb_all_bot_team value after rup", FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_NOTIFY);
    //new way of readying up?
    cvarReadyUpStyle = CreateConVar("l4d_ready_up_style", "0", "0 = old style, 1 = infected can move during rup, players can move after rup", FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_NOTIFY);
    //added to enable blocking sm_reready
    cvarAllowReready = CreateConVar("l4d_ready_allow_reready", "1", "Allow players to use sm_reready.", FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_NOTIFY);
    HookConVarChange(cvarAllowReready, ConVarChange_AllowReready);
    //added to be able to set the !spectate !inf penalty
    cvarSpectatePenalty = CreateConVar("l4d_ready_spectate_penalty", "8", "Time in seconds an infected player can't rejoin the infected team.", FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_NOTIFY);
    HookConVarChange(cvarSpectatePenalty, ConVarChange_cvarSpectatePenalt);
    
    CheckAllowReready();
    CheckSpectatePenalty();
    
    cvarSearchKey = FindConVar("sv_search_key");
    
    HookConVarChange(cvarEnforceReady, ConVarChange_ReadyEnabled);
    //HookConVarChange(cvarReadyCompetition, ConVarChange_ReadyCompetition);
    HookConVarChange(cvarSearchKey, ConVarChange_SearchKey);
    
    #if HEALTH_BONUS_FIX
    CreateConVar("l4d_eb_health_bonus", EBLOCK_VERSION, "Version of the Health Bonus Exploit Blocker", FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_NOTIFY|FCVAR_REPLICATED);
    
    HookEvent("item_pickup", Event_ItemPickup); 
    HookEvent("pills_used", Event_PillsUsed);
    HookEvent("heal_success", Event_HealSuccess);
    
    HookEvent("round_start", Event_RoundStart);
    
    #if EBLOCK_DEBUG
    RegConsoleCmd("sm_updatehealth", Command_UpdateHealth);
    
    //RegConsoleCmd("sm_givehealth", Command_GiveHealth);
    #endif
    #endif
    
    AddCommandListener(Version_Command, "l4d_ready_version");
    
    AddConVarToReport(cvarReadyHalves);
    AddConVarToReport(cvarReadyMinimum);
    AddConVarToReport(cvarReadyServerCfg);
    AddConVarToReport(cvarReadyUpStyle);
    AddConVarToReport(cvarReadyLeagueNotice);
    AddConVarToReport(cvarReadyLiveCountdown);
    AddConVarToReport(cvarReadySpectatorRUP);
    AddConVarToReport(cvarReadyRestartRound);
    AddConVarToReport(cvarReadyCommonLimit);
    AddConVarToReport(cvarReadyMegaMobSize);
    AddConVarToReport(cvarReadyAllBotTeam);
    AddConVarToReport(cvarAllowReready);
    AddConVarToReport(cvarSpectatePenalty);
}
//sm_switch
public Action:Switch_Client(client, args)
{
    if(args < 2)
    {
        ReplyToCommand(client, "[SM] Usage: sm_switch <player1> <player2> - switch both players to the opposite team.");        
        return Plugin_Handled;
    }
    decl String:player1[64];
    decl String:player2[64];
    GetCmdArg(1, player1, sizeof(player1));
    GetCmdArg(2, player2, sizeof(player2));
    
    new target1 = FindTarget(client, player1, true /*nobots*/, false /*immunity*/);
    new target2 = FindTarget(client, player2, true /*nobots*/, false /*immunity*/);
    
    if((target1 == -1) || (target2 == -1)) return Plugin_Handled;
    
    new targetTeamA = GetClientTeam(target1);
    new targetTeamB = GetClientTeam(target2);
    
    if (targetTeamA == targetTeamB)
    {
        if(client != 0)
        PrintToChat(client, "[SM] Both players are on the same team.");
        return Plugin_Handled;
    }
        
    if((target1 != -1) && (target2 != -1))
    {
        new String:player1Name[64];
        new String:player2Name[64];
        GetClientName(target1, player1Name, sizeof(player1Name));
        GetClientName(target2, player2Name, sizeof(player2Name));

        if (targetTeamA != 1) ChangeClientTeam(target1, 1);
        if (targetTeamB != 1) ChangeClientTeam(target2, 1);
        
        if (targetTeamA == 1) PrintToChatAll("[SM] %s has been swapped to the Spectator team.", player2Name);
        if (targetTeamB == 1) PrintToChatAll("[SM] %s has been swapped to the Spectator team.", player1Name);
        if (targetTeamA == 2) CreateTimer(0.1, SwitchTargetSurvivor, target2, TIMER_FLAG_NO_MAPCHANGE);
        if (targetTeamA == 3) CreateTimer(0.1, SwitchTargetInfected, target2, TIMER_FLAG_NO_MAPCHANGE);
        if (targetTeamB == 2) CreateTimer(0.1, SwitchTargetSurvivor, target1, TIMER_FLAG_NO_MAPCHANGE);
        if (targetTeamB == 3) CreateTimer(0.1, SwitchTargetInfected, target1, TIMER_FLAG_NO_MAPCHANGE);
        return Plugin_Handled;
    }
    return Plugin_Handled;
}

public Action:SwitchTargetSurvivor(Handle:timer, any:target)
{
    new String:playerName[64];
    GetClientName(target, playerName, sizeof(playerName));
    FakeClientCommand(target, "sm_survivor");
    PrintToChatAll("[SM] %s has been swapped to the Survivor team.", playerName);
    //make target go survivor
}

public Action:SwitchTargetInfected(Handle:timer, any:target)
{
    new String:playerName[64];
    GetClientName(target, playerName, sizeof(playerName));
    FakeClientCommand(target, "sm_infected");
    PrintToChatAll("[SM] %s has been swapped to the Infected team.", playerName);   
    //make target go inf
}
//previously in comp_loader sm_inf and sm_sur
stock GetTeamHumanCount(team)
{
    new humans = 0;
    
    new i;
    for(i = 1; i < (MaxClients + 1); i++)
    {
        if(IsClientInGameHuman(i) && GetClientTeam(i) == team)
        {
            humans++;
        }
    }
    
    return humans;
}

stock GetTeamMaxHumans(team)
{
    if(team == 2)
    {
        return GetConVarInt(FindConVar("survivor_limit"));
    }
    else if(team == 3)
    {
        return GetConVarInt(FindConVar("z_max_player_zombies"));
    }
    
    return -1;
}

public Action:Join_Survivor(client, args)	//on !survivor
{	
	new maxSurvivorSlots = GetTeamMaxHumans(2);
	new survivorUsedSlots = GetTeamHumanCount(2);
	new freeSurvivorSlots = (maxSurvivorSlots - survivorUsedSlots);
	//debug
	//PrintToChatAll("Number of Survivor Slots %d.\nNumber of Survivor Players %d.\nNumber of Free Slots %d.", maxSurvivorSlots, survivorUsedSlots, freeSurvivorSlots);
	
	if (GetClientTeam(client) == 2)			//if client is survivor
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
			bot < (MaxClients + 1) && (!IsClientConnected(bot) || !IsFakeClient(bot) || (GetClientTeam(bot) != 2));
			bot++) {}
		
		if(bot == (MaxClients + 1))
		{			
			new String:command[] = "sb_add";
			new flags = GetCommandFlags(command);
			SetCommandFlags(command, flags & ~FCVAR_CHEAT);
			
			ServerCommand("sb_add");
			
			SetCommandFlags(command, flags);
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
		while((localClientTeam != 2) && i < 4)
		{
			FakeClientCommand(client, "sb_takecontrol %s", botNames[i]);
			localClientTeam = GetClientTeam(client);
			i++;
		}
		SetCommandFlags(command, flags);
}


public Action:Join_Infected(client, args)	//on !infected
{	
	new maxInfectedSlots = GetTeamMaxHumans(3);
	new infectedUsedSlots = GetTeamHumanCount(3);
	new freeInfectedSlots = (maxInfectedSlots - infectedUsedSlots);
	//PrintToChatAll("Number of Infected Slots %d.\nNumber of Infected Players %d.\nNumber of Free Slots %d.", maxInfectedSlots, infectedUsedSlots, freeInfectedSlots);
	if (GetClientTeam(client) == 3)			//if client is infected
	{
		PrintToChat(client, "[SM] You are already on the Infected team.");
		return Plugin_Handled;
	}
	if (freeInfectedSlots <= 0)
	{
		PrintToChat(client, "[SM] Infected team is full.");
		return Plugin_Handled;
	}
	else
	{
		ChangeClientTeam(client, 3);	//ServerCommand("sm_swapto %N 3",client);	//swapping the client to the infected team if he is spectator or survivor
	}
	return Plugin_Handled;
}

/**
 * On report status client command.
 *
 * @param client        Client id that performed the command.
 * @param command       The command performed.
 * @param args          Number of arguments.
 * @return              Plugin_Handled to stop command from being performed, 
 *                      Plugin_Continue to allow the command to pass.
 */
public Action:Version_Command(client, const String:command[], argc)
{
    if (client == 0) return Plugin_Continue; // Server already have a cvar named this, return continue

    if (g_bIsResultCached) // If we have a cached result
    {
        PrintToConsole(client, g_sResultCache); // Print cached result
        return Plugin_Handled; // Handled
    }

    decl String:result[REPORT_STATUS_MAX_MSG_LENGTH];

    Format(result, sizeof(result), "version: %s\n", READY_VERSION);
    //Format(result, sizeof(result), "%supdated: %s%s\n", result, (IsPluginUpdated() ? "yes" : "no"));
    Format(result, sizeof(result), "%senabled: %s\n", result, (GetConVarBool(cvarEnforceReady) ? "yes" : "no"));
    Format(result, sizeof(result), "%slisting %i cvars:", result, (GetArraySize(g_aConVarArray) / CVAR_ARRAY_BLOCK));

    decl String:name[MAX_CONVAR_NAME_LENGTH];
    decl String:value[MAX_CONVAR_NAME_LENGTH];
    decl String:defaultValue[MAX_CONVAR_NAME_LENGTH];
    decl Handle:cvar;

    for (new i = FIRST_CVAR_IN_ARRAY; i < GetArraySize(g_aConVarArray); i += CVAR_ARRAY_BLOCK)
    {
        GetArrayString(g_aConVarArray, i, name, MAX_CONVAR_NAME_LENGTH);
        cvar = FindConVar(name);
        if (cvar == INVALID_HANDLE) continue;
        GetConVarString(cvar, value, MAX_CONVAR_NAME_LENGTH);

        GetArrayString(g_aConVarArray, i + 1, defaultValue, MAX_CONVAR_NAME_LENGTH);
        Format(defaultValue, MAX_CONVAR_NAME_LENGTH, "( def. \"%s\" )", defaultValue);

        Format(result, sizeof(result), "%s\n \"%s\" = \"%s\" %s", result, name, value, defaultValue);
    }

    PrintToConsole(client, result);

    // Cache result to prevent clients spamming this command to lag the server
    g_sResultCache = result;
    g_bIsResultCached = true;
    CreateTimer(CACHE_RESULT_TIME, _RS_Cache_Timer);

    return Plugin_Handled;
}

/**
 * Called when the cached timer interval has elapsed.
 * 
 * @param timer         Handle to the timer object.
 * @noreturn
 */
public Action:_RS_Cache_Timer(Handle:timer)
{
    g_bIsResultCached = false;
}

/**
 * Adds convar to the report status array.
 * 
 * @param convar        Handle to convar.
 * @noreturn
 */
stock AddConVarToReport(Handle:convar)
{
    SetupConVarArray(); // Setup array if needed

    /*
     * Get name of convar
     */
    decl String:name[MAX_CONVAR_NAME_LENGTH];
    GetConVarName(convar, name, MAX_CONVAR_NAME_LENGTH);

    if (FindStringInArray(g_aConVarArray, name) != -1) return; // Already in array

    /*
     * Get default value of convar
     */
    decl String:value[MAX_CONVAR_NAME_LENGTH], String:defaultvalue[MAX_CONVAR_NAME_LENGTH];
    GetConVarString(convar, value, MAX_CONVAR_NAME_LENGTH);

    new flags = GetConVarFlags(convar);
    if (flags & FCVAR_NOTIFY)
    {
        SetConVarFlags(convar, flags ^ FCVAR_NOTIFY);
    }

    ResetConVar(convar);
    GetConVarString(convar, defaultvalue, MAX_CONVAR_NAME_LENGTH);
    SetConVarString(convar, value);
    SetConVarFlags(convar, flags);

    /*
     * Push to array
     */
    PushArrayString(g_aConVarArray, name);
    PushArrayString(g_aConVarArray, defaultvalue);
}

/**
 * Adds convar to the report status array.
 * 
 * @param convar        Handle to convar.
 * @noreturn
 */
static SetupConVarArray()
{
    if (g_bIsArraySetup) return;
    g_aConVarArray = CreateArray(MAX_CONVAR_NAME_LENGTH);

    g_bIsArraySetup = true;
}

/**
 * On net info client command.
 *
 * @param client        Index of the client, or 0 from the server.
 * @param args          Number of arguments that were in the argument string.
 * @return              Plugin_Handled.
 */
public Action:ratesCommand(client, args)
{
    /* Prevent spammage of this command */
    if (g_bCooldown[client]) return Plugin_Handled;
    g_bCooldown[client] = true;

    new const maxLen = 1024;
    decl String:result[maxLen];

    Format(result, maxLen, "\nPrinting net information about players:\n\n");

    Format(result, maxLen, "%s | UID    | NAME                 | STEAMID              | PING  | RATE  | CR  | UR  |  INTERP  | IRATIO |\n", result);
    Format(result, maxLen, "%s |--------|----------------------|----------------------|-------|-------|-----|-----|----------|--------|", result);

    if (client == 0)
    {
        PrintToServer(result);
    }
    else
    {
        PrintToConsole(client, result);
    }

    decl uid, String:name[20], String:auth[20], Float:ping;
    decl String:rawRate[20], String:rawCR[20], String:rawUR[20], String:rawInterp[20], String:rawIRatio[20];
    decl rate, cmdrate, updaterate, /*Float:interp,*/ Float:interpRatio;
    for(new i=1; i <= MaxClients; i++)
    {
        if(IsClientInGame(i) && !IsFakeClient(i))
        {
            uid = GetClientUserId(i);
            GetClientName(i, name, 20);
            GetClientAuthString(i, auth, 20);
            ping = (1000.0 * GetClientAvgLatency(i, NetFlow_Outgoing)) / 2;

            rate = -1;
            if (GetClientInfo(i, "rate", rawRate, 20))
            {
                rate = StringToInt(rawRate);
            }

            cmdrate = -1;
            if (GetClientInfo(i, "cl_cmdrate",rawCR, 20))
            {
                cmdrate = StringToInt(rawCR);
            }

            updaterate = -1;
            if (GetClientInfo(i, "cl_updaterate", rawUR, 20))
            {
                updaterate = StringToInt(rawUR);
            }

            //interp = -1.0;
            if (GetClientInfo(i, "cl_interp", rawInterp, 20))
            {
                Format(rawInterp, 9, rawInterp);
                //interp = StringToFloat(rawInterp);
            }

            interpRatio = -1.0;
            if (GetClientInfo(i, "cl_interp_ratio", rawIRatio, 20))
            {
                interpRatio = StringToFloat(rawIRatio);
            }

            Format(result, maxLen, " | #%-5i | %20s | %20s | %5.0f | %5i | %3i | %3i | %8s | %.4f |",
                uid,
                name,
                auth,
                ping,
                rate,
                cmdrate,
                updaterate,
                rawInterp,
                interpRatio);

            if (client == 0)
            {
                PrintToServer(result);
            }
            else
            {
                PrintToConsole(client, result);
            }
        }
    }

    Format(result, maxLen, "\nLegend:\n");
    Format(result, maxLen, "%s UID     - UserID\n", result);
    Format(result, maxLen, "%s NAME    - Current name of player\n", result);
    Format(result, maxLen, "%s STEAMID - SteamID of player\n", result);
    Format(result, maxLen, "%s PING    - Average ping\n", result);
    Format(result, maxLen, "%s RATE    - Rate\n", result);
    Format(result, maxLen, "%s CR      - Command rate\n", result);
    Format(result, maxLen, "%s UR      - Upload rate\n", result);
    Format(result, maxLen, "%s INTERP  - Interp value\n", result);
    Format(result, maxLen, "%s IRATIO  - Interp ratio value\n", result);

    if (client == 0)
    {
        PrintToServer(result);
    }
    else
    {
        PrintToConsole(client, result);
    }

    CreateTimer(1.0, ratesCooldownTimer, client);
    return Plugin_Handled;
}

public Action:ratesCooldownTimer(Handle:timer, any:client)  //ZACK
{
    g_bCooldown[client] = false;
    return Plugin_Stop;
}

public OnAllPluginsLoaded()
{   
    if(FindConVar("l4d_team_manager_ver") != INVALID_HANDLE)
    {
        // l4d scores manager plugin is loaded
        
        // allow reready because it will fix scores when rounds are restarted?
        RegConsoleCmd("sm_reready", Command_Reready);
    }
    else
    {
        // l4d scores plugin is NOT loaded
        // supply these commands which would otherwise be done by the team manager
        
        RegAdminCmd("sm_swap", Command_PlayerSwap, ADMFLAG_BAN, "sm_swap <player1> <player2> - swap player1's and player2's teams");
        RegAdminCmd("sm_swapteams", Command_SwapTeams, ADMFLAG_BAN, "sm_swapteams - swap all the players to the opposite teams");
    }
    
    CheckDependencyVersions(/*throw*/true);
}

new bool:insidePluginEnd = false;
public OnPluginEnd()
{
    insidePluginEnd = true;
    
    readyOff(); 
}

public OnMapEnd()
{
    isSecondRound = false;  
    
    DebugPrintToAll("Event: Map ended.");
}

public OnMapStart()
{
    DebugPrintToAll("Event map started.");
    //----
    //allowing reready to be used again incase the map changed before timer could reset bool back to false
    g_bCooldownReready = false;
    //----
    //resetting all spectator status
    decl i;
    for(i = 1; i <= MaxClients; i++)
    {   
        infectedSpectator[i] = false;                       //not infected that used !spectate
        g_iSpectatePenaltyCounter[i] = g_iSpectatePenalty;  //counter gets reset to default
        g_iLastRespecced[i] = 0;                            //last respecced time was never
    }
    //----
    /*
    * execute the cfg specified in l4d_ready_server_cfg
    */
    //if(GetConVarInt(cvarEnforceReady))
    //{
    decl String:cfgFile[128];
    GetConVarString(cvarReadyServerCfg, cfgFile, sizeof(cfgFile));
    
    if(strlen(cfgFile) == 0)
    {
        return;
    }
    
    decl String:cfgPath[1024];
    BuildPath(Path_SM, cfgPath, 1024, "../../cfg/%s", cfgFile);
    
    if(FileExists(cfgPath))
    {
        DebugPrintToAll("Executing server config %s", cfgPath);
        
        ServerCommand("exec %s", cfgFile);
    }
    else
    {
        LogError("[SM] Could not execute server config %s, file not found", cfgPath);
        PrintToServer("[SM] Could not execute server config %s, file not found", cfgFile);  
        PrintToChatAll("[SM] Could not execute server config %s, file not found", cfgFile); 
    }
    //}
}

public bool:OnClientConnect()
{
    if(readyMode) 
    {
        checkStatus();
    }
    
    return true;
}

public OnClientDisconnect()
{
    if(readyMode) checkStatus();
}

/*
public _PS_OnClientPutInServer(client)
{

    g_iSpectatePenaltyCounter[client] = g_iSpectatePenalty;
}
*/

public OnClientDisconnect_Post(client)
{
    infectedSpectator[client] = false;
    g_iSpectatePenaltyCounter[client] = g_iSpectatePenalty;
}

checkStatus()
{
    new humans, ready;
    decl i;
    
    //count number of non-bot players in-game
    for(i = 1; i <= MaxClients; i++)
    {
        if(IsClientConnected(i) && !IsFakeClient(i) && IsClientInGame(i) && GetClientTeam(i) != L4D_TEAM_SPECTATE)
        {
            humans++;
            if(readyStatus[i]) ready++;
        }
    }
    if(humans == 0 || humans < GetConVarInt(cvarReadyMinimum))
        return;
    
    if(goingLive && (humans == ready)) return;
    else if(goingLive && (humans != ready))
    {
        goingLive = 0;
        PrintHintTextToAll("Aborted going live due to player unreadying.");
        KillTimer(liveTimer);
    }
    else if(!goingLive && (humans == ready))
    {
        if(!insideCampaignRestart)
        {
            goingLive = GetConVarInt(cvarReadyLiveCountdown);
            liveTimer = CreateTimer(1.0, timerLiveCountCallback, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
        }
    }
    else if(!goingLive && (humans != ready)) PrintHintTextToAll("%d of %d players are ready.", ready, humans);
    else PrintToChatAll("checkStatus bad state (tell Downtown1)");
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)    //should prevent players from moving
{
    if (readyMode)
    {
        if (IsClientInGame(client) && GetClientTeam(client) == L4D_TEAM_SURVIVORS && !(GetEntityMoveType(client) == MOVETYPE_NONE || GetEntityMoveType(client) == MOVETYPE_NOCLIP))
        {
            ToggleFreezePlayer(client, true);
        }
    }
}

//repeatedly count down until the match goes live
public Action:timerLiveCountCallback(Handle:timer)
{
    //will go live soon
    if(goingLive)
    {
        if(forcedStart) PrintHintTextToAll("Forcing match start.  An admin must 'say !abort' to abort!\nGoing live in %d seconds.", goingLive);
        else PrintHintTextToAll("All players ready.  Say !unready now to abort!\nGoing live in %d seconds.", goingLive);
        goingLive--;
    }
    //actually go live and unfreeze everyone
    else
    {
        //readyOff();
        
        if(GetConVarBool(cvarReadyRestartRound) && !GetConVarBool(cvarReadyUpStyle))
        {
            PrintHintTextToAll("Match will be live after 2 round restarts.");
            
            insideCampaignRestart = 2;
            RestartCampaignAny();
            
            //      CreateTimer(4.0, timerLiveMessageCallback, _, _);
            //SDKCall(restartScenario, gConf, "Director", 1);
            //HookEvent("round_start", eventRSLiveCallback);
            //SDKCall(restartScenario, gConf, "Director", 1);
        }
        else
        {
            //dev
            readyOff();
            UnfreezeAllPlayers();
            CreateTimer(1.0, timerLiveMessageCallback, _, _);
        }
        
        return Plugin_Stop;
    }
    
    return Plugin_Continue;
}

public Action:eventRoundEndCallback(Handle:event, const String:name[], bool:dontBroadcast)
{
    #if READY_DEBUG
    DebugPrintToAll("[DEBUG] Event round has ended");
    #endif
    
    if(!isCampaignBeingRestarted)
    {
        #if READY_DEBUG
        if(!isSecondRound)
            DebugPrintToAll("[DEBUG] Second round detected.");
        else
        DebugPrintToAll("[DEBUG] End of second round detected.");
        #endif
        isSecondRound = true;
    }
    
    //we just ended the last restart, match will be live soon
    if(insideCampaignRestart == 1) 
    {
        //enable the director etc, but dont unfreeze all players just yet
        RoundEndBeforeLive();
    }
    
    isCampaignBeingRestarted = false;
}

public Action:eventRSLiveCallback(Handle:event, const String:name[], bool:dontBroadcast)
{
    #if READY_DEBUG
    DebugPrintToAll("[DEBUG] Event round has started");
    #endif
    
    //currently automating campaign restart before going live?
    if(insideCampaignRestart > 0) 
    {
        insideCampaignRestart--;
        #if READY_DEBUG
        DebugPrintToAll("[DEBUG] Round restarting, left = %d", insideCampaignRestart);
        #endif
        
        //first restart, do one more
        if(insideCampaignRestart == 1) 
        {
            CreateTimer(READY_RESTART_ROUND_DELAY, timerOneRoundRestart, _, _);
            
            //PrintHintTextToAll("Match will be live after 1 round restart.");
            
        }
        //last restart, match is now live!
        else if(insideCampaignRestart == 0)
        {
            RoundIsLive();
        }
        else
        {
            LogError("insideCampaignRestart somehow neither 0 nor 1 after decrementing");
        }
        
        return Plugin_Continue;
    }
    
    //normal round start event not triggered by our plugin
    
    //our code will just enable ready mode at the start of a round
    //if the cvar is set to it
    if(GetConVarInt(cvarEnforceReady)
    && (!isSecondRound || GetConVarInt(cvarReadyHalves) || pauseBetweenHalves || GetConVarInt(cvarReadyUpStyle))) 
    {
        #if READY_DEBUG
        DebugPrintToAll("[DEBUG] Calling comPready, pauseBetweenHalves = %d", pauseBetweenHalves);
        #endif
        
        compReady(0, 0);
        pauseBetweenHalves = 0;
    }
    
    return Plugin_Continue;
}

public Action:timerOneRoundRestart(Handle:timer)
{
    PrintToChatAll("[SM] Match will be live after 1 round restart!");
    PrintHintTextToAll("Match will be live after 1 round restart!");
    
    RestartCampaignAny();
    
    return Plugin_Stop;
}

public Action:timerLiveMessageCallback(Handle:timer)
{   
    PrintHintTextToAll("Match is LIVE!");
    
    //if(GetConVarInt(cvarReadyHalves) || isSecondRound)
    //{
    PrintToChatAll("[SM] Match is LIVE!");
    //}
    //else
    //{
    //  PrintToChatAll("[SM] Match is LIVE for both halves, say !reready to request a ready-up before the next half.");
    //}
    
    return Plugin_Stop;
}


public Action:timerUnreadyCallback(Handle:timer)
{
    if(!readyMode)
    {
        unreadyTimerExists = false;
        return Plugin_Stop;
    }
    
    if(insideCampaignRestart)
    {
        return Plugin_Continue;
    }
    
    //new curPlayers = CountInGameHumans();
    //new minPlayers = GetConVarInt(cvarReadyMinimum);
    
    decl i;
    for(i = 1; i <= MaxClients; i++)
    {
        if(IsClientInGameHuman(i)) 
        {
            //use panel for ready up stuff?
            if(!readyStatus[i])
            {
                PrintHintText(i, "You are NOT READY!\n\nSay !ready in chat to ready up.");
            }
            else
            {
                PrintHintText(i, "You are ready.\n\nSay !unready in chat if no longer ready.");
            }
        }
        else if(IsClientInGameHumanSpec(i) && GetClientTeam(i) == L4D_TEAM_SPECTATE)
        {
            PrintHintText(i, "You are spectating.");
        }
    }
    
    DrawReadyPanelList();
    
    return Plugin_Continue;
}

public Action:eventSpawnReadyCallback(Handle:event, const String:name[], bool:dontBroadcast)
{
    if(!readyMode)
    {
        #if READY_DEBUG
        new player = GetClientOfUserId(GetEventInt(event, "userid"));
        
        new String:curname[128];
        GetClientName(player,curname,128);
        DebugPrintToAll("[DEBUG] Spawned %s [%d], doing nothing.", curname, player);
        #endif
        
        return Plugin_Handled;
    }
    
    new player = GetClientOfUserId(GetEventInt(event, "userid"));
    
    #if READY_DEBUG
    new String:curname[128];
    GetClientName(player,curname,128);
    DebugPrintToAll("[DEBUG] Spawned %s [%d], freezing.", curname, player);
    #endif
    
    ToggleFreezePlayer(player, true);
    return Plugin_Handled;
}

public Action:L4D_OnSpawnTank(const Float:vector[3], const Float:qangle[3])
{
    DebugPrintToAll("OnSpawnTank(vector[%f,%f,%f], qangle[%f,%f,%f]", 
        vector[0], vector[1], vector[2], qangle[0], qangle[1], qangle[2]);
        
    if(readyMode)
    {
        DebugPrintToAll("Blocking tank spawn...");
        return Plugin_Handled;
    }
    else
    {
        return Plugin_Continue;
    }
}

public Action:L4D_OnSpawnWitch(const Float:vector[3], const Float:qangle[3])
{
    DebugPrintToAll("OnSpawnWitch(vector[%f,%f,%f], qangle[%f,%f,%f])", 
        vector[0], vector[1], vector[2], qangle[0], qangle[1], qangle[2]);
        
    if(readyMode)
    {
        DebugPrintToAll("Blocking witch spawn...");
        return Plugin_Handled;
    }
    else
    {
        return Plugin_Continue;
    }
}


public Action:Event_TankSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
/*  new tankid = GetEventInt(event, "tankid");
    new player = GetClientOfUserId(GetEventInt(event, "userid"));
    
    new String:curname[128];
    GetClientName(player,curname,128);*/
}

public Action:Event_WitchSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{/* new witchid = GetEventInt(event, "witchid");
    new client = GetClientOfUserId(witchid);*/
}

public Action:Event_PlayerLeftStartArea(Handle:event, const String:name[], bool:dontBroadcast)
{
}

//When a player replaces a bot (i.e. player joins survivors team)
public Action:eventBotPlayerReplaceCallback(Handle:event, const String:name[], bool:dontBroadcast)
{
    //  new bot = GetClientOfUserId(GetEventInt(event, "bot"));
    new player = GetClientOfUserId(GetEventInt(event, "player"));
    
    if(readyMode)
    {
        //called when player joins survivor....?
        #if READY_DEBUG
        new String:curname[128];
        GetClientName(player,curname,128);
        DebugPrintToAll("[DEBUG] Player %s [%d] replacing bot, freezing player.", curname, player);
        #endif
        
        ToggleFreezePlayer(player, true);
    }
    else
    {
        #if READY_DEBUG
        new String:curname[128];
        GetClientName(player,curname,128);
        DebugPrintToAll("[DEBUG] Player %s [%d] replacing bot, doing nothing.", curname, player);
        #endif  
    }
    
    return Plugin_Handled;
}


//When a bot replaces a player (i.e. player switches to spectate or infected)
public Action:eventPlayerBotReplaceCallback(Handle:event, const String:name[], bool:dontBroadcast)
{
    
    new player = GetClientOfUserId(GetEventInt(event, "player"));
    //  new bot = GetClientOfUserId(GetEventInt(event, "bot"));
    
    if(readyMode)
    {
        #if READY_DEBUG
        new String:curname[128];
        GetClientName(player,curname,128);
        
        DebugPrintToAll("[DEBUG] Bot replacing player %s [%d], unfreezing player.", curname, player);
        #endif
        
        ToggleFreezePlayer(player, false);
    }
    else
    {
        #if READY_DEBUG
        new String:curname[128];
        GetClientName(player,curname,128);
        DebugPrintToAll("[DEBUG] Bot replacing player %s [%d], doing nothing.", curname, player);
        #endif  
    }
    
    return Plugin_Handled;
}

//When a player changes team
public Action:eventPlayerTeamCallback(Handle:event, const String:name[], bool:dontBroadcast)
{
    #if READY_DEBUG
    new player = GetClientOfUserId(GetEventInt(event, "player"));
    new String:curname[128];
    GetClientName(player,curname,128);
    
    DebugPrintToAll("[DEBUG] Player %s changing team.", curname);
    #endif
    
    if(readyMode)
    {
        DrawReadyPanelList();
        checkStatus();
    }
}

//When a player gets hurt during ready mode, block all damage
public Action:eventPlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
    new player = GetClientOfUserId(GetEventInt(event, "userid"));
    new health = GetEventInt(event, "health");
    new dmg_health = GetEventInt(event, "dmg_health");
    
    #if READY_DEBUG
    new String:curname[128];
    GetClientName(player,curname,128);
    
    DebugPrintToAll("[DEBUG] Player hurt %s [%d], health = %d, dmg_health = %d.", curname, player, health, dmg_health);
    #endif
    
    SetEntityHealth(player, health + dmg_health);
}

public Action:eventVotePassed(Handle:event, const String:name[], bool:dontBroadcast)
{
    new String:details[128];
    new String:param1[128];
    new team;
    
    GetEventString(event, "details", details, 128);
    GetEventString(event, "param1", param1, 128);
    team = GetEventInt(event, "team");
    
    //[DEBUG] Vote passed, details=#L4D_vote_passed_restart_game, param1=, team=[-1].
    
    DebugPrintToAll("[DEBUG] Vote passed, details=%s, param1=%s, team=[%d].", details, param1, team);
    
    return Plugin_Handled;
}

public Action:eventVoteStarted(Handle:event, const String:name[], bool:dontBroadcast)
{
    new String:issue[128];
    new String:param1[128];
    new team;
    new initiator;
    
    GetEventString(event, "issue", issue, 128);
    GetEventString(event, "param1", param1, 128);
    team = GetEventInt(event, "team");
    initiator = GetEventInt(event, "initiator");
    
    //[DEBUG] Vote started, issue=#L4D_vote_restart_game, param1=, team=[-1], initiator=[1].
    
    DebugPrintToAll("[DEBUG] Vote started, issue=%s, param1=%s, team=[%d], initiator=[%d].", issue, param1, team, initiator);
}

public Action:eventVoteEnded(Handle:event, const String:name[], bool:dontBroadcast)
{
    DebugPrintToAll("[DEBUG] Vote ended");
}


public ConVarChange_DirectorNoBosses(Handle:convar, const String:oldValue[], const String:newValue[])
{
    DebugPrintToAll("director_no_bosses changed from %s to %s", oldValue, newValue);
    
}

public Action:SendVoteRestartPassed(client, args)
{
    new Handle:event = CreateEvent("vote_passed");  
    if(event == INVALID_HANDLE) 
    {
        return;
    }
    
    SetEventString(event, "details", "#L4D_vote_passed_restart_game");
    SetEventString(event, "param1", "");
    SetEventInt(event, "team", -1);
    
    FireEvent(event);
    
    DebugPrintToAll("[DEBUG] Sent fake vote passed to restart game");
}

public Action:SendVoteRestartStarted(client, args)
{
    new Handle:event = CreateEvent("vote_started"); 
    if(event == INVALID_HANDLE) 
    {
        return;
    }
    
    SetEventString(event, "issue", "#L4D_vote_restart_game");
    SetEventString(event, "param1", "");
    SetEventInt(event, "team", -1);
    SetEventInt(event, "initiator", client);
    
    FireEvent(event);
    
    DebugPrintToAll("[DEBUG] Sent fake vote started to restart game");
}

public Action:FakeRestartVoteCampaign(client, args)
{
    //re-enable ready mode after the restart
    pauseBetweenHalves = 1;
    
    RestartCampaignAny();
    PrintToChatAll("[SM] Round manually restarted.");
    DebugPrintToAll("[SM] Round manually restarted.");
}

RestartCampaignAny()
{   
    decl String:currentmap[128];
    GetCurrentMap(currentmap, sizeof(currentmap));
    
    DebugPrintToAll("RestartCampaignAny() - Restarting scenario from vote ...");
    
    Call_StartForward(fwdOnReadyRoundRestarted);
    Call_Finish();
    
    L4D_RestartScenarioFromVote(currentmap);
}

public Action:CommandRestartMap(client, args)
{   
    if((!isMapRestartPending) || (isMapRestartPending))
    {
        PrintToChatAll("[SM] Map resetting in %.0f seconds.", READY_RESTART_MAP_DELAY);
        RestartMapDelayed();
    }
    return Plugin_Handled;
}

RestartMapDelayed()
{
    isMapRestartPending = true;
    
    CreateTimer(READY_RESTART_MAP_DELAY, timerRestartMap, _, TIMER_FLAG_NO_MAPCHANGE);
    DebugPrintToAll("[SM] Map will restart in %f seconds.", READY_RESTART_MAP_DELAY);
}

public Action:timerRestartMap(Handle:timer)
{
    RestartMapNow();
}

RestartMapNow()
{
    isMapRestartPending = false;
    
    decl String:currentMap[256];
    
    GetCurrentMap(currentMap, 256);
    
    ServerCommand("changelevel %s", currentMap);
}

public Action:callVote(client, args)
{
    //only allow voting when are not enforcing ready modes
    if(!GetConVarInt(cvarEnforceReady)) 
    {
        return Plugin_Continue;
    }
    
    if(!votesUnblocked) 
    {
        #if READY_DEBUG
        DebugPrintToAll("[DEBUG] Voting is blocked");
        #endif
        return Plugin_Handled;
    }
    
    new String:votetype[32];
    GetCmdArg(1,votetype,32);
    
    if(strcmp(votetype,"RestartGame",false) == 0)
    {
        #if READY_DEBUG
        DebugPrintToAll("[DEBUG] Vote on RestartGame called");
        #endif
        votesUnblocked = false;
    }
    
    return Plugin_Continue;
}

public Action:Command_Spectate(client, args)
{
    if(GetClientTeam(client) != L4D_TEAM_SPECTATE)
    {
        if(GetClientTeam(client) == L4D_TEAM_SURVIVORS) //someone can't swap to survivor team to get reduced spawn timers
        {
            ChangePlayerTeam(client, L4D_TEAM_SPECTATE);
            PrintToChat(client, "[SM] You are now spectating.");
        }
        if(GetClientTeam(client) == L4D_TEAM_INFECTED)
        {
            if(readyMode || infectedSpectator[client])                              //if game is in ready up, allow normal spectate, or player is already an inf/spectator
            {
                ChangePlayerTeam(client, L4D_TEAM_SPECTATE);
                PrintToChat(client, "[SM] You are now spectating.");
            }
            else
            {
                if(g_iSpectatePenalty > -1)
                {
                    infectedSpectator[client] = true;
                    ChangePlayerTeam(client, L4D_TEAM_SPECTATE);
                    CreateTimer(1.0, Timer_InfectedSpectate, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE); // Start unpause countdown
                }
                else
                {
                    ChangePlayerTeam(client, L4D_TEAM_SPECTATE);
                    PrintToChat(client, "[SM] You are now spectating.");
                }
            }
        }       
    }
    //respectate trick to get around spectator camera being stuck
    else
    {
        g_bIsSpectating[client] = true;
        ChangePlayerTeam(client, L4D_TEAM_INFECTED);
        CreateTimer(0.1, Timer_Respectate, client, TIMER_FLAG_NO_MAPCHANGE);
    }
    
    if(readyMode)
    {
        DrawReadyPanelList();
        checkStatus();
    }

    return Plugin_Handled;
}

public Action:Respec_Client(client, args)
{
    if (client == 0)
    {
        PrintToServer("[SM] sm_respec cannot be used by server.");
        return Plugin_Handled;
    }
    
    if (GetClientTeam(client) != 3 || g_bIsSpectating[client])
    {
        ReplyToCommand(client, "[SM] Can only be used by the Infected.");
        return Plugin_Handled;
    }
    
    if(args < 1)
    {
        ReplyToCommand(client, "[SM] Usage: sm_respec <player> - force the player to respectate.");     
        return Plugin_Handled;
    }
    
    decl String:target[64];
    GetCmdArgString(target, sizeof(target));
    
    new tclient = FindTarget(client, target, true /*nobots*/, false /*immunity*/);
    if (tclient == -1) return Plugin_Handled;
    
    decl String:respecClient[64];
    GetClientName(client, respecClient, sizeof(respecClient));
    
    decl String:respecTarget[64];
    GetClientName(tclient, respecTarget, sizeof(respecTarget));
        
    if (GetClientTeam(tclient) != L4D_TEAM_SPECTATE)
    {
        ReplyToCommand(client, "[SM] %s is not a spectator.", respecTarget);
        return Plugin_Handled;
    }
    else if (g_bIsSpectating[tclient])
    {
        ReplyToCommand(client, "[SM] %s is already being respecced.", respecTarget);
        return Plugin_Handled;
    }
    
    new curtime = GetTime();
    
    new tdiff = (g_iLastRespecced[tclient] + g_iRespecCooldownTime) - curtime;
    
    if (tdiff > 0)
    {
        ReplyToCommand(client, "[SM] %s cannot be respecced for another %i second(s), you must wait.", respecTarget, tdiff);
        return Plugin_Handled;
    }
    
    g_iLastRespecced[tclient] = curtime;
    
    g_bIsSpectating[tclient] = true;
    
    ChangePlayerTeam(tclient, 3);
    CreateTimer(0.1, Timer_Respec_A, tclient, TIMER_FLAG_NO_MAPCHANGE); //spec
    CreateTimer(0.6, Timer_Respec_B, tclient, TIMER_FLAG_NO_MAPCHANGE); //inf
    CreateTimer(0.7, Timer_Respec_C, tclient, TIMER_FLAG_NO_MAPCHANGE); //spec + reset spectating[tclient] = false;
    PrintToChat(tclient, "[SM] %s has forced you to respectate.", respecClient);
    PrintToChat(client, "[SM] %s has been forced to respectate.", respecTarget);
    
    return Plugin_Handled;
}

public Action:Timer_Respec_A(Handle:timer, any:tclient)
{
    ChangeClientTeam(tclient, 1);
}

public Action:Timer_Respec_B(Handle:timer, any:tclient)
{
    ChangeClientTeam(tclient, 3);
}

public Action:Timer_Respec_C(Handle:timer, any:tclient)
{
    ChangeClientTeam(tclient, 1);
    g_bIsSpectating[tclient] = false;   
}

public Action:Timer_InfectedSpectate(Handle:timer, any:client)
{
    static bClientJoinedInfected = false;       //did the client try to join the infected?
    
    if (!infectedSpectator[client] || !IsClientInGame(client) || IsFakeClient(client)) return Plugin_Stop; //if client disconnected or is fake client
    
    if (g_iSpectatePenaltyCounter[client] != 0)
    {
        if (GetClientTeam(client) == L4D_TEAM_INFECTED)
        {
            ChangePlayerTeam(client, L4D_TEAM_SPECTATE);
            PrintToChat(client, "[SM] You can join the infected team again in %d seconds", g_iSpectatePenaltyCounter[client]);
            bClientJoinedInfected = true;   //client tried to join the infected again when not allowed
        }
        g_iSpectatePenaltyCounter[client]--;
        return Plugin_Continue;
    }
    else if (g_iSpectatePenaltyCounter[client] == 0)
    {
        if (GetClientTeam(client) == L4D_TEAM_INFECTED)
        {
            ChangePlayerTeam(client, L4D_TEAM_SPECTATE);
            bClientJoinedInfected = true;
        }
        if (GetClientTeam(client) == L4D_TEAM_SPECTATE && bClientJoinedInfected)
        {
            PrintToChat(client, "[SM] You can now join the infected team again.");  //only print this hint text to the spectator if he tried to join the infected team, and got swapped before
        }
        infectedSpectator[client] = false;
        bClientJoinedInfected = false;
        g_iSpectatePenaltyCounter[client] = g_iSpectatePenalty;
        return Plugin_Stop;
    }
    return Plugin_Continue;
}

public Action:Timer_Respectate(Handle:timer, any:client)
{
    ChangePlayerTeam(client, L4D_TEAM_SPECTATE);
    PrintToChat(client, "[SM] You are now spectating (again).");
    g_bIsSpectating[client] = false;
}

public Action:Command_Unfreezeme1(client, args)
{
    SetEntityMoveType(client, MOVETYPE_NOCLIP); 
    PrintToChatAll("Unfroze %N with noclip");
    
    return Plugin_Handled;
}

public Action:Command_Unfreezeme2(client, args)
{
    SetEntityMoveType(client, MOVETYPE_OBSERVER);   
    PrintToChatAll("Unfroze %N with observer");
    
    return Plugin_Handled;
}

public Action:Command_Unfreezeme3(client, args)
{
    SetEntityMoveType(client, MOVETYPE_WALK);   
    PrintToChatAll("Unfroze %N with WALK");
    
    return Plugin_Handled;
}


public Action:Command_Unfreezeme4(client, args)
{
    SetEntityMoveType(client, MOVETYPE_CUSTOM); 
    PrintToChatAll("Unfroze %N with customs");
    
    return Plugin_Handled;
}


public Action:printClients(client, args)
{
    
    decl i;
    for(i = 1; i <= MaxClients; i++)
    {
        if(IsClientInGame(i)) 
        {
            new String:curname[128];
            GetClientName(i,curname,128);
            DebugPrintToAll("[DEBUG] Player %s with client id [%d]", curname, i);
        }
    }   
}

public Action:Command_Say(client, args)
{
    if(args < 1)
    {
        return Plugin_Continue;
    }
        
    decl String:sayWord[MAX_NAME_LENGTH];
    GetCmdArg(1, sayWord, sizeof(sayWord));
    
    if(StrEqual(sayWord, "!rates", true))
    {
        PrintToChat(client, "[SM] Check the console for players rates.");
        return Plugin_Handled;
    }
    if(StrEqual(sayWord, "/rates", true))
    {
        PrintToChat(client, "[SM] Check the console for players rates.");
        return Plugin_Handled;
    }
    
    if (!readyMode) return Plugin_Continue;
    
    if(StrEqual(sayWord, "!r", false))
    {
        readyUp(client, args);
        return Plugin_Handled;
    }
    else if(StrEqual(sayWord, "/r", false))
    {
        readyUp(client, args);
        return Plugin_Handled;
    }
    else if(StrEqual(sayWord, "!ready", false))
    {
        readyUp(client, args);
        return Plugin_Handled;
    }
    else if(StrEqual(sayWord, "/ready", false))
    {
        readyUp(client, args);
        return Plugin_Handled;
    }
    else if(StrEqual(sayWord, "!notready", false))
    {
        readyDown(client, args);
        return Plugin_Handled;
    }
    else if(StrEqual(sayWord, "/notready", false))
    {
        readyDown(client, args);
        return Plugin_Handled;
    }
    else if(StrEqual(sayWord, "!n", false))
    {
        readyDown(client, args);
        return Plugin_Handled;
    }
    else if(StrEqual(sayWord, "/n", false))
    {
        readyDown(client, args);
        return Plugin_Handled;
    }
    else if(StrEqual(sayWord, "!unready", false))
    {
        readyDown(client, args);
        return Plugin_Handled;
    }
    else if(StrEqual(sayWord, "/unready", false))
    {
        readyDown(client, args);
        return Plugin_Handled;
    }
    else if(StrEqual(sayWord, "!u", false))
    {
        readyDown(client, args);
        return Plugin_Handled;
    }
    else if(StrEqual(sayWord, "/u", false))
    {
        readyDown(client, args);
        return Plugin_Handled;
    }
    
    return Plugin_Continue;
}

public Action:readyUp(client, args)
{
    if(!readyMode || readyStatus[client] || GetClientTeam(client) == L4D_TEAM_SPECTATE || g_bIsSpectating[client]) return Plugin_Handled;
    
    //don't allow readying up if there's too few players
    new realPlayers = CountInGameHumans();
    new minPlayers = GetConVarInt(cvarReadyMinimum);
    
    //ready up the player and see if everyone is ready now
    decl String:name[MAX_NAME_LENGTH];
    GetClientName(client, name, sizeof(name));
    
    if(realPlayers >= minPlayers)
        PrintToChatAll("%s is ready.", name);
    else
    PrintToChatAll("%s is ready. A minimum of %d players is required.", name, minPlayers);
    
    readyStatus[client] = 1;
    checkStatus();
    
    DrawReadyPanelList();
    
    return Plugin_Handled;
}

public Action:readyDown(client, args)
{
    if(!readyMode || !readyStatus[client] || GetClientTeam(client) == L4D_TEAM_SPECTATE || g_bIsSpectating[client]) return Plugin_Handled;
    if(isCampaignBeingRestarted || insideCampaignRestart) return Plugin_Handled;
    
    decl String:name[MAX_NAME_LENGTH];
    GetClientName(client, name, sizeof(name));
    PrintToChatAll("%s is no longer ready.", name);
    
    readyStatus[client] = 0;
    checkStatus();
    
    DrawReadyPanelList();
    
    return Plugin_Handled;
}

public Action:Command_Reready(client, args)
{
    if(readyMode || !g_bAllowReready || GetConVarBool(cvarReadyUpStyle)) return Plugin_Handled;
    
    if(GetClientTeam(client) == L4D_TEAM_SPECTATE || g_bIsSpectating[client] == true)
    {
        PrintToChat(client, "[SM] Only players can use !reready.");
        return Plugin_Handled;
    }
    if(g_bCooldownReready) return Plugin_Handled;
    
    decl String:name[64];
    decl String:who[32];
    GetClientName(client, name, 64);
    
    if(GetClientTeam(client) == L4D_TEAM_SURVIVORS)
    {
        Format(who, 32, "Survivors");
    }
    if(GetClientTeam(client) == L4D_TEAM_INFECTED)
    {
        Format(who, 32, "Infected");
    }
    //printing to admins who invoked the !reready
    //and to non admins if it was the infected or survivor team
    for(new i=1; i <= MaxClients; i++)
    {
        if(IsClientInGame(i) && !IsFakeClient(i))
        {
            if(GetUserAdmin(i) != INVALID_ADMIN_ID) PrintToChat(i, "[SM] %s used !reready.", name);
            else PrintToChat(i, "[SM] The %s have requested a !reready.", who);
        }
    }
    pauseBetweenHalves = 1;
    PrintToChatAll("[SM] Match will pause at the end of this half and require readying up again.");
    
    return Plugin_Handled;
}

public Action:Command_Unreready(client, args)
{
    if(readyMode || !g_bAllowReready || GetConVarBool(cvarReadyUpStyle)) return Plugin_Handled;

    if(pauseBetweenHalves == 0)
    {
        PrintToChat(client, "[SM] No !reready to undo.");
        return Plugin_Handled;
    }
    PrintToChatAll("[SM] Match will no longer pause at the end of this half and require readying up again.");
    pauseBetweenHalves = 0;
    g_bCooldownReready = true;
    CreateTimer(30.0, Timer_Cooldown_Reready, TIMER_FLAG_NO_MAPCHANGE); 
    return Plugin_Handled;
}

public Action:Timer_Cooldown_Reready(Handle:timer)
{
    g_bCooldownReready = false;
}


public Action:readyWho(client, args)
{
    if(!readyMode) return Plugin_Handled;
    
    decl String:readyPlayers[1024];
    decl String:unreadyPlayers[1024];
    
    readyPlayers[0] = 0;
    unreadyPlayers[0] = 0;
    
    new numPlayers = 0;
    new numPlayers2 = 0;
    
    new i;
    for(i = 1; i <= MaxClients; i++) 
    {
        if(IsClientInGameHuman(i)) 
        {
            decl String:name[MAX_NAME_LENGTH];
            GetClientName(i, name, sizeof(name));
            
            if(readyStatus[i]) 
            {
                if(numPlayers > 0 )
                    StrCat(readyPlayers, 1024, ", ");
                
                StrCat(readyPlayers, 1024, name);
                
                numPlayers++;
            }
            else
            {
                if(numPlayers2 > 0 )
                    StrCat(unreadyPlayers, 1024, ", ");
                
                StrCat(unreadyPlayers, 1024, name);
                
                numPlayers2++;
            }
        }
    }
    
    if(numPlayers == 0) 
    {
        StrCat(readyPlayers, 1024, "NONE");
    }
    if(numPlayers2 == 0) 
    {
        StrCat(unreadyPlayers, 1024, "NONE");
    }
    
    DebugPrintToAll("[SM] Players ready: %s", readyPlayers);
    DebugPrintToAll("[SM] Players NOT ready: %s", unreadyPlayers);
    
    return Plugin_Handled;
}


//draws a menu panel of ready and unready players
DrawReadyPanelList()
{
    if(!readyMode) return;
    
    /*
    #if READY_DEBUG
    DebugPrintToAll("[DEBUG] Drawing the ready panel");
    #endif
    */
    
    decl String:readyPlayers[1024];
    decl String:name[MAX_NAME_LENGTH];
    
    readyPlayers[0] = 0;
    
    new numPlayers = 0;
    new numPlayers2 = 0;
    new numPlayers3 = 0;
    
    new ready, unready, specs;
    
    new i;
    for(i = 1; i <= MaxClients; i++) 
    {
        if(IsClientInGameHuman(i)) 
        {
            if(readyStatus[i]) 
                ready++;
            else
                unready++;
        }
        else if(IsClientInGameHumanSpec(i) && GetClientTeam(i) == L4D_TEAM_SPECTATE)
        {
            specs++;
        }
    }
    
    new Handle:panel = CreatePanel();
    
    if(ready)
    {
        
        DrawPanelText(panel, "READY");
        
        //->%d. %s makes the text yellow
        // otherwise the text is white
        
        for(i = 1; i <= MaxClients; i++) 
        {
            if(IsClientInGameHuman(i)) 
            {
                GetClientName(i, name, sizeof(name));
                
                if(readyStatus[i]) 
                {
                    numPlayers++;
                    Format(readyPlayers, 1024, "->%d. %s", numPlayers, name);
                    DrawPanelText(panel, readyPlayers);
                    
                    #if READY_DEBUG
                    DrawPanelText(panel, readyPlayers);
                    #endif
                }
            }
        }
    }
    
    if(unready)
    {
        DrawPanelText(panel, "NOT READY");
        
        for(i = 1; i <= MaxClients; i++) 
        {
            if(IsClientInGameHuman(i)) 
            {
                GetClientName(i, name, sizeof(name));
                
                if(!readyStatus[i]) 
                {
                    numPlayers2++;
                    Format(readyPlayers, 1024, "->%d. %s", numPlayers2, name);
                    DrawPanelText(panel, readyPlayers);
                    #if READY_DEBUG
                    DrawPanelText(panel, readyPlayers);
                    #endif
                }
            }
        }
    }
    
    if(specs)
    {
        DrawPanelText(panel, "SPECTATORS");
        
        for(i = 1; i <= MaxClients; i++)
        {
            if(IsClientInGameHumanSpec(i) && GetClientTeam(i) == L4D_TEAM_SPECTATE)
            {
                GetClientName(i, name, sizeof(name));
                
                numPlayers3++;
                Format(readyPlayers, 1024, "->%d. %s", numPlayers3, name);
                DrawPanelText(panel, readyPlayers);
                #if READY_DEBUG
                DrawPanelText(panel, readyPlayers);
                #endif
            }
        }
    }
    
    new String:versionInfo[128];
    Format(versionInfo, 128, "RUP Mod v%s", READY_VERSION);
    DrawPanelText(panel, versionInfo);
    
#if LEAGUE_ADD_NOTICE
    new String:Notice[128];
    GetConVarString(cvarReadyLeagueNotice, Notice, sizeof(Notice));
    DrawPanelText(panel, Notice);
#endif
    
    for(i = 1; i <= MaxClients; i++) 
    {
        if(IsClientInGameHumanSpec(i)) 
        {
            SendPanelToClient(panel, i, Menu_ReadyPanel, READY_LIST_PANEL_LIFETIME);
            
            /*
            //some other menu was open during this time?
            if(menuInterrupted[i])
            {
                //if the menu is still up, dont refresh
                if(GetClientMenu(i))
                {
                    DebugPrintToAll("MENU: Will not draw to %N, has menu open (and its not ours)", i);
                    continue;
                }
                else
                {
                    menuInterrupted[i] = false;
                }
            }
            //send to client if he doesnt have menu already
            //this menu will be refreshed automatically from timeout callback
            if(!GetClientMenu(i))
                SendPanelToClient(panel, i, Menu_ReadyPanel, READY_LIST_PANEL_LIFETIME);
            else
                DebugPrintToAll("MENU: Will not draw to %N, has menu open (and it could be ours)", i);
            */
            
            /*
            #if READY_DEBUG
            PrintToChat(i, "[DEBUG] You have been sent the Panel.");
            #endif
            */
        }
    }
    
    if(menuPanel != INVALID_HANDLE)
    {
        CloseHandle(menuPanel);
    }
    menuPanel = panel;
}


public Action:readyDraw(client, args)
{
    DrawReadyPanelList();
}

public Menu_ReadyPanel(Handle:menu, MenuAction:action, param1, param2) 
{ 
    /*
    if(!readyMode)
    {
        return;
    }
    
    if(action == MenuAction_Cancel) {
        new reason = param2;
        new client = param1;

        //some other menu was opened, dont refresh
        if(reason == MenuCancel_Interrupted)
        {
            DebugPrintToAll("MENU: Ready menu was interrupted");
            menuInterrupted[client] = true;
        }
        //usual timeout, refresh the menu
        else if(reason == MenuCancel_Timeout)
        {
            DebugPrintToAll("MENU: Ready menu timed out, refreshing");
            SendPanelToClient(menuPanel, client, Menu_ReadyPanel, READY_LIST_PANEL_LIFETIME);
        }
    }*/
    
}




//thanks to Liam for helping me figure out from the disassembly what the server's director_stop does
directorStop()
{
    #if READY_DEBUG
    DebugPrintToAll("[DEBUG] Director stopped.");
    #endif      
    //doing director_stop on the server sets the below variables like so
    SetConVarInt(FindConVar("director_no_bosses"), 1);
    if(GetConVarBool(cvarReadyUpStyle))
    {
        SetConVarInt(FindConVar("director_no_specials"), 0);
        SetConVarInt(FindConVar("versus_force_start_time"), 86400); //24hours : D
    }
    else
    {
        SetConVarInt(FindConVar("director_no_specials"), 1);
        SetConVarInt(FindConVar("versus_force_start_time"), 90);    //default
    }
    SetConVarInt(FindConVar("director_no_mobs"), 1);
    SetConVarInt(FindConVar("director_ready_duration"), 0);
    SetConVarInt(FindConVar("z_common_limit"), 0);
    SetConVarInt(FindConVar("z_mega_mob_size"), 1); //why not 0? only Valve knows
    //SetConVarInt(FindConVar("z_health"), 0);                                          //doest spawn zombies but doesnt stop director
    
    //empty teams of survivors dont cycle the round
    SetConVarInt(FindConVar("sb_all_bot_team"), 1);
    
    //dont accidentally spawn tanks in ready mode
    ResetConVar(FindConVar("director_force_tank"));
}

directorStart()
{
    #if READY_DEBUG
    DebugPrintToAll("[DEBUG] Director started.");
    #endif
    //getting values from the convars
    new ready_z_common_limit = GetConVarInt(cvarReadyCommonLimit);
    new ready_z_mega_mob_size = GetConVarInt(cvarReadyMegaMobSize);
    new ready_sb_all_bot_team = GetConVarInt(cvarReadyAllBotTeam);
    ResetConVar(FindConVar("director_no_bosses"));
    ResetConVar(FindConVar("director_no_specials"));
    ResetConVar(FindConVar("director_no_mobs"));
    ResetConVar(FindConVar("director_ready_duration"));
    //support for ?v? cfgs - only reset these cvars if the round isn't being restarted, or there isn't a ?v? cfg
    //if(!GetConVarBool(cvarReadyRestartRound) || !GetConVarBool(cvarReadyServerCfg))
    SetConVarInt(FindConVar("z_common_limit"), ready_z_common_limit);
    SetConVarInt(FindConVar("z_mega_mob_size"), ready_z_mega_mob_size);
    SetConVarInt(FindConVar("sb_all_bot_team"), ready_sb_all_bot_team);     
}

//freeze everyone until they ready up
readyOn()
{
    DebugPrintToAll("readyOn() called");
    
    readyMode = true;
    
    PrintHintTextToAll("Ready mode on.\nSay !ready to ready up or !unready to unready.");
    /*if(!hookedSpawnReady) 
    {
    HookEvent("player_spawn", eventSpawnReadyCallback);
    hookedSpawnReady = 1;
    }*/
    if(!hookedPlayerHurt) 
    {
        HookEvent("player_hurt", eventPlayerHurt);
        hookedPlayerHurt = 1;
    }
    
    directorStop();
    
    decl i;
    for(i = 1; i <= MaxClients; i++)
    {
        readyStatus[i] = 0;
        if(IsValidEntity(i) && IsClientInGame(i) && (GetClientTeam(i) == L4D_TEAM_SURVIVORS)) 
        {
            
            #if READY_DEBUG
            new String:curname[128];
            GetClientName(i,curname,128);
            DebugPrintToAll("[DEBUG] Freezing %s [%d] during readyOn().", curname, i);
            #endif
            
            ToggleFreezePlayer(i, true);
        }
    }
    
    if(!unreadyTimerExists)
    {
        unreadyTimerExists = true;
        CreateTimer(READY_UNREADY_HINT_PERIOD, timerUnreadyCallback, _, TIMER_REPEAT);
    }
}

//allow everyone to move now
readyOff()
{
    DebugPrintToAll("readyOff() called");
    
    readyMode = false;
    
    //events seem to be all unhooked _before_ OnPluginEnd
    //though even if it wasnt, they'd get unhooked after anyway..
    if(hookedPlayerHurt && !insidePluginEnd) 
    {
        UnhookEvent("player_hurt", eventPlayerHurt);
        hookedPlayerHurt = 0;
    }
    
    directorStart();
    
    if(insidePluginEnd)
    {
        UnfreezeAllPlayers();
    }
    
    //used to unfreeze all players here always
    //now we will do it at the beginning of the round when its live
    //so that players cant open the safe room door during the restarts
}

UnfreezeAllPlayers()
{
    decl i;
    for(i = 1; i <= MaxClients; i++) 
    {
        if(IsClientInGame(i) && (GetClientTeam(i) != L4D_TEAM_SPECTATE)) 
        {
            #if READY_DEBUG
            new String:curname[128];
            GetClientName(i,curname,128);
            DebugPrintToAll("[DEBUG] Unfreezing %s [%d] during UnfreezeAllPlayers().", curname, i);
            #endif
            
            //if(GetClientTeam(i) != L4D_TEAM_SPECTATE)
                ToggleFreezePlayer(i, false);
            /*else
                SetEntityMoveType(i, MOVETYPE_OBSERVER);*/
        }
    }
}

//make everyone un-ready, but don't actually freeze them
compOn()
{
    DebugPrintToAll("compOn() called");
    
    goingLive = 0;
    readyMode = false;
    forcedStart = 0;
    
    decl i;
    for(i = 1; i <= MAXPLAYERS; i++) readyStatus[i] = 0;
}

//abort an impending countdown to a live match
public Action:compAbort(client, args)
{
    if(!goingLive)
    {
        ReplyToCommand(0, "L4DC: Nothing to abort.");
        return Plugin_Handled;
    }
    
    //  if(readyMode) readyOff();
    if(goingLive)
    {
        KillTimer(liveTimer);
        forcedStart = 0;
        goingLive = 0;
    }
    
    PrintHintTextToAll("Match was aborted by command.");
    
    return Plugin_Handled;
}

//begin the ready mode (everyone now needs to ready up before they can move)
public Action:compReady(client, args)
{
    if(goingLive)
    {
        ReplyToCommand(0, "L4DC: Already going live, ignoring.");
        return Plugin_Handled;
    }
    
    compOn();
    readyOn();
    
    return Plugin_Handled;
}

//force start a match using admin
public Action:compStart(client, args)
{
    if(!readyMode)
        return Plugin_Handled;
    
    if(goingLive)
    {
        ReplyToCommand(0, "L4DC: Already going live, ignoring.");
        return Plugin_Handled;
    }
    
    //  compOn();
    
    goingLive = GetConVarInt(cvarReadyLiveCountdown);
    forcedStart = 1;
    liveTimer = CreateTimer(1.0, timerLiveCountCallback, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
    
    return Plugin_Handled;
}

//restart the map when we toggle the cvar
public ConVarChange_ReadyEnabled(Handle:convar, const String:oldValue[], const String:newValue[])
{   
    /*if(!IsSourcemodVersionValid())
    {
        PrintToChatAll("Your SourceMod version is out of date, please upgrade to 1.2.1 stable");
        return;
    }
    if(!IsLeft4DowntownVersionValid())
    {
        PrintToChatAll("Your Left 4 Downtown Extension is out of date, please upgrade to 0.3.0 or later");
        return;
    }*/
    
    if(oldValue[0] == newValue[0])
    {
        return;
    }
    else
    {
        new value = StringToInt(newValue);
        
        if(value)
        {
            //if sv_search_key is "" && l4d_ready_disable_search_key is 1
            //then don't let admins turn on our plugin
            if(GetConVarInt(cvarReadySearchKeyDisable))
            {
                decl String:searchKey[128];
                GetConVarString(cvarSearchKey, searchKey, 128);
                
                if(searchKey[0] == 0)
                {
                    LogMessage("Ready plugin will ignore sv_search_key");
                    //PrintToChatAll("[SM] Ready plugin will not start while sv_search_key is \"\"");
                    
                    //ServerCommand("l4d_ready_enabled 0");
                    return;
                }
            }
            
            PrintToChatAll("[SM] Ready plugin has been enabled, restarting map in %.0f seconds", READY_RESTART_MAP_DELAY);
        }
        else
        {
            PrintToChatAll("[SM] Ready plugin has been disabled, restarting map in %.0f seconds", READY_RESTART_MAP_DELAY);
            readyOff();
        }
        RestartMapDelayed();
    }
}


//disable the ready mod if sv_search_key is ""
public ConVarChange_SearchKey(Handle:convar, const String:oldValue[], const String:newValue[])
{
    if(oldValue[0] == newValue[0])
    {
        return;
    }
    else
    {   
        if(newValue[0] == 0)
        {
            //wait about 5 secs and then disable the ready up mod
            
            //this gives time for l4d_ready_server_cfg to get executed
            //if a server.cfg disables the sv_search_key
            CreateTimer(5.0, Timer_SearchKeyDisabled, _, TIMER_FLAG_NO_MAPCHANGE);
        }
    }
}

public ConVarChange_AllowReready(Handle:convar, const String:oldValue[], const String:newValue[])
{
    CheckAllowReready();
}

public ConVarChange_cvarSpectatePenalt(Handle:convar, const String:oldValue[], const String:newValue[])
{
    CheckSpectatePenalty();
}

static CheckAllowReready()
{
    if(GetConVarInt(cvarAllowReready) == 0) g_bAllowReready = false;
    else g_bAllowReready = true;
}

static CheckSpectatePenalty()
{
    if(GetConVarInt(cvarSpectatePenalty) < -1) g_iSpectatePenalty = -1;
    else g_iSpectatePenalty = GetConVarInt(cvarSpectatePenalty);
    g_iSpectatePenalty--;
    
    new i;
    for(i = 1; i <= MaxClients; i++)
    {   
        g_iSpectatePenaltyCounter[i] = g_iSpectatePenalty;
    }   
}

//repeatedly count down until the match goes live
public Action:Timer_SearchKeyDisabled(Handle:timer)
{
    //if sv_search_key is "" && l4d_ready_disable_search_key is 1
    //then don't let admins turn on our plugin
    if(GetConVarInt(cvarReadySearchKeyDisable) && GetConVarInt(cvarEnforceReady))
    {
        decl String:searchKey[128];
        GetConVarString(cvarSearchKey, searchKey, 128);
        
        if(searchKey[0] == 0)
        {
            PrintToChatAll("[SM] Sv_search_key is set to \"\", the ready plugin will now do absolutely nothing.");
            
            //ServerCommand("l4d_ready_enabled 0");
            return;
        }
    }
}

public Action:Command_DumpEntities(client, args)
{
    decl String:netClass[128];
    decl String:className[128];
    new i;
    
    DebugPrintToAll("Dumping entities...");
    
    for(i = 1; i < GetMaxEntities(); i++)
    {
        if(IsValidEntity(i))
        {
            if(IsValidEdict(i)) 
            {
                GetEdictClassname(i, className, 128);
                GetEntityNetClass(i, netClass, 128);
                DebugPrintToAll("Edict = %d, class name = %s, net class = %s", i, className, netClass);
            }
            else
            {
                GetEntityNetClass(i, netClass, 128);
                DebugPrintToAll("Entity = %d, net class = %s", i, netClass);
            }
        }
    }
    
    return Plugin_Handled;
}

public Action:Command_DumpGameRules(client,args) 
{
    new getTeamScore = GetTeamScore(2);
    DebugPrintToAll("Get team Score for team 2 = %d", getTeamScore);
    
    new gamerules = FindEntityByClassname(-1, "terror_gamerules");
    
    if(gamerules == -1)
    {
        DebugPrintToAll("Failed to find terror_gamerules edict");
        return Plugin_Handled;
    }
    
    new offset = FindSendPropInfo("CTerrorGameRulesProxy","m_iSurvivorScore");
    if(offset == -1)
    {
        DebugPrintToAll("Failed to find the property when searching for offset");
        return Plugin_Handled;
    }
    
    new entValue = GetEntData(gamerules, offset, 4);
    new entValue2 = GetEntData(gamerules, offset+4, 4);
    //  new distance = GetEntProp(gamerules, Prop_Send, "m_iSurvivorScore");
    
    DebugPrintToAll("Survivor score = %d, %d [offset = %d]", entValue, entValue2, offset);
    
    new c_offset = FindSendPropInfo("CTerrorGameRulesProxy","m_iCampaignScore");
    if(c_offset == -1)
    {
        DebugPrintToAll("Failed to find the property when searching for c_offset");
        return Plugin_Handled;
    }
    
    new centValue = GetEntData(gamerules, c_offset, 2);
    new centValue2 = GetEntData(gamerules, c_offset+4, 2);
    //  new distance = GetEntProp(gamerules, Prop_Send, "m_iSurvivorScore");
    
    DebugPrintToAll("Campaign score = %d, %d [offset = %d]", centValue, centValue2, c_offset);
    
    /*
    * try the 4 cs_team_manager aka CCSTeam edicts
    * 
    */
    
    decl teamNumber, score;
    decl String:teamName[128];
    decl String:curClassName[128];
    
    new i, teams;
    for(i = 0; i < GetMaxEntities() && teams < 4; i++)
    {
        if(IsValidEdict(i)) 
        {
            GetEdictClassname(i, curClassName, 128);
            if(strcmp(curClassName, "cs_team_manager") == 0) 
            {
                teams++;
                
                teamNumber = GetEntData(i, FindSendPropInfo("CCSTeam", "m_iTeamNum"), 1);
                score = GetEntData(i, FindSendPropInfo("CCSTeam", "m_iScore"), 4);
                
                GetEntPropString(i, Prop_Send, "m_szTeamname", teamName, 128);
                
                DebugPrintToAll("Team #%d, score = %d, name = %s", teamNumber, score, teamName);
            }
        }
        
    }
    
    return Plugin_Handled;
}

public Action:Command_ScanProperties(client, args)
{
    if(GetCmdArgs() != 3)
    {
        PrintToChat(client, "Usage: sm_scanproperties <step> <size> <needle>");
        return Plugin_Handled;
    }
    
    decl String:cmd1[128], String:cmd2[128], String:cmd3[128];
    decl String:curClassName[128];
    
    GetCmdArg(1, cmd1, 128);
    GetCmdArg(2, cmd2, 128);    
    GetCmdArg(3, cmd3, 128);
    
    new step = StringToInt(cmd1);
    new size = StringToInt(cmd2);
    new needle = StringToInt(cmd3);
    
    new gamerules = FindEntityByClassname(-1, "terror_gamerules");
    
    if(gamerules == -1)
    {
        DebugPrintToAll("Failed to find terror_gamerules edict");
        return Plugin_Handled;
    }
    
    
    new i;
    new value = -1;
    for(i = 100; i < 1000; i += step)
    {
        value = GetEntData(gamerules, i, size);
        
        if(value == needle)
        {
            break;
        }
    }
    if(value == needle)
    {
        DebugPrintToAll("Found value at offset = %d in terror_gamesrules", i);
    }
    else
    {
        DebugPrintToAll("Failed to find value in terror_gamesrules");
    }
    
    new teams;
    new j;
    for(j = 0; j < GetMaxEntities() && teams < 4; j++)
    {
        if(IsValidEdict(j)) 
        {
            GetEdictClassname(j, curClassName, 128);
            if(strcmp(curClassName, "cs_team_manager") == 0)
            {
                teams++;
                value = -1;
                
                for(i = 100; i < 1000; i += step)
                {
                    value = GetEntData(j, i, size);
                    
                    if(value == needle)
                    {
                        break;
                    }
                }
                if(value == needle)
                {
                    DebugPrintToAll("Found value at offset = %d in cs_team_manager", i);
                    break;
                }
                else
                {
                    DebugPrintToAll("Failed to find value in cs_team_manager");
                }
            }
        }
        
    }
    
    return Plugin_Handled;
    
}

public Action:Command_PlayerSwap(client, args)
{
    if(args < 2)
    {
        ReplyToCommand(client, "[SM] Usage: sm_swap <player1> <player2> - swap player1's and player2's teams");
        return Plugin_Handled;
    }
    
    new player1_id, player2_id;

    new String:player1[64];
    GetCmdArg(1, player1, sizeof(player1));

    new String:player2[64];
    GetCmdArg(2, player2, sizeof(player2));
    
    player1_id = FindTarget(client, player1, true /*nobots*/, false /*immunity*/);
    player2_id = FindTarget(client, player2, true /*nobots*/, false /*immunity*/);
    
    if(player1_id == -1 || player2_id == -1)
        return Plugin_Handled;
    
    SwapPlayers(player1_id, player2_id);
    
    PrintToChatAll("[SM] %N and %N have been swapped.", player1_id, player2_id);
    
    return Plugin_Handled;
}

public Action:Command_SwapTeams(client, args)
{
    new infected[4];
    new survivors[4];
    
    new inf = 0, sur = 0;
    new i;
    
    for(i = 1; i <= MaxClients; i++)
    {
        if(IsClientInGameHuman(i)) 
        {
            new team = GetClientTeam(i);
            if(team == L4D_TEAM_SURVIVORS)
            {
                survivors[sur] = i;
                sur++;
            }
            else if(team == L4D_TEAM_INFECTED)
            {
                infected[inf] = i;
                inf++;
            }
        }
    }
    
    new min = inf > sur ? sur : inf;
    
    //first swap everyone that we can (equal # on both sides)
    for(i = 0; i < min; i++)
    {
        SwapPlayers(infected[i], survivors[i]);
    }
    
    //then move the remainder of the team to the other team
    if(inf > sur)
    {
        for(i = min; i < inf; i++)
        {
            ChangePlayerTeam(infected[i], L4D_TEAM_SURVIVORS);
        }
    }
    else 
    {
        for(i = min; i < sur; i++)
        {
            ChangePlayerTeam(survivors[i], L4D_TEAM_INFECTED);
        }
    }
    
    PrintToChatAll("[SM] Infected and Survivors have been swapped.");
    
    return Plugin_Handled;
}

//swap the two given players' teams
SwapPlayers(i, j)
{
    if(GetClientTeam(i) == GetClientTeam(j))
        return;
    
    new inf, surv;
    if(GetClientTeam(i) == L4D_TEAM_INFECTED)
    {
        inf = i;
        surv = j;
    }
    else
    {
        inf = j;
        surv = i;
    }

    ChangePlayerTeam(inf,  L4D_TEAM_SPECTATE); 
    ChangePlayerTeam(surv, L4D_TEAM_INFECTED); 
    ChangePlayerTeam(inf,  L4D_TEAM_SURVIVORS); 
}

ChangePlayerTeam(client, team)
{
    if(GetClientTeam(client) == team) return;
    
    if(team != L4D_TEAM_SURVIVORS)
    {
        ChangeClientTeam(client, team);
        return;
    }
    
    //for survivors its more tricky
    
    new String:command[] = "sb_takecontrol";
    new flags = GetCommandFlags(command);
    SetCommandFlags(command, flags & ~FCVAR_CHEAT);
    
    new String:botNames[][] = { "zoey", "louis", "bill", "francis" };
    
    new cTeam;
    cTeam = GetClientTeam(client);
    
    new i = 0;
    while(cTeam != L4D_TEAM_SURVIVORS && i < 4)
    {
        FakeClientCommand(client, "sb_takecontrol %s", botNames[i]);
        cTeam = GetClientTeam(client);
        i++;
    }

    SetCommandFlags(command, flags);
}



//when the match goes live, at round_end of the last automatic restart
//just before the round_start
RoundEndBeforeLive()
{
    readyOff(); 
}

//round_start just after the last automatic restart
RoundIsLive()
{
    UnfreezeAllPlayers();
    
    CreateTimer(1.0, timerLiveMessageCallback, _, _);
}

ToggleFreezePlayer(client, freeze)
{
    SetEntityMoveType(client, freeze ? MOVETYPE_NONE : MOVETYPE_WALK);
}

//client is connected
bool:IsClientInGameHumanSpec(client)
{
    return IsClientInGame(client) && !IsFakeClient(client);
}
//client is in-game and not a bot and not spec
bool:IsClientInGameHuman(client)
{
    return IsClientInGame(client) && !IsFakeClient(client) && ((GetClientTeam(client) == L4D_TEAM_SURVIVORS || GetClientTeam(client) == L4D_TEAM_INFECTED) || GetConVarBool(cvarReadySpectatorRUP));
}

CountInGameHumans()
{
    new i, realPlayers = 0;
    for(i = 1; i <= MaxClients; i++)
    {
        if(IsClientInGameHuman(i)) 
        {
            realPlayers++;
        }
    }
    return realPlayers;
}

public GetAnyClient()
{
    new i;
    for(i = 1; i <= MaxClients; i++)
    {
        if(IsClientConnected(i) && IsClientInGameHuman(i))
        {
            return i;
        }
    }
    return 0;
}


DebugPrintToAll(const String:format[], any:...)
{
#if READY_DEBUG || READY_DEBUG_LOG
    decl String:buffer[192];
    
    VFormat(buffer, sizeof(buffer), format, 2);
    
#if READY_DEBUG
    PrintToChatAll("[READY] %s", buffer);
#endif
    LogMessage("%s", buffer);
#else
    //suppress "format" never used warning
    if(format[0])
        return;
    else
        return;
#endif
}


#if HEALTH_BONUS_FIX
public Action:Command_UpdateHealth(client, args)
{
    DelayedUpdateHealthBonus();
    
    return Plugin_Handled;
}

CheckDependencyVersions(bool:throw=false)
{
#if !READY_DEBUG
    if(!IsSourcemodVersionValid())
    {
        decl String:version[64];
        GetConVarString(FindConVar("sourcemod_version"), version, sizeof(version));
        
        PrintToChatAll("[L4D RUP] Your SourceMod version (%s) is out of date, please upgrade.", version);
        
        if(throw)
            ThrowError("Your SourceMod version (%s) is out of date, please upgrade.", version);
    }
    if(!IsLeft4DowntownVersionValid())
    {
        decl String:version[64];
        new Handle:versionCvar = FindConVar("left4downtown_version");
        if(versionCvar == INVALID_HANDLE)
        {
            strcopy(version, sizeof(version), "0.1.0");
        }
        else
        {
            GetConVarString(versionCvar, version, sizeof(version));
        }
        
        PrintToChatAll("[L4D RUP] Your Left4Downtown Extension (%s) is out of date, please upgrade to %s or later", version, READY_VERSION_REQUIRED_LEFT4DOWNTOWN);
        if(throw)
            ThrowError("Your Left4Downtown Extension (%s) is out of date, please upgrade to %s or later", version, READY_VERSION_REQUIRED_LEFT4DOWNTOWN);
        return;
    }
#else
//suppress warnings
    if(throw && !throw)
    {
        IsSourcemodVersionValid();
        IsLeft4DowntownVersionValid();
    }
#endif
}

bool:IsSourcemodVersionValid()
{
    decl String:version[64];
    GetConVarString(FindConVar("sourcemod_version"), version, sizeof(version));
    
    new minVersion = ParseVersionNumber(READY_VERSION_REQUIRED_SOURCEMOD);
    new versionNumber = ParseVersionNumber(version);

    DebugPrintToAll("SourceMod Minimum version=%x, current=%s (%x)", minVersion, version, versionNumber);
    
    if(versionNumber == minVersion)
    {
#if READY_VERSION_REQUIRED_SOURCEMOD_NONDEV //snapshot-dev might not have latest bugfixes
        if(StrContains(version, "-dev", false) != -1)
        {
            //1.2.1-dev is no good
            return false;
        }
#endif
        return true;
    }
    //newer version or 1.3, assume they know what they're doing
    else if(versionNumber > minVersion)
    {
        return true;
    }
    else
    {
        return false;
    }
}

bool:IsLeft4DowntownVersionValid()
{
    new Handle:versionCvar = FindConVar("left4downtown_version");
    if(versionCvar == INVALID_HANDLE)
    {
        DebugPrintToAll("Could not find left4downtown_version, maybe using 0.1.0");
        return false;
    }
    
    decl String:version[64];
    GetConVarString(versionCvar, version, sizeof(version));
    
    new minVersion = ParseVersionNumber(READY_VERSION_REQUIRED_LEFT4DOWNTOWN);
    new versionNumber = ParseVersionNumber(version);

    DebugPrintToAll("Left4Downtown min version=%x, current=%s (%x)", minVersion, version, versionNumber);

    return versionNumber >= minVersion;
}

/* parse a version string such as "1.2.3.4", up to 4 subversions allowed */
ParseVersionNumber(const String:versionText[])
{
    new String:versionNumbers[4][4];
    ExplodeString(versionText, /*split*/".", versionNumbers, 4, 4);
    
    new version = 0;
    new shift = 24;
    for(new i = 0; i < 4; i++)
    {
        version = version | (StringToInt(versionNumbers[i]) << shift);
        
        shift -= 8;
    }
    
    //DebugPrintToAll("Parsed version '%s' as %x", versionText, version);
    return version;
}

public Action:Event_ItemPickup(Handle:event, const String:name[], bool:dontBroadcast)
{   
    new player = GetClientOfUserId(GetEventInt(event, "userid"));
    
    new String:item[128];
    GetEventString(event, "item", item, sizeof(item));
    
    #if EBLOCK_DEBUG
    new String:curname[128];
    GetClientName(player,curname,128);
    
    if(strcmp(item, "pain_pills") == 0)     
        DebugPrintToAll("EVENT - Item %s picked up by %s [%d]", item, curname, player);
    #endif
    
    if(strcmp(item, "pain_pills") == 0)
    {
        painPillHolders[player] = true;
        DelayedPillUpdate();
    }
    
    return Plugin_Handled;
}

public Action:Event_PillsUsed(Handle:event, const String:name[], bool:dontBroadcast)
{   
    new player = GetClientOfUserId(GetEventInt(event, "userid"));
    
    #if EBLOCK_DEBUG
    new subject = GetClientOfUserId(GetEventInt(event, "subject"));
    
    new String:curname[128];
    GetClientName(player,curname,128);
    
    new String:curname_subject[128];
    GetClientName(subject,curname_subject,128);
    
    DebugPrintToAll("EVENT - %s [%d] used pills on subject %s [%d]", curname, player, curname_subject, subject);
    #endif
    
    painPillHolders[player] = false;
    
    return Plugin_Handled;
}



public Action:Event_HealSuccess(Handle:event, const String:name[], bool:dontBroadcast)
{   
    #if EBLOCK_DEBUG
    new player = GetClientOfUserId(GetEventInt(event, "userid"));
    new subject = GetClientOfUserId(GetEventInt(event, "subject"));
    
    new String:curname[128];
    GetClientName(player,curname,128);
    
    new String:curname_subject[128];
    GetClientName(subject,curname_subject,128);
    
    DebugPrintToAll("EVENT - %s [%d] healed %s [%d] successfully", curname, player, curname_subject, subject);
    #endif

    DelayedUpdateHealthBonus();
    
    return Plugin_Handled;
}

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{   
    decl i;
    for(i = 1; i <= MaxClients; i++)
    {
        painPillHolders[i] = false;
    }
    
    return Plugin_Handled;
}


DelayedUpdateHealthBonus()
{
    #if EBLOCK_USE_DELAYED_UPDATES
    CreateTimer(EBLOCK_BONUS_UPDATE_DELAY, Timer_DoUpdateHealthBonus, _, _);
    #else
    UpdateHealthBonus();
    #endif
    
    DebugPrintToAll("Delayed health bonus update");
}

public Action:Timer_DoUpdateHealthBonus(Handle:timer)
{
    UpdateHealthBonus();
}

UpdateHealthBonus()
{
    decl i;
    for(i = 1; i <= MaxClients; i++)
    {
        if(IsClientInGame(i) && GetClientTeam(i) == 2) 
        {
            UpdateHealthBonusForClient(i);
        }
    }
}

DelayedPillUpdate()
{
    #if EBLOCK_USE_DELAYED_UPDATES
    CreateTimer(EBLOCK_BONUS_UPDATE_DELAY, Timer_PillUpdate, _, _);
    #else
    UpdateHealthBonusForPillHolders();
    #endif
    
    DebugPrintToAll("Delayed pill bonus update");
}

public Action:Timer_PillUpdate(Handle:timer)
{
    UpdateHealthBonusForPillHolders();
}

UpdateHealthBonusForPillHolders()
{
    decl i;
    for(i = 1; i <= MaxClients; i++)
    {
        if(IsClientInGame(i) && GetClientTeam(i) == 2 && painPillHolders[i]) 
        {
            UpdateHealthBonusForClient(i);
        }
    }
}

UpdateHealthBonusForClient(client)
{
    SendHurtMe(client);
}

SendHurtMe(i)
{   /*
    * when a person uses pills the m_healthBuffer gets set to 
    * minimum(50, 100-currentHealth)
    * 
    * it stays at that value until the person heals (or uses pills?)
    * or the round is over
    * 
    * once the m_healthBuffer property is non-0 the health bonus for that player
    * seems to keep updating
    * 
    * The first time we set it ourselves that player gets that much temp hp,
    * setting it afterwards crashes the server, and setting it after we set it
    * for the first time doesn't do anything.
    */
    new Float:healthBuffer = GetEntPropFloat(i, Prop_Send, "m_healthBuffer");
    
    DebugPrintToAll("Health buffer for player [%d] is %f", i, healthBuffer);    
    if(healthBuffer == 0.0)
    {
        SetEntPropFloat(i, Prop_Send, "m_healthBuffer", EBLOCK_BONUS_HEALTH_BUFFER);
        DebugPrintToAll("Health buffer for player [%d] set to %f", i, EBLOCK_BONUS_HEALTH_BUFFER);
    }
    
    DebugPrintToAll("Sent hurtme to [%d]", i);
}
#endif