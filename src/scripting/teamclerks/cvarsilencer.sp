/**
 * CVAR Silencer
 * 
 * TeamClerks plugin module that keeps cvar changes from being shown to clients.
 * Honestly, I do not know why this is not something that SourceMod does by default,
 * but here we are -- a huge list of cvars I know change rather often (from loaded
 * module to module) that I would prefer clients not be bother with.
 */

// Don't let the script be included more than once.
#if defined _teamclerks_cvarsilencer
  #endinput
#endif
#define _teamclerks_cvarsilencer

#define NUM_CVARS 58

new String:cvars[NUM_CVARS][64] = {
    "vs_max_team_switches",            "sb_all_bot_team",                 "director_no_survivor_bots",         "survivor_limit",
    "z_max_player_zombies",            "z_mob_spawn_min_size",            "z_mob_spawn_max_size",              "z_common_limit",
    "z_mega_mob_size",                 "z_ghost_finale_spawn_interval",   "z_ghost_checkpoint_spawn_interval", "z_ghost_delay_min",
    "z_ghost_delay_max",               "z_hunter_limit",                  "z_versus_smoker_limit",             "z_versus_boomer_limit",
    "z_pounce_damage",                 "hunter_pz_claw_dmg",              "survivor_max_incapacitated_count",  "survivor_ledge_grab_health",
    "z_tank_health",                   "versus_tank_chance_intro",        "versus_tank_chance_finale",         "versus_tank_chance",
    "versus_witch_chance_intro",       "versus_witch_chance_finale",      "versus_witch_chance",               "versus_boss_flow_max_intro",
    "versus_boss_flow_max",            "versus_tank_flow_team_variation", "director_convert_pills",            "director_vs_convert_pills",
    "director_scavenge_item_override", "director_pain_pill_density",      "director_scavenge_item_override",   "director_propane_tank_density",
    "director_gas_can_density",        "director_oxygen_tank_density",    "director_molotov_density",          "director_pipe_bomb_density",
    "director_pistol_density",         "z_ghost_delay_max",               "z_ghost_delay_min",                 "tank_stuck_time_suicide",
    "director_min_start_players",      "mp_logdetail",                    "fps_max",                           "sv_minupdaterate",
    "sv_maxupdaterate",                "sv_client_min_interp_ratio",      "rotoblin_enable",                   "rotoblin_health_style",
    "rotoblin_interp_min",             "rotoblin_interp_max",             "rotoblin_enable_throwables",        "rotoblin_enable_cannisters",
    "sv_alltalk",                      "l4d_ready_enabled"
};

public _CvarSilencer_OnPluginStart()
{
    for(new i = 0; i < NUM_CVARS; i++)
    {
        SilenceCvar(cvars[i]);
    }
}

SilenceCvar(const String:cvar[64]) 
{
    new flags, Handle:cvarH = FindConVar(cvar);
    
    if (cvarH != INVALID_HANDLE)
    {
        flags = GetConVarFlags(cvarH);
        flags &= ~FCVAR_NOTIFY;
        SetConVarFlags(cvarH, flags);
        
        TC_Debug("Not notify: %s", cvar);
        
        CloseHandle(cvarH);
    }
    else
    {
        TC_Debug("Invalid cvar: %s", cvar);
    }
}