// Don't let the script be included more than once.
#if defined _teamclerks_1v1
  #endinput
#endif
#define _teamclerks_1v1

// --------------------
//     Private
// --------------------

static const String: m1v1_CVAR[]               = "1v1";
static const String: m1v1_CVAR_DEFAULT_VALUE[] = "0";
static const String: m1v1_CVAR_DESCRIPTION[]   = "Whether 1v1 mode enabled.";
static       Handle: g_h1v1Cvar                = INVALID_HANDLE;


// **********************************************
//             Forwards
// **********************************************

/**
 * Plugin is starting.
 *
 * @noreturn
 */
public _1v1_OnPluginStart()
{
    _H_TankManager_OnPluginStart();
    // Always register the convar for 1v1 and disable it.
    g_h1v1Cvar = CreateConVar(m1v1_CVAR, m1v1_CVAR_DEFAULT_VALUE, m1v1_CVAR_DESCRIPTION, FCVAR_PLUGIN|FCVAR_SPONLY, true, 0.0, true, 1.0);
    
    // This will be called when teamclerks.main is enabled/disabled
    HookPublicEvent(EVENT_ONPLUGINENABLE, _1v1_OnPluginEnabled);
    HookPublicEvent(EVENT_ONPLUGINDISABLE, _1v1_OnPluginDisabled);
    HookPublicEvent(EVENT_ONCLIENTDISCONNECT_POST, _1v1_OnClientDisconnect);
}

/**
 * Plugin is now enabled.
 *
 * @noreturn
 */
public _1v1_OnPluginEnabled()
{
    HookConVarChange(g_h1v1Cvar, _1v1_CvarChange);
}

/**
 * Plugin is now disabled.
 *
 * @noreturn
 */
public _1v1_OnPluginDisabled()
{
    UnhookConVarChange(g_h1v1Cvar, _1v1_CvarChange);
}

/**
 * 1v1 cvar changed.
 *
 * @param convar        Handle to the convar that was changed.
 * @param oldValue        String containing the value of the convar before it was changed.
 * @param newValue        String containing the new value of the convar.
 * @noreturn
 */
public _1v1_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
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
            Command1v1Start();
        }
        else
        {
            Command1v1Stop();
        }
    }
}

new Handle:_1v1_HunterSurvivor[MAXPLAYERS+1];

public _1v1_OnClientDisconnect(client)
{
    if (_1v1_HunterSurvivor[client] != INVALID_HANDLE)
    {
        KillTimer(_1v1_HunterSurvivor[client]);
        _1v1_HunterSurvivor[client] = INVALID_HANDLE;
    }
}

public _1v1_Event_PlayerPounced(Handle:event, const String:name[], bool:dontBroadcast)
{
    new hunterClient = GetClientOfUserId(GetEventInt(event, "userid"));
    decl String:hunterName[256];
    GetClientName(hunterClient, hunterName, 256);
    new hunterHealth = GetClientHealth(hunterClient);
    new survivorClient = GetClientOfUserId(GetEventInt(event, "victim"));
    
    PrintToChat(hunterClient,"\x01[SM] \x05%s\x01 had \x05%i\x01 health left.", hunterName, hunterHealth);
    PrintToChat(survivorClient,"\x01[SM] \x05%s\x01 had \x05%i\x01 health left.", hunterName, hunterHealth);
    
    new Handle:hunterPack;
    _1v1_HunterSurvivor[hunterClient] = CreateDataTimer(1.25, _1v1_killPouncedHunter, hunterPack);
    WritePackCell(hunterPack, hunterClient);
    
    // Turning this off for some testing.
    //new Handle:survivorPack;
    //_1v1_HunterSurvivor[survivorClient] = CreateDataTimer(2.0, _1v1_adjustSurvivorHealth, survivorPack);
    //WritePackCell(survivorPack, survivorClient);
}

public Action:_1v1_killPouncedHunter(Handle:timer, Handle:pack)
{
    new hunterClient;
    
    ResetPack(pack);
    hunterClient = ReadPackCell(pack);
    
    ForcePlayerSuicide(hunterClient);
    
    _1v1_HunterSurvivor[hunterClient] = INVALID_HANDLE;
}

public Action:_1v1_adjustSurvivorHealth(Handle:timer, Handle:pack)
{
    new survivorClient;
    
    ResetPack(pack);
    survivorClient = ReadPackCell(pack);
    
    // So, this was fired a second after the hunter was killed, the 
    // survivor should be NO MORE than 30 damage lower (25dp + 5scratch)
    // than before he was hit.
    new hp = GetClientHealth(survivorClient);
    
    if (hp <= 33)
    {
        // You died... sorry.
        ForcePlayerSuicide(survivorClient);
    }
    else if (hp <= 67)
    {
        // You're down to your last pounce
        SetEntData(survivorClient, FindDataMapOffs(survivorClient,"m_iHealth"), 33, 4, true);
    }
    else
    {
        // You haven't been pounced... till now.
        SetEntData(survivorClient, FindDataMapOffs(survivorClient,"m_iHealth"), 66, 4, true);
    }
    
    _1v1_HunterSurvivor[survivorClient] = INVALID_HANDLE;
}

public Action:_1v1_Event_AbilityUsed(Handle:event, const String:name[], bool:dontBroadcast)
{
    new Client = GetClientOfUserId(GetEventInt(event, "userid"));
    new String:AbilityName[64];
    
    GetEventString(event, "ability", AbilityName, sizeof(AbilityName));
    if(Is_Client_Player_Infected(Client) && strcmp(AbilityName, "ability_lunge", false) == 0) //pouncing
    {
        ForcePlayerSuicide(Client);
        PrintToChatAll("\x01[1v1] Blocked \x05%N\x01 from wallkicking.", Client);
        return Plugin_Stop;
    }
    
    return Plugin_Continue;
}

public Action:_1v1_groundTouchTimer(Handle:timer, any:client)
{
    if((Is_Valid_Player_Client(client) && (GetEntProp(client, Prop_Data, "m_fFlags") & FL_ONGROUND) > 0) 
            || !Is_Client_Player_Infected(client))
    {
        UnhookEvent("ability_use", _1v1_Event_AbilityUsed);
        KillTimer(timer);
    }
    
    return Plugin_Continue;
}

public Action:_1v1_Event_PlayerJump(Handle:event, const String:name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    
    // is not using normal wall pounce (using wallkick)
    if(Is_Client_Player_Infected(client) && (GetClientButtons(client) & IN_JUMP))
    {
        HookEvent("ability_use", _1v1_Event_AbilityUsed);
        CreateTimer(0.5, _1v1_groundTouchTimer, client, TIMER_REPEAT);
    }
    
    return Plugin_Continue;
}

Command1v1Start()
{
    // Hook the pounce event up.
    HookEvent("lunge_pounce", _1v1_Event_PlayerPounced);
    HookEvent("player_jump", _1v1_Event_PlayerJump);
}

Command1v1Stop()
{
    UnhookEvent("lunge_pounce", _1v1_Event_PlayerPounced);
    UnhookEvent("player_jump", _1v1_Event_PlayerJump);
}
