# Vanish

Uninstall Mac apps completely — no leftovers.

Dragging an app to the Trash removes the app bundle but leaves its caches,
preferences, containers, and support files scattered around `~/Library`.
Vanish cleans up all of it.

## How it works

1. Drop an app onto the Vanish window (or pick one with **Choose App…**).
2. Vanish reads the app's bundle identifier and scans the standard
   locations in `~/Library` for related files: Application Support, Caches,
   Containers, Group Containers, Preferences, Saved Application State,
   LaunchAgents, Logs, WebKit data, and more.
3. Everything found is listed with its size, pre-selected. Untick anything
   you want to keep.
4. Hit **Vanish** — the app and the selected leftovers move to the Trash.

Nothing is permanently deleted: everything goes to the Trash, so you can
always put it back.

## Building

```sh
./build-app.sh
```

This produces `Vanish.app` in the project root — drag it to `/Applications`.

Requires macOS 14+ and Xcode command line tools.

## Tests

```sh
swift test
```
