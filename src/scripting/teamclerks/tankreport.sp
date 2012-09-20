
// Don't let the script be included more than once.
#if defined _teamclerks_tank_report
  #endinput
#endif
#define _teamclerks_tank_report

#define ZOMBIECLASS_TANK 8
#define TANK_REPORT_PANEL_LIFETIME 15

static Handle:_TankReport_Panel = INVALID_HANDLE;
static Handle:_TankReport_Cvar  = INVALID_HANDLE;
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
}

/**
 * Empty, as we don't care about what gets pressed in the HUD.
 */
public _TankReport_Panel_Event(Handle:menu, MenuAction:action, param1, param2) { }

public _TankReport_OnMapStart()
{
    if (_TankReport_Enabled)
    {
        // Clear out the damage report in case there's a tank.
        for (new i = 0; i < MAXPLAYERS; i++)
        {
            damageReport[i] = 0;
        }
        
        HookEvent("player_hurt", _TankReport_Player_Hurt_Event);
        HookTankEvent(TANK_SPAWNED, _TankReport_Tank_Spawned);
        HookTankEvent(TANK_KILLED, _TankReport_Report_To_Players);
    }
}

/**
 * Handles setting up all the values for recording damage.
 */
public _TankReport_Tank_Spawned(Handle:event, const String:name[], bool:dontBroadcast)
{    
    tankReportRequired = true;
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
 * If enabled, send the report to the players.
 */
public _TankReport_Report_To_Players(Handle:event, const String:name[], bool:dontBroadcast)
{
    if (_TankReport_Enabled)
    {
        if (tankReportRequired)
        {
            // Report it!
            if (_TankReport_Panel != INVALID_HANDLE) CloseHandle(_TankReport_Panel);
            _TankReport_Panel = CreatePanel();
            
            decl String:sBuffer[512];
            Format(sBuffer, sizeof(sBuffer), "Tank Damage Report", PLUGIN_TAG);
            SetPanelTitle(_TankReport_Panel, sBuffer);
            
            new const maxLen = 1024;
            decl String:result[maxLen];
            decl String:nameTag[MAX_NAME_LENGTH + 2];
            decl String:clientName[MAX_NAME_LENGTH];
            
            // Iterate over all survivors
            for (new survivor = 1; survivor < MAXPLAYERS; survivor++)
            {
                // If not a survivor, ignore
                if (!Is_Client_Survivor(survivor)) continue;
                // TODO: maybe we can allow this to be infected as well... friendly-fire!
    
                GetClientName(survivor, clientName, sizeof(clientName));
                Format(nameTag, MAX_NAME_LENGTH + 2, "%s: ", clientName);
                // Draw the name as "kain: " as an item to the panel
                DrawPanelItem(_TankReport_Panel, nameTag);
                Format(result, maxLen, "%i", damageReport[survivor]);
                // Draw the damage dealt as "1321" as plain text to that item on the panel.
                DrawPanelText(_TankReport_Panel, result);
            }
    
            // Iterate over all clients
            for (new client = 1; client < MAXPLAYERS; client++)
            {
                // If not a player, just ignore
                if (!Is_Valid_Player_Client(client)) continue;
                
                SendPanelToClient(_TankReport_Panel, client, _TankReport_Panel_Event, TANK_REPORT_PANEL_LIFETIME);
            }
        }
        
        UnhookEvent("player_hurt", _TankReport_Player_Hurt_Event);
        UnhookTankEvent(TANK_SPAWNED, _TankReport_Tank_Spawned);
        UnhookTankEvent(TANK_KILLED, _TankReport_Report_To_Players);
        
        // Lastly...
        tankReportRequired = false;
    }
}