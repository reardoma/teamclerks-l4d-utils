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