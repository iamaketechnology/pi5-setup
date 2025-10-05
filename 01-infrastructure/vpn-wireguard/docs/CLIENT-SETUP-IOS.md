# Tailscale Client Setup Guide - iOS/iPadOS

Complete guide for installing and configuring Tailscale on iOS and iPadOS devices to access your Raspberry Pi 5 services remotely.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Accessing Pi Services](#accessing-pi-services)
- [Adding Services to Home Screen (PWA)](#adding-services-to-home-screen-pwa)
- [Common Use Cases](#common-use-cases)
- [Troubleshooting](#troubleshooting)
- [Security Best Practices](#security-best-practices)

---

## Prerequisites

Before you begin, ensure you have:

- iPhone or iPad running iOS 15.0 or later (iPadOS 15.0+ for iPad)
- Apple ID with access to App Store
- Tailscale account (same account used on your Raspberry Pi 5)
- Your Pi 5 running and connected to Tailscale network
- Active internet connection (WiFi or cellular)

---

## Installation

### Step 1: Download Tailscale from App Store

1. Open the **App Store** on your iPhone or iPad
2. Tap the **Search** tab at the bottom
3. Type **"Tailscale"** in the search bar
4. Look for the official app by **Tailscale Inc.**
5. Tap **GET** then **Install**
6. Authenticate with Face ID, Touch ID, or Apple ID password

**Download Link**: [Tailscale on App Store](https://apps.apple.com/us/app/tailscale/id1470499037)

**App Details**:
- App name: Tailscale
- Developer: Tailscale Inc.
- Size: ~35 MB
- Requires: iOS 15.0 or later
- Compatibility: iPhone, iPad, iPod touch

### Step 2: Launch the App

1. Once installation completes, tap **Open** in App Store
2. Or find the Tailscale app icon on your home screen
3. The app icon shows a white "T" on a dark gradient background

---

## Configuration

### Step 3: Sign In to Tailscale

1. On the welcome screen, tap **Get Started** or **Log In**
2. Choose your authentication provider:
   - **Apple** (recommended for iOS users - uses Sign in with Apple)
   - **Google**
   - **Microsoft**
   - **GitHub**
   - **Email** (with magic link)
   - **Okta** or other SSO providers

3. **IMPORTANT**: Use the **same account** you used to set up Tailscale on your Raspberry Pi 5

4. If using Sign in with Apple:
   - Tap **Continue with Apple**
   - Authenticate with Face ID/Touch ID
   - Choose to share or hide your email
   - Tap **Continue**

5. For other providers, follow their authentication flow

### Step 4: Grant VPN Permission

1. After authentication, iOS will show: **"Tailscale" Would Like to Add VPN Configurations**
2. Tap **Allow**
3. Authenticate with Face ID, Touch ID, or passcode
4. A VPN icon will appear in your status bar (top right)

**What this means**: Tailscale creates an on-demand VPN connection to route traffic to your private network. This is secure and necessary for Tailscale to function.

### Step 5: Connect to Your Tailnet

1. After granting VPN permission, you'll see the main Tailscale screen
2. The connection toggle at the top will automatically turn **ON** (green)
3. Wait 2-5 seconds for connection to establish
4. You should see:
   - Your iOS device listed with an IP address (100.x.x.x)
   - Your Raspberry Pi 5 in the "Other devices" section
   - Status: **Connected** or **Active**

**Screenshot description**: Main screen displays a large toggle switch (ON/green) at top, your device name (e.g., "iPhone 15") with Tailscale IP below it, and a list of connected devices including your Pi 5 with its hostname and IP.

### Step 6: Configure On-Demand Activation (Optional)

For seamless connectivity:

1. In Tailscale app, tap the **gear icon** (Settings) in top right
2. Toggle **On-Demand Activation** to ON
3. This automatically connects Tailscale when you try to access a Tailnet device

**Benefit**: You don't need to manually enable VPN - it activates when needed.

---

## Accessing Pi Services

Once connected to your Tailnet, you can access all services running on your Raspberry Pi 5 using Safari or other browsers.

### Method 1: Access via Tailscale IP

1. Open **Safari** (recommended) or your preferred browser
2. Tap the address bar
3. Enter your Pi's Tailscale IP address with service port

**Examples**:
```
http://100.x.x.x:8000    # Supabase Studio
http://100.x.x.x:3000    # Grafana
http://100.x.x.x:3001    # Homepage Dashboard
```

**To find your Pi's IP**:
- Open Tailscale app
- Look for your Raspberry Pi in device list
- Tap the device
- IP is shown (e.g., "100.64.1.5")
- Tap to copy

### Method 2: Access via MagicDNS (Recommended)

If MagicDNS is enabled on your Tailnet:

```
http://raspberry-pi-5:8000    # Supabase Studio
http://raspberry-pi-5:3000    # Grafana
http://raspberry-pi-5:3001    # Homepage
```

**Note**: Replace `raspberry-pi-5` with your actual Pi hostname (visible in Tailscale app).

### Supabase Studio Access

1. Open Safari and navigate to: `http://100.x.x.x:8000`
2. Supabase Studio interface will load
3. View database tables, authentication, storage
4. Execute SQL queries in the SQL Editor
5. Manage your database schema

**Tip**: Supabase Studio works best in Safari on iOS. Chrome may have issues with local addresses.

### Grafana Access

1. Navigate to: `http://100.x.x.x:3000`
2. Enter your Grafana credentials
3. View monitoring dashboards:
   - System metrics (CPU, RAM, disk)
   - Docker container stats
   - Network traffic
   - Custom dashboards

**Tip**: For better viewing on iPhone, rotate to landscape mode. On iPad, Grafana works great in full screen.

### Homepage Dashboard Access

1. Navigate to: `http://100.x.x.x:3001`
2. See all your Pi services in one centralized dashboard
3. Quick access links to:
   - Supabase Studio
   - Grafana
   - Portainer
   - Other configured services
4. System status widgets and information

---

## Adding Services to Home Screen (PWA)

Create home screen shortcuts for quick access to your Pi services.

### Adding Supabase Studio to Home Screen

1. Open Safari and navigate to: `http://100.x.x.x:8000`
2. Wait for Supabase Studio to fully load
3. Tap the **Share** button (square with arrow up)
4. Scroll down and tap **Add to Home Screen**
5. Edit the name to: **Supabase Studio**
6. Tap **Add** in top right
7. Icon appears on your home screen

**Result**: Tap the icon to open Supabase Studio directly, almost like a native app.

### Adding Grafana to Home Screen

1. Navigate to: `http://100.x.x.x:3000`
2. Login to Grafana
3. Tap **Share** button in Safari
4. Tap **Add to Home Screen**
5. Name it: **Pi Grafana** or **Monitoring**
6. Tap **Add**

### Adding Homepage Dashboard

1. Navigate to: `http://100.x.x.x:3001`
2. Tap **Share** > **Add to Home Screen**
3. Name it: **Pi Dashboard** or **Homepage**
4. Tap **Add**

### Creating a Dedicated Folder

For organization:

1. Press and hold any home screen icon
2. Drag a Pi service icon onto another Pi service icon
3. This creates a folder
4. Name the folder: **Pi Services** or **Raspberry Pi**
5. Add all your Pi shortcuts to this folder

**Screenshot description**: Home screen shows a folder labeled "Pi Services" containing icons for Supabase Studio, Grafana, and Homepage. Each icon shows the service's logo or a generic web app icon.

---

## Common Use Cases

### Use Case 1: Monitor Your Pi While Traveling

**Scenario**: You're on vacation and want to verify your Pi is healthy.

1. Ensure Tailscale is connected (check VPN icon in status bar)
2. Open Grafana home screen shortcut
3. View system dashboards
4. Check for any alerts or anomalies
5. If issues detected, SSH via terminal app

### Use Case 2: Database Management on iPad

**Scenario**: Manage your database from iPad while away from desk.

1. Connect to Tailscale
2. Open Supabase Studio bookmark/shortcut
3. Use SQL Editor in split-screen mode:
   - Supabase on left
   - Notes/documentation on right
4. Execute queries, view results
5. Export data if needed using Share button

### Use Case 3: SSH to Raspberry Pi

**Scenario**: You need terminal access to your Pi from iPhone/iPad.

**Option A: Using Termius (Recommended)**

1. Install **Termius** from App Store (free with in-app purchases)
2. Open Termius
3. Tap **+** to add new host:
   - Alias: Raspberry Pi 5
   - Hostname: `100.x.x.x` (your Pi's Tailscale IP)
   - Port: `22`
   - Username: `pi`
   - Password: your Pi password
4. Tap **Save**
5. Tap the host to connect

**Option A: Using Blink Shell**

1. Install **Blink Shell** from App Store (paid, $20)
2. Open Blink
3. Type: `ssh pi@100.x.x.x`
4. Enter password when prompted
5. Full terminal access with mouse/trackpad support on iPad

**Option C: Using LibTerm (Free)**

1. Install **LibTerm** from App Store
2. Open LibTerm
3. Type: `ssh pi@100.x.x.x`
4. Accept host key
5. Enter password

### Use Case 4: File Transfer with Pi

**Scenario**: Access files on your Pi from iOS.

**Using FE File Explorer**

1. Install **FE File Explorer** from App Store (freemium)
2. Tap **+** to add connection
3. Select **SFTP/SSH**
4. Configure:
   - Name: Raspberry Pi
   - Host: `100.x.x.x`
   - Port: `22`
   - Username: `pi`
   - Password: your Pi password
5. Tap **Save** then connect
6. Browse files, upload/download with iOS Files integration

**Using Secure ShellFish**

1. Install **Secure ShellFish** from App Store
2. Add SFTP connection with Pi details
3. Browse and manage files
4. Integrates with iOS Files app
5. Edit text files directly in app

### Use Case 5: Quick Health Check via Shortcuts

**Scenario**: Create an iOS Shortcut for instant Pi status.

1. Open **Shortcuts** app (built-in iOS app)
2. Tap **+** to create new shortcut
3. Add actions:
   - **Get Contents of URL**: `http://100.x.x.x:3001`
   - **Show Result**: Display the response
4. Name it: "Check Pi Status"
5. Add to home screen or widgets

**Advanced**: Use Shortcuts with Grafana API to fetch specific metrics.

---

## Troubleshooting

### Issue 1: VPN Won't Connect

**Symptoms**: Toggle switch turns off immediately, or shows "Connection failed"

**Solutions**:
1. Check internet connection:
   - Open Safari and load any website
   - Try both WiFi and cellular data
2. Restart Tailscale app:
   - Swipe up from bottom (or double-click home)
   - Swipe up on Tailscale to close
   - Reopen from home screen
3. Re-authorize VPN permission:
   - Settings > General > VPN & Device Management
   - Find Tailscale
   - Tap and review configuration
4. Restart iPhone/iPad:
   - Hold power button + volume button
   - Slide to power off
   - Wait 30 seconds, power on
5. Check if VPN is restricted:
   - If using corporate/school WiFi, VPNs may be blocked
   - Switch to cellular data to test

### Issue 2: Can't See Raspberry Pi in Device List

**Symptoms**: Connected to Tailscale but Pi doesn't appear

**Solutions**:
1. Verify same Tailscale account:
   - In Tailscale app, tap your profile icon
   - Confirm email/account matches Pi setup
2. Pull to refresh device list:
   - In Tailscale app, pull down on device list
3. Check Pi is online:
   - SSH from another device (if available)
   - Run: `sudo tailscale status`
4. Check admin console on computer:
   - Visit: https://login.tailscale.com/admin/machines
   - Verify both iOS device and Pi are listed
   - Check last seen time
5. Restart Tailscale on Pi:
   ```bash
   sudo systemctl restart tailscaled
   ```

### Issue 3: Safari Won't Load Services

**Symptoms**: Can see Pi in Tailscale but services won't load in browser

**Solutions**:
1. Verify using HTTP not HTTPS:
   - Use `http://100.x.x.x:8000`
   - NOT `https://100.x.x.x:8000`
2. Clear Safari cache:
   - Settings > Safari > Clear History and Website Data
   - Tap "Clear History and Data"
3. Disable content blockers:
   - Settings > Safari > Extensions
   - Disable ad blockers temporarily
4. Try private browsing mode:
   - Safari > Tabs > Private
   - Enter service URL
5. Verify service is running on Pi:
   - SSH to Pi
   - Run: `docker ps` to check containers
6. Check correct port numbers:
   - Supabase: 8000
   - Grafana: 3000
   - Homepage: 3001

### Issue 4: "Cannot Connect to Server" Error

**Symptoms**: Specific error message when accessing services

**Solutions**:
1. Ping Pi to verify connectivity:
   - Use Network Ping app from App Store
   - Ping: `100.x.x.x`
   - If ping fails, issue is network layer
2. Verify firewall settings on Pi:
   - SSH to Pi
   - Check UFW: `sudo ufw status`
   - Ensure Tailscale subnet allowed
3. Test from different network:
   - Switch between WiFi and cellular
   - Rules out network-specific blocking
4. Check service logs on Pi:
   ```bash
   docker logs supabase-studio
   docker logs grafana
   ```
5. Verify service binding:
   - Services should listen on `0.0.0.0` or Tailscale IP
   - Not just `localhost` or `127.0.0.1`

### Issue 5: Frequent Disconnections

**Symptoms**: VPN keeps turning off or reconnecting

**Solutions**:
1. Disable Low Power Mode:
   - Settings > Battery
   - Turn off "Low Power Mode"
   - Low Power Mode can disconnect VPN
2. Enable Always-On VPN:
   - This feature may not be available for Tailscale
   - Check Settings > General > VPN & Device Management
3. Check for iOS updates:
   - Settings > General > Software Update
   - Install any available updates
4. Reinstall Tailscale:
   - Delete app (hold icon > Remove App)
   - Reinstall from App Store
   - Sign in again
5. Check cellular data settings:
   - Settings > Cellular
   - Scroll to Tailscale
   - Ensure it's allowed to use cellular

### Issue 6: Slow Performance / Timeouts

**Symptoms**: Services load very slowly or timeout

**Solutions**:
1. Check connection type:
   - In Tailscale app, tap your Pi device
   - Look for "Direct" or "Relay" connection
   - Relay is slower - may indicate NAT/firewall issues
2. Force direct connection:
   - Ensure UPnP enabled on router
   - Or configure port forwarding for Tailscale
3. Test network speed:
   - Use Speedtest app
   - Slow network = slow Tailscale
4. Check Pi performance:
   - View Grafana for CPU/RAM usage
   - Pi might be overloaded
5. Reduce concurrent requests:
   - Close other tabs/apps accessing Pi
6. Switch networks:
   - Try different WiFi or cellular

### Issue 7: Home Screen Shortcuts Don't Work

**Symptoms**: Tapping home screen icon doesn't load service

**Solutions**:
1. Ensure Tailscale is connected:
   - Check VPN icon in status bar
   - Open Tailscale app to verify
2. Enable On-Demand Activation:
   - Tailscale app > Settings
   - Turn on "On-Demand Activation"
3. Recreate the shortcut:
   - Delete current home screen icon
   - Navigate to service in Safari
   - Add to home screen again
4. Check URL hasn't changed:
   - Pi IP might have changed
   - Verify current IP in Tailscale app
   - Update bookmark if needed

### Issue 8: Can't Login to Services After iOS Update

**Symptoms**: Cookies/sessions lost after updating iOS

**Solutions**:
1. Re-login to each service:
   - Grafana: enter credentials again
   - Supabase: may need to re-authenticate
2. Check "Prevent Cross-Site Tracking":
   - Settings > Safari > Privacy
   - Try toggling "Prevent Cross-Site Tracking"
3. Allow cookies for Tailscale IPs:
   - Settings > Safari > Advanced > Website Data
   - Ensure data for your service URLs is allowed
4. Clear and rebuild shortcuts:
   - Remove old home screen shortcuts
   - Clear Safari data
   - Re-add shortcuts with fresh login

---

## Security Best Practices

### 1. Don't Share Your Tailscale Account

- Each person should have their own Tailscale account
- Share specific devices using Tailscale's sharing features
- Never share Apple ID or Tailscale credentials

### 2. Enable Two-Factor Authentication (2FA)

**On Tailscale Account**:
1. Visit: https://login.tailscale.com/admin/settings/account
2. Click **Enable two-factor authentication**
3. Use iOS Passwords (built-in) or authenticator app:
   - Settings > Passwords > Set up Verification Code
   - Or use Authy, Google Authenticator
4. Save backup codes in secure location:
   - Store in iCloud Keychain
   - Or use password manager like 1Password

**On Apple ID** (if using Sign in with Apple):
1. Settings > [Your Name] > Password & Security
2. Turn on "Two-Factor Authentication"
3. Add trusted phone number
4. Complete setup

### 3. Use Face ID / Touch ID Lock for Tailscale

1. Check if Tailscale has app lock:
   - Currently Tailscale doesn't have built-in app lock
2. Use Screen Time to restrict:
   - Settings > Screen Time
   - App Limits (workaround, not perfect)
3. Keep device locked when not in use:
   - Settings > Face ID & Passcode
   - Set auto-lock to 30 seconds or 1 minute

### 4. Review Connected Devices Regularly

1. In Tailscale app:
   - View all connected devices
   - Look for unknown devices
2. In admin console (on computer):
   - Visit: https://login.tailscale.com/admin/machines
   - Review all devices
   - Disable or remove unrecognized devices
3. Check "Last seen" times:
   - Old devices may be compromised
   - Remove inactive devices

### 5. Use Strong Passwords for All Services

- Don't rely on Tailscale security alone
- Use unique, strong passwords for:
  - SSH access to Pi
  - Grafana login
  - Supabase authentication
  - Other services
- Use iOS Keychain or password manager:
  - iCloud Keychain (built-in)
  - 1Password
  - Bitwarden

### 6. Enable iCloud Keychain for Password Sync

1. Settings > [Your Name] > iCloud
2. Turn on **Passwords and Keychain**
3. Passwords sync across iPhone, iPad, Mac
4. Automatic password generation and fill

### 7. Keep Everything Updated

**iOS/iPadOS**:
- Settings > General > Software Update
- Enable "Automatic Updates"

**Tailscale App**:
- App Store > Profile > Update All
- Or enable automatic app updates:
  - Settings > App Store > App Updates (toggle ON)

**Raspberry Pi Tailscale**:
- Regularly update Pi software
- Check for Tailscale updates

### 8. Use Private Browsing for Sensitive Operations

When accessing sensitive data:
1. Safari > Tabs icon > Private
2. Enter service URL
3. Complete sensitive task
4. Close private tabs when done
5. Data doesn't persist

### 9. Be Cautious on Public WiFi

- Tailscale encrypts traffic, but:
  - Public WiFi can expose device to threats
  - Other devices on network could be malicious
- Best practices:
  - Use cellular data for sensitive operations
  - Never share Tailscale credentials on public WiFi
  - Keep device locked when not actively using

### 10. Enable Find My iPhone

Protection if device is lost:
1. Settings > [Your Name] > Find My
2. Turn on "Find My iPhone"
3. Enable "Send Last Location"
4. If lost:
   - Use another device to locate
   - Enable "Lost Mode"
   - Erase remotely if necessary

### 11. Set Up Emergency Access

In case you lose access:
1. Document recovery steps:
   - Tailscale account email
   - 2FA backup codes (stored securely)
   - Pi access from alternate device
2. Use iCloud Keychain recovery:
   - Stores passwords securely
   - Accessible from any Apple device
3. Keep backup SSH keys:
   - Store on secure computer
   - For Pi access if iOS device fails

### 12. Disable Tailscale When Not Needed

For battery and privacy:
1. Turn off VPN when not accessing Pi:
   - Swipe to open Tailscale
   - Toggle OFF
2. Or configure Exit Nodes:
   - Settings > Use Exit Node
   - Route only specific traffic through Tailscale

### 13. Monitor Tailscale Activity

**In App**:
- Review device list for unauthorized access
- Check connection logs (if available)

**On Pi**:
- View Tailscale logs:
  ```bash
  sudo journalctl -u tailscaled -f
  ```
- Check for unauthorized SSH attempts:
  ```bash
  sudo grep "Failed password" /var/log/auth.log
  ```

**In Admin Console**:
- Visit: https://login.tailscale.com/admin/machines
- Review activity logs
- Check for unusual patterns

---

## iOS-Specific Tips & Tricks

### Using Siri Shortcuts for Quick Access

Create a Siri command to check Pi status:
1. Shortcuts app > + > Add Action
2. Search "Get Contents of URL"
3. Enter: `http://100.x.x.x:3001`
4. Add "Show Result"
5. Name: "Check Pi"
6. Settings > Siri & Search > Add to Siri
7. Record phrase: "Check my Pi"

Now say: "Hey Siri, check my Pi"

### Using iPad Split View

Perfect for monitoring and working:
1. Open Grafana in Safari
2. Swipe up from bottom for dock
3. Drag another app to side
4. Monitor Pi while working

### Using Picture-in-Picture (PiP)

For video dashboards or monitoring:
1. If service supports video
2. Tap full screen
3. Swipe up to home
4. Video continues in small window

### Widget for Quick Status

While Tailscale doesn't have official widgets:
1. Use Shortcuts widget
2. Add your "Check Pi" shortcut
3. Tap widget to run

### Handoff Between Devices

If you have Mac or iPad:
1. Ensure Handoff enabled:
   - Settings > General > AirPlay & Handoff
2. Open service in Safari on iPhone
3. On Mac/iPad, see Safari icon in dock
4. Click to continue on other device

---

## Additional Resources

- **Tailscale Official iOS Documentation**: https://tailscale.com/kb/1020/install-ios/
- **Tailscale Admin Console**: https://login.tailscale.com/admin/
- **iOS VPN Configuration Guide**: https://support.apple.com/en-us/HT201459
- **Tailscale Community Forum**: https://forum.tailscale.com/
- **Raspberry Pi 5 Setup Guide**: Refer to main project documentation

---

## Quick Reference Card

### Essential URLs (Replace 100.x.x.x with Your Pi IP)

```
Supabase Studio:      http://100.x.x.x:8000
Grafana:              http://100.x.x.x:3000
Homepage Dashboard:   http://100.x.x.x:3001
Portainer:            http://100.x.x.x:9000

SSH (use terminal app):
ssh pi@100.x.x.x
```

### Tailscale App Quick Actions

- **Connect/Disconnect**: Toggle at top of app
- **View All Devices**: Main screen
- **Copy Device IP**: Tap device > long press IP > Copy
- **Share Device**: Tap device > Share icon
- **App Settings**: Gear icon (top right)
- **Account Settings**: Profile icon (top left)

### Recommended Apps for iOS

| Purpose | App | Price | App Store Link |
|---------|-----|-------|----------------|
| SSH Client | Termius | Free (IAP) | termius.com |
| SSH Client | Blink Shell | $19.99 | blink.sh |
| File Transfer | FE File Explorer | Free (IAP) | Available on App Store |
| File Transfer | Secure ShellFish | Free (IAP) | secureshellfish.app |
| Network Tools | Network Ping Lite | Free | Available on App Store |
| Terminal | LibTerm | Free | Available on App Store |

### Troubleshooting Checklist

- [ ] Tailscale VPN is connected (check status bar)
- [ ] Using correct IP address for Pi
- [ ] Using HTTP (not HTTPS)
- [ ] Service is running on Pi (check via SSH)
- [ ] Safari cache cleared
- [ ] Content blockers disabled
- [ ] Tried both WiFi and cellular
- [ ] Restarted Tailscale app
- [ ] Checked Pi is online in admin console

---

**Last Updated**: October 2025

**Compatible With**:
- iOS 15.0+
- iPadOS 15.0+
- Tailscale iOS app version 1.x

For issues or improvements to this guide, please open an issue in the project repository.
