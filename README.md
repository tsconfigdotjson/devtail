<p align="center">
  <img src="web/public/favicon.svg" width="80" height="80" alt="devtail">
</p>

<h1 align="center">devtail</h1>

<p align="center">
  A macOS menu bar app for launching and monitoring local development processes.<br>
  Free up your terminal for AI agents — your dev servers live in the menu bar now.
</p>

<p align="center">
  <a href="https://tsconfigdotjson.github.io/devtail/devtail.dmg"><strong>Download for macOS &rarr;</strong></a>
</p>

## Features

- **Process management** — Configure processes with a name, command, and working directory
- **Status indicators** — Green/red dots show whether each process is running
- **Live output** — View command output in a terminal-style display
- **Log watchers** — Attach auxiliary tail commands to monitor log files alongside your process
- **Detail view** — Click into a process for full scrollable output with tabbed log switching
- **Pop-out windows** — Open any terminal output in a standalone window to keep it visible while you work

## Requirements

- macOS 14+
- Swift 6.2

## Build & Run

```
swift build
swift run
```

The app appears as a terminal icon in your menu bar.

## License

MIT
