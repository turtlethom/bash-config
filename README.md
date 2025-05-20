# 🐚 Personal Bash Configuration (WSL / Debian 12)

This repository contains a personal Bash configuration setup that works across both **WSL** and **Debian 12** environments.

---

## ⚙️ Setup Instructions

To initialize the configuration:

1. Open the file [`doc/bashrc.txt`](doc/bashrc.txt).
2. Copy its contents into your `~/.bashrc` file:

    ```bash
    cat doc/bashrc.txt >> ~/.bashrc
    ```

3. Reload your shell or source the updated file:

    ```bash
    source ~/.bashrc
    ```

---

## 📁 Repository Structure

| File/Directory       | Description                                  |
|----------------------|----------------------------------------------|
| `aliases.sh`         | Custom command aliases                       |
| `commands.sh`        | Handy Bash functions                         |
| `main.sh`            | Entry point for sourcing all components      |
| `startup.sh`         | Commands to run at shell startup             |
| `util/colors.sh`     | Color codes for prompt and terminal output   |
| `oh_my_bash.sh`      | Optional extensions mimicking oh-my-zsh      |
| `.shortcuts.txt`     | Notes on common or custom shortcuts          |
| `doc/bashrc.txt`     | Snippet to append to your `.bashrc`          |

---

Feel free to fork or clone for your own setup.
