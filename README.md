# fullscreen-niri

Give niri the macOS "fullscreen apps get their own virtual desktop" behaviour.

Press one key on a window and it:

1. creates a new workspace **immediately after** the window's current one,
2. moves the window onto it,
3. puts the window into niri's real fullscreen,
4. remembers the origin workspace so the key can undo all of it.

```
before:  [ ws1: A ][ ws2: X, Y ][ ws3 ]
Mod+F on Y
after:   [ ws1: A ][ ws2: X ][ ws3: Y (fullscreen) ][ ws4 ]
```

Toggling again removes the temporary workspace, moves the window back to where
it was, and turns fullscreen off — exactly the macOS "Space is born, Space is
destroyed" lifecycle.

## Requirements

- niri (tested against the 26.x IPC)
- `python3`
- the script on `$PATH` (or referenced by absolute path)

## Install

With Nix flakes:

```sh
nix profile install github:USER/fullscreen-niri
# or, from a local checkout
nix profile install .
# or run without installing
nix run github:USER/fullscreen-niri
```

NixOS / Home Manager:

```nix
{
  inputs.fullscreen-niri.url = "github:USER/fullscreen-niri";

  # NixOS
  environment.systemPackages = [
    inputs.fullscreen-niri.packages.${pkgs.system}.default
  ];

  # Home Manager
  home.packages = [
    inputs.fullscreen-niri.packages.${pkgs.system}.default
  ];
}
```

The flake exposes `packages.default` / `packages.fullscreen-niri`,
`apps.default`, `overlays.default` and a `devShells.default` with Python and
niri. The packaged binary is wrapped so `niri` and `python3` are on its `PATH`.

Or by hand:

```sh
install -Dm755 fullscreen-niri ~/.local/bin/fullscreen-niri
```

Bind it in `~/.config/niri/config.kdl`. Use `spawn` if the script is on
`$PATH`, or `spawn-sh` for a one-liner:

```kdl
binds {
    Mod+F { spawn "fullscreen-niri"; }
    // or, without installing it:
    Mod+F { spawn-sh "python3 ~/Code/fullscreen-niri/fullscreen-niri"; }
}
```

Remove niri's own `Mod+F { fullscreen-window; }` default if it conflicts.

## Usage

```
fullscreen-niri                 # toggle macOS fullscreen on the focused window
fullscreen-niri enter           # only enter
fullscreen-niri exit            # only leave
fullscreen-niri status          # list windows currently in macOS fullscreen
fullscreen-niri prune           # drop state for closed windows, unpin their origins
                                # (also run automatically before every command)

fullscreen-niri --window-id 42  # act on a specific window id
```

## How it works

niri's workspaces are a dynamic stack per output and it does **not** expose an
"insert a workspace at index N" action. This tool composes existing IPC actions:

1. `set-workspace-name` pins the *empty workspace at the bottom* of the output
   under a unique temporary name. A named workspace survives niri's automatic
   garbage collection of empty workspaces.
2. `move-workspace-to-index` moves that now-pinned workspace to `origin + 1`.
   niri re-inserts it and shifts the following workspaces down — this is the
   actual "insert between" step.
3. `move-window-to-workspace` moves the focused window onto it (focus follows).
4. `fullscreen-window` toggles real fullscreen.
5. `unset-workspace-name` turns the temporary workspace back into a normal one;
   it persists only because it now holds the window.

The origin workspace is preserved the same way. If moving the window out would
leave it empty (it had no other windows), it too gets a temporary name so niri
does not delete the desktop you came from. On exit the name is removed again.

State lives in `$XDG_RUNTIME_DIR/fullscreen-niri/state.json` (or `/tmp`). Windows
that were closed while fullscreen are dropped on the next run, which also removes
the temporary name from their origin workspace.

## Why macOS does this, and Linux usually doesn't

macOS treats native fullscreen as **entering a new Space**, not as a window
state:

- Fullscreen removes the menu bar, Dock and all other windows, so Apple models
  it as a temporary, distraction-free workspace rather than a big window.
- It matches iOS/iPadOS: a fullscreen app behaves like a standalone app you
  swipe between. A new Space is created directly to the **right of the current
  one**, and exiting destroys it and returns the window, unchanged, to its
  origin.
- It gives one consistent rule for multi-monitor setups and trackpad gestures.

Linux desktops and compositors take a different, older view: fullscreen is a
**property of a window** (`_NET_WM_STATE_FULLSCREEN` on X11, a Wayland state),
applied inside the workspace the window already lives on. Workspaces are
user-owned spatial containers with a stable order, so:

- Linux avoids silently creating/moving/reordering workspaces behind the user's
  back — predictable placement is a core value.
- In tiling compositors fullscreen is just a state on a layout node; there is
  no notion of "the app now owns a desktop".
- The Wayland/X11 protocols describe fullscreen as a request to the compositor
  to draw the surface over the output, with no workspace-registry change.

This tool keeps the Linux model as the default but layers the macOS *policy*
on top for the windows you choose, using only public IPC.

## Caveats

- niri's IPC does not expose whether a window is currently fullscreen, so the
  tool tracks that itself. To leave macOS fullscreen, use this same key/command;
  if you toggle fullscreen another way first, the tool may toggle it back on
  before restoring the window.
- If the origin workspace is deleted while the app is fullscreen, the window is
  restored to the nearest remaining workspace at the stored index.
- Workspace insertion is relative to the active output; moving windows across
  monitors is not handled.
- If you already have a custom `set-workspace-name` on the bottom workspace, the
  temporary name will override it for the duration and it is not restored.
