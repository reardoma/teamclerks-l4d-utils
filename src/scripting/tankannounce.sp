// **********************************************
//                 Preprocessor
// **********************************************

#pragma semicolon 1

// **********************************************
//                   Reference
// **********************************************

#define SERVER_INDEX            0 // The client index of the server
#define FIRST_CLIENT            1 // First valid client index

// The team list
#define TEAM_SPECTATOR          1
#define TEAM_SURVIVOR           2
#define TEAM_INFECTED           3

#define MAX_ENTITIES            2048 // Max number of entities l4d supports

// Plugin info
#define PLUGIN_FULLNAME         "Tank Announce"                               // Used when printing the plugin name anywhere
#define PLUGIN_SHORTNAME        "tankannounce"                                // Shorter version of the full name, used in file paths, and other things
#define PLUGIN_AUTHOR           "Giffin and Blade; modified by kain"          // Author of the plugin
#define PLUGIN_DESCRIPTION      "Announce damage dealt to tanks by survivors" // Description of the plugin
#define PLUGIN_VERSION          "0.6.6"                                       // http://wiki.eclipse.org/Version_Numbering
#define PLUGIN_URL              "http://teamclerks-l4d-utils.googlecode.com/" // URL associated with the project
#define PLUGIN_CVAR_PREFIX      PLUGIN_SHORTNAME                              // Prefix for cvars
#define PLUGIN_CMD_PREFIX       PLUGIN_SHORTNAME                              // Prefix for cmds
#define PLUGIN_TAG              "TankAnnounce"                                // Tag for prints and commands
#define PLUGIN_GAMECONFIG_FILE  PLUGIN_SHORTNAME                              // Name of gameconfig file

#include <sourcemod>

new bool: g_bEnabled = true;
new bool: g_bAnnounceTankDamage = false; // Whether or not tank damage should be announced
new g_iLastTankHealth = 0; // Used to award the killing blow the exact right amount of damage
new g_iSurvivorLimit = 4; // For survivor array in damage print
new g_iDamage[MAXPLAYERS + 1];
new Float: g_fMaxTankHealth = 6000.0;
new Handle: g_hCvarEnabled = INVALID_HANDLE;
new Handle: g_hCvarSurvivorLimit = INVALID_HANDLE;

#include "rotoblin/helpers/debug.inc"
#include "rotoblin/helpers/eventmanager.inc"
#include "rotoblin/helpers/tankmanager.inc"
#include "rotoblin/helpers/wrappers.inc"

public Plugin:myinfo =
{
    name = PLUGIN_FULLNAME,
    author = PLUGIN_AUTHOR,
    description = PLUGIN_DESCRIPTION,
    version = PLUGIN_VERSION,
    url = PLUGIN_URL
};

public OnPluginStartEx()
{
    _H_TankManager_OnPluginStart();

    HookPublicEvent(EVENT_ONPLUGINENABLE, _TA_OnPluginEnable);
    HookPublicEvent(EVENT_ONPLUGINDISABLE, _TA_OnPluginDisable);
    
    g_hCvarEnabled = CreateConVar("l4d_tankdamage_enabled", "0", "Announce damage done to tanks when enabled", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_hCvarSurvivorLimit = FindConVar("survivor_limit");
    
    HookConVarChange(g_hCvarEnabled, Cvar_Enabled);
    HookConVarChange(g_hCvarSurvivorLimit, Cvar_SurvivorLimit);
    
    g_bEnabled = GetConVarBool(g_hCvarEnabled);
}

public _TA_OnPluginEnable()
{
    HookEvent("round_start", Event_RoundStart);
    HookEvent("round_end", Event_RoundEnd);
    HookEvent("player_hurt", Event_PlayerHurt);
    
    g_bAnnounceTankDamage = false;
    ClearTankDamage();
    
    HookPublicEvent(EVENT_ONMAPSTART, TA_OnMapStart);
}

public _TA_OnPluginDisable()
{
    
    UnhookEvent("round_start", Event_RoundStart);
    UnhookEvent("round_end", Event_RoundEnd);
    UnhookEvent("player_hurt", Event_PlayerHurt);
    
    UnhookPublicEvent(EVENT_ONMAPSTART, TA_OnMapStart);
}

public TA_OnMapStart()
{
    HookTankEvent(TANK_SPAWNED, Event_TankSpawn);
    HookTankEvent(TANK_KILLED, Event_TankKilled);
    
    // In cases where a tank spawns and map is changed manually, bypassing round end
    ClearTankDamage();
}

public Cvar_Enabled(Handle:convar, const String:oldValue[], const String:newValue[])
{
    g_bEnabled = StringToInt(newValue) > 0 ? true:false;
    
    SetPluginState(g_bEnabled);
}

public Cvar_SurvivorLimit(Handle:convar, const String:oldValue[], const String:newValue[])
{
    g_iSurvivorLimit = StringToInt(newValue);
}

public Event_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
    if (!IsTankInPlay()) return; // No tank in play; no damage to record
    
    new victim = GetClientOfUserId(GetEventInt(event, "userid"));
    if (victim != GetTankClient() || // Victim isn't tank; no damage to record
        IsTankDying() // Something buggy happens when tank is dying with regards to damage
    ) return;

    new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
    // We only care about damage dealt by survivors, though it can be funny to see
    // claw/self inflicted hittable damage, so maybe in the future we'll do that
    if (attacker == 0 || // Damage from world?
        !IsClientInGame(attacker) || // Not sure if this happens
        GetClientTeam(attacker) != TEAM_SURVIVOR
    ) return;

    g_iDamage[attacker] += GetEventInt(event, "dmg_health");
    g_iLastTankHealth = GetEventInt(event, "health");
}

public Event_TankKilled(Handle:event, const String:name[], bool:dontBroadcast)
{
    if (g_bAnnounceTankDamage) PrintTankDamage();
    ClearTankDamage();
}

public Event_TankSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{   
    // Set the max health to whatever the health is right now since the tank hasn't taken damage yet (hopefully).
    g_fMaxTankHealth = float(GetClientHealth(GetTankClient()));
    // New tank, damage has not been announced
    g_bAnnounceTankDamage = true;
    // Set health for damage print in case it doesn't get set by player_hurt (aka no one shoots the tank)
    g_iLastTankHealth = GetClientHealth(GetTankClient());
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{    
    ClearTankDamage(); // Probably redundant
}

// When survivors wipe or juke tank, announce damage
public Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
    // But only if a tank that hasn't been killed exists
    if (g_bAnnounceTankDamage)
    {
        PrintRemainingHealth();
        PrintTankDamage();
    }
    ClearTankDamage();
    
    UnhookTankEvent(TANK_SPAWNED, Event_TankSpawn);
    UnhookTankEvent(TANK_KILLED, Event_TankKilled);
}

PrintRemainingHealth()
{
    if (!g_bEnabled) return;
    new tankclient = GetTankClient();
    if (!tankclient) return;
    
    decl String:name[MAX_NAME_LENGTH];
    if (IsFakeClient(tankclient)) name = "AI";
    else GetClientName(tankclient, name, sizeof(name));
    PrintToChatAll("\x01[SM] Tank (\x03%s\x01) had \x05%d\x01 health remaining", name, g_iLastTankHealth);
}

PrintTankDamage()
{
    if (!g_bEnabled) return;
    PrintToChatAll("[SM] Damage dealt to tank:");
    
    new client;
    new percent_total; // Accumulated total of calculated percents, for fudging out numbers at the end
    new damage_total; // Accumulated total damage dealt by survivors, to see if we need to fudge upwards to 100%
    new survivor_index = -1;
    new survivor_clients[g_iSurvivorLimit]; // Array to store survivor client indexes in, for the display iteration
    decl percent_damage, damage;
    for (client = 1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client) || GetClientTeam(client) != TEAM_SURVIVOR) continue;
        survivor_index++;
        survivor_clients[survivor_index] = client;
        damage = g_iDamage[client];
        damage_total += damage;
        percent_damage = GetDamageAsPercent(damage);
        percent_total += percent_damage;
    }
    SortCustom1D(survivor_clients, g_iSurvivorLimit, SortByDamageDesc);
    
    new percent_adjustment;
    // Percents add up to less than 100% AND > 99.5% damage was dealt to tank
    if ((percent_total < 100 &&
        float(damage_total) > (g_fMaxTankHealth - (g_fMaxTankHealth / 200.0)))
    )
    {
        percent_adjustment = 100 - percent_total;
    }
    
    new last_percent = 100; // Used to store the last percent in iteration to make sure an adjusted percent doesn't exceed the previous percent
    decl adjusted_percent_damage;
    for (new i; i <= survivor_index; i++)
    {
        client = survivor_clients[i];
        damage = g_iDamage[client];
        percent_damage = GetDamageAsPercent(damage);
        // Attempt to adjust the top damager's percent, defer adjustment to next player if it's an exact percent
        // e.g. 3000 damage on 6k health tank shouldn't be adjusted
        if (percent_adjustment != 0 && // Is there percent to adjust
        damage > 0 && // Is damage dealt > 0%
        !IsExactPercent(damage) // Percent representation is not exact, e.g. 3000 damage on 6k tank = 50%
        )
        {
            adjusted_percent_damage = percent_damage + percent_adjustment;
            if (adjusted_percent_damage <= last_percent) // Make sure adjusted percent is not higher than previous percent, order must be maintained
            {
                percent_damage = adjusted_percent_damage;
                percent_adjustment = 0;
            }
        }
        PrintToChatAll("\x05%4d\x01 [\x04%d%%\x01]: \x03%N\x01", damage, percent_damage, client);
    }
}

ClearTankDamage()
{
    g_iLastTankHealth = 0;
    for (new i = 1; i <= MaxClients; i++)
    {
        g_iDamage[i] = 0;
    }
    g_bAnnounceTankDamage = false;
}

GetDamageAsPercent(damage)
{
    return RoundToFloor(FloatMul(FloatDiv(float(damage), g_fMaxTankHealth), 100.0));
}

bool:IsExactPercent(damage)
{
    return FloatAbs(float(GetDamageAsPercent(damage)) - FloatMul(FloatDiv(float(damage), g_fMaxTankHealth), 100.0)) < 0.001;
}

public SortByDamageDesc(elem1, elem2, const array[], Handle:hndl)
{
    // By damage, then by client index, descending
    if (g_iDamage[elem1] > g_iDamage[elem2]) return -1;
    else if (g_iDamage[elem2] > g_iDamage[elem1]) return 1;
    else if (elem1 > elem2) return -1;
    else if (elem2 > elem1) return 1;
    return 0;
}