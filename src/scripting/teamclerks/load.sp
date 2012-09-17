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

// Don't let the script be included more than once.
#if defined _teamclerks_load
  #endinput
#endif
#define _teamclerks_load

#define VOTE_THRESHOLD 0.5

// --------------------
//     Public
// --------------------
new            bool: hasVoted[MAXPLAYERS+1]       = {false};
new          String: votingOn[]                   = "";
new            bool: currentlyVoting              = false;
new            bool: tallyingVotes                = false;
new            bool: votePassed                   = false;
new          Handle: recentVoters[MAXPLAYERS+1];
new          String: currentlyLoaded[]            = "";

// --------------------
//     Private
// --------------------
static       Handle: TC_CONFIG                    = INVALID_HANDLE;

static const String: TC_LOAD_CMD[]                = "load";
static const String: TC_FORCE_LOAD_CMD[]          = "force";


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
    TC_CONFIG = LoadGameConfigFile("teamclerks.load");
    GameConfGetKeyValue(TC_CONFIG, "DEFAULT", currentlyLoaded, MAX_NAME_LENGTH);

    RegAdminCmd("tc_force", _Load_OnCommandForce, ADMFLAG_CHANGEMAP, "tc_force - force the loading of a modual");

    AddCommandListener(_Load_OnClientCommandIssued, "say");
    AddCommandListener(_Load_OnClientCommandIssued, "say_team");
    
    //HookPublicEvent(EVENT_ONCLIENTDISCONNECT_POST, _Load_OnClientDisconnectPost);

    //_Load_Load_Default_If_Present();
}

public _Load_OnClientDisconnectPost(client)
{
    if (!Server_Has_Player_Clients())
    {
        // No clients, load the default.
        _Load_Load_Default_If_Present();
    }
}

public Action:_Load_OnCommandForce(client, args)
{
    decl String:moduleName[MAX_NAME_LENGTH];
    
    if (GetCmdArg(1, moduleName, sizeof(moduleName)) > 0)
    {
        // Means there was a module specified to load.
        _Load_Load_Module(moduleName);
    }
}

public Action:_Load_OnClientCommandIssued(client, const String:command[], argc)
{
    if (argc < 1)
    {
        return Plugin_Continue;
    }

    decl String:sayWord[MAX_NAME_LENGTH];
    GetCmdArg(1, sayWord, sizeof(sayWord));
    
    if (StrContains(sayWord, "!", false) != 0)
    {
        // We ONLY allow !-commands
        return Plugin_Continue;
    }
    
    decl String:tokens[32][MAX_NAME_LENGTH];
    ExplodeString(sayWord, " ", tokens, 32, MAX_NAME_LENGTH);
    
    // Get the first command; might be 'load', 'force', etc.
    new idx = StrContains(sayWord, TC_LOAD_CMD, false);
    
    // !LOAD
    if (idx == 1)
    {
        if (!_Load_Check_Module(tokens[1]))
        {
            PrintToChat(client, "Module %s not available", tokens[1]);
            return Plugin_Continue;
        }
        
        _Load_Vote_On_Module(client, tokens[1]);
        
        return Plugin_Handled;
    }
    
    idx = StrContains(command, TC_FORCE_LOAD_CMD, false);
    
    // !FORCELOAD
    if (idx == 1)
    {
        if (CheckCommandAccess(client, "tc_force", 0))
        {            
            if (!_Load_Check_Module(tokens[1]))
            {
                return Plugin_Continue;
            }
            
            // Admin can use tc_force... do it.
            _Load_Load_Module(tokens[1]);
            
            return Plugin_Handled;
        }
    }
    
    return Plugin_Continue;
}

/**
 * We are given a window for a vote request to load a module. When
 * the initial load is requested, a timer is created to tally the
 * votes, and if the tallies are in the majority, the load is called.
 */
public Action:_Load_Tally_Votes(Handle:timer)
{
    currentlyVoting = false;
    tallyingVotes = true;
    
    if (!votePassed)
    {
        if (_Load_Is_Vote_Passing())
        {
            _Load_Load_Module(votingOn);
        }
        else
        {
            // Vote failed.
            PrintToChatAll("Vote failed for module: %s", votingOn);
        }
        
        _Load_End_Vote(votingOn);
    }
    
    votePassed = false;
    // Maybe EVERYONE voted yes before the timer went off; we need
    // to just ignore this in that case.
}

public Action:_Load_Allow_Start_Vote(Handle:timer, Handle:pack)
{
    new voterClient;
    
    ResetPack(pack);
    voterClient = ReadPackCell(pack);
    
    // There is no guarantee that voterClient is still a valid
    // clientid, so don't use it for anything.
    // This will make it so someone who starts a vote, leaves the
    // server, and immediately rejoins will not be able to start
    // another vote until the timer runs out.
    recentVoters[voterClient] = INVALID_HANDLE;
}


/**************************************
 *             PRIVATES               *
 **************************************/

/**
 * Returns whether the vote is passing
 */
bool:_Load_Is_Vote_Passing(bool:requireAll=false)
{
    new yesVotes = 0;
    for (new i = 0; i < sizeof(hasVoted); i++)
    {
        if (hasVoted[i])
        {
            yesVotes ++;
        }
    }
    
    new survsAndInfs = Get_Survivor_Player_Count() + Get_Infected_Player_Count();
    
    new Float:percent = FloatDiv(float(yesVotes), float(survsAndInfs));
    
    if (requireAll)
    {
        return percent == 1.0;
    }
    else
    {
        return percent > VOTE_THRESHOLD;
    }
}

/**
 * By here, we have guaranteed that target is an actual loadable
 * module, and we're going to start voting or cast a current vote.
 */
_Load_Vote_On_Module(client, String:target[])
{
    if (!tallyingVotes)
    {
        if (currentlyVoting)
        {
            if (StrEqual(votingOn, target, false))
            {
                _Load_Cast_Vote(client, target);
            }
        }
        else if (recentVoters[client] == INVALID_HANDLE)
        {
            _Load_Start_Vote(client, target);
        }
        else
        {
            PrintToChat(client, "You started a vote within the last %i seconds; please wait to start a new one.", 60);
        }
    }
    else
    {
        // Voting not allowed right now.
    }
}

/**
 * By here, we are casting a vote for a currently active voting
 * process and we know that target is the module being voted on.
 * We need to ensure that client has not already cast a vote.
 */
_Load_Cast_Vote(client, String:target[])
{    
    if (hasVoted[client])
    {
        // Naughty; send a message back.
        PrintToChat(client, "You have already cast your vote for %s.", target);
    }
    else
    {
        hasVoted[client] = true;
        
        PrintToChat(client, "You have cast a vote for %s.", target);
        
        if (_Load_Is_Vote_Passing(true))
        {
            // Then that was a 100% agreement.
            _Load_Load_Module(target);
        }
    }
}

/**
 * By here, we are starting a new vote on a target we know. Let's
 * set up out variables for the vote.
 */
_Load_Start_Vote(client, String:target[])
{
    currentlyVoting = true;
    strcopy(votingOn, MAX_NAME_LENGTH, target);
    hasVoted[client] = true;
    
    CreateTimer(20.0, _Load_Tally_Votes);

    new Handle:clientPack;
    recentVoters[client] = CreateDataTimer(60.0, _Load_Allow_Start_Vote, clientPack);
    WritePackCell(clientPack, client);
    
    decl String:nick[64];
    GetClientName(client, nick, sizeof(nick));
    
    PrintToChatAll("%s has started a vote for: %s ", nick, target);
    PrintToChatAll("Type \"!%s\" to cast a vote in favor of this config load.", target);
    
    // If we're the only player, then it should load.
    if (_Load_Is_Vote_Passing(true))
    {
        // Then that was a 100% agreement.
        _Load_Load_Module(target);
    }
}

/**
 * Checks that the target module is actually a valid entry in the gamedata.
 * If the target is valid, toLoad is given the valid and the return is true.
 * If the target is not valid, false is returned and toLoad remains unchanged.
 */
bool:_Load_Check_Module(String:target[], String:toLoad[]="")
{
    return GameConfGetKeyValue(TC_CONFIG, target, toLoad, MAX_NAME_LENGTH);
}

/**
 * Loads the actual module voted up (or forced) by the players.
 */
_Load_Load_Module(String:target[])
{
    decl String:loadable[MAX_NAME_LENGTH];
    
    if (_Load_Check_Module(target, loadable))
    {
        PrintToChatAll("Vote successful; loading module: %s...", target);
        votePassed = true;
        // Successfully read the target's value from the config file into loadable.
        _Load_End_Vote(target);
        // Load it!
        ServerCommand("exec %s", loadable);
    }
}

/**
 * Loads the default config if present.
 */
_Load_Load_Default_If_Present()
{
    decl String:defalt[MAX_NAME_LENGTH];
    
    if (_Load_Check_Module("DEFAULT", defalt) && !StrEqual("", defalt))
    {
        // Okay, there IS a default value specified
        _Load_Load_Module(defalt);
    }
}

/**
 * Resets all the vote variables to their original positions.
 */
_Load_End_Vote(String:target[])
{
    for (new i = 0; i < sizeof(hasVoted); i++)
    {
        hasVoted[i] = false;
    }
    votingOn = "";
    currentlyVoting = false;
    tallyingVotes = false;
    strcopy(currentlyLoaded, MAX_NAME_LENGTH, target);
}