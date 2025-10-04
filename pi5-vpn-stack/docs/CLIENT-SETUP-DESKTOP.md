# Tailscale Client Setup Guide - Desktop (Windows, macOS, Linux)

Comprehensive guide for installing and configuring Tailscale on desktop platforms to access your Raspberry Pi 5 services remotely.

## Table of Contents

- [Overview](#overview)
- [Windows Setup](#windows-setup)
- [macOS Setup](#macos-setup)
- [Linux Setup](#linux-setup)
- [Accessing Pi Services](#accessing-pi-services)
- [SSH Access to Raspberry Pi](#ssh-access-to-raspberry-pi)
- [Common Use Cases](#common-use-cases)
- [Advanced Configuration](#advanced-configuration)
- [Troubleshooting](#troubleshooting)
- [Security Best Practices](#security-best-practices)

---

## Overview

### What You'll Get

After completing this guide, you'll be able to:
- Access your Raspberry Pi 5 from any desktop computer
- Connect to Supabase Studio, Grafana, Homepage, and other services
- SSH into your Pi without port forwarding
- Transfer files securely between desktop and Pi
- Monitor your Pi remotely
- Use your Pi as an exit node (optional)

### Prerequisites

**All Platforms**:
- Tailscale account (same account used on your Raspberry Pi 5)
- Raspberry Pi 5 running and connected to Tailscale
- Administrator/sudo access on your desktop
- Active internet connection

**Platform-Specific Requirements**:
- **Windows**: Windows 10 or later
- **macOS**: macOS 11 Big Sur or later
- **Linux**: Most distributions with systemd (Ubuntu 20.04+, Debian 11+, Fedora 35+, Arch Linux)

---

## Windows Setup

### Installation Methods

#### Method 1: GUI Installer (Recommended for Most Users)

**Step 1: Download Installer**

1. Visit: https://tailscale.com/download/windows
2. Click **Download Tailscale for Windows**
3. Save the installer: `tailscale-setup-x.xx.x.exe`

**Direct Download**: https://pkgs.tailscale.com/stable/tailscale-setup-latest.exe

**Step 2: Run Installer**

1. Locate downloaded file (usually in `Downloads` folder)
2. Double-click `tailscale-setup-x.xx.x.exe`
3. If Windows Defender SmartScreen appears:
   - Click **More info**
   - Click **Run anyway**
4. User Account Control (UAC) prompt:
   - Click **Yes** to allow installation

**Step 3: Installation Wizard**

1. Welcome screen:
   - Click **Next**
2. License agreement:
   - Read the BSD 3-Clause License
   - Click **I Agree**
3. Installation location:
   - Default: `C:\Program Files\Tailscale`
   - Click **Next** (or **Browse** to change)
4. Start Menu folder:
   - Default: **Tailscale**
   - Click **Install**
5. Wait for installation to complete (30-60 seconds)
6. Click **Finish**

**Step 4: Initial Configuration**

1. Tailscale icon appears in **System Tray** (bottom right, near clock)
   - If not visible, click **^** to show hidden icons
2. Click the Tailscale icon (looks like a network diagram)
3. Click **Log in**
4. Browser opens with Tailscale authentication
5. Choose your authentication provider:
   - **Microsoft** (recommended for Windows users)
   - **Google**
   - **GitHub**
   - **Email** (magic link)
   - Other SSO providers

6. **IMPORTANT**: Use the **same account** as your Raspberry Pi 5

7. After authentication:
   - Browser shows "Success! You can close this window"
   - Return to Windows

**Step 5: Verify Connection**

1. Click Tailscale icon in system tray
2. You should see:
   - Your computer name with Tailscale IP (100.x.x.x)
   - Your Raspberry Pi 5 listed
   - Status: **Connected**

**Screenshot description**: System tray shows Tailscale icon (white network diagram). Menu displays computer name at top with IP "100.101.102.103", separator line, then list of devices including "raspberry-pi-5 (100.64.1.5)" with green dot indicating online status.

#### Method 2: Package Manager (winget)

For users who prefer command-line installation:

1. Open **PowerShell** or **Windows Terminal** (as Administrator)
2. Run:
   ```powershell
   winget install --id Tailscale.Tailscale
   ```
3. Wait for installation to complete
4. Follow authentication steps from Method 1, Step 4

#### Method 3: Chocolatey

If you use Chocolatey package manager:

1. Open **PowerShell** (as Administrator)
2. Run:
   ```powershell
   choco install tailscale
   ```
3. Accept prompts
4. Follow authentication steps from Method 1, Step 4

### Windows-Specific Features

**System Tray Integration**:
- Right-click Tailscale icon for menu:
  - **This Device**: View your Tailscale IP
  - **Other Devices**: Quick access to list
  - **Preferences**: Settings and options
  - **Admin console**: Opens web admin panel
  - **Exit Tailscale**: Disconnect and quit

**Preferences**:
1. Right-click Tailscale icon > **Preferences**
2. Options:
   - **Run Tailscale on startup**: Auto-start with Windows
   - **Allow incoming connections**: Let others access your Windows machine
   - **Use Tailscale DNS**: Enable MagicDNS
   - **Accept routes**: Allow subnet routing

**File Sharing via Taildrop**:
- Right-click files in Explorer
- Send to Tailscale devices (if Taildrop enabled)

### Post-Installation

**Update Windows Firewall** (usually automatic):
- Tailscale automatically configures Windows Defender Firewall
- If blocked, add exception:
  1. Windows Security > Firewall & network protection
  2. Allow an app through firewall
  3. Find Tailscale, ensure all networks checked

---

## macOS Setup

### Installation Methods

#### Method 1: GUI Installer (Recommended)

**Step 1: Download Installer**

1. Visit: https://tailscale.com/download/macos
2. Click **Download Tailscale for macOS**
3. Save the file: `Tailscale-x.xx.x.pkg`

**Direct Download**: https://pkgs.tailscale.com/stable/Tailscale-latest.pkg

**Step 2: Install Package**

1. Locate downloaded file (usually in `Downloads`)
2. Double-click `Tailscale-x.xx.x.pkg`
3. macOS may show "unidentified developer" warning:
   - Right-click package
   - Click **Open**
   - Click **Open** again in dialog
4. Installation wizard opens

**Step 3: Installation Process**

1. **Introduction** screen:
   - Click **Continue**
2. **License** screen:
   - Read BSD 3-Clause License
   - Click **Continue** then **Agree**
3. **Installation Type**:
   - Shows space required (~50 MB)
   - Click **Install**
4. **Authentication**:
   - Enter your macOS password
   - Click **Install Software**
5. Wait for installation (30-60 seconds)
6. **Summary** screen:
   - Click **Close**
7. Optional: Move installer to Trash

**Step 4: Initial Setup**

1. Tailscale icon appears in **Menu Bar** (top right)
   - Icon: White network diagram on dark background
2. Click the Tailscale menu bar icon
3. Click **Log in to Tailscale**
4. Safari (or default browser) opens
5. Choose authentication provider:
   - **Apple** (recommended - Sign in with Apple)
   - **Google**
   - **Microsoft**
   - **GitHub**
   - **Email** (magic link)

6. **IMPORTANT**: Use the **same account** as your Raspberry Pi 5

7. Authenticate:
   - If using Apple: Face ID / Touch ID / password
   - Other providers: follow their flow
8. Browser shows "Success! You can close this window"

**Step 5: Grant Network Extension Permission**

1. macOS System Settings opens automatically
2. Navigate to: **Privacy & Security** > **Network**
3. Find **Tailscale**
4. Toggle to **allow** Tailscale network extension
5. Authenticate with password/Touch ID/Face ID if prompted

**Step 6: Verify Connection**

1. Click Tailscale icon in menu bar
2. You should see:
   - Your Mac name with Tailscale IP
   - Your Raspberry Pi 5 in device list
   - Status indicator (green dot = connected)

**Screenshot description**: Menu bar shows Tailscale icon. Dropdown menu displays MacBook name at top with IP "100.101.102.103", followed by device list including "raspberry-pi-5" with IP "100.64.1.5" and green online indicator.

#### Method 2: Homebrew (Recommended for Developers)

For command-line enthusiasts:

**Step 1: Install via Homebrew**

1. Open **Terminal** (Applications > Utilities > Terminal)
2. Install Homebrew if not already installed:
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```
3. Install Tailscale:
   ```bash
   brew install --cask tailscale
   ```
4. Wait for download and installation

**Step 2: Launch Tailscale**

```bash
open -a Tailscale
```

Or find Tailscale in Applications folder

**Step 3: Follow Authentication**

- Follow Steps 4-6 from Method 1 above

**Updating via Homebrew**:
```bash
brew upgrade --cask tailscale
```

#### Method 3: Mac App Store

**Alternative method**:

1. Open **App Store**
2. Search for **"Tailscale"**
3. Click **Get** then **Install**
4. Authenticate with Apple ID
5. Launch Tailscale from Applications
6. Follow authentication steps

**Note**: App Store version may lag behind direct download version.

### macOS-Specific Features

**Menu Bar Integration**:
- Click icon for quick access:
  - **This Device**: Your Mac's Tailscale info
  - **Other Devices**: Device list with quick copy IP
  - **Preferences**: Advanced settings
  - **Admin console**: Web interface
  - **Quit Tailscale**: Disconnect and exit

**Preferences** (Click Tailscale icon > Preferences):
- **Run Tailscale on login**: Auto-start with macOS
- **Allow incoming connections**: Let others access your Mac
- **Use Tailscale DNS**: Enable MagicDNS
- **Accept routes**: Enable subnet routing
- **Key expiry**: Auto-reauth settings

**Network Settings**:
- System Settings > Network
- Tailscale appears as network interface
- Shows connection status

**Taildrop File Sharing**:
- Drag files to Tailscale devices
- Receive files via Finder integration

### Post-Installation

**Update macOS Firewall** (if enabled):
1. System Settings > Network > Firewall
2. Ensure Tailscale is allowed
3. Usually configured automatically

---

## Linux Setup

Linux installation varies by distribution. Below are instructions for popular distributions.

### Ubuntu / Debian

**Supported Versions**:
- Ubuntu 20.04 LTS, 22.04 LTS, 24.04 LTS
- Debian 11 (Bullseye), 12 (Bookworm)
- Linux Mint 20+, Pop!_OS 20.04+

**Step 1: Add Tailscale Repository**

Open terminal and run:

```bash
# Add Tailscale's GPG key
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null

# Add Tailscale repository
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.tailscale-list | sudo tee /etc/apt/sources.list.d/tailscale.list
```

**Note**: For Debian, replace `ubuntu/jammy` with `debian/bookworm` (or your version).

**Step 2: Install Tailscale**

```bash
# Update package list
sudo apt update

# Install Tailscale
sudo apt install tailscale
```

**Step 3: Start and Enable Service**

```bash
# Start Tailscale service
sudo systemctl start tailscaled

# Enable on boot
sudo systemctl enable tailscaled
```

**Step 4: Authenticate**

```bash
# Login to Tailscale
sudo tailscale up
```

**Output**:
```
To authenticate, visit:

        https://login.tailscale.com/a/xxxxxxxxx
```

1. Copy the URL
2. Open in web browser
3. Choose authentication provider
4. **IMPORTANT**: Use same account as your Raspberry Pi 5
5. Authorize the device
6. Return to terminal

**Step 5: Verify Connection**

```bash
# Check Tailscale status
tailscale status
```

**Expected Output**:
```
100.101.102.103  ubuntu-desktop       user@      linux   -
100.64.1.5       raspberry-pi-5       user@      linux   -
```

Your desktop and Pi should both be listed.

### Fedora / Red Hat / CentOS

**Supported Versions**:
- Fedora 38+
- RHEL 8+, Rocky Linux 8+, AlmaLinux 8+
- CentOS Stream 9

**Step 1: Add Tailscale Repository**

```bash
# Add Tailscale repository
sudo dnf config-manager --add-repo https://pkgs.tailscale.com/stable/fedora/tailscale.repo
```

**Step 2: Install Tailscale**

```bash
# Install Tailscale
sudo dnf install tailscale
```

**Step 3: Start and Enable Service**

```bash
# Start service
sudo systemctl start tailscaled

# Enable on boot
sudo systemctl enable tailscaled
```

**Step 4: Authenticate**

```bash
# Login
sudo tailscale up
```

Follow authentication process (same as Ubuntu above).

**Step 5: Configure Firewall**

```bash
# Allow Tailscale through firewalld
sudo firewall-cmd --permanent --add-service=tailscale
sudo firewall-cmd --reload
```

### Arch Linux / Manjaro

**Step 1: Install from Official Repos**

```bash
# Tailscale is in official Arch repos
sudo pacman -S tailscale
```

**Step 2: Start and Enable Service**

```bash
# Start and enable
sudo systemctl start tailscaled
sudo systemctl enable tailscaled
```

**Step 3: Authenticate**

```bash
# Login
sudo tailscale up
```

Follow browser authentication.

**Step 4: Verify**

```bash
tailscale status
```

### openSUSE

**Step 1: Add Repository**

```bash
# Add Tailscale repo
sudo zypper ar -f https://pkgs.tailscale.com/stable/opensuse/tumbleweed/tailscale.repo
```

**Step 2: Install**

```bash
sudo zypper install tailscale
```

**Step 3: Start Service**

```bash
sudo systemctl start tailscaled
sudo systemctl enable tailscaled
```

**Step 4: Authenticate**

```bash
sudo tailscale up
```

### Linux GUI Clients

While Tailscale works great from CLI, GUI options exist:

#### Trayscale (GTK System Tray)

**For GNOME, KDE, XFCE, etc.**

**Install via AUR (Arch)**:
```bash
yay -S trayscale
```

**Install via Flatpak (All Distros)**:
```bash
flatpak install flathub dev.deedles.Trayscale
```

**Features**:
- System tray icon
- Quick connect/disconnect
- Device list
- Connection status
- Desktop notifications

**Launch**:
```bash
flatpak run dev.deedles.Trayscale
```

#### GNOME Extension

**For GNOME Desktop**:

1. Install GNOME Shell integration
2. Visit: https://extensions.gnome.org/
3. Search "Tailscale"
4. Install "Tailscale Status" extension
5. Adds Tailscale to top bar

### Linux-Specific Features

**Systemd Service**:
```bash
# Check service status
sudo systemctl status tailscaled

# View logs
sudo journalctl -u tailscaled -f

# Restart service
sudo systemctl restart tailscaled
```

**Command-Line Interface**:
```bash
# View help
tailscale --help

# Check status
tailscale status

# Ping devices
tailscale ping raspberry-pi-5

# View IP addresses
tailscale ip -4  # IPv4
tailscale ip -6  # IPv6

# Disconnect
sudo tailscale down

# Reconnect
sudo tailscale up

# Logout completely
sudo tailscale logout
```

**Accept Routes** (for subnet routing):
```bash
sudo tailscale up --accept-routes
```

**Use as Exit Node**:
```bash
# Use Pi as exit node
sudo tailscale up --exit-node=raspberry-pi-5
```

---

## Accessing Pi Services

Once Tailscale is connected on any desktop platform, accessing services is the same.

### Via Web Browser

**Method 1: Using Tailscale IP**

Open your browser (Chrome, Firefox, Safari, Edge) and navigate to:

```
http://100.x.x.x:8000    # Supabase Studio
http://100.x.x.x:3000    # Grafana
http://100.x.x.x:3001    # Homepage Dashboard
http://100.x.x.x:9000    # Portainer
```

**To find your Pi's IP**:
- **Windows/macOS**: Click Tailscale tray/menu icon > find Pi > copy IP
- **Linux**: Run `tailscale status` and note Pi's IP

**Method 2: Using MagicDNS (Recommended)**

If MagicDNS is enabled (default):

```
http://raspberry-pi-5:8000    # Supabase Studio
http://raspberry-pi-5:3000    # Grafana
http://raspberry-pi-5:3001    # Homepage
http://raspberry-pi-5:9000    # Portainer
```

**Enable MagicDNS** (if not already):
1. Visit: https://login.tailscale.com/admin/dns
2. Enable **MagicDNS**
3. Hostnames auto-resolve on all devices

### Service-Specific Access

#### Supabase Studio

1. Navigate to: `http://100.x.x.x:8000` or `http://raspberry-pi-5:8000`
2. Supabase Studio interface loads
3. Features:
   - **Table Editor**: View and edit database tables
   - **SQL Editor**: Run custom queries
   - **Database**: Manage schema, functions, triggers
   - **Authentication**: Manage users and auth
   - **Storage**: File storage management
   - **Logs**: View real-time logs

**Tip**: Bookmark this URL for quick access.

#### Grafana

1. Navigate to: `http://100.x.x.x:3000` or `http://raspberry-pi-5:3000`
2. Login screen appears:
   - **Username**: admin (or your configured username)
   - **Password**: your Grafana password
3. After login, access:
   - **Dashboards**: Pre-built monitoring dashboards
   - **Explore**: Ad-hoc queries
   - **Alerting**: Alert rules and notifications
   - **Configuration**: Data sources, plugins

**Common Dashboards**:
- System metrics (CPU, RAM, disk)
- Docker container stats
- Network traffic
- Custom application metrics

**Tip**: Set homepage to your most-used dashboard.

#### Homepage Dashboard

1. Navigate to: `http://100.x.x.x:3001` or `http://raspberry-pi-5:3001`
2. Centralized dashboard with:
   - Quick links to all services
   - Service status indicators
   - System resource widgets
   - Bookmarks and custom links
3. Click any service to open directly

**Tip**: Set as browser homepage for instant access to all Pi services.

#### Portainer

1. Navigate to: `http://100.x.x.x:9000` or `http://raspberry-pi-5:9000`
2. Docker management interface:
   - Container list and controls (start/stop/restart)
   - Image management
   - Volume and network configuration
   - Logs and console access
   - Resource usage

### Creating Browser Bookmarks

**Chrome/Edge**:
1. Navigate to service URL
2. Press `Ctrl+D` (Windows/Linux) or `Cmd+D` (macOS)
3. Name bookmark (e.g., "Pi Grafana")
4. Save to Bookmarks Bar for quick access

**Firefox**:
1. Navigate to service URL
2. Click star icon in address bar
3. Edit name and location
4. Save

**Safari** (macOS):
1. Navigate to service URL
2. Press `Cmd+D`
3. Name and save

**Organize into Folder**:
- Create folder: "Raspberry Pi Services"
- Store all Pi-related bookmarks there

---

## SSH Access to Raspberry Pi

Tailscale makes SSH access simple and secure without port forwarding.

### Windows SSH Access

**Option 1: Built-in OpenSSH (Windows 10/11)**

1. Open **PowerShell** or **Command Prompt**
2. Run:
   ```cmd
   ssh pi@100.x.x.x
   ```
   Or with MagicDNS:
   ```cmd
   ssh pi@raspberry-pi-5
   ```
3. First connection prompts:
   ```
   The authenticity of host '100.x.x.x' can't be established.
   ED25519 key fingerprint is SHA256:xxxxx.
   Are you sure you want to continue connecting (yes/no/[fingerprint])?
   ```
4. Type `yes` and press Enter
5. Enter your Pi password
6. You're now connected!

**Option 2: PuTTY (GUI SSH Client)**

1. Download PuTTY: https://www.putty.org/
2. Install and launch PuTTY
3. Configuration:
   - **Host Name**: `100.x.x.x` or `raspberry-pi-5`
   - **Port**: `22`
   - **Connection Type**: SSH
4. Click **Open**
5. Accept host key (first time)
6. Login as: `pi`
7. Enter password

**Save Session for Quick Access**:
1. After entering host details
2. In "Saved Sessions" box, type: **Raspberry Pi 5**
3. Click **Save**
4. Next time: select from list, click **Load**, then **Open**

**Option 3: Windows Terminal (Modern)**

1. Install **Windows Terminal** from Microsoft Store (if not already)
2. Open Windows Terminal
3. SSH:
   ```powershell
   ssh pi@raspberry-pi-5
   ```
4. Create profile for quick access:
   - Settings > Add new profile
   - Command line: `ssh pi@raspberry-pi-5`
   - Name: "Raspberry Pi 5"
   - Icon: Choose custom

### macOS SSH Access

**Built-in SSH** (Terminal):

1. Open **Terminal** (Applications > Utilities > Terminal)
2. Run:
   ```bash
   ssh pi@100.x.x.x
   ```
   Or with MagicDNS:
   ```bash
   ssh pi@raspberry-pi-5
   ```
3. Accept host key on first connection (type `yes`)
4. Enter Pi password
5. Connected!

**Create SSH Alias** (for convenience):

1. Edit SSH config:
   ```bash
   nano ~/.ssh/config
   ```
2. Add:
   ```
   Host pi
       HostName raspberry-pi-5
       User pi
   ```
3. Save: `Ctrl+O`, Enter, `Ctrl+X`
4. Now connect with just:
   ```bash
   ssh pi
   ```

**Option: iTerm2** (Advanced Terminal):

1. Download iTerm2: https://iterm2.com/
2. Offers better features than Terminal
3. Create profile for Pi SSH
4. Supports tabs, split panes, search

### Linux SSH Access

**Built-in SSH** (all distributions):

1. Open terminal
2. Run:
   ```bash
   ssh pi@100.x.x.x
   ```
   Or:
   ```bash
   ssh pi@raspberry-pi-5
   ```
3. Accept host key (first time)
4. Enter password

**Create SSH Alias**:

Same as macOS:
```bash
nano ~/.ssh/config
```

Add:
```
Host pi
    HostName raspberry-pi-5
    User pi
```

Connect:
```bash
ssh pi
```

**Advanced: SSH Key Authentication** (More Secure):

1. Generate SSH key (if you don't have one):
   ```bash
   ssh-keygen -t ed25519 -C "your_email@example.com"
   ```
2. Copy key to Pi:
   ```bash
   ssh-copy-id pi@raspberry-pi-5
   ```
3. Enter Pi password one last time
4. Future connections don't require password!

**GUI Option: Remmina**:

For GUI-based SSH on Linux:
```bash
sudo apt install remmina  # Ubuntu/Debian
sudo dnf install remmina  # Fedora
```

1. Launch Remmina
2. New Connection
3. Protocol: SSH
4. Server: `raspberry-pi-5`
5. Username: `pi`
6. Save and connect

---

## Common Use Cases

### Use Case 1: Remote Monitoring While at Work

**Scenario**: Monitor your Pi's health during the day without leaving work computer.

**Steps**:
1. Ensure Tailscale connected (check tray/menu icon)
2. Open browser to Grafana: `http://raspberry-pi-5:3000`
3. View dashboards:
   - System resources (CPU, RAM, disk)
   - Docker container health
   - Network traffic
4. Set up alerts for issues:
   - Grafana Alerting for critical thresholds
   - Email/Slack notifications
5. Keep tab open for periodic checking

**Pro Tip**: Use browser extension like "Auto Refresh Plus" to reload Grafana every 5 minutes.

### Use Case 2: Database Development and Management

**Scenario**: Develop application using Pi-hosted database from your desktop.

**Steps**:
1. Connect to Tailscale
2. Access Supabase Studio: `http://raspberry-pi-5:8000`
3. Development workflow:
   - **SQL Editor**: Test queries
   - **Table Editor**: Modify data
   - **Database** tab: Manage schema
   - **API**: Generate API calls for your app
4. Connect your app to database:
   - Database host: `100.x.x.x` or `raspberry-pi-5`
   - Port: `5432` (PostgreSQL)
   - Use Tailscale IP in connection string

**Connection String Example**:
```
postgresql://user:password@100.x.x.x:5432/database
```

**Security**: Database only accessible via Tailscale - no public exposure!

### Use Case 3: File Transfer Between Desktop and Pi

**Scenario**: Transfer project files, backups, or media between machines.

#### Windows File Transfer

**Method 1: SCP (Command Line)**:
```cmd
# Upload file to Pi
scp C:\Users\YourName\file.txt pi@raspberry-pi-5:/home/pi/

# Download file from Pi
scp pi@raspberry-pi-5:/home/pi/file.txt C:\Users\YourName\

# Upload directory
scp -r C:\Users\YourName\folder pi@raspberry-pi-5:/home/pi/
```

**Method 2: WinSCP (GUI)**:
1. Download WinSCP: https://winscp.net/
2. Install and launch
3. New Session:
   - **File protocol**: SFTP
   - **Host name**: `raspberry-pi-5` or `100.x.x.x`
   - **Port**: 22
   - **User name**: pi
   - **Password**: your Pi password
4. Save and Login
5. Drag-and-drop files between panels

**Method 3: Taildrop** (if enabled):
- Right-click files in Explorer
- Send via Tailscale to Pi
- Files appear in Pi's Taildrop folder

#### macOS/Linux File Transfer

**SCP (Command Line)**:
```bash
# Upload file
scp ~/file.txt pi@raspberry-pi-5:/home/pi/

# Download file
scp pi@raspberry-pi-5:/home/pi/file.txt ~/

# Upload directory
scp -r ~/folder pi@raspberry-pi-5:/home/pi/
```

**Rsync** (More Efficient):
```bash
# Sync directory to Pi
rsync -avz ~/project/ pi@raspberry-pi-5:/home/pi/project/

# Sync from Pi to local
rsync -avz pi@raspberry-pi-5:/home/pi/backup/ ~/backup/
```

**GUI Option (macOS)**: Cyberduck
1. Download: https://cyberduck.io/
2. New Connection > SFTP
3. Server: `raspberry-pi-5`
4. Username: `pi`
5. Connect and transfer

**GUI Option (Linux)**: Nautilus (GNOME Files)
1. Files > Other Locations
2. Connect to Server
3. Enter: `sftp://raspberry-pi-5`
4. Username: pi
5. Connect

### Use Case 4: Container Management with Portainer

**Scenario**: Manage Docker containers on Pi from desktop.

**Steps**:
1. Access Portainer: `http://raspberry-pi-5:9000`
2. Login with credentials
3. Select your Pi environment
4. Container operations:
   - **View logs**: Click container > Logs
   - **Restart container**: Select > Restart
   - **Console access**: Container > Console > Connect
   - **Resource stats**: View CPU/RAM per container
5. Deploy new containers:
   - Containers > Add container
   - Configure and deploy
6. Stack management:
   - Stacks > Add stack
   - Paste docker-compose.yml
   - Deploy

**Use Case**: Restart Grafana container if it becomes unresponsive:
1. Portainer > Containers
2. Find `grafana`
3. Click checkbox
4. Click **Restart**
5. Wait for restart (10-15 seconds)
6. Verify in Grafana dashboard

### Use Case 5: Automated Backups via Tailscale

**Scenario**: Automatically back up Pi data to desktop every night.

**Linux/macOS Backup Script**:

Create `~/backup-pi.sh`:
```bash
#!/bin/bash

# Backup directories
BACKUP_DIRS="/home/pi/important-data /home/pi/configs"
DEST_DIR="$HOME/pi-backups/$(date +%Y-%m-%d)"

# Create destination
mkdir -p "$DEST_DIR"

# Rsync from Pi
rsync -avz --delete pi@raspberry-pi-5:$BACKUP_DIRS "$DEST_DIR/"

# Log
echo "Backup completed: $(date)" >> "$HOME/pi-backups/backup.log"
```

Make executable:
```bash
chmod +x ~/backup-pi.sh
```

**Schedule with Cron** (Linux/macOS):
```bash
crontab -e
```

Add:
```
0 2 * * * /home/yourusername/backup-pi.sh
```

Runs every night at 2 AM.

**Windows Task Scheduler**:
1. Create PowerShell script: `C:\Scripts\backup-pi.ps1`:
   ```powershell
   $date = Get-Date -Format "yyyy-MM-dd"
   $dest = "C:\Backups\Pi\$date"
   New-Item -ItemType Directory -Force -Path $dest
   scp -r pi@raspberry-pi-5:/home/pi/important-data $dest
   ```
2. Task Scheduler > Create Task
3. Trigger: Daily at 2 AM
4. Action: Run PowerShell script

### Use Case 6: Using Pi as Exit Node (VPN)

**Scenario**: Route all internet traffic through your Pi when on public WiFi.

**Enable on Pi** (if not already):
SSH to Pi and run:
```bash
echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf
echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
sudo tailscale up --advertise-exit-node
```

**Approve in Admin Console**:
1. Visit: https://login.tailscale.com/admin/machines
2. Find your Pi
3. Click **...** (three dots)
4. **Edit route settings**
5. Enable **Use as exit node**
6. Save

**Use from Desktop**:

**Windows/macOS**:
1. Click Tailscale tray/menu icon
2. Click **Use exit node**
3. Select **raspberry-pi-5**
4. All traffic now routes through Pi

**Linux**:
```bash
sudo tailscale up --exit-node=raspberry-pi-5
```

**Disable**:
```bash
sudo tailscale up --exit-node=
```

**Use Case**: At coffee shop, route traffic through home Pi for security and privacy.

---

## Advanced Configuration

### MagicDNS Configuration

**Enable MagicDNS** (if not already):
1. Visit: https://login.tailscale.com/admin/dns
2. Toggle **MagicDNS** to ON
3. All devices can now use hostnames instead of IPs
4. Access services: `http://raspberry-pi-5:3000`

**Custom DNS**:
- Add custom DNS servers
- Override specific domains
- Configure split DNS

### Access Control Lists (ACLs)

Control who can access what on your tailnet.

**Basic ACL Example**:
1. Visit: https://login.tailscale.com/admin/acls
2. Edit ACL policy (JSON format):
   ```json
   {
     "acls": [
       {
         "action": "accept",
         "src": ["autogroup:member"],
         "dst": ["raspberry-pi-5:22,8000,3000,3001,9000"]
       }
     ]
   }
   ```
3. This allows all members to access SSH and web services on Pi
4. Save and test

**Advanced**: Restrict by user, device, or service.

### Subnet Routing

Expose entire networks via Tailscale.

**If your Pi routes to other devices**:
1. On Pi, advertise subnet:
   ```bash
   sudo tailscale up --advertise-routes=192.168.1.0/24
   ```
2. Approve in admin console:
   - https://login.tailscale.com/admin/machines
   - Find Pi > Edit route settings
   - Approve subnet routes
3. On desktop, accept routes:
   - **Windows/macOS**: Preferences > Accept routes
   - **Linux**: `sudo tailscale up --accept-routes`
4. Now access entire home network through Tailscale

### SSH Configuration for Tailscale

**Restrict SSH to Tailscale Only** (on Pi):

Edit `/etc/ssh/sshd_config`:
```bash
sudo nano /etc/ssh/sshd_config
```

Add:
```
ListenAddress 100.x.x.x  # Your Pi's Tailscale IP
```

Restart SSH:
```bash
sudo systemctl restart sshd
```

Now SSH only accepts connections via Tailscale - more secure!

### Taildrop File Sharing

**Enable on Pi** (if not already):
```bash
sudo tailscale up --operator=$USER
```

**Send Files to Pi** (from desktop):

**Windows/macOS GUI**:
1. Right-click file
2. Send via Tailscale > raspberry-pi-5
3. File appears on Pi in: `/var/lib/tailscale/files/`

**Linux CLI**:
```bash
tailscale file cp file.txt raspberry-pi-5:
```

**Receive on Pi**:
```bash
tailscale file get .
```

### Key Expiry Management

**Disable Key Expiry** (for always-on devices like Pi):
1. Visit: https://login.tailscale.com/admin/machines
2. Find device
3. Click **...** > **Disable key expiry**
4. Confirm

**Useful for**: Servers that should never need re-authentication.

---

## Troubleshooting

### Windows Troubleshooting

#### Issue 1: Tailscale Won't Install

**Symptoms**: Installer fails or won't start

**Solutions**:
1. Run as Administrator:
   - Right-click installer
   - "Run as administrator"
2. Disable antivirus temporarily
3. Check Windows version (needs Windows 10+)
4. Clear Windows Installer cache:
   - `C:\Windows\Installer`
5. Try winget method instead

#### Issue 2: Can't See System Tray Icon

**Symptoms**: Tailscale installed but icon missing

**Solutions**:
1. Click **^** (Show hidden icons) in system tray
2. Enable always show:
   - Settings > Personalization > Taskbar
   - Select which icons appear on taskbar
   - Toggle Tailscale ON
3. Restart Tailscale:
   - Task Manager > Tailscale > End task
   - Start > Tailscale

#### Issue 3: Connection Failed on Windows

**Symptoms**: Can't connect to Tailscale network

**Solutions**:
1. Check Windows Firewall:
   - Windows Security > Firewall & network protection
   - Allow an app through firewall
   - Ensure Tailscale is checked for all networks
2. Disable VPN or other network software temporarily
3. Run Network Troubleshooter:
   - Settings > Network & Internet > Status
   - Network troubleshooter
4. Reinstall Tailscale:
   - Uninstall via Settings > Apps
   - Restart computer
   - Reinstall fresh

#### Issue 4: Can't Access Services in Browser

**Symptoms**: Tailscale connected but services won't load

**Solutions**:
1. Verify correct URL format:
   - Use `http://` NOT `https://`
   - Example: `http://100.64.1.5:3000`
2. Check Pi is online:
   - Tailscale tray icon > Other devices
   - Pi should show green dot
3. Ping Pi to test connectivity:
   - PowerShell: `ping 100.64.1.5`
   - Should get replies
4. Clear browser cache:
   - Ctrl+Shift+Delete
   - Clear cached images and files
5. Try different browser (Edge vs Chrome)
6. Disable Windows Defender Firewall temporarily to test

### macOS Troubleshooting

#### Issue 1: Installation Blocked by Gatekeeper

**Symptoms**: "Cannot be opened because it is from an unidentified developer"

**Solutions**:
1. Right-click package > Open
2. Click "Open" in dialog
3. Or disable Gatekeeper temporarily:
   ```bash
   sudo spctl --master-disable
   ```
4. After install, re-enable:
   ```bash
   sudo spctl --master-enable
   ```

#### Issue 2: Network Extension Not Allowed

**Symptoms**: Tailscale can't create VPN connection

**Solutions**:
1. System Settings > Privacy & Security > Network
2. Find Tailscale
3. Toggle to allow
4. May need to restart Mac
5. Check for MDM restrictions (corporate Macs):
   - May need IT approval

#### Issue 3: Menu Bar Icon Missing

**Symptoms**: Tailscale running but no menu bar icon

**Solutions**:
1. Check menu bar isn't full:
   - Reduce other menu bar items
   - Or use Bartender app to manage
2. Restart Tailscale:
   - Activity Monitor > Tailscale > Quit
   - Applications > Tailscale
3. Reinstall if persists

#### Issue 4: MagicDNS Not Resolving

**Symptoms**: Can't access `raspberry-pi-5` by hostname

**Solutions**:
1. Verify MagicDNS enabled:
   - https://login.tailscale.com/admin/dns
2. Check DNS settings:
   - System Settings > Network
   - Select connection > Details > DNS
   - Should see Tailscale DNS (100.100.100.100)
3. Flush DNS cache:
   ```bash
   sudo dscacheutil -flushcache
   sudo killall -HUP mDNSResponder
   ```
4. Restart Tailscale
5. Use IP address as fallback

### Linux Troubleshooting

#### Issue 1: Service Won't Start

**Symptoms**: `sudo tailscale up` fails

**Solutions**:
1. Check service status:
   ```bash
   sudo systemctl status tailscaled
   ```
2. View logs:
   ```bash
   sudo journalctl -u tailscaled -n 50
   ```
3. Restart service:
   ```bash
   sudo systemctl restart tailscaled
   ```
4. Check for port conflicts:
   ```bash
   sudo ss -tulpn | grep 41641
   ```
5. Reinstall package

#### Issue 2: Permission Denied

**Symptoms**: `tailscale status` shows "permission denied"

**Solutions**:
1. Use sudo:
   ```bash
   sudo tailscale status
   ```
2. Add user to tailscale group (if exists):
   ```bash
   sudo usermod -aG tailscale $USER
   newgrp tailscale
   ```
3. Or set permissions:
   ```bash
   sudo chmod +x /usr/bin/tailscale
   ```

#### Issue 3: Firewall Blocking

**Symptoms**: Connected but can't access services

**Solutions**:

**UFW (Ubuntu/Debian)**:
```bash
# Allow Tailscale
sudo ufw allow in on tailscale0

# Or specific ports
sudo ufw allow from 100.64.0.0/10 to any
```

**firewalld (Fedora/RHEL)**:
```bash
# Add Tailscale interface
sudo firewall-cmd --permanent --zone=trusted --add-interface=tailscale0
sudo firewall-cmd --reload
```

**iptables**:
```bash
# Allow Tailscale subnet
sudo iptables -A INPUT -s 100.64.0.0/10 -j ACCEPT
```

#### Issue 4: DNS Not Working

**Symptoms**: Can't resolve MagicDNS names

**Solutions**:
1. Check `/etc/resolv.conf`:
   ```bash
   cat /etc/resolv.conf
   ```
   Should include Tailscale DNS
2. If using systemd-resolved:
   ```bash
   sudo systemctl restart systemd-resolved
   ```
3. Manually add DNS:
   ```bash
   sudo tailscale up --accept-dns=true
   ```
4. Check NetworkManager isn't overriding:
   - Edit `/etc/NetworkManager/NetworkManager.conf`
   - Add under `[main]`:
     ```
     dns=none
     ```
   - Restart NetworkManager

### General Troubleshooting (All Platforms)

#### Issue: Can't Access Pi Services

**Diagnostic Steps**:

1. **Verify Tailscale Connected**:
   - Check tray/menu icon
   - Run: `tailscale status`
   - Both desktop and Pi should be listed

2. **Test Network Connectivity**:
   ```bash
   # Ping Pi
   ping 100.x.x.x

   # Test specific port
   telnet 100.x.x.x 3000  # or: nc -zv 100.x.x.x 3000
   ```

3. **Check Service Running on Pi**:
   SSH to Pi:
   ```bash
   ssh pi@raspberry-pi-5
   docker ps  # Verify containers running
   docker logs grafana  # Check logs
   ```

4. **Verify Firewall Settings**:
   On Pi:
   ```bash
   sudo ufw status
   # Should allow Tailscale subnet
   ```

5. **Check Service Binding**:
   On Pi:
   ```bash
   sudo ss -tulpn | grep :3000
   ```
   Should show `0.0.0.0:3000` or Tailscale IP, not just `127.0.0.1:3000`

6. **Browser Troubleshooting**:
   - Use HTTP not HTTPS
   - Disable HTTPS Everywhere extension
   - Try incognito/private mode
   - Clear cache and cookies
   - Try different browser

#### Issue: Relay Connection (Slow Performance)

**Symptoms**: Tailscale shows "Relay" instead of "Direct"

**Solutions**:
1. Enable UPnP on router (both desktop and Pi networks)
2. Configure port forwarding:
   - Forward UDP 41641 to Pi
   - Forward UDP 41641 to desktop (if possible)
3. Check NAT type:
   ```bash
   tailscale netcheck
   ```
4. Use subnet router as workaround
5. Contact ISP about NAT restrictions

#### Issue: Key Expired

**Symptoms**: "Key has expired" message

**Solutions**:
1. Re-authenticate:
   ```bash
   sudo tailscale up
   ```
2. Disable key expiry for device:
   - https://login.tailscale.com/admin/machines
   - Select device > Disable key expiry
3. Set longer expiry globally:
   - Admin console > Settings > Key expiry

---

## Security Best Practices

### 1. Use Strong Authentication

**Enable 2FA on Tailscale Account**:
1. Visit: https://login.tailscale.com/admin/settings/account
2. Click **Enable two-factor authentication**
3. Use authenticator app:
   - Google Authenticator
   - Authy
   - 1Password
   - Bitwarden
4. Save backup codes securely
5. Test 2FA before closing setup

**Use Hardware Keys** (Advanced):
- YubiKey or other FIDO2 keys
- Register in Tailscale account settings
- Provides strongest authentication

### 2. Principle of Least Privilege

**Use ACLs to Restrict Access**:
1. Don't allow all users to access all services
2. Define specific rules:
   ```json
   {
     "acls": [
       {
         "action": "accept",
         "src": ["user@example.com"],
         "dst": ["raspberry-pi-5:22,3000,8000"]
       }
     ]
   }
   ```
3. Regularly review and update ACLs

**Separate User Accounts**:
- Each person should have their own Tailscale account
- Share tailnets, not account credentials
- Use Tailscale's sharing features

### 3. Secure SSH Configuration

**On Pi** (`/etc/ssh/sshd_config`):
```bash
# Disable password authentication (use keys only)
PasswordAuthentication no
PubkeyAuthentication yes

# Disable root login
PermitRootLogin no

# Limit to Tailscale interface
ListenAddress 100.x.x.x

# Use strong ciphers
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com
```

**Use SSH Keys Instead of Passwords**:
```bash
# Generate key
ssh-keygen -t ed25519 -C "your_email@example.com"

# Copy to Pi
ssh-copy-id pi@raspberry-pi-5
```

### 4. Keep Everything Updated

**Regular Updates**:

**Windows**:
- Windows Update (monthly)
- Tailscale auto-updates (or via winget)

**macOS**:
- Software Update (Settings)
- Homebrew updates:
  ```bash
  brew upgrade tailscale
  ```

**Linux**:
```bash
# Ubuntu/Debian
sudo apt update && sudo apt upgrade

# Fedora
sudo dnf upgrade

# Arch
sudo pacman -Syu
```

**Pi Updates**:
```bash
ssh pi@raspberry-pi-5
sudo apt update && sudo apt upgrade
```

### 5. Monitor Access Logs

**Check Tailscale Activity**:
1. Admin console: https://login.tailscale.com/admin/machines
2. Review:
   - Last seen times
   - Connection history
   - Unusual access patterns

**Check Pi Logs**:
```bash
# SSH attempts
sudo grep "Failed password" /var/log/auth.log

# Tailscale logs
sudo journalctl -u tailscaled | grep -i error

# Service access logs (varies by service)
docker logs grafana
docker logs supabase-studio
```

### 6. Use Unique, Strong Passwords

**For All Services**:
- SSH to Pi
- Grafana login
- Supabase admin
- Portainer

**Use Password Manager**:
- 1Password
- Bitwarden (open source)
- KeePassXC (offline)
- LastPass

**Generate Strong Passwords**:
- 16+ characters
- Mix of letters, numbers, symbols
- Unique per service

### 7. Regular Security Audits

**Monthly Checklist**:
- [ ] Review connected devices in Tailscale admin console
- [ ] Remove unused or old devices
- [ ] Check for expired keys
- [ ] Review ACLs for unnecessary permissions
- [ ] Update all software (desktop OS, Tailscale, Pi)
- [ ] Review access logs for suspicious activity
- [ ] Verify backups are running
- [ ] Test disaster recovery procedure

### 8. Secure Your Tailscale Account

**Account Security**:
1. Use strong, unique password for Tailscale account
2. Enable 2FA (mandatory recommendation)
3. Regularly review authorized devices
4. Don't share account credentials
5. Use org/tailnet sharing features instead

**Email Security**:
- Tailscale account tied to email
- Secure your email with 2FA
- Use reputable email provider

### 9. Physical Security

**Desktop Security**:
- Lock screen when away: `Win+L` (Windows), `Ctrl+Cmd+Q` (macOS)
- Enable screen auto-lock (1-5 minutes)
- Use strong login password
- Enable disk encryption:
  - Windows: BitLocker
  - macOS: FileVault
  - Linux: LUKS

**Pi Security**:
- Physical access = full access
- Keep Pi in secure location
- Consider case with lock if in shared space

### 10. Network Segmentation

**Isolate Services**:
- Run services in Docker containers (already doing this)
- Use Docker networks for isolation
- Don't expose unnecessary ports

**Tailscale-Only Access**:
- Don't expose services to public internet
- Use Tailscale as only access method
- Firewall Pi to block non-Tailscale traffic:
  ```bash
  # Example UFW rules
  sudo ufw default deny incoming
  sudo ufw allow in on tailscale0
  sudo ufw enable
  ```

### 11. Backup and Disaster Recovery

**Regular Backups**:
- Automate backups (see Use Case 5)
- Test restoration regularly
- Store backups securely (encrypted)

**Document Everything**:
- Keep secure notes of:
  - Tailscale account email
  - Service passwords (in password manager)
  - Pi configuration
  - Recovery procedures

**Emergency Access Plan**:
- What if desktop lost/stolen?
  - Access from another device
  - Disable compromised device in admin console
- What if Pi fails?
  - Restore from backup
  - Reconfigure Tailscale

### 12. Exit Node Security

**When Using Pi as Exit Node**:
- All traffic routes through Pi
- Pi's IP appears as your IP online
- Ensure Pi has strong security
- Monitor Pi's bandwidth usage
- Consider privacy implications

**When NOT to Use**:
- Streaming services (may violate TOS)
- Banking (unusual location flags)
- Very high bandwidth needs

---

## Advanced Tips & Tricks

### Desktop-Specific Optimizations

**Windows**:
- Pin services to Start Menu/Taskbar
- Use PowerToys for quick launchers
- Create keyboard shortcuts for SSH sessions

**macOS**:
- Add services to Dock
- Use Alfred/Raycast for quick SSH
- Create Automator workflows for common tasks

**Linux**:
- Create desktop entries (`.desktop` files)
- Use custom keybindings
- Integrate with window manager scripts

### Browser Extensions for Convenience

**Tab Manager**:
- Group Pi service tabs
- Quick access to all services

**Password Managers**:
- Auto-fill Grafana, Supabase logins
- Generate strong passwords

**Bookmarklets**:
- Quick-switch between services
- Dashboard shortcuts

### CLI Power User Tips

**Aliases** (Linux/macOS `~/.bashrc` or `~/.zshrc`):
```bash
# SSH
alias sshpi='ssh pi@raspberry-pi-5'

# Quick status
alias tstat='tailscale status'

# Services
alias pgrafana='open http://raspberry-pi-5:3000'  # macOS
alias pgrafana='xdg-open http://raspberry-pi-5:3000'  # Linux
```

**PowerShell Profile** (Windows):
```powershell
# Edit profile
notepad $PROFILE

# Add functions
function sshpi { ssh pi@raspberry-pi-5 }
function tstat { tailscale status }
function pgrafana { Start-Process "http://raspberry-pi-5:3000" }
```

---

## Additional Resources

### Official Documentation
- **Tailscale Docs**: https://tailscale.com/kb/
- **Download Page**: https://tailscale.com/download/
- **Admin Console**: https://login.tailscale.com/admin/
- **Status Page**: https://status.tailscale.com/

### Platform-Specific
- **Windows**: https://tailscale.com/kb/1022/install-windows/
- **macOS**: https://tailscale.com/kb/1016/install-mac/
- **Linux**: https://tailscale.com/kb/1031/install-linux/

### Community
- **Forum**: https://forum.tailscale.com/
- **GitHub**: https://github.com/tailscale
- **Discord**: https://discord.gg/tailscale
- **Reddit**: r/Tailscale

### Learning Resources
- **Tailscale Blog**: https://tailscale.com/blog/
- **Use Cases**: https://tailscale.com/customers/
- **SSH Guide**: https://tailscale.com/kb/1193/tailscale-ssh/

---

## Quick Reference

### Service URLs

Replace `100.x.x.x` with your Pi's Tailscale IP, or use hostname with MagicDNS:

```
Supabase Studio:   http://100.x.x.x:8000  or  http://raspberry-pi-5:8000
Grafana:           http://100.x.x.x:3000  or  http://raspberry-pi-5:3000
Homepage:          http://100.x.x.x:3001  or  http://raspberry-pi-5:3001
Portainer:         http://100.x.x.x:9000  or  http://raspberry-pi-5:9000
```

### Essential Commands

**All Platforms**:
```bash
# Check status
tailscale status

# Ping device
tailscale ping raspberry-pi-5

# View IP
tailscale ip -4

# SSH to Pi
ssh pi@raspberry-pi-5
```

**Linux Only**:
```bash
# Connect
sudo tailscale up

# Disconnect
sudo tailscale down

# Logout
sudo tailscale logout

# Use exit node
sudo tailscale up --exit-node=raspberry-pi-5

# Accept routes
sudo tailscale up --accept-routes

# Service management
sudo systemctl status tailscaled
sudo systemctl restart tailscaled
```

### Tailscale Admin URLs
- **Machines**: https://login.tailscale.com/admin/machines
- **DNS Settings**: https://login.tailscale.com/admin/dns
- **ACLs**: https://login.tailscale.com/admin/acls
- **Account Settings**: https://login.tailscale.com/admin/settings/account

### Troubleshooting Quick Checks
```bash
# Test connectivity to Pi
ping 100.x.x.x

# Test specific port
telnet 100.x.x.x 3000
# or: nc -zv 100.x.x.x 3000

# Check Tailscale service (Linux)
sudo systemctl status tailscaled

# View Tailscale logs (Linux)
sudo journalctl -u tailscaled -f

# Network check
tailscale netcheck
```

---

**Last Updated**: October 2025

**Supported Platforms**:
- Windows 10, 11 (x64, ARM64)
- macOS 11+ (Intel, Apple Silicon)
- Linux: Ubuntu 20.04+, Debian 11+, Fedora 38+, Arch, openSUSE

For issues or improvements to this guide, please open an issue in the project repository.
