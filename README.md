# MacThemes

macOS has no themes: dark mode, accent colour, highlight colour, wallpaper and
the Dock are all set separately. MacThemes bundles them into one theme file
and applies the lot in one click — from a SwiftUI app, its menu bar item, or
the `macthemes` command.

Themes use [lucent](https://github.com/paulbeavers/lucent)'s format, so its
themes work unchanged.

## Build and install

```bash
./build.sh             # dist/MacThemes.app and dist/macthemes
./build.sh --install   # /Applications, ~/.local/bin, and seeds ~/.config/macthemes
```

Requires macOS 14+ and Swift 5.9+. The first switch between light and dark
asks for permission to control System Events.

## Config

```
~/.config/macthemes/
  config              settings every theme inherits (see config.example)
  themes/<slug>.theme one file per theme
  .active-theme       written by MacThemes
```

A theme is lucent's 19 colour roles plus `name` and `mode`; every macOS key is
optional and unset keys leave that setting alone:

```ini
name = Catppuccin Mocha
mode = dark                 # light | dark | auto
accent = mauve              # Apple accent name, palette role or hex
highlight = rosewater       # default: the accent, lightened
wallpaper = gradient        # gradient | solid | none | path/to/image
dock_autohide = yes
dock_size = 48
sidebar_icons = medium
kitty = yes                 # writes ~/.config/kitty/macthemes.conf
defaults = com.apple.finder AppleShowAllFiles -bool true

crust = 11111b
...
```

`config.example` documents every key. The app reloads when files in
`~/.config/macthemes` change; ⌘R forces it.

## CLI

```
macthemes list | current | show <theme> | apply <theme>
macthemes wallpaper <theme> out.png [WxH]
```

## Windows, borders and Terminal

macOS can't recolour other apps' windows, so these get the theme onto them:

- **`window_tinting = yes`** lets macOS tint window backgrounds and sidebars
  with the wallpaper, which MacThemes generates from the palette.
- **`borders = yes`** drives [JankyBorders](https://github.com/FelixKratz/JankyBorders)
  for lucent-style window borders (mauve→blue on the focused window).
  Install it with `brew install FelixKratz/formulae/borders`.
- **`terminal_app = yes`** gives each theme a Terminal.app profile, made from
  your current default profile with the theme's colours, and switches open
  tabs to it.

## Limits

- **Accent**: macOS offers only eight accent colours, so a theme's colour is
  snapped to the nearest. The highlight colour takes any RGB and keeps it exact.
- **Fonts**: macOS has no supported way to change the system UI font. `font`
  styles the app's preview; `mono` goes to kitty.
- **Wallpaper**: macOS sets it on each screen's current Space only.
- **Auto mode** may need a log out to take full effect.
