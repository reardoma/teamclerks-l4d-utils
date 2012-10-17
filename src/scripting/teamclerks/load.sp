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

    decl String:defalt[MAX_NAME_LENGTH];
    GameConfGetKeyValue(TC_CONFIG, "DEFAULT", defalt, MAX_NAME_LENGTH);

    RegAdminCmd("sm_force", _Load_OnCommandForce, ADMFLAG_CHANGEMAP, "sm_force <module> - force the loading of a modual.");
    RegConsoleCmd("sm_load", _Load_OnCommandLoad, "sm_load <module> - vote to load a module.");
    
    AutoExecConfig(true, defalt, "teamclerks");
}

/**
 * Handler method for the load command. Is called when an admin client issues
 * 'sm_force' from the console or uses '!force' or '/force' from chat.
 */
public Action:_Load_OnCommandForce(client, args)
{
    if (args < 1)
    {
        ReplyToCommand(client, "[SM] Usage: sm_force <module> - force a module to load.");        
        return Plugin_Handled;
    }
    
    decl String:module[64];
    GetCmdArg(1, module, sizeof(module));
    
    if (!_Load_Check_Module(module))
    {
        PrintToChat(client, "Module '%s' not available", module);
        return Plugin_Handled;
    }
    
    // There was a good module specified to load.
    _Load_Load_Module(module);
    
    return Plugin_Handled;
}

/**
 * Handler method for the load command. Is called when a client issues
 * 'sm_load' from the console or uses '!load' or '/load' from chat.
 */
public Action:_Load_OnCommandLoad(client, args)
{
    if (args < 1)
    {
        ReplyToCommand(client, "[SM] Usage: sm_load <module> - vote to load a module.");        
        return Plugin_Handled;
    }
    
    decl String:module[64];
    GetCmdArg(1, module, sizeof(module));
    
    if (!_Load_Check_Module(module))
    {
        PrintToChat(client, "Module '%s' not available", module);
        return Plugin_Handled;
    }
    
    _Load_Vote_On_Module(client, module);
    
    return Plugin_Handled;
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
    
    if (survsAndInfs == 0)
    {
        // No div-zeros please; this will happen if there are no players
        // in the server and the console-admin issues a load.
        survsAndInfs = 1;
    }
    
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
            PrintToChat(client, "You started a vote within the last %i seconds; please wait to start a new one.", 20);
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
    recentVoters[client] = CreateDataTimer(20.0, _Load_Allow_Start_Vote, clientPack);
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