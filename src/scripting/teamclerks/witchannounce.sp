// Don't let the script be included more than once.
#if defined _teamclerks_WA
  #endinput
#endif
#define _teamclerks_WA

// **********************************************
//                   Reference
// **********************************************

static const String: mWA_CVAR[]               = "witchannounce";
static const String: mWA_CVAR_DEFAULT_VALUE[] = "0";
static const String: mWA_CVAR_DESCRIPTION[]   = "Whether announcing witch crowns/fails is enabled.";
static       Handle: g_hWACvar                = INVALID_HANDLE;

// **********************************************
//                   Variables
// **********************************************

new bool: g_bWitchLived       = false;
new       g_iWitchEntId       = 0;
new bool: g_bWitchUntouched   = false;

// **********************************************
//             Forwards
// **********************************************

/**
 * Plugin is starting.
 *
 * @noreturn
 */
public _WA_OnPluginStart()
{
    // Always register the convar for witchannounce and disable it.
    g_hWACvar = CreateConVar(mWA_CVAR, mWA_CVAR_DEFAULT_VALUE, mWA_CVAR_DESCRIPTION, FCVAR_PLUGIN|FCVAR_SPONLY, true, 0.0, true, 1.0);

    HookPublicEvent(EVENT_ONPLUGINENABLE, _WA_OnPluginEnabled);
    HookPublicEvent(EVENT_ONPLUGINDISABLE, _WA_OnPluginDisabled);
}

/**
 * Plugin is now enabled.
 *
 * @noreturn
 */
public _WA_OnPluginEnabled()
{
    HookConVarChange(g_hWACvar, _WA_CvarChange);
}

/**
 * Plugin is now disabled.
 *
 * @noreturn
 */
public _WA_OnPluginDisabled()
{
    UnhookConVarChange(g_hWACvar, _WA_CvarChange);
}

/**
 * Witch Announce cvar changed.
 *
 * @param convar        Handle to the convar that was changed.
 * @param oldValue        String containing the value of the convar before it was changed.
 * @param newValue        String containing the new value of the convar.
 * @noreturn
 */
public _WA_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
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
            CommandWitchAnnounceStart();
        }
        else
        {
            CommandWitchAnnounceStop();
        }
    }
}

/**
 * Event handler for the witch_spawn event. Sets up our local variables for
 * announcing later.
 */
public Event_WitchSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
    // Now she has "lived"
    g_bWitchLived = true;
    // She hasn't been "touched" yet
    g_bWitchUntouched = true;
    // This is her entId
    g_iWitchEntId = GetEventInt(event, "witchid");
}

/**
 * Event handler for the witch_killed event. If the witch was killed in one
 * (which Valve was kind enough to provide as a data point) then we announce
 * our hero here.
 */
public Event_WitchDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
    new killer = GetClientOfUserId(GetEventInt(event, "userid"));
    if (!Is_Valid_Player_Client(killer)) return;
    if (GetEventBool(event, "oneshot"))
    {
        decl String:killername[MAX_NAME_LENGTH];
        GetClientName(killer, killername, MAX_NAME_LENGTH);
        PrintToChatAll("\x01[SM] \x05%s\x01 crowned the witch!", killername);
    }
    // Reset the default values.
    g_bWitchLived = false;
    g_bWitchUntouched = false;
    g_iWitchEntId = 0;
}

/**
 * Event handler for the infected_hurt event (commons and witch).
 * 
 * This is pretty spammy in general, so we don't want to do anything too 
 * complicated (like creating variables) except under very rare circumstances
 * that are cheap to check. I am using two local bools to determine whether
 * this event is worth our time:
 *   g_bWitchLived - whether the witch has spawned and is alive currently
 *   g_bWitchUntouched - whether the witch (which is spawned for sure) has been
 *                       damaged before.
 * These values get set by the witch_spawn event and this method if the witch
 * has been hurt and it is the first time. Once these two values are set, we
 * should never do anything in this function until the next witch spawn.
 */
public Event_InfectedHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
    if (g_bWitchLived && 
        g_bWitchUntouched &&
        GetEventInt(event, "entityid") == g_iWitchEntId)
    {
        // Okay, she's been touched; set that first so the next player_hurt
        // events don't get into this block.
        g_bWitchUntouched = false;
        // Create a timer to see if she's been crowned.
        CreateTimer(0.1, Timer_WitchCrowned);
    }
}

public Action:Timer_WitchCrowned(Handle:timer, any:oldtankclient)
{
    // This will have been set to false if she died.
    if (g_iWitchEntId)
    {
        new healthLeft = 
            GetEntData(g_iWitchEntId, FindDataMapOffs(g_iWitchEntId,"m_iHealth"));
        // Okay, she was NOT crowned... print that noise out.
        PrintToChatAll("\x01[SM] Witch had \x05%i\x01 health left.", healthLeft);
    }
}

CommandWitchAnnounceStart()
{
    HookEvent("witch_spawn", Event_WitchSpawn);
    HookEvent("witch_killed", Event_WitchDeath);
    HookEvent("infected_hurt", Event_InfectedHurt);
}

CommandWitchAnnounceStop()
{
    UnhookEvent("witch_spawn", Event_WitchSpawn);
    UnhookEvent("witch_killed", Event_WitchDeath);
    UnhookEvent("infected_hurt", Event_InfectedHurt);
}