# 🐚 Personal Bash Configuration (WSL / Debian 12)

This repository contains a personal Bash configuration setup that works across both **WSL** and **Debian 12** environments.

---

## ⚙️ Setup Instructions

1. **Clone the repository into your home directory as `bashconfig`:**

    ```bash
    git clone <repo-url> ~/bashconfig
    ```

2. **Run the installer.** It adds one block to `~/.bashrc` (backing it up first), then checks every dependency and asks `y/N` before installing anything missing. Re-run it any time as a health check:

    ```bash
    bash ~/bashconfig/install.sh
    ```

3. **Optional — machine-specific settings** (extra PATH entries, tools only this machine has):

    ```bash
    cp ~/bashconfig/local.sh.example ~/bashconfig/local.sh
    ```

4. **Reload your shell or source the updated file:**

    ```bash
    source ~/.bashrc
    ```

---

## 📁 Repository Structure

| File/Directory               | Description                                                       |
|------------------------------|-------------------------------------------------------------------|
| `install.sh`                 | Hooks `main.sh` into `~/.bashrc`; checks/installs dependencies    |
| `main.sh`                    | Entry point; loads everything below in a fixed order              |
| `env.sh`                     | PATH and exports — loaded for every shell, prints nothing         |
| `local.sh.example`           | Template for `local.sh` (gitignored, per-machine settings)        |
| `interactive/oh_my_bash.sh`  | Oh My Bash configuration and prompt (prints install hint if absent) |
| `interactive/tools.sh`       | Wrappers/completions for optional tools (fcd)                     |
| `interactive/tmux.sh`        | Auto-attach new terminals to the tmux session `main`              |
| `claude/statusline.sh`       | Claude Code status line in the powerline prompt's style (run by `~/.claude/settings.json`, not sourced) |
| `interactive/aliases.sh`     | Custom aliases — loaded last so nothing overrides them            |
| `functions/*.sh`             | One shell function (plus its completion) per file                 |

Everything under `interactive/` and `functions/` loads only in interactive shells, so `ssh host cmd`, `scp`, and `rsync` stay unaffected.

---

Feel free to fork or clone for your own shell setup. Contributions and ideas welcome!
