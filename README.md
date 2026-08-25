# TinkerGame

[![Wiki](https://img.shields.io/badge/docs-wiki-66c0f4?logo=github)](https://github.com/360900/tinkergame/wiki)

> **Warning!** This project is still in alpha! Expect bugs and major changes.

TinkerGame is a Linux game-launch wrapper for Steam. It gives each game a
small graphical control panel for Proton, Wine, Gamescope, MangoHud, mod
managers, launch commands, environment variables, and troubleshooting tools.

It supports Proton games, native Linux games, non-Steam games launched through
Steam, X11, Wayland, and Steam Deck game mode.

> TinkerGame is independent software. It is not affiliated with Valve or
> Steam. Use third-party tools and game modifications at your own risk.

## Documentation

The [TinkerGame wiki](https://github.com/360900/tinkergame/wiki) covers every
feature category with detailed pages, including the [Install
guide](https://github.com/360900/tinkergame/wiki/Installation), use as a
[Steam Compatibility Tool](https://github.com/360900/tinkergame/wiki/Steam-Compatibility-Tool),
and per-feature options. Every TinkerGame window can also open the matching
wiki page with the F1 key.

## What It Provides

- Per-game environment variables, launch commands, executables, and scripts.
- Proton and Wine selection, downloads, and prefix tools.
- Gamescope, MangoHud, GameMode, DXVK, VKD3D, FSR, and related options.
- Mod Organizer 2, Vortex, ReShade, Special K, Hedge Mod Manager, and other
  integrations.
- Native Linux game support through a Steam launch option.
- A YAD-based interface that works from the desktop and Steam Deck game mode.
- Command-line tools for installation, diagnostics, compatibility tools, and
  configuration.

## Install

Use your distribution package manager when a TinkerGame package is available.
ProtonUp-Qt and ProtonPlus support depends on their current release and package
metadata.

The quickest way from a source checkout is the one-command installer:

```sh
git clone https://github.com/360900/tinkergame.git
cd tinkergame
./install.sh
```

`./install.sh` asks whether to install for the current user only (recommended,
no root rights) or system-wide. It can also run non-interactively:

```sh
./install.sh --user     # install to ~/.local, no sudo
./install.sh --system   # install to /usr, uses sudo
```

The same with plain make:

```sh
sudo make install       # system-wide (/usr)
make install-user       # current user (~/.local)
```

The install requires Bash, Make, YAD, Git, Wget, Tar, Unzip, `jq`
(custom Proton and shader repository data), `xxd`, and the X11 tools
`xprop`, `xrandr`, and `xwininfo`. Optional integrations add their own
dependencies.

Debian/Ubuntu:

```sh
sudo apt-get install bash yad git wget tar unzip jq xdotool xxd x11-xserver-utils x11-utils
```

Arch:

```sh
sudo pacman -S bash git jq tar unzip wget xdotool xxd xorg-xprop xorg-xrandr xorg-xwininfo yad
```

(`xdotool` is only needed for a few optional legacy features.)

When installed for the current user, make sure `~/.local/bin` is in `PATH`.

For distribution packaging, `DESTDIR` stages files without changing the
runtime prefix embedded in the installed scripts:

```sh
make PREFIX=/usr DESTDIR="$PWD/pkg" install
```

An Arch Linux package recipe is provided at
[`packaging/arch/PKGBUILD`](packaging/arch/PKGBUILD).

To uninstall, run the uninstaller - it scans the usual install locations
(user and system), removes every TinkerGame installation it finds, and also
removes the Steam compatibility-tool registration:

```sh
tinkergame-uninstall
# or, for a system installation:
sudo tinkergame-uninstall
```

The default keeps your settings, cache, downloaded tools, and game data. Add
`--purge` to remove those as well, and `--yes` to skip the confirmation
prompt. If the uninstaller lives outside your `PATH`, run it from the
repository instead:

```sh
bash uninstall.sh --purge
```

## Use With Steam

### Proton games

Installing TinkerGame registers it as a Steam compatibility tool
automatically. If the registration was removed, or you installed without
running the registration step, re-register it:

```sh
tinkergame compat add
```

Select TinkerGame in the game's compatibility settings, or set it as the
default compatibility tool in Steam's Steam Play settings.

### Native Linux games

Set this as the game's launch option:

```text
tinkergame %command%
```

Use only one integration method per game. Do not select TinkerGame as a
compatibility tool and add it as a launch option at the same time.

### Command line

Run `tinkergame help` for the complete command list. Useful commands include:

```sh
tinkergame settings
tinkergame config dir
tinkergame version
tinkergame help
```

## Configuration

User configuration is stored under:

```text
${XDG_CONFIG_HOME:-$HOME/.config}/tinkergame
```

Logs are stored in the configuration directory and temporary startup logs are
stored under `/dev/shm/tinkergame`.

This is a full breaking rename. Existing users should read
[MIGRATION.md](MIGRATION.md) before installing.

## Troubleshooting

Start with the latest log from the configured `logs` directory and the startup
log under `/dev/shm/tinkergame`. Verify a source checkout with:

```sh
make build   # syntax-check the entry point and all lib/ modules
make check   # smoke checks
```

When reporting a problem, include the TinkerGame version, distribution,
desktop or game mode, display server, YAD version, game AppID, and relevant log
sections. Remove personal paths and tokens first.

## Credits

TinkerGame is a rename and continuation of
[SteamTinkerLaunch](https://github.com/sonic2kk/steamtinkerlaunch), the project
this repo was forked from, and builds on the work of its many contributors.
TinkerGame's parent project was created by
[`frostworx`](https://github.com/frostworx) and long maintained by
[`sonic2kk`](https://github.com/sonic2kk), with help from the broader
[SteamTinkerLaunch](https://github.com/sonic2kk/steamtinkerlaunch) community
over the years.

The complete history of the code remains available through this repository's
git log. This project is licensed under the GPLv3, as was its upstream
[SteamTinkerLaunch](https://github.com/sonic2kk/steamtinkerlaunch); see
[LICENSE](LICENSE).

## Development

TinkerGame is primarily Bash. The main script remains intentionally portable,
but new code should use arrays for external command arguments, quote paths, and
handle optional dependencies explicitly.

Run the local checks with:

```sh
make build          # syntax-check the entry point and all modules
make check          # smoke checks
./tests/run.sh unit # full unit test suite
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for development notes.

## License

TinkerGame is licensed under the GNU General Public License v3.0. See
[LICENSE](LICENSE).
