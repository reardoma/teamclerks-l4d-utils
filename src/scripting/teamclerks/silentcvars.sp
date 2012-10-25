// Don't let the script be included more than once.
#if defined _teamclerks_SC
  #endinput
#endif
#define _teamclerks_SC

// **********************************************
//                   Reference
// **********************************************

// **********************************************
//                   Variables
// **********************************************

// **********************************************
//             Forwards
// **********************************************

/**
 * Plugin is starting.
 *
 * @noreturn
 */
public _SC_OnPluginStart()
{
    RegAdminCmd("sm_scvar", Command_Cvar, ADMFLAG_CONVARS, "sm_scvar <cvar> [value]");
}


public Action:Command_Cvar(client, args)
{
    if (args < 1)
    {
        if (client == 0)
        {
            ReplyToCommand(client, "[SM] Usage: sm_scvar <cvar> [value]");
        }
        else
        {
            ReplyToCommand(client, "[SM] Usage: sm_scvar <cvar> [value]");
        }
        return Plugin_Handled;
    }

    decl String:cvarname[64];
    GetCmdArg(1, cvarname, sizeof(cvarname));

    new Handle:hndl = FindConVar(cvarname);
    if (hndl == INVALID_HANDLE)
    {
        ReplyToCommand(client, "[SM] %t", "Unable to find cvar", cvarname);
        return Plugin_Handled;
    }

    decl String:value[255];
    if (args < 2)
    {
        GetConVarString(hndl, value, sizeof(value));

        ReplyToCommand(client, "[SM] %t", "Value of cvar", cvarname, value);
        return Plugin_Handled;
    }

    GetCmdArg(2, value, sizeof(value));

    TC_Debug("\"%L\" changed cvar (cvar \"%s\") (value \"%s\")", client, cvarname, value);

    SetConVarString(hndl, value, true);

    return Plugin_Handled;
}