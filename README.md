![SysMint](https://github.com/AhmadMWaddah/SysMaint/blob/master/SysMaint.png)

# SysMaint

Automated system maintenance for Ubuntu — one command, all updates, one log.

## What It Does

Runs all maintenance tasks in sequence:

1. **apt update** — refresh package lists
2. **apt upgrade** — install available updates
3. **apt autoremove** — remove unused packages
4. **apt autoclean** — clear repository cache
5. **Kernel cleanup** — remove old kernels, keep newest 2
6. **npm update** — update Node.js package manager
7. **pipx update** — update Python tool installer
8. **rkhunter refresh** — re-baseline after updates

## Why

I used to forget one step, then wonder why something broke. Now it's one command, one run, one log. Consistency beats memory.

## Requirements

- Ubuntu (tested on 22.04+)
- `sudo` access
- Internet connection (for updates)

**Auto-installed if missing:**
- `byobu` (provides `purge-old-kernels`)

## Usage

```bash
# Clone
git clone https://github.com/AhmadMWaddah/SysMaint.git
cd SysMaint

# Make executable
chmod +x SysMaint.sh

# Run
./SysMaint.sh
```

## Help

```bash
./SysMaint.sh help
```

## Project Structure

```
SysMaint/
├── SysMaint.sh          # Main entry point
├── lib/
│   ├── colors.sh        # Terminal colors
│   ├── runner.sh        # Module loader
│   ├── state.sh         # State tracking
│   ├── ui.sh            # Print functions
│   └── utils.sh         # Utility functions
└── modules/
    ├── apt.sh           # System update/upgrade
    ├── kernel.sh        # Old kernel cleanup
    ├── npm.sh           # npm self-update
    └── pipx.sh          # pipx self-update
```

## License

MIT
