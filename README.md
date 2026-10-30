
# Dungeon Divers Solver

The main purpose of this app is to use it as helper app or map solver for the game called Dungeon Divers. The overall aim of the game itself is to solve each provided map by finding specified secret rooms that are placed on the map, but aren't visible to the player until marked correctly. This app is meant to simulate the map from the game with option to build your own map structure, define how many secret rooms of each type should be placed on the map and then either display hints for where the secret rooms could be placed or suggest solution on where they are most likely to be located.

This is rather small app that I decided to make inside Godot 4.x, in order to learn how to use it and become more familiar with it.

## Preview

![Main application view](docs/images/main_view.png)

---

## Usage

### Running the Project

1. Install [Godot Engine](https://godotengine.org/).
2. Clone or download this repository.
3. Import `project.godot` into Godot.
4. Run the project.

### Basic Controls

| Action | Input |
| --- | --- |
| Move camera | Right Mouse Button |
| Zoom | Mouse Wheel Up/Down Scroll |
| Center camera | Mouse Wheel Click |
| Interact / Create room / Open room editor menu | Left Mouse Button |

---

## TODOs

Currently working on:

- [ ] Implement MapSolver feature along with displaying it's results on map.
	- [ ] Make sure that the map solver results from the last stage don't conflict with each other.
	- [ ] Fix issue with invalid room placements if they are only located next to a secret room and no other room is connected to them (weight 0).
- [ ] Check if it would be a good idea to move some MapSolver functions logic to specific SecretPlacementConfig/SecretPlacementType/SecretPlacementType* to make it less messy and more organized.
<br>
- [ ] Add features section to this readme, that would include description of each available feature and guide how to use them.
- [ ] Add info about secret room type placement restrictions upon clicking or hovering them.
- [ ] Create a custom app icon to replace the existing one (for example some small miniature with example room layout on some parchment and pencil/pen/quill).

Things that could be improved in the future versions:

- [ ] Refactor existing code (add comments, hide internal functions/variables, check indentation)
- [ ] Implement way to load in map state from the game screenshot.
- [ ] Implement audio system for game/map interactions (for example placing a room or destroying it, clicking map/hud elements).
- [ ] Implement map validation based on some basic rules.
- [ ] Implement animations for placing/deleting rooms on map (especially upon loading/importing game state from save).

---

## Third-Party Resources

This project uses and draws insipiration from the following third-party projects, addons, assets, and fonts.

### Inspiration

#### Dungeon Divers

This project is heavily inspired by **Dungeon Divers**, particularly its dungeon-based puzzle mechanics, room presentation, and visual style.

Somve visuals are original assets inspired by the visual style of **Dungeon Divers**, while certain room and room-type representations were recreated from game itself as visual reference. These assets were drawn independently by me; no original game asset files were extracted or redistributed.

- Developer: Wilson The Ball
- Publisher: GIGATANK 3000
- Source: [Dungeon Divers on Steam](https://store.steampowered.com/app/1844790/Dungeon_Divers/)

### Godot Addons

#### Godot Radial Menu Control

A radial menu `Control` for Godot, used as the basis for the project's radial context menus.

- Author: [jesuisse](https://github.com/jesuisse)
- Source: [godot-radial-menu-control](https://github.com/jesuisse/godot-radial-menu-control)
- License: MIT

#### Easy Store

EasyStore is a lightweight, modular save system addon for Godot 4. It's used as a basis for the project's save manager menus.

- Author: [IUXGames](https://github.com/IUXGames)
- Source: [EasyStore](https://github.com/IUXGames/EasyStore)
- License: MIT

### UI Assets

#### Fantasy UI Borders

Fantasy-themed UI border assets used for parts of the project's user interface.

- Author: [Kenney](https://kenney.nl/)
- Source: [Fantasy UI Borders](https://kenney.nl/assets/fantasy-ui-borders)
- License: [Creative Commons CC0](https://creativecommons.org/publicdomain/zero/1.0/)

### Fonts

#### Monogram

- Author: [datagoblin](https://datagoblin.itch.io/)
- Source: [Monogram](https://datagoblin.itch.io/monogram)
- License: [Creative Commons CC0](https://creativecommons.org/publicdomain/zero/1.0/)

---

## License

The source code and original project documentation are licensed under the [MIT License](LICENSE), unless otherwise noted.

Original artwork and visual assets created specifically for this project are licensed under the [Creative Commons Attribution 4.0 International License](https://creativecommons.org/licenses/by/4.0/), unless otherwise noted.

### Dungeon Divers-Based Visual Assets

Certain room, room-type, special-room, secret-room, and related visual assets were recreated using screenshots from **Dungeon Divers** as visual references.

These assets are explicitly **excluded** from both the MIT License and the Creative Commons Attribution 4.0 license used by this project. No separate license to reuse or redistribute these particular assets is granted by this project, and no ownership of the original Dungeon Divers designs is claimed.

Dungeon Divers and its original artwork, designs, names, and other intellectual property belong to their respective rights holders.

### Third-Party Resources

Third-party addons, fonts, and assets included in this project remain subject to their respective licenses. See [Third-Party Resources](#third-party-resources) for attribution and licensing information.

This project is an independent project and is not affiliated with or endorsed by the developers or publishers of Dungeon Divers.
