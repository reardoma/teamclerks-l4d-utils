
// Don't let the script be included more than once.
#if defined _teamclerks_tank_report
  #endinput
#endif
#define _teamclerks_tank_report

#define ZOMBIECLASS_TANK 8
#define TANK_REPORT_PANEL_LIFETIME 25
#define SURVIVOR_LIMIT 4

static Handle:_TankReport_Panel = INVALID_HANDLE;
static Handle:_TankReport_Cvar  = INVALID_HANDLE;
static bool:_TankReport_Enabled = false;
static bool:_TankReport_Tank_In_Play = false;
static _TankReport_Tank_Total_HP = 6000;
static _TankReport_Survivors_Standing = 0;

// Attacker, Victim
new damageReport[MAXPLAYERS+1];
new bool:tankReportRequired = false;

public _TankReport_OnPluginStart()
{
    _TankReport_Cvar = CreateConVar("tank_report_enabled", "0", "Controls whether tank info is displayed to players.", FCVAR_PLUGIN|FCVAR_SPONLY, true, 0.0, true, 1.0);
    HookConVarChange(_TankReport_Cvar, _TankReport_Cvar_Changed);

    HookEvent("player_hurt", _TankReport_Player_Hurt_Event);
    HookEvent("player_incapacitated", _TankReport_Player_Incapd_Event);
    HookEvent("revive_success", _TankReport_Player_Revived);
    
    HookPublicEvent(EVENT_ONMAPSTART, _TankReport_OnMapStart);
    HookPublicEvent(EVENT_ONMAPEND, _TankReport_OnMapEnd);
    
    HookEvent("round_start", _TankReport_OnRoundStart);
    HookEvent("round_end", _TankReport_OnRoundEnd);
}

/**
 * Empty, as we don't care about what gets pressed in the HUD.
 */
public _TankReport_Panel_Event(Handle:menu, MenuAction:action, param1, param2) { }

/**
 * Hook up our tank events and reset our data just to be safe.
 */
public _TankReport_OnMapStart()
{
    if (_TankReport_Enabled)
    {
        // Clear out the damage report in case there's a tank.
        for (new i = 0; i < MaxClients; i++)
        {
            damageReport[i] = 0;
        }
        _TankReport_Tank_Total_HP = GetConVarInt(FindConVar("z_tank_health"));
        _TankReport_Survivors_Standing = SURVIVOR_LIMIT;
        // Avoid div-0, thank you.
        if (_TankReport_Tank_Total_HP == 0)
        {
            _TankReport_Tank_Total_HP = 1;
        }
        HookTankEvent(TANK_SPAWNED, _TankReport_Tank_Spawned);
        HookTankEvent(TANK_KILLED, _TankReport_Tank_Died);
    }
}

/**
 * Unhook our tank events.
 */
public _TankReport_OnMapEnd()
{
    _TankReport_Tank_In_Play = false;
    
    UnhookTankEvent(TANK_SPAWNED, _TankReport_Tank_Spawned);
    UnhookTankEvent(TANK_KILLED, _TankReport_Report_To_Players);
}

public _TankReport_OnRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
    if (_TankReport_Enabled)
    {
        // Clear out the damage report in case there's a tank.
        for (new i = 0; i < MaxClients; i++)
        {
            damageReport[i] = 0;
        }
        _TankReport_Survivors_Standing = SURVIVOR_LIMIT;
        // Avoid div-0, thank you.
        if (_TankReport_Tank_Total_HP == 0)
        {
            _TankReport_Tank_Total_HP = 1;
        }
        HookTankEvent(TANK_SPAWNED, _TankReport_Tank_Spawned);
        HookTankEvent(TANK_KILLED, _TankReport_Report_To_Players);
    }
}

public _TankReport_OnRoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
    _TankReport_Tank_In_Play = false;
    
    UnhookTankEvent(TANK_SPAWNED, _TankReport_Tank_Spawned);
    UnhookTankEvent(TANK_KILLED, _TankReport_Report_To_Players);
}

/**
 * Handles setting up all the values for recording damage.
 */
public _TankReport_Tank_Spawned(Handle:event, const String:name[], bool:dontBroadcast)
{
    if (!_TankReport_Tank_In_Play)
    {
        _TankReport_Tank_In_Play = true;
        tankReportRequired = true;
        _TankReport_Tank_Total_HP = GetClientHealth(GetTankClient());
    }
    // Else this is a pass... we don't care
}

/**
 * Handles reporting the values when the tank dies.
 */
public _TankReport_Tank_Died(Handle:event, const String:name[], bool:dontBroadcast)
{
    _TankReport_Tank_In_Play = false;
    _TankReport_Report_To_Players(INVALID_HANDLE, "", true);
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
    new victim   = GetClientOfUserId(GetEventInt(event, "userid"));
    
    if (GetTankClient() == victim && !IsTankDying())
    {
        new survivor = GetClientOfUserId(GetEventInt(event, "attacker"));
        damageReport[survivor] += GetEventInt(event, "dmg_health");
    }
    
    return Plugin_Continue;
}

/**
 * If the client that was incapacitated was a survivor, then we reduce the
 * number of _TankReport_Survivors_Standing; when that number hits zero, we display the
 * tank report.
 */
public Action:_TankReport_Player_Incapd_Event(Handle:event, String:event_name[], bool:dontBroadcast)
{
    new victim = GetClientOfUserId(GetEventInt(event, "userid"));
    
    if (Is_Client_Survivor(victim))
    {
        _TankReport_Survivors_Standing --;
        TC_Debug("Survivor Incapd; Standing Count: %i", _TankReport_Survivors_Standing);
    }
    
    if (_TankReport_Survivors_Standing == 0)
    {
        _TankReport_Report_To_Players(INVALID_HANDLE, "", true);
    }
    
    return Plugin_Continue;
}

/**
 * It's truly unclear whether a survivor is "rescued" or "revived", but
 * we will increment the number of _TankReport_Survivors_Standing if a either happen
 * to a survivor.
 */
public Action:_TankReport_Player_Revived(Handle:event, String:event_name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(event, "subject"));
    
    if (Is_Client_Survivor(client))
    {
        _TankReport_Survivors_Standing ++;
        TC_Debug("Survivor Revived; Standing Count: %i", _TankReport_Survivors_Standing);
    }
    
    return Plugin_Continue;
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
            if (_TankReport_Panel != INVALID_HANDLE)
            {
                CloseHandle(_TankReport_Panel);
            }
            _TankReport_Panel = CreatePanel();
            
            decl String:sBuffer[512];
            SetPanelTitle(_TankReport_Panel, "Tank Damage Report");
            
            new survivorIndex = -1;
            decl survivorClients[SURVIVOR_LIMIT];
            decl damage, totalDamage;
            
            // Iterate over all survivors
            for (new survivor = 1; survivor < MaxClients; survivor++)
            {
                // If not a survivor, ignore
                if (!Is_Client_Survivor(survivor)) continue;
                // TODO: maybe we can allow this to be infected as well... friendly-fire!
                
                survivorIndex ++;
                survivorClients[survivorIndex] = survivor;
                totalDamage += damageReport[survivor];
            }
            SortCustom1D(survivorClients, SURVIVOR_LIMIT, _TankReport_SortByDamageDesc);
            // survivorClients is now sorted in order of who did most damage.

            new healthDiff = _TankReport_Tank_Total_HP - totalDamage;
            new const maxLen = 1024;
            decl String:result[maxLen];
            decl survivor, damagePercent;
            
            if (_TankReport_Tank_Total_HP > totalDamage)
            {
                new hpRemaining = _TankReport_Tank_Total_HP - totalDamage;
                Format(result, maxLen, "Total HP: %i", hpRemaining);
                DrawPanelText(_TankReport_Panel, result);
            }
            else
            {
                Format(result, maxLen, "Total HP: %i", _TankReport_Tank_Total_HP);
                DrawPanelText(_TankReport_Panel, result);
            }
            
            for (new i; i <= survivorIndex; i++)
            {
                survivor = survivorClients[i];
                damage = damageReport[survivor];
                if (healthDiff > 0.0)
                {
                    // Pad the first survivor's damage with the leftover, if any.
                    damage += healthDiff;
                    healthDiff = 0;
                }
                damagePercent = _TankReport_GetDamageAsPercent(damage, _TankReport_Tank_Total_HP);
                Format(result, maxLen, "%N: %i (%d%%)", survivor, damage, damagePercent);
                DrawPanelText(_TankReport_Panel, result);
            }
    
            // Iterate over all clients
            for (new client = 1; client < MaxClients; client++)
            {
                // If not a player, just ignore
                if (!Is_Valid_Player_Client(client)) continue;
                
                SendPanelToClient(_TankReport_Panel, client, _TankReport_Panel_Event, TANK_REPORT_PANEL_LIFETIME);
            }
            
            // Clear out the damage report in case there's ANOTHER tank (finales)
            for (new i = 0; i < MaxClients; i++)
            {
                damageReport[i] = 0;
            }
            
            CloseHandle(_TankReport_Panel);
        }
        
        // Lastly...
        tankReportRequired = false;
    }
}

/**
 * Helper method for finding the damage as a percent of the total damage.
 */
public _TankReport_GetDamageAsPercent(damage, totalDamage)
{
    return RoundToFloor(FloatMul(FloatDiv(float(damage), float(totalDamage)), 100.0));
}

/**
 * Helper method for sorting.
 */
public _TankReport_SortByDamageDesc(elem1, elem2, const array[], Handle:handle)
{
    if (damageReport[elem1] > damageReport[elem2])
    {
        return -1;
    }
    else if (damageReport[elem2] > damageReport[elem1])
    {
        return 1;
    }
    else if (elem1 > elem2)
    {
        return -1;
    }
    else if (elem2 > elem1)
    {
        return 1;
    }
    return 0;
}