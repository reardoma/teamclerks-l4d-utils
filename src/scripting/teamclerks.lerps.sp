/**
 * This lerptracker was originally written by ProdigySim, and as such I have left all his
 * plugin info as-is. However, I wanted to add the command that shows the lerps to a
 * player who requests it, so I forked his code.
 */

#pragma semicolon 1
#include <sourcemod>

//#define clamp(%0, %1, %2) ( ((%0) < (%1)) ? (%1) : ( ((%0) > (%2)) ? (%2) : (%0) ) )
#define MAX(%0,%1) (((%0) > (%1)) ? (%0) : (%1))

public Plugin:myinfo = 
{
    name = "LerpTracker",
    author = "ProdigySim",
    description = "Keep track of players' lerp settings",
    version = "0.8",
    url = "https://bitbucket.org/ProdigySim/misc-sourcemod-plugins"
};

/* Global Vars */
new Float:g_fCurrentLerps[MAXPLAYERS+1];

/* My CVars */
new Handle:hLogLerp;
new Handle:hAnnounceLerp;
new Handle:hFixLerpValue;
new Handle:hMaxLerpValue;

/* Valve CVars */
new Handle:hMinUpdateRate;
new Handle:hMaxUpdateRate;
new Handle:hMinInterpRatio;
new Handle:hMaxInterpRatio;

static const String: LERPS_CMD[]       = "lerps";

// psychonic made me do it

#define ShouldFixLerp() (GetConVarBool(hFixLerpValue))

#define ShouldAnnounceLerpChanges() (GetConVarBool(hAnnounceLerp))

#define ShouldAnnounceInitialLerp() (GetConVarInt(hAnnounceLerp) == 1)

#define ShouldLogLerpChanges() (GetConVarBool(hLogLerp))

#define ShouldLogInitialLerp() (GetConVarInt(hLogLerp) == 1)

#define IsCurrentLerpValid(%0) (g_fCurrentLerps[(%0)] >= 0.0)

#define InvalidateCurrentLerp(%0) (g_fCurrentLerps[(%0)] = -1.0)

#define GetCurrentLerp(%0) (g_fCurrentLerps[(%0)])
#define SetCurrentLerp(%0,%1) (g_fCurrentLerps[(%0)] = (%1))

public _Lerps_OnPluginStart()
{
    hMinUpdateRate = FindConVar("sv_minupdaterate");
    hMaxUpdateRate = FindConVar("sv_maxupdaterate");
    hMinInterpRatio = FindConVar("sv_client_min_interp_ratio");
    hMaxInterpRatio= FindConVar("sv_client_max_interp_ratio");
    hLogLerp = CreateConVar("sm_log_lerp", "1", "Log changes to client lerp. 1=Log initial lerp and changes 2=Log changes only", FCVAR_PLUGIN);
    hAnnounceLerp = CreateConVar("sm_announce_lerp", "1", "Announce changes to client lerp. 1=Announce initial lerp and changes 2=Announce changes only", FCVAR_PLUGIN);
    hFixLerpValue = CreateConVar("sm_fixlerp", "0", "Fix Lerp values clamping incorrectly when interp_ratio 0 is allowed", FCVAR_PLUGIN);
    hMaxLerpValue = CreateConVar("sm_max_interp", "0.5", "Kick players whose settings breach this Hard upper-limit for player lerps.", FCVAR_PLUGIN);
    
    RegConsoleCmd("sm_lerps", Lerps_Cmd, "List the Lerps of all players in game", FCVAR_PLUGIN);

    AddCommandListener(_Lerps_OnClientCommandIssued, "say");
    AddCommandListener(_Lerps_OnClientCommandIssued, "say_team");
    
    HookPublicEvent(EVENT_ONCLIENTDISCONNECT_POST, _Lerps_OnClientDisconnect_Post);
    HookPublicEvent(EVENT_ONCLIENTSETTINGSCHANGED, _Lerps_OnClientSettingsChanged);
    
    ScanAllPlayersLerp();
}

public _Lerps_OnClientDisconnect_Post(client)
{
    InvalidateCurrentLerp(client);
}

/* Lerp calculation adapted from hl2sdk's CGameServerClients::OnClientSettingsChanged */
public _Lerps_OnClientSettingsChanged(client)
{
    if(IsValidEntity(client) &&  !IsFakeClient(client))
    {
        ProcessPlayerLerp(client);
    }
}

public Action:Lerps_Cmd(client, args)
{
    new lerpcnt;
    for(new rclient=1; rclient <= MaxClients; rclient++)
    {
        if(IsClientInGame(rclient) && !IsFakeClient(rclient))
        {
            ReplyToCommand(client, "%02d. %N Lerp: %.01f", ++lerpcnt, rclient, (GetCurrentLerp(rclient)*1000));
        }
    }
    return Plugin_Handled;
}


public Action:_Lerps_OnClientCommandIssued(client, const String:command[], argc)
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
    
    if (StrContains(sayWord, LERPS_CMD, false) == 1)
    {
        new lerpcnt;
        for(new rclient=1; rclient <= MaxClients; rclient++)
        {
            if(IsClientInGame(rclient) && !IsFakeClient(rclient))
            {
                PrintToChat(client, "%02d. %N Lerp: %.01f", ++lerpcnt, rclient, (GetCurrentLerp(rclient)*1000));
            }
        }
        return Plugin_Handled;
    }

    return Plugin_Continue;   
}

ScanAllPlayersLerp()
{
    for(new client=1; client <= MaxClients; client++)
    {
        InvalidateCurrentLerp(client);
        if(IsClientInGame(client) && !IsFakeClient(client))
        {
            ProcessPlayerLerp(client);
        }
    }
}

ProcessPlayerLerp(client)
{   
    new Float:m_fLerpTime = GetEntPropFloat(client, Prop_Data, "m_fLerpTime");
    
    if(ShouldFixLerp())
    {
        m_fLerpTime = GetLerpTime(client);
        SetEntPropFloat(client, Prop_Data, "m_fLerpTime", m_fLerpTime);
    }
    
    if(IsCurrentLerpValid(client))
    {
        if(m_fLerpTime != GetCurrentLerp(client))
        {
            if(ShouldAnnounceLerpChanges())
            {
                PrintToChatAll("%N's LerpTime Changed from %.01f to %.01f", client, GetCurrentLerp(client)*1000, m_fLerpTime*1000);
            }
            if(ShouldLogLerpChanges())
            {
                LogMessage("%N's LerpTime Changed from %.01f to %.01f", client, GetCurrentLerp(client)*1000, m_fLerpTime*1000);
            }
        }
    }
    else
    {
        if(ShouldAnnounceInitialLerp())
        {
            PrintToChatAll("%N's LerpTime set to %.01f", client, m_fLerpTime*1000);
        }
        if(ShouldLogInitialLerp())
        {
            LogMessage("%N's LerpTime set to %.01f", client, m_fLerpTime*1000);
        }
    }
    
    new Float:max=GetConVarFloat(hMaxLerpValue);
    if(m_fLerpTime > max)
    {
        KickClient(client, "Lerp %.01f exceeds server max of %.01f", m_fLerpTime*1000, max*1000);
        PrintToChatAll("%N kicked for lerp too high. %.01f > %.01f", client, m_fLerpTime*1000, max*1000);
        if(ShouldLogLerpChanges())
        {
            LogMessage("Kicked %L for having lerp %.01f (max: %.01f)", client, m_fLerpTime*1000, max*1000);
        }
    }
    else
    {
        SetCurrentLerp(client, m_fLerpTime);
    }
}



stock Float:GetLerpTime(client)
{
    decl String:buf[64], Float:lerpTime;
    
#define QUICKGETCVARVALUE(%0) (GetClientInfo(client, (%0), buf, sizeof(buf)) ? buf : "")
    
    new updateRate = StringToInt( QUICKGETCVARVALUE("cl_updaterate") );
    updateRate = RoundFloat(clamp(float(updateRate), GetConVarFloat(hMinUpdateRate), GetConVarFloat(hMaxUpdateRate)));
    
    /*new bool:useInterpolation = StringToInt( QUICKGETCVARVALUE("cl_interpolate") ) != 0;
    if ( useInterpolation )
    {*/
    new Float:flLerpRatio = StringToFloat( QUICKGETCVARVALUE("cl_interp_ratio") );
    /*if ( flLerpRatio == 0 )
        flLerpRatio = 1.0;*/
    new Float:flLerpAmount = StringToFloat( QUICKGETCVARVALUE("cl_interp") );

    
    if ( hMinInterpRatio != INVALID_HANDLE && hMaxInterpRatio != INVALID_HANDLE && GetConVarFloat(hMinInterpRatio) != -1.0 )
    {
        flLerpRatio = clamp( flLerpRatio, GetConVarFloat(hMinInterpRatio), GetConVarFloat(hMaxInterpRatio) );
    }
    else
    {
        /*if ( flLerpRatio == 0 )
            flLerpRatio = 1.0;*/
    }
    lerpTime = MAX( flLerpAmount, flLerpRatio / updateRate );
    /*}
    else
    {
        lerpTime = 0.0;
    }*/
    
#undef QUICKGETCVARVALUE
    return lerpTime;
}

stock Float:clamp(Float:in, Float:low, Float:high)
{
    return in > high ? high : (in < low ? low : in);
}