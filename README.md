# BGKF - Battleground Kill Feed

## Overview
BGKF (Battleground Kill Feed) enhances World of Warcraft's PvP experience by adding a CS:GO-style kill feed to battlegrounds. Watch in real-time as players earn kills and progress through classic PvP ranks, complete with announcer sounds and visual notifications.

## Features
- **Dynamic Kill Feed**: Displays player kills in battlegrounds with class colors and faction icons
- **PvP Rank System**: Players earn ranks based on killing blows, visualized with classic WoW PvP rank icons
- **CS:GO Style Audio**: Announcer sounds for kills, multi-kills, and rank progression
- **Nameplate Integration**: See enemy rank icons directly on their nameplates
- **Customizable Display**: Adjust size, position, colors, and behavior of the kill feed
- **Test Mode**: Try out all features without needing to be in a battleground

## Installation
1. Download the latest version from CurseForge
2. Extract the folder into your `World of Warcraft\_retail_\Interface\AddOns` directory
3. Make sure the folder is named "BGKF" (remove any version numbers or suffixes)
4. Restart World of Warcraft if it's currently running

## Usage
- Type `/bgkf` to open the configuration panel
- All settings are customizable through this interface
- Use the "Test Mode" button to preview the addon in action

## Configuration Options

### General Settings
- **Enable Addon**: Toggle the entire addon on/off
- **Test Mode**: Simulate battleground activity to see how the addon works

### Kill Feed Display
- **Width/Height**: Adjust the size of the kill feed window
- **Max Entries**: Set how many kills to display at once
- **Fade Time**: Control how long kills stay visible (0 = never fade)
- **Permanent Kill Feed**: Option to keep all kills visible for the entire battleground
- **Font Size**: Change text size for better readability
- **Show Faction Icons**: Display Horde/Alliance icons next to player names
- **Show Timestamps**: Add time stamps to each kill
- **Background Color**: Customize color and transparency of the kill feed window

### PvP Rank System
- **Enable Ranks**: Toggle the rank system on/off
- **Reset on Death**: Option to reset a player's rank when they die
- **Show on Nameplates**: Display rank icons on enemy nameplates
- **Rank Information**: View the Alliance and Horde rank progression system

### Sound Settings
- **Enable Sounds**: Toggle kill announcement sounds on/off
- **Sound Volume**: Adjust the volume of sound effects
- **First Kill Sound**: Select which sound to play on a single kill
- **Sound Information**: See which sounds play for different kill streaks and achievements

## Known Issues
- Combat log events only detect deaths within approximately 100 yards. Deaths outside this range will still be detected when the battleground score updates.
- In large battlegrounds, there may be a slight delay in rank updates for distant players.

## Credits
- Sound effects inspired by CS:GO and Unreal Tournament
- Uses standard WoW PvP rank icons for consistency with the game's existing visual language
- Special thanks to the Ace3 library developers

## Feedback and Support
Please report any bugs or feature suggestions on the GitHub repository or in the comments section on CurseForge.

## License
All Rights Reserved

---

Enjoy your enhanced battleground experience with BGKF!