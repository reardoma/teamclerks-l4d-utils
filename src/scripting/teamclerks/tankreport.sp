
// Don't let the script be included more than once.
#if defined _teamclerks_tank_report
  #endinput
#endif
#define _teamclerks_tank_report

#define ZOMBIECLASS_TANK 8
#define TANK_REPORT_PANEL_LIFETIME 15

static Handle:_TankReport_Cvar = INVALID_HANDLE;
static bool:_TankReport_Enabled = false;

// Attacker, Victim
new damageReport[MAXPLAYERS+1];
new bool:tankReportRequired = false;

public _TankReport_OnPluginStart()
{
    _TankReport_Cvar = CreateConVar("tank_report_enabled", "0", "Controls whether tank info is displayed to players.", FCVAR_PLUGIN|FCVAR_SPONLY, true, 0.0, true, 1.0);
    HookConVarChange(_TankReport_Cvar, _TankReport_Cvar_Changed);

    HookPublicEvent(EVENT_ONMAPSTART, _TankReport_OnMapStart);
    HookPublicEvent(EVENT_ONMAPEND, _TankReport_Report_To_Players);
    
    HookTankEvent(TANK_SPAWNED, _TankReport_Tank_Spawned);
    HookTankEvent(TANK_KILLED, _TankReport_Tank_Killed);
}

public _TankReport_OnMapStart()
{
    // Clear out the damage report in case there's a tank.
    for (new i = 0; i < MAXPLAYERS+1; i++)
    {
        damageReport[i] = 0;
    }
}

/**
 * Handles setting up all the values for recording damage.
 */
public _TankReport_Tank_Spawned(Handle:event, const String:name[], bool:dontBroadcast)
{
    HookEvent("player_hurt", _TankReport_Player_Hurt_Event);
    
    tankReportRequired = true;
}

/**
 * Handles packaging the final report, then creates the timer to display to users. 
 */
public _TankReport_Tank_Killed(Handle:event, const String:name[], bool:dontBroadcast)
{
    UnhookEvent("player_hurt", _TankReport_Player_Hurt_Event);
    
    _TankReport_Report_To_Players();
}


/**
 * Tank Report cvar changed.
 *
 * @param convar        Handle to the convar that was changed.
 * @param oldValue        String containing the value of the convar before it was changed.
 * @param newValue        String containing the new value of the convar.
 * @noreturn
 */
public _TankReport_Cvar_Changed(Handle:convar, const String:oldValue[], const String:newValue[])
{
    _TankReport_Enabled = GetConVarBool(convar);
}

/**
 * Any time the tank takes damage, we want to add that to the report for a player.
 */
public Action:_TankReport_Player_Hurt_Event(Handle:event, String:event_name[], bool:dontBroadcast)
{
    new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
    new victim   = GetClientOfUserId(GetEventInt(event, "userid"));
    new damage   = GetEventInt(event, "dmg_health");
    
    if (Is_Client_Infected(victim) &&
        GetEntProp(victim, Prop_Send, "m_zombieClass") == ZOMBIECLASS_TANK)
    {
        damageReport[attacker] += damage;
    }
}

/**
 * This was needed as a callback; not sure why.
 */
public _TankReport_Panel(Handle:menu, MenuAction:action, param1, param2) 
{ 
}


/**
 * If enabled, send the report to the players.
 */
public _TankReport_Report_To_Players()
{
    if (tankReportRequired && _TankReport_Enabled)
    {
        // Report it!
        new Handle:panel = CreatePanel();
        
        new const maxLen = 1024;
        decl String:result[maxLen];
        decl String:name[MAX_NAME_LENGTH];

        DrawPanelText(panel,"Damage to tank");
        
        // Iterate over all survivors
        for (new survivor = 1; survivor < MAXPLAYERS+1; survivor++)
        {
            // If not a survivor, ignore
            if (!Is_Client_Survivor(survivor)) continue;

            GetClientName(survivor, name, sizeof(name));
            // "kain: 4214" per survivor drawn as text to the panel
            Format(result, maxLen, "->%s: %i", name, damageReport[survivor]);
            DrawPanelText(panel, result);
        }

        // Iterate over all clients
        for (new client = 1; client < MAXPLAYERS+1; client++)
        {
            // If not a player, just ignore
            if (!Is_Valid_Player_Client(client)) continue;
            
            SendPanelToClient(panel, client, _TankReport_Panel, TANK_REPORT_PANEL_LIFETIME);
        }
    }
    
    // Lastly...
    tankReportRequired = false;
}