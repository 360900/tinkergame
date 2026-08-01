# TinkerGame

TinkerGame is a Linux game-launch wrapper for Steam. It gives each game a
small graphical control panel for Proton, Wine, Gamescope, MangoHud, mod
managers, launch commands, environment variables, and troubleshooting tools.

It supports Proton games, native Linux games, non-Steam games launched through
Steam, X11, Wayland, and Steam Deck game mode.

> TinkerGame is independent software. It is not affiliated with Valve or
> Steam. Use third-party tools and game modifications at your own risk.

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

For a local system installation:

```sh
make
sudo make install
```

For a user-local installation:

```sh
make PREFIX="$HOME/.local"
make PREFIX="$HOME/.local" install
```

For distribution packaging, `DESTDIR` stages files without changing the
runtime prefix embedded in the installed scripts:

```sh
make PREFIX=/usr DESTDIR="$PWD/pkg" install
```

An Arch Linux package recipe is provided at
[`packaging/arch/PKGBUILD`](packaging/arch/PKGBUILD).

To uninstall an installation, run the installed uninstaller:

```sh
# System installation
sudo tinkergame-uninstall

# User-local installation
tinkergame-uninstall
```

The default keeps your settings, cache, downloaded tools, and game data. Add
`--purge` to remove those files and the TinkerGame Steam compatibility-tool
registration as well. Add `--yes` to skip the confirmation prompt.

```sh
sudo tinkergame-uninstall --purge
```

The install requires Bash, YAD, Git, Wget, Tar, Unzip, and the other tools
listed by the installation checks. Optional integrations add their own
dependencies. `jq` is required for custom Proton and shader repository data.

## Use With Steam

### Proton games

Register TinkerGame as a Steam compatibility tool:

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
tinkergame configdir
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
log under `/dev/shm/tinkergame`. Run the following to verify the local script:

```sh
bash -n tinkergame
shellcheck tinkergame
```

When reporting a problem, include the TinkerGame version, distribution,
desktop or game mode, display server, YAD version, game AppID, and relevant log
sections. Remove personal paths and tokens first.

## Development

TinkerGame is primarily Bash. The main script remains intentionally portable,
but new code should use arrays for external command arguments, quote paths, and
handle optional dependencies explicitly.

Run the local checks with:

```sh
bash -n tinkergame
shellcheck tinkergame
make -n install PREFIX="$HOME/.local"
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for development notes.

## License

TinkerGame is licensed under the GNU General Public License v3.0. See
[LICENSE](LICENSE).
