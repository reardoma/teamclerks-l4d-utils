// **********************************************
//                 Preprocessor
// **********************************************

#pragma semicolon 1


// **********************************************
//                   Reference
// **********************************************

// The client index of the server
#define SERVER_INDEX            0
// First valid client index
#define FIRST_CLIENT            1
// The team list
#define TEAM_SPECTATOR          1
#define TEAM_SURVIVOR           2
#define TEAM_INFECTED           3
// Max number of entities l4d supports
#define MAX_ENTITIES            2048


// **********************************************
//                  Plugin info
// **********************************************

#define PLUGIN_FULLNAME         "Tank Announce"
#define PLUGIN_SHORTNAME        "tankannounce"
#define PLUGIN_AUTHOR           "Giffin and Blade; modified by kain"
#define PLUGIN_DESCRIPTION      "Announce damage dealt to tanks by survivors"
#define PLUGIN_VERSION          "0.6.6"
#define PLUGIN_URL              "http://teamclerks-l4d-utils.googlecode.com/"
#define PLUGIN_CVAR_PREFIX      PLUGIN_SHORTNAME
#define PLUGIN_CMD_PREFIX       PLUGIN_SHORTNAME
#define PLUGIN_TAG              "TankAnnounce"

public Plugin:myinfo =
{
    name = PLUGIN_FULLNAME,
    author = PLUGIN_AUTHOR,
    description = PLUGIN_DESCRIPTION,
    version = PLUGIN_VERSION,
    url = PLUGIN_URL
};


// **********************************************
//                   Includes
// **********************************************

#include <sourcemod>

#include "rotoblin/helpers/debug.inc"
#include "rotoblin/helpers/eventmanager.inc"
#include "rotoblin/helpers/tankmanager.inc"
#include "rotoblin/helpers/wrappers.inc"


// **********************************************
//                   Variables
// **********************************************

new bool:   g_bEnabled                 = true;
// Whether or not tank damage should be announced
new bool:   g_bAnnounceTankDamage      = false;
new bool:   g_bHooked                  = false;
new bool:   g_bTankLived               = false;
// Used to award the killing blow the exact right amount of damage
new         g_iLastTankHealth          = 0;
// For survivor array in damage print
new         g_iSurvivorLimit           = 4;
new         g_iDamage[MAXPLAYERS + 1];
new Float:  g_fMaxTankHealth           = 6000.0;
new Handle: g_hCvarEnabled             = INVALID_HANDLE;
new Handle: g_hCvarSurvivorLimit       = INVALID_HANDLE;


// **********************************************
//               Public Functions
// **********************************************

/**
 * Forward from eventmanager.inc
 * 
 * Basically the same as the OnPluginStart forward, but a few helpers are
 * automated for us doing things this way.
 */
public OnPluginStartEx()
{
    _H_TankManager_OnPluginStart();

    HookPublicEvent(EVENT_ONPLUGINENABLE, _TA_OnPluginEnable);
    HookPublicEvent(EVENT_ONPLUGINDISABLE, _TA_OnPluginDisable);
    
    g_hCvarEnabled = CreateConVar("l4d_tankdamage_enabled", "0", 
            "Announce damage done to tanks when enabled", 
            FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_hCvarSurvivorLimit = FindConVar("survivor_limit");
    
    HookConVarChange(g_hCvarEnabled, Cvar_Enabled);
    HookConVarChange(g_hCvarSurvivorLimit, Cvar_SurvivorLimit);
    
    g_bEnabled = GetConVarBool(g_hCvarEnabled);
}

/**
 * Called whenever g_hCvarEnabled is changed.
 * Sets the plugin's state.
 */
public Cvar_Enabled(Handle:convar, const String:oldValue[], 
        const String:newValue[])
{
    g_bEnabled = StringToInt(newValue) > 0;
    
    SetPluginState(g_bEnabled);
}

/**
 * Called whenever the cvar "survivor_limit" is changed. Sets our local 
 * value to whatever the cvar "survivor_limit" is set.
 */
public Cvar_SurvivorLimit(Handle:convar, const String:oldValue[], 
        const String:newValue[])
{
    g_iSurvivorLimit = StringToInt(newValue);
}

/**
 * Called whenever the plugin's state is set to enabled. This must be done
 * after the server is started and set up (read: cannot do this in server.cfg).
 * 
 * Sets up the event hooks required for capturing tank damage info for display.
 */
public _TA_OnPluginEnable()
{
    HookEvent("round_start", Event_RoundStart);
    HookEvent("round_end", Event_RoundEnd);
    HookEvent("player_hurt", Event_PlayerHurt);
}

/**
 * Called whenever the plugin's state is set to disabled.
 * 
 * Unhooks all the public events associated with this plugin.
 */
public _TA_OnPluginDisable()
{
    UnhookEvent("round_start", Event_RoundStart);
    UnhookEvent("round_end", Event_RoundEnd);
    UnhookEvent("player_hurt", Event_PlayerHurt);
}

/**
 * Called when the tank is spawned. This is **NOT** called when the tank passes
 * at all. The original tank_spawn event will be called whenever the tank is
 * passed from AI-player or player-AI, but thanks to rotoblin's tankmanager.inc
 * that distinction is done for us and we can simply listen to the tank event
 * TANK_SPAWNED.
 */
public Event_TankSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{   
    ClearTankDamage();
    // Set the max health to whatever the health is right now since the tank 
    // hasn't taken damage yet (hopefully).
    g_fMaxTankHealth = float(GetClientHealth(GetTankClient()));
    // New tank, damage has not been announced
    g_bAnnounceTankDamage = true;
    // Set health for damage print in case it doesn't get set by player_hurt 
    // (aka no one shoots the tank)
    g_iLastTankHealth = GetClientHealth(GetTankClient());
    // This is the ONLY place we will set this value to true.
    g_bTankLived = true;
}

/**
 * Called when the tank is killed; if we are set to display the damage done to
 * the tank, we make that call here and follow up with setting the damage
 * values back to zero.
 */
public Event_TankKilled(Handle:event, const String:name[], bool:dontBroadcast)
{
    if (g_bAnnounceTankDamage && g_bTankLived)
    {
        PrintTankDamage();
    }
    // We have reported it... he has not "lived" anymore.
    g_bTankLived = false;
}

/**
 * Called whenever a unit takes damage. Technically, this could be a player or
 * a bot, but not common infected or the witch; basically, any client unit. We
 * check to see if the tank is active and if the tank is the one taking damage,
 * we add that damage to the array to be added up for the report later.
 */
public Event_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
    if (!IsTankInPlay()) return; // No tank in play; no damage to record
    
    new victim = GetClientOfUserId(GetEventInt(event, "userid"));
    // Something buggy happens when tank is dying with regards to damage
    if (victim != GetTankClient() || IsTankDying() )
    {
        // Victim isn't tank or tank is in death-animation; no damage to record
        return;
    }

    new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
    // We only care about damage dealt by survivors, though it can be funny to
    // see claw/self inflicted hittable damage, so maybe for the future I will
    // remove the TEAM_SURVIVOR predicate.
    if (attacker == 0 || !IsClientInGame(attacker) || 
        GetClientTeam(attacker) != TEAM_SURVIVOR)
    {
        return;
    }

    g_iDamage[attacker] += GetEventInt(event, "dmg_health");
    g_iLastTankHealth = GetEventInt(event, "health");
}

/**
 * Called at the end of the round.
 * Zeroes out the damage report and will print the remaining health of the tank
 * if the survivors wiped or ended up juking around the tank and making it to
 * the safe room.
 */
public Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
    // But only if a tank that hasn't been killed and exists
    if (g_bAnnounceTankDamage && g_bTankLived)
    {
        PrintRemainingHealth();
        PrintTankDamage();
    }
    
    if (g_bHooked)
    {
        UnhookTankEvent(TANK_SPAWNED, Event_TankSpawn);
        UnhookTankEvent(TANK_KILLED, Event_TankKilled);
        g_bHooked = false;
    }
    
    // We have either reported it or there was no tank
    g_bTankLived = false;
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
    // This could be true if no round_end event was fired (say a map change was
    // called and round_end got interrupted).
    if (g_bHooked)
    {
        UnhookTankEvent(TANK_SPAWNED, Event_TankSpawn);
        UnhookTankEvent(TANK_KILLED, Event_TankKilled);
        g_bHooked = false;
    }
    
    // There are definitely no events hooked and g_bHooked MUST be false.    
    HookTankEvent(TANK_SPAWNED, Event_TankSpawn);
    HookTankEvent(TANK_KILLED, Event_TankKilled);
    // This is the only place we set g_bHooked to true since this is the
    // only place we hook tank events.
    g_bHooked = true;

    
    // There cannot have been a tank yet.
    g_bTankLived = false;
}

/**
 * Helper method for sorting by who did the most damage descending.
 */
public SortByDamageDesc(elem1, elem2, const array[], Handle:hndl)
{
    // By damage, then by client index, descending
    if (g_iDamage[elem1] > g_iDamage[elem2])
    {
        return -1;
    }
    else if (g_iDamage[elem2] > g_iDamage[elem1])
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


// **********************************************
//               Private Functions
// **********************************************

/**
 * Prints the remaining health of the tank in chat to all players/specs.
 */
PrintRemainingHealth()
{
    if (!g_bEnabled)
    {
        return;
    }
    new tankclient = GetTankClient();
    if (!tankclient)
    {
        return;
    }
    
    decl String:name[MAX_NAME_LENGTH];
    if (IsFakeClient(tankclient))
    {
        name = "AI";
    }
    else
    {
        GetClientName(tankclient, name, sizeof(name));
    }
    PrintToChatAll("\x01[SM] Tank (\x03%s\x01) had \x05%d\x01 health remaining", 
            name, g_iLastTankHealth);
}

/**
 * Prints out the damage report to all the players/specs.
 */
PrintTankDamage()
{
    if (!g_bEnabled)
    {
        return;
    }
    PrintToChatAll("[SM] Damage dealt to tank:");
    
    new client;
    // Accumulated total of calculated percents, for fudging out numbers at 
    // the end
    new percent_total;
    // Accumulated total damage dealt by survivors, to see if we need to fudge 
    // upwards to 100%.
    new damage_total;
    new survivor_index = -1;
    // Array to store survivor client indexes in, for the display iteration
    new survivor_clients[g_iSurvivorLimit];
    decl percent_damage, damage;
    for (client = 1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client) || GetClientTeam(client) != TEAM_SURVIVOR)
        {
            continue;
        }
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
    if ( percent_total < 100 &&
         float(damage_total) > (g_fMaxTankHealth - (g_fMaxTankHealth / 200.0)) )
    {
        percent_adjustment = 100 - percent_total;
    }
    
    // Used to store the last percent in iteration to make sure an adjusted 
    // percent doesn't exceed the previous percent.
    new last_percent = 100;
    decl adjusted_percent_damage;
    for (new i; i <= survivor_index; i++)
    {
        client = survivor_clients[i];
        damage = g_iDamage[client];
        percent_damage = GetDamageAsPercent(damage);
        // Attempt to adjust the top damager's percent, defer adjustment to 
        // next player if it's an exact percent.
        // e.g. 3000 damage on 6k health tank shouldn't be adjusted
        if (percent_adjustment != 0 && damage > 0 && !IsExactPercent(damage) )
        {
            adjusted_percent_damage = percent_damage + percent_adjustment;
            // Make sure adjusted percent is not higher than previous percent, 
            // order must be maintained
            if (adjusted_percent_damage <= last_percent)
            {
                percent_damage = adjusted_percent_damage;
                percent_adjustment = 0;
            }
        }
        PrintToChatAll("\x05%4d\x01 [\x04%d%%\x01]: \x03%N\x01", 
                damage, percent_damage, client);
    }
}

/**
 * Zeroes out all the damage done to the tank.
 */
ClearTankDamage()
{
    g_iLastTankHealth = 0;
    for (new i = 1; i <= MaxClients; i++)
    {
        g_iDamage[i] = 0;
    }
    g_bAnnounceTankDamage = false;
}

/**
 * Helper function for returning the percent of damage done versus the tank's
 * maximum health.
 */
GetDamageAsPercent(damage)
{
    return RoundToFloor(
            FloatMul(FloatDiv(float(damage), g_fMaxTankHealth), 100.0) );
}

/**
 * Helper method to determine whether the percent is exact.
 * Used in making sure that all the percentages add up to 100.0 so that we do
 * not end up with 97.9% damage output (can happen mathematically).
 */
bool:IsExactPercent(damage)
{
    return FloatAbs( 
        float(GetDamageAsPercent(damage)) - 
        FloatMul(FloatDiv(float(damage), g_fMaxTankHealth), 100.0) ) < 0.001;
}