# linux-smb-screenshot-uploader

Small script to:

1. Take a screenshot on Linux
2. Mount a Windows SMB share
3. Upload the screenshot
4. Unmount and shut down the machine

## Requirements

- Linux Mint / Debian / Ubuntu
- `cifs-utils` for SMB mounting:
  ```bash
  sudo apt update
  sudo apt install cifs-utils gnome-screenshot