#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#include "rotoblin.helpers/tankmanager.inc"

// --------------------
//     Private
// --------------------

static const String: SP_CVAR[]               = "skeet_practice";
static const String: SP_CVAR_DEFAULT_VALUE[] = "0";
static const String: SP_CVAR_DESCRIPTION[]   = "Whether skeet practice is enabled.";
static       Handle: g_hSkeetPracticeCvar    = INVALID_HANDLE;


// **********************************************
//             Forwards
// **********************************************

/**
 * Plugin is starting.
 *
 * @noreturn
 */
public _SkeetPractice_OnPluginStart()
{
    _H_TankManager_OnPluginStart();
    // Always register the convar for skeetpractice and disable it.
    g_hSkeetPracticeCvar = CreateConVar(SP_CVAR, SP_CVAR_DEFAULT_VALUE, SP_CVAR_DESCRIPTION, FCVAR_PLUGIN|FCVAR_NOTIFY, true, 0.0, true, 1.0);
    
    // This will be called when teamclerks.main is enabled/disabled
    HookPublicEvent(EVENT_ONPLUGINENABLE, _SP_OnPluginEnabled);
    HookPublicEvent(EVENT_ONPLUGINDISABLE, _SP_OnPluginDisabled);
    HookPublicEvent(EVENT_ONCLIENTDISCONNECT_POST, _SP_OnClientDisconnect);
}

/**
 * Plugin is now enabled.
 *
 * @noreturn
 */
public _SP_OnPluginEnabled()
{
    HookConVarChange(g_hSkeetPracticeCvar, _SkeetPractice_CvarChange);
    HookTankEvent(TANK_SPAWNED, _SkeetPractice_TankSpawned);
}

/**
 * Plugin is now disabled.
 *
 * @noreturn
 */
public _SP_OnPluginDisabled()
{
    UnhookConVarChange(g_hSkeetPracticeCvar, _SkeetPractice_CvarChange);
    UnhookTankEvent(TANK_SPAWNED, _SkeetPractice_TankSpawned);
}

/**
 * Fired when a tank spawns; technically we don't want this to happen EVER in 
 * skeet practice, so we just remove the tank entirely.
 */
public _SkeetPractice_TankSpawned(Handle:event, const String:name[], bool:dontBroadcast)
{
    new tankClient = GetClientOfUserId(GetEventInt(event, "userid"));
    // Hopefully, this tankClient will NEVER be a player with this mod enabled.
    ForcePlayerSuicide(tankClient);
}

/**
 * No mobs cvar changed.
 *
 * @param convar        Handle to the convar that was changed.
 * @param oldValue        String containing the value of the convar before it was changed.
 * @param newValue        String containing the new value of the convar.
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

new Handle:_SP_HunterSurvivor[MAXPLAYERS+1];

public _SP_OnClientDisconnect(client)
{
    if (_SP_HunterSurvivor[client] != INVALID_HANDLE)
    {
        KillTimer(_SP_HunterSurvivor[client]);
        _SP_HunterSurvivor[client] = INVALID_HANDLE;
    }
}

public _SP_Event_PlayerPounced(Handle:event, const String:name[], bool:dontBroadcast)
{
    new hunterClient = GetClientOfUserId(GetEventInt(event, "userid"));
    decl String:hunterName[256];
    GetClientName(hunterClient, hunterName, 256);
    new hunterHealth = GetClientHealth(hunterClient);
    new survivorClient = GetClientOfUserId(GetEventInt(event, "victim"));
    
    PrintHintText(hunterClient,"%s had %i health left.", hunterName, hunterHealth);
    PrintHintText(survivorClient,"%s had %i health left.", hunterName, hunterHealth);
    
    new Handle:hunterPack;
    _SP_HunterSurvivor[hunterClient] = CreateDataTimer(1.0, _SP_killPouncedHunter, hunterPack);
    WritePackCell(hunterPack, hunterClient);
    
    new Handle:survivorPack;
    _SP_HunterSurvivor[survivorClient] = CreateDataTimer(2.0, _SP_healPouncedSurvivor, survivorPack);
    WritePackCell(survivorPack, survivorClient);
}

public Action:_SP_killPouncedHunter(Handle:timer, Handle:pack)
{
    new hunterClient;
    
    ResetPack(pack);
    hunterClient = ReadPackCell(pack);
    
    ForcePlayerSuicide(hunterClient);
    
    _SP_HunterSurvivor[hunterClient] = INVALID_HANDLE;
}

public Action:_SP_healPouncedSurvivor(Handle:timer, Handle:pack)
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
    
    _SP_HunterSurvivor[survivorClient] = INVALID_HANDLE;
}

//
// Private methods
//

CommandSkeetPracticeStart()
{
    // Hook the pounce event up.
    HookEvent("lunge_pounce", _SP_Event_PlayerPounced);
    
    PrintToChatAll("[SM] Skeet practice loaded.");
    
    RestartMapIn(5.0);
}

CommandSkeetPracticeStop()
{    
    UnhookEvent("lunge_pounce", _SP_Event_PlayerPounced);
    
    PrintToChatAll("[SM] Skeet practice unloaded.");
}