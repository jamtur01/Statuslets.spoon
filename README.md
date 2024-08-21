# Statuslets

Statuslets is a Hammerspoon spoon that provides a menubar icon displaying the status of various system metrics such as CPU usage, memory usage, system updates, Time Machine backups, network traffic, USB power draw, and available storage. The statuses are color-coded for easy identification.

## Features

- CPU Usage: Monitors CPU usage and displays a green, yellow, or red dot based on usage thresholds.
- Memory Usage: Checks available memory and displays a corresponding status.
- System Updates: Indicates whether system updates are available.
- Time Machine Backup: Shows the status of the latest Time Machine backup.
- Network Traffic: Monitors network traffic and displays the status.
- USB Power Draw: Checks USB power draw and displays the status.
- Available Storage: Monitors available storage space and displays the status.

## Installation

Download the Spoon: Clone or download the repository to your Hammerspoon Spoons directory.

```
git clone https://github.com/jamtur01/Statuslets.spoon.git ~/.hammerspoon/Spoons/Statuslets.spoon
```

Load the Spoon: Add the following lines to your `~/.hammerspoon/init.lua` file:

```lua
hs.loadSpoon("Statuslets")
spoon.Statuslets:start()
```

## Usage

Once installed and started, Statuslets will display a menubar icon with colored dots representing the status of various system metrics. The menu provides detailed information about each metric and options to refresh the status or quit the spoon.

### Menubar Icon

- Green Dot (●): Indicates a good status.
- Yellow Dot (◐): Indicates a warning status.
- Red Dot (○): Indicates an error status.

### Menu Options

- Refresh Status: Manually refreshes the status of all metrics.
- Quit Statuslets: Stops the Statuslets spoon and removes the menubar icon.

## Configuration

You can customize the status colors by modifying the `obj.statusColors` table in the `init.lua` file.

```lua
obj.statusColors = {
    cpu = hs.drawing.color.osx_yellow,
    memory = hs.drawing.color.osx_yellow,
    updates = hs.drawing.color.osx_yellow,
    timemachine = hs.drawing.color.osx_yellow,
    network = hs.drawing.color.osx_yellow,
    usbpower = hs.drawing.color.osx_yellow,
    storage = hs.drawing.color.osx_yellow
}
```

The default colors are set to yellow for all statuses.

## License

Statuslets is released under the MIT License. See the LICENSE file for more details.

## Author

James Turnbull <james@lovedthanlost.net>. Owns heritage to [this spoon](https://github.com/wangshub/hammerspoon-config/blob/master/statuslets/statuslets.lua).

## Contributing

Contributions are welcome! Please fork the repository and submit a pull request with your changes.

Acknowledgments
Hammerspoon - The automation tool for macOS that makes this spoon possible.
Enjoy using Statuslets and keep your system status at your fingertips!
