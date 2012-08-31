#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

// --------------------
//	 Private
// --------------------

static	const	String:	SP_CVAR[]               	= "skeetpractice";
static  const   String: SP_CVAR_DEFAULT_VALUE[] 	= "0";
static  const   String: SP_CVAR_DESCRIPTION[]   	= "Whether skeet practice is enabled.";
static		    Handle:	g_hSkeetPracticeCvar    	= INVALID_HANDLE;

// **********************************************
//			 Forwards
// **********************************************

/**
 * Plugin is starting.
 *
 * @noreturn
 */
public _SkeetPractice_OnPluginStart()
{
	HookPublicEvent(EVENT_ONPLUGINENABLE, _SP_OnPluginEnabled);
	HookPublicEvent(EVENT_ONPLUGINDISABLE, _SP_OnPluginDisabled);
}

/**
 * Plugin is now enabled.
 *
 * @noreturn
 */
public _SP_OnPluginEnabled()
{
	g_hSkeetPracticeCvar = CreateConVar(SP_CVAR, SP_CVAR_DEFAULT_VALUE, SP_CVAR_DESCRIPTION, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 1.0);
	HookConVarChange(g_hSkeetPracticeCvar, _SkeetPractice_CvarChange);
}

/**
 * Plugin is now disabled.
 *
 * @noreturn
 */
public _SP_OnPluginDisabled()
{
	UnhookConVarChange(g_hSkeetPracticeCvar, _SkeetPractice_CvarChange);
	g_hSkeetPracticeCvar = INVALID_HANDLE;
}

/**
 * No mobs cvar changed.
 *
 * @param convar		Handle to the convar that was changed.
 * @param oldValue		String containing the value of the convar before it was changed.
 * @param newValue		String containing the new value of the convar.
 * @noreturn
 */
public _SkeetPractice_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (oldValue[0] == newValue[0])
	{
		return;
	}
	else
	{
		new value = StringToInt(newValue);
		
		if (value)
		{
			CommandSkeetPracticeStart();
		}
		else
		{
			CommandSkeetPracticeStop();
		}
	}
}

public Action:timerRestartMap(Handle:timer)
{
	RestartMapNow();
}

new Handle:HunterSurvivor[MAXPLAYERS+1];

public OnClientDisconnect(client)
{
	if (HunterSurvivor[client] != INVALID_HANDLE)
	{
		KillTimer(HunterSurvivor[client]);
		HunterSurvivor[client] = INVALID_HANDLE;
	}
}

public Event_PlayerPounced(Handle:event, const String:name[], bool:dontBroadcast)
{
	new hunterClient = GetClientOfUserId(GetEventInt(event, "userid"));
	decl String:hunterName[256];
	GetClientName(hunterClient, hunterName, 256);
	new hunterHealth = GetClientHealth(hunterClient);
	new survivorClient = GetClientOfUserId(GetEventInt(event, "victim"));
	
	PrintHintText(hunterClient,"%s had %i health left.", hunterName, hunterHealth);
	PrintHintText(survivorClient,"%s had %i health left.", hunterName, hunterHealth);
    
	new Handle:hunterPack;
	HunterSurvivor[hunterClient] = CreateDataTimer(1.0, killPouncedHunter, hunterPack);
	WritePackCell(hunterPack, hunterClient);
	
	new Handle:survivorPack;
	HunterSurvivor[survivorClient] = CreateDataTimer(2.0, healPouncedSurvivor, survivorPack);
	WritePackCell(survivorPack, survivorClient);
}

public Action:killPouncedHunter(Handle:timer, Handle:pack)
{
	new hunterClient;
	
	ResetPack(pack);
	hunterClient = ReadPackCell(pack);
	
	ForcePlayerSuicide(hunterClient);
	
	HunterSurvivor[hunterClient] = INVALID_HANDLE;
}

public Action:healPouncedSurvivor(Handle:timer, Handle:pack)
{
	new survivorClient;
	
	ResetPack(pack);
	survivorClient = ReadPackCell(pack);
	
	new flags = GetCommandFlags("give");
	// Turn this off as a cheat
	SetCommandFlags("give", flags & ~FCVAR_CHEAT);
	if (IsClientInGame(survivorClient))
	{
		// Make the survivor give himself some health
		FakeClientCommand(survivorClient, "give health");
	}
	// QUICK, turn it back on as a cheat
	SetCommandFlags("give", flags | FCVAR_CHEAT);
	
	HunterSurvivor[survivorClient] = INVALID_HANDLE;
}

//
// Private methods
//

CommandSkeetPracticeStart()
{
	// Hook the pounce event up.
	HookEvent("lunge_pounce", Event_PlayerPounced);
	
	//doing director_stop on the server sets the below variables like so
	SetConVarFloat(FindConVar("versus_tank_chance"), 0.00);
	SetConVarFloat(FindConVar("versus_witch_chance"), 0.00);
	SetConVarFloat(FindConVar("versus_tank_chance_intro"), 0.00);
	SetConVarFloat(FindConVar("versus_tank_chance_finale"), 0.00);
	SetConVarFloat(FindConVar("versus_witch_chance_intro"), 0.00);
	SetConVarFloat(FindConVar("versus_witch_chance_finale"), 0.00);
	SetConVarInt(FindConVar("director_no_bosses"), 1);
	SetConVarInt(FindConVar("director_no_mobs"), 1);
	SetConVarInt(FindConVar("director_ready_duration"), 0);
	SetConVarInt(FindConVar("z_common_limit"), 0);
	SetConVarInt(FindConVar("z_mega_mob_size"), 1); //why not 0? only Valve knows
	
	//empty teams of survivors dont cycle the round
	SetConVarInt(FindConVar("sb_all_bot_team"), 1);
	
	// Set it so only hunters can load
	SetConVarInt(FindConVar("z_minion_limit"), 4);
	SetConVarInt(FindConVar("z_hunter_limit"), 4);
	SetConVarInt(FindConVar("z_versus_boomer_limit"), 0);
	SetConVarInt(FindConVar("z_versus_smoker_limit"), 0);
	
	// Set respawn timers really low
	SetConVarInt(FindConVar("z_ghost_delay_max"), 1);
	SetConVarInt(FindConVar("z_ghost_delay_min"), 1);
	
	// Turn on alltalk for fun
	SetConVarInt(FindConVar("sv_alltalk"), 1);
	SetConVarInt(FindConVar("vs_max_team_switches"),999);
	
	// Turn off items and junk
	SetConVarInt(FindConVar("director_convert_pills"),0);
	SetConVarFloat(FindConVar("director_vs_convert_pills"),0.0);
	SetConVarFloat(FindConVar("director_pain_pill_density"),0.0);
	SetConVarFloat(FindConVar("director_propane_tank_density"),0.0);
	SetConVarFloat(FindConVar("director_gas_can_density"),0.0);
	SetConVarFloat(FindConVar("director_oxygen_tank_density"),0.0);
	SetConVarFloat(FindConVar("director_molotov_density"),0.0);
	SetConVarFloat(FindConVar("director_pipe_bomb_density"),0.0);
	SetConVarFloat(FindConVar("director_pistol_density"),0.0);
	
	PrintToChatAll("[SM] Skeet practice loaded.");
	
	RestartMapIn(5.0);
}

CommandSkeetPracticeStop()
{	
	UnhookEvent("lunge_pounce", Event_PlayerPounced);
	
	ResetConVar(FindConVar("director_no_bosses"));
	ResetConVar(FindConVar("director_no_mobs"));
	ResetConVar(FindConVar("director_ready_duration"));
	ResetConVar(FindConVar("z_common_limit"));
	ResetConVar(FindConVar("z_mega_mob_size"));
	ResetConVar(FindConVar("sb_all_bot_team"));
	ResetConVar(FindConVar("z_minion_limit"));
	ResetConVar(FindConVar("z_hunter_limit"));
	ResetConVar(FindConVar("z_versus_boomer_limit"));
	ResetConVar(FindConVar("z_versus_smoker_limit"));
	ResetConVar(FindConVar("versus_tank_chance_intro"));
	ResetConVar(FindConVar("versus_tank_chance_finale"));
	ResetConVar(FindConVar("versus_tank_chance"));
	ResetConVar(FindConVar("versus_witch_chance_intro"));
	ResetConVar(FindConVar("versus_witch_chance_finale"));
	ResetConVar(FindConVar("versus_witch_chance"));
	ResetConVar(FindConVar("z_ghost_delay_max"));
	ResetConVar(FindConVar("z_ghost_delay_min"));
	ResetConVar(FindConVar("sv_alltalk"));
	ResetConVar(FindConVar("vs_max_team_switches"));
	ResetConVar(FindConVar("director_convert_pills"));
	ResetConVar(FindConVar("director_scavenge_item_override"));
	ResetConVar(FindConVar("director_vs_convert_pills"));
	ResetConVar(FindConVar("director_pain_pill_density"));
	ResetConVar(FindConVar("director_propane_tank_density"));
	ResetConVar(FindConVar("director_gas_can_density"));
	ResetConVar(FindConVar("director_oxygen_tank_density"));
	ResetConVar(FindConVar("director_molotov_density"));
	ResetConVar(FindConVar("director_pipe_bomb_density"));
	ResetConVar(FindConVar("director_pistol_density"));
	
	PrintToChatAll("[SM] Skeet practice stopped.");
	
	RestartMapIn(5.0);
}

RestartMapIn(Float:seconds)
{	
	CreateTimer(seconds, timerRestartMap, _, TIMER_FLAG_NO_MAPCHANGE);
	PrintToChatAll("[SM] Map will restart in %f seconds.", seconds);
}

RestartMapNow()
{
	// Create a buffer for the current map name
	decl String:currentMap[256];
	// Set the buffer to the current map name
	GetCurrentMap(currentMap, 256);
	// Run 'changelevel' as if RCON to the current map name
	ServerCommand("changelevel %s", currentMap);
}
