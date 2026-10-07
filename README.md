# Denial plugins

A collection of independently selectable plugins for
[Denial](https://github.com/denialwm/denial), a Flutter-native Wayland compositor.

| Package | Path | Purpose |
| --- | --- | --- |
| `neo_top_bar` | [`plugins/neo_top_bar`](plugins/neo_top_bar) | **Neo Top Bar** — a customizable top bar. Its components can be toggled, moved between the bar's left / centre / right zones, and reordered — by dragging the pills on the bar itself or from a settings card. |

The repository is a **source container**, not a Dart package: each plugin under
`plugins/` is an ordinary Dart package with its own `pubspec.yaml`, and selecting
one does not enable the others. `plugins.yaml` is the discovery catalog and
records Git sources and package paths only — never dependencies, SDK constraints
or contribution metadata, which belong in each package.

## Install

In Denial's Plugins app, choose **Add plugin**, then either paste this
repository's URL (with the package path `plugins/neo_top_bar`) or use
**Local development** and point it at the package directory.

The CLI equivalent:

```sh
denial-plugins --path plugins/neo_top_bar add <THIS_REPOSITORY_URL>
denial-plugins plan
denial-plugins build CANDIDATE_ID
denial-plugins activate CANDIDATE_ID
```

⚠️ `neo_top_bar` reserves the native work area through the **exclusive**
`ShellWorkArea` contract, so disable the built-in Top Bar before applying it.
Denial's plugin manager rejects a composition that supplies two work areas.

## Develop

Each package is developed on its own:

```sh
cd plugins/neo_top_bar
flutter pub get
dart analyze --fatal-infos lib test
```

Pure-Dart tests read the resolved package configuration directly, because these
packages depend on the Flutter SDK and `dart test` would fail at resolution:

```sh
dart --packages=.dart_tool/package_config.json test/config_test.dart
```

`pubspec_overrides.yaml`, `pubspec.lock` and editor settings are git-ignored:
with local SDK overrides active, they contain machine-specific paths. SDK
compatibility belongs in `pubspec.yaml` constraints instead.

## Licences

No repository-wide licence is declared yet. Note that `plugins/neo_top_bar`
bundles the official Arch Linux logo, which is a trademark of the Arch Linux
project — see that package's README for the attribution and the terms it is used
under.
