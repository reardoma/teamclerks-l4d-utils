/**
 * Load will listen to survivors and infected and institute "votes" for
 * particular load values.
 * 
 * For example, if a server only has 2 players in it, they might opt to
 * play a 1v1 game, but not have admin. As such, they could type:
 * 
 *  !load 1v1
 *  
 * This command would trigger the plugin, cache the player who asked for
 * the module load, and wait for a majority of players to agree (in this
 * case we are hoping there are only 2 players on the server, but if 
 * there are 8 players and they all agree, then the 1v1 module will
 * load).
 * 
 * Load expects there to be a 'teamclerks.load.cfg' in the
 * 'addons/sourcemod/configs' folder for the server. Every entry in the
 * config will be iterated over and become available to be voted against.
 * 
 * __WARNING__ This means that if you have an entry that maps to a config
 * that does something stupid (like change your RCON password), it will
 * still load it. 
 * 
 */

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

// --------------------
//     Public
// --------------------
new                     SurvivorIndex[MAXPLAYERS+1] = {0};
new                     InfectedIndex[MAXPLAYERS+1] = {0};
new                     SpectateIndex[MAXPLAYERS+1] = {0};

// --------------------
//     Private
// --------------------

static const String: TC_LOAD_CVAR[]               = "teamclerks_load_enable";
static const String: TC_LOAD_CVAR_DEFAULT_VALUE[] = "0";
static const String: TC_LOAD_CVAR_DESCRIPTION[]   = "Whether the load modual is enabled.";
static       Handle: g_hLoadCvar                  = INVALID_HANDLE;
static       Handle: TC_CONFIG                    = INVALID_HANDLE;

static const String: TC_LOAD_CMD[]                = "load";
static const String: TC_FORCE_LOAD_CMD[]          = "force";

static       bool:   currentlyVoting              = false;


// **********************************************
//             Forwards
// **********************************************

/**
 * Plugin is starting.
 *
 * @noreturn
 */
public _Load_OnPluginStart()
{    
    // Always register the convar for Load and disable it.
    g_hLoadCvar = CreateConVar(TC_LOAD_CVAR, TC_LOAD_CVAR_DEFAULT_VALUE, TC_LOAD_CVAR_DESCRIPTION, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 1.0);
    
    TC_CONFIG = LoadGameConfigFile("teamclerks.load");

    RegAdminCmd("tc_force", _Load_OnCommandForce, ADMFLAG_CHANGEMAP, "tc_force - force the loading of a modual");
    
    // This will be called when teamclerks.main is enabled/disabled
    HookPublicEvent(EVENT_ONPLUGINENABLE, _Load_OnPluginEnabled);
    HookPublicEvent(EVENT_ONPLUGINDISABLE, _Load_OnPluginDisabled);
}

/**
 * Plugin is now enabled.
 *
 * @noreturn
 */
public _Load_OnPluginEnabled()
{
    HookConVarChange(g_hLoadCvar, _Load_CvarChange);
    
    HookPublicEvent(EVENT_ONCLIENTCONNECTED, _Load_OnClientConnected);
    HookPublicEvent(EVENT_ONCLIENTDISCONNECT_POST, _Load_OnClientDisconnect);

    AddCommandListener(_Load_OnClientCommandIssued, "say");
    AddCommandListener(_Load_OnClientCommandIssued, "say_team");
}

/**
 * Plugin is now disabled.
 *
 * @noreturn
 */
public _Load_OnPluginDisabled()
{
    UnhookConVarChange(g_hLoadCvar, _Load_CvarChange);
    
    UnhookPublicEvent(EVENT_ONCLIENTCONNECTED, _Load_OnClientConnected);
    UnhookPublicEvent(EVENT_ONCLIENTDISCONNECT_POST, _Load_OnClientDisconnect);
    
    RemoveCommandListener(_Load_OnClientCommandIssued, "say");
    RemoveCommandListener(_Load_OnClientCommandIssued, "say_team");
}

public Action:_Load_OnCommandForce(client, args)
{
    decl String:moduleName[MAX_NAME_LENGTH];
    
    if (GetCmdArg(1, moduleName, sizeof(moduleName)) > 0)
    {
        // Means there was a module to load.
        _Load_Load_Module(moduleName);
    }
    
    PrintToServer("Got command: %s", moduleName);
}

/**
 * No mobs cvar changed.
 *
 * @param convar        Handle to the convar that was changed.
 * @param oldValue        String containing the value of the convar before it was changed.
 * @param newValue        String containing the new value of the convar.
 * @noreturn
 */
public _Load_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
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
            _Load_OnPluginEnabled();
        }
        else
        {
            _Load_OnPluginDisabled();
        }
    }
}

public _Load_OnClientDisconnect(client)
{
    
}

public _Load_OnClientConnected(client)
{
    
}


public Action:_Load_OnClientCommandIssued(client, const String:command[], argc)
{
    if (argc < 1)
    {
        return Plugin_Continue;
    }
    
    decl String:sayWord[MAX_NAME_LENGTH];
    GetCmdArg(1, sayWord, sizeof(sayWord));
    
    if (!StrContains(sayWord, "!", false))
    {
        // We ONLY allow !-commands
        return Plugin_Continue;
    }
    
    new idx = StrContains(sayWord, TC_LOAD_CMD, false);

    // !LOAD
    if (idx == 1)
    {
        decl String:moduleName[MAX_NAME_LENGTH];
        
        if (GetCmdArg(2, moduleName, sizeof(moduleName)) < 1)
        {
            return Plugin_Continue;
        }
        
        if (currentlyVoting)
        {
            // Cast the vote
            return Plugin_Handled;
        }
        else
        {
            // Start a new vote
        }
    }
    
    idx = StrContains(sayWord, TC_FORCE_LOAD_CMD, false);
    
    // !FORCELOAD
    if (idx == 1)
    {
        if (CheckCommandAccess(client, "tc_force", 0))
        {
            decl String:moduleName[MAX_NAME_LENGTH];
            
            if (GetCmdArg(2, moduleName, sizeof(moduleName)) < 1)
            {
                return Plugin_Continue;
            }
            
            // Admin can use tc_force... do it.
            _Load_Load_Module(moduleName);
            
            return Plugin_Handled;
        }
    }
    
    return Plugin_Continue;
}

_Load_Load_Module(const String:target[])
{
    decl String:loadable[MAX_NAME_LENGTH];
    
    if (GameConfGetKeyValue(TC_CONFIG, target, loadable, MAX_NAME_LENGTH))
    {
        // Successfully read the target's value from the config file into loadable.
        // Load it!
        ServerCommand("exec %s", loadable);
    }
}