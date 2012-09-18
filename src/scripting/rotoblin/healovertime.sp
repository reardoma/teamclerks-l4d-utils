/*
 * ============================================================================
 *
 *  Rotoblin
 *
 *  File:			rotoblin.healovertime.sp
 *  Type:			Module
 *  Description:	Pills heal over time.
 *
 *  Author = ProdigySim
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * ============================================================================
 */

/**
 *	To-Do: remove the unneeded code, reset the g_fHealthBuffer array on round starts,
 *		   add a cvar to set the interval of the heal updates,
		   make the plugin get the max heal value of "pain_pills_health_value"
 */
 
// --------------------
//       Private
// --------------------

static			Handle:	g_hHealOverTimeCvar					= INVALID_HANDLE;
static			Handle: g_hHealOverTimeIntervalCvar			= INVALID_HANDLE;
static			Handle: g_hHealOverTimeAmmountCvar			= INVALID_HANDLE;
static			Handle: g_hHealOverTimeIncrementCvar		= INVALID_HANDLE;

static					g_iHealOverTimeAmmount				= 50;
static					g_iHealOverTimeIncrement			= 10;
static	const	String:	PILLS_HEALTH_CVAR[]					= "pain_pills_health_value";
static			bool:	g_bHealOverTimeEnabled				= false;
static			Float:	g_fHealOverTimeInterval				= 1.0;
static			Float:	g_fHealthBuffer[MAXPLAYERS + 1] 	= {0.0};

static					g_iDebugChannel						= 0;
static	const	String:	DEBUG_CHANNEL_NAME[]				= "HealOverTime";

public _HealOverTime_OnPluginStart()
{
	HookPublicEvent(EVENT_ONPLUGINENABLE, _HOT_OnPluginEnabled);
	HookPublicEvent(EVENT_ONPLUGINDISABLE, _HOT_OnPluginDisabled);
	
	CreateBoolConVar(g_hHealOverTimeCvar, "hot", "Pills heal over time (10 hp each interval).", g_bHealOverTimeEnabled);
	g_bHealOverTimeEnabled = GetConVarBool(g_hHealOverTimeCvar);
	
	g_hHealOverTimeIntervalCvar = CreateConVarEx("hot_interval", "1.0", "Interval in seconds between health gains.", FCVAR_NOTIFY | FCVAR_PLUGIN);
	if (g_hHealOverTimeIntervalCvar == INVALID_HANDLE) ThrowError("Unable to create hot_interval cvar!");
	
	g_iHealOverTimeAmmount = GetConVarInt(FindConVar(PILLS_HEALTH_CVAR));	//so on plugin load, if for some reason a person uses different pain_pills_health_value, they are saved on plugin use
	
	g_hHealOverTimeAmmountCvar = CreateConVarEx("hot_ammount", "50", "Max health gained from one set of pills.", FCVAR_NOTIFY | FCVAR_PLUGIN);
	if (g_hHealOverTimeAmmountCvar == INVALID_HANDLE) ThrowError("Unable to create hot_ammount cvar!");
	
	g_hHealOverTimeIncrementCvar = CreateConVarEx("hot_increment", "10", "Health gained per interval.", FCVAR_NOTIFY | FCVAR_PLUGIN);
	if (g_hHealOverTimeIncrementCvar == INVALID_HANDLE) ThrowError("Unable to create hot_increment cvar!");
	
	AddConVarToReport(g_hHealOverTimeIntervalCvar);	// Add to report status module
	AddConVarToReport(g_hHealOverTimeIncrementCvar); // Add to report status module
	AddConVarToReport(g_hHealOverTimeAmmountCvar); // Add to report status module
	
	UpdateHealOverTime();
	
	g_iDebugChannel = DebugAddChannel(DEBUG_CHANNEL_NAME);
	DebugPrintToAllEx("Module is now setup");
}



static CreateBoolConVar(&Handle:conVar, const String:cvarName[], const String:cvarDescription[], bool:initialValue)
{	
	decl String:buffer[10];
	IntToString(int:initialValue, buffer, sizeof(buffer)); // Get default value for replacement style
	
	conVar = CreateConVarEx(cvarName, buffer, 
		cvarDescription, 
		FCVAR_NOTIFY | FCVAR_PLUGIN);
	
	if (conVar == INVALID_HANDLE) 
	{
		ThrowError("Unable to create enable cvar named %s!", cvarName);
	}
	
	AddConVarToReport(conVar); // Add to report status module
}

public _HOT_OnPluginEnabled()
{
	g_fHealOverTimeInterval		= GetConVarFloat(g_hHealOverTimeIntervalCvar);
	g_iHealOverTimeIncrement	= GetConVarInt(g_hHealOverTimeIncrementCvar);
	g_iHealOverTimeAmmount 		= GetConVarInt(g_hHealOverTimeAmmountCvar);
	
	HookConVarChange(g_hHealOverTimeCvar, _HOT_HealOverTime_CvarChange);
	HookConVarChange(g_hHealOverTimeIntervalCvar, _HOT_HealOverTime_CvarChange);
	HookConVarChange(g_hHealOverTimeAmmountCvar, _HOT_HealOverTime_CvarChange);
	HookConVarChange(g_hHealOverTimeIncrementCvar, _HOT_HealOverTime_CvarChange);
	HookEvent("pills_used", PillsUsed_Event);
	HookEvent("round_start", _HOT_RoundStart_Event, EventHookMode_PostNoCopy);
	HookPublicEvent(EVENT_ONPLAYERRUNCMD, _HOT_OnPlayerRunCmd);
}

/**
 * Updates players m_healthBuffer when they use +attack button
 *
 * @noreturn
 */
public Action:_HOT_OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if (GetClientTeam(client) == 2 && buttons & IN_ATTACK)
	{
		g_fHealthBuffer[client] = GetSurvivorTempHealth(client);
		DebugPrintToAllEx("updated %N's m_healthBuffer with %f", client, g_fHealthBuffer[client]);	
	}
	return Plugin_Continue;
}

public _HOT_OnPluginDisabled()
{
	UnhookConVarChange(g_hHealOverTimeCvar, _HOT_HealOverTime_CvarChange);
	UnhookConVarChange(g_hHealOverTimeIntervalCvar, _HOT_HealOverTime_CvarChange);
	UnhookConVarChange(g_hHealOverTimeAmmountCvar, _HOT_HealOverTime_CvarChange);
	UnhookConVarChange(g_hHealOverTimeIncrementCvar, _HOT_HealOverTime_CvarChange);	
	UnhookEvent("pills_used", PillsUsed_Event);
	UnhookEvent("round_start", _HOT_RoundStart_Event, EventHookMode_PostNoCopy);
	UnhookPublicEvent(EVENT_ONPLAYERRUNCMD, _HOT_OnPlayerRunCmd);
}

public _HOT_RoundStart_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (g_bHealOverTimeEnabled)
	{
		ResetHealthBufferArray();
	}
}

public _HOT_HealOverTime_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	UpdateHealOverTime();
}

/**
 * Updates all integers and floats and sets convars, when one cvar is changed
 * 
 * @noreturn
 */
static UpdateHealOverTime()
{
	g_bHealOverTimeEnabled 		= GetConVarBool(g_hHealOverTimeCvar);
	g_fHealOverTimeInterval 	= GetConVarFloat(g_hHealOverTimeIntervalCvar);
	g_iHealOverTimeAmmount 		= GetConVarInt(g_hHealOverTimeAmmountCvar);
	g_iHealOverTimeIncrement 	= GetConVarInt(g_hHealOverTimeIncrementCvar);
	
	SetConVarInt(FindConVar(PILLS_HEALTH_CVAR), g_iHealOverTimeAmmount);
}

/**
 * Set the g_fHealthBuffer[MaxPlayers] to 0
 *
 * @noreturn
 */
static ResetHealthBufferArray()
{
	for(new i = 1; i <= MaxClients; i++)
	{
		g_fHealthBuffer[i] = 0.0;
	}
}

public Action:PillsUsed_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!g_bHealOverTimeEnabled) return;
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", g_fHealthBuffer[client]); //sets the current temp hp before eating pills
	HealEntityOverTime(client, g_fHealOverTimeInterval, g_iHealOverTimeIncrement, g_iHealOverTimeAmmount);
}

static Float:GetSurvivorTempHealth(client)
{
	new Float:temphp = GetEntPropFloat(client, Prop_Send, "m_healthBuffer") - ((GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * GetConVarFloat(FindConVar("pain_pills_decay_rate"))) - 1.0;
	return Float:temphp > 0.0 ? temphp : 0.0;
}

static HealEntityOverTime(client, Float:interval, increment, total)
{
	new maxhp=GetEntProp(client, Prop_Send, "m_iMaxHealth", 2);
	
	if(client==0 || !IsClientInGame(client) || !IsPlayerAlive(client))
	{
		return;
	}
	if(increment >= total)
	{
		HealTowardsMax(client, total, maxhp);
	}
	else
	{
		HealTowardsMax(client, increment, maxhp);
		new Handle:myDP;
		CreateDataTimer(interval, __HOT_ACTION, myDP, 
			TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
		WritePackCell(myDP, client);
		WritePackCell(myDP, increment);
		WritePackCell(myDP, total-increment);
		WritePackCell(myDP, maxhp);
	}
}

public Action:__HOT_ACTION(Handle:timer, Handle:pack)
{
	ResetPack(pack);
	new client = ReadPackCell(pack);
	new increment = ReadPackCell(pack);
	new pos = GetPackPosition(pack);
	new remaining = ReadPackCell(pack);
	new maxhp = ReadPackCell(pack);
	
	DebugPrintToAllEx("player: %N, increment: %d, remaining: %d, max: %d (interval: %f)", client, increment, remaining, maxhp, g_fHealOverTimeInterval);
	
	if(client==0 || !IsClientInGame(client) || !IsPlayerAlive(client))
	{
		return Plugin_Stop;
	}
	
	if(increment >= remaining)
	{
		HealTowardsMax(client, remaining, maxhp);
		return Plugin_Stop;
	}
	HealTowardsMax(client, increment, maxhp);
	SetPackPosition(pack, pos);
	WritePackCell(pack, remaining-increment);
	
	return Plugin_Continue;
}

/**
 * Heal Towards Max hp
 *
 * @param amount		Ammount of health to heal.
 * @param max			Max health value to heal to.
 * @noreturn
 */
static HealTowardsMax(client, amount, max)
{
	new Float:hb = float(amount) + GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
	new Float:overflow = (hb+GetClientHealth(client))-max;
	if(overflow > 0)
	{
		hb -= overflow;
	}
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", hb);
}

/**
 * Wrapper for printing a debug message without having to define channel index
 * everytime.
 *
 * @param format		Formatting rules.
 * @param ...			Variable number of format parameters.
 * @noreturn
 */
static DebugPrintToAllEx(const String:format[], any:...)
{
	decl String:buffer[DEBUG_MESSAGE_LENGTH];
	VFormat(buffer, sizeof(buffer), format, 2);
	DebugPrintToAll(g_iDebugChannel, buffer);
}