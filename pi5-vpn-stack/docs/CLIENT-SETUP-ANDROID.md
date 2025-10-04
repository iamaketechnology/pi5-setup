# Tailscale Client Setup Guide - Android

Complete guide for installing and configuring Tailscale on Android devices to access your Raspberry Pi 5 services remotely.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Accessing Pi Services](#accessing-pi-services)
- [Common Use Cases](#common-use-cases)
- [Troubleshooting](#troubleshooting)
- [Security Best Practices](#security-best-practices)

---

## Prerequisites

Before you begin, ensure you have:

- Android device running Android 6.0 (Marshmallow) or later
- Google account with access to Google Play Store
- Tailscale account (same account used on your Raspberry Pi 5)
- Your Pi 5 running and connected to Tailscale network
- Active internet connection (WiFi or mobile data)

---

## Installation

### Step 1: Download Tailscale from Google Play Store

1. Open the **Google Play Store** app on your Android device
2. Tap the search bar at the top
3. Type **"Tailscale"** and search
4. Look for the official app by **Tailscale Inc.**
5. Tap **Install**

**Download Link**: [Tailscale on Google Play](https://play.google.com/store/apps/details?id=com.tailscale.ipn)

**App Details**:
- App name: Tailscale
- Publisher: Tailscale Inc.
- Size: ~25 MB
- Permissions: Network access, VPN configuration

### Step 2: Launch the App

1. Once installation completes, tap **Open**
2. You'll see the Tailscale welcome screen
3. The app icon shows a white "T" on a dark background

---

## Configuration

### Step 3: Sign In to Tailscale

1. On the welcome screen, tap **Get Started** or **Sign In**
2. Choose your authentication provider:
   - **Google** (recommended for personal use)
   - **Microsoft**
   - **GitHub**
   - **Email** (with magic link)
   - **Okta** or other SSO providers

3. **IMPORTANT**: Use the **same account** you used to set up Tailscale on your Raspberry Pi 5

4. Follow the authentication flow for your chosen provider
5. Grant necessary permissions when prompted

### Step 4: Grant VPN Permission

1. After authentication, Android will prompt: **"Tailscale wants to set up a VPN connection"**
2. Tap **OK** to allow
3. A VPN key icon will appear in your status bar

**What this means**: Tailscale creates a secure VPN connection to route traffic to your private network. This is normal and safe.

### Step 5: Connect to Your Tailnet

1. After granting VPN permission, you'll see the main Tailscale screen
2. Toggle the switch at the top to **ON** (green)
3. Wait 3-5 seconds for connection to establish
4. You should see:
   - Your Android device listed with an IP (100.x.x.x)
   - Your Raspberry Pi 5 in the list of devices
   - Connection status: **Connected**

**Screenshot description**: Main screen shows a toggle switch (ON/green), your device name with Tailscale IP (e.g., "pixel-7 100.101.102.103"), and a list of network devices including your Pi 5.

---

## Accessing Pi Services

Once connected to your Tailnet, you can access all services running on your Raspberry Pi 5.

### Method 1: Access via Tailscale IP

1. Open **Chrome**, **Firefox**, or your preferred browser
2. Navigate to your Pi's Tailscale IP address (found in the Tailscale app)
3. Add the service port number

**Examples**:
```
http://100.x.x.x:8000    # Supabase Studio
http://100.x.x.x:3000    # Grafana
http://100.x.x.x:3001    # Homepage Dashboard
```

### Method 2: Access via MagicDNS (Recommended)

If MagicDNS is enabled on your Tailnet:

```
http://raspberry-pi-5:8000    # Supabase Studio
http://raspberry-pi-5:3000    # Grafana
http://raspberry-pi-5:3001    # Homepage
```

**Note**: Replace `raspberry-pi-5` with your actual Pi hostname.

### Supabase Studio Access

1. Open browser and navigate to: `http://100.x.x.x:8000`
2. You'll see the Supabase Studio interface
3. View your database, tables, and data
4. Execute SQL queries directly

**Screenshot description**: Supabase Studio loads with dark theme, showing table editor, SQL editor, and authentication sections.

### Grafana Access

1. Navigate to: `http://100.x.x.x:3000`
2. Login with your Grafana credentials
3. View your Pi 5 monitoring dashboards
4. Check CPU, memory, disk, and container metrics

### Homepage Dashboard Access

1. Navigate to: `http://100.x.x.x:3001`
2. See all your Pi services in one place
3. Quick links to Supabase, Grafana, Portainer, etc.
4. System status overview

---

## Common Use Cases

### Use Case 1: Monitor Your Pi While Away

**Scenario**: You're at work or traveling and want to check if your Pi services are healthy.

1. Enable mobile data or connect to WiFi
2. Open Tailscale app and ensure it's connected
3. Open browser and go to Grafana: `http://100.x.x.x:3000`
4. View real-time metrics and alerts

### Use Case 2: Access Database Remotely

**Scenario**: Update your database or run queries from anywhere.

1. Connect to Tailscale
2. Open Supabase Studio: `http://100.x.x.x:8000`
3. Navigate to SQL Editor
4. Execute your queries
5. View results and export data if needed

### Use Case 3: SSH to Raspberry Pi

**Scenario**: You need terminal access to your Pi.

1. Install **Termux** from Google Play Store
2. Open Termux and install openssh:
   ```bash
   pkg update
   pkg install openssh
   ```
3. Connect to Tailscale
4. SSH to your Pi:
   ```bash
   ssh pi@100.x.x.x
   # or
   ssh pi@raspberry-pi-5
   ```
5. Enter your Pi password

### Use Case 4: File Transfer with Your Pi

**Scenario**: Transfer files between Android and Pi.

1. Install **Solid Explorer** or **FX File Explorer** from Play Store
2. Add a network location (SFTP/SSH)
3. Use your Pi's Tailscale IP:
   - Protocol: SFTP
   - Host: `100.x.x.x`
   - Port: `22`
   - Username: `pi`
   - Password: your Pi password
4. Browse and transfer files

---

## Troubleshooting

### Issue 1: Connection Failed

**Symptoms**: Toggle switch won't stay on, or shows "Connection failed"

**Solutions**:
1. Check internet connection (try opening a website)
2. Force stop and restart Tailscale app:
   - Settings > Apps > Tailscale > Force Stop
   - Reopen Tailscale
3. Revoke and re-grant VPN permission:
   - Settings > Apps > Tailscale > Permissions
   - Disable and re-enable VPN permission
4. Check if VPN is blocked:
   - Some corporate WiFi networks block VPNs
   - Try switching to mobile data
5. Clear app cache:
   - Settings > Apps > Tailscale > Storage > Clear Cache

### Issue 2: Can't See Raspberry Pi in Device List

**Symptoms**: Connected to Tailscale but Pi doesn't appear

**Solutions**:
1. Verify Pi is online and running Tailscale:
   - SSH to Pi (if you have another device)
   - Run: `sudo tailscale status`
2. Check you're using the same Tailscale account:
   - Tap your profile in Tailscale app
   - Verify email/account matches Pi setup
3. Pull to refresh the device list in app
4. Restart Tailscale on both devices
5. Check Tailscale admin console: https://login.tailscale.com/admin/machines

### Issue 3: Can't Access Services (Connection Refused)

**Symptoms**: Can ping Pi but services won't load in browser

**Solutions**:
1. Verify service is running on Pi:
   - SSH to Pi: `ssh pi@100.x.x.x`
   - Check containers: `docker ps`
2. Verify correct port number:
   - Supabase Studio: 8000
   - Grafana: 3000
   - Homepage: 3001
3. Check firewall on Pi isn't blocking Tailscale subnet
4. Try HTTP not HTTPS: `http://` not `https://`
5. Verify service is bound to correct interface:
   - Should listen on `0.0.0.0` or Tailscale IP

### Issue 4: VPN Keeps Disconnecting

**Symptoms**: Connection drops frequently

**Solutions**:
1. Disable battery optimization for Tailscale:
   - Settings > Apps > Tailscale > Battery
   - Select "Unrestricted" or "Don't optimize"
2. Enable "Always-on VPN":
   - Settings > Network & Internet > VPN
   - Tap gear icon next to Tailscale
   - Enable "Always-on VPN"
3. Check for app updates in Play Store
4. Verify stable internet connection

### Issue 5: Slow Performance

**Symptoms**: Services load slowly or timeout

**Solutions**:
1. Check your internet speed (both mobile and Pi's connection)
2. Try direct connection instead of relay:
   - In Tailscale app, check if connection shows "Direct" or "Relay"
   - Relay connections are slower
3. Verify Pi isn't overloaded:
   - Check Grafana for CPU/memory usage
4. Close bandwidth-heavy apps on Android
5. Switch between WiFi and mobile data to test

### Issue 6: App Crashes or Freezes

**Symptoms**: Tailscale app won't open or crashes

**Solutions**:
1. Update to latest version from Play Store
2. Clear app data (WARNING: will need to re-login):
   - Settings > Apps > Tailscale > Storage > Clear Data
3. Uninstall and reinstall Tailscale
4. Check Android version compatibility
5. Report bug to Tailscale support with logs

---

## Security Best Practices

### 1. Don't Share Your Tailscale Account

- Each person should have their own Tailscale account
- Share devices within a tailnet, not account credentials
- Use Tailscale's sharing features for multi-user access

### 2. Enable Two-Factor Authentication (2FA)

1. Visit: https://login.tailscale.com/admin/settings/account
2. Click **Enable two-factor authentication**
3. Use an authenticator app:
   - Google Authenticator
   - Authy
   - Microsoft Authenticator
4. Save backup codes in a secure location

### 3. Use Key Expiry

- Tailscale keys can be set to expire
- Regularly re-authenticate devices
- Check admin console for expired devices: https://login.tailscale.com/admin/machines
- Remove unused devices

### 4. Enable ACLs (Access Control Lists)

For advanced users:
- Define who can access what services
- Restrict access by user and device
- Configure in admin console: https://login.tailscale.com/admin/acls

### 5. Review Connected Devices Regularly

1. Open Tailscale app on Android
2. Review list of connected devices
3. Check admin console for unknown devices
4. Remove any unrecognized devices immediately

### 6. Use Strong Passwords for Pi Services

- Don't rely on Tailscale security alone
- Use strong, unique passwords for:
  - SSH access
  - Grafana
  - Supabase
  - Other services
- Consider using a password manager (Bitwarden, 1Password)

### 7. Keep Tailscale Updated

- Enable auto-updates in Play Store
- Regularly check for Android OS updates
- Update Tailscale on your Pi as well

### 8. Be Cautious on Public WiFi

- Tailscale encrypts traffic, but:
  - Public WiFi can still be risky for device security
  - Use mobile data for sensitive operations
  - Keep screen locked when not in use

### 9. Disable Tailscale When Not Needed

- To save battery and improve privacy
- Toggle off in app when not accessing Pi
- Or use "Use Tailscale only for these IPs" in app settings

### 10. Monitor Access Logs

- Check Tailscale admin console for unusual activity
- Review access logs on your Pi:
  ```bash
  sudo journalctl -u tailscaled
  ```
- Monitor failed SSH attempts
- Check Grafana for unexpected traffic patterns

---

## Additional Resources

- **Tailscale Official Documentation**: https://tailscale.com/kb/
- **Tailscale Android FAQ**: https://tailscale.com/kb/1134/android/
- **Tailscale Status Page**: https://status.tailscale.com/
- **Community Support**: https://forum.tailscale.com/
- **Raspberry Pi 5 Setup Guide**: Refer to main project documentation

---

## Quick Reference

### Tailscale App Actions

- **Connect/Disconnect**: Toggle switch at top
- **View Devices**: Main screen shows all devices
- **Copy IP**: Tap device > Copy IP
- **Share Node**: Tap device > Share
- **Exit Nodes**: Settings > Use exit node
- **Logout**: Profile icon > Logout

### Service URLs (Replace with Your Pi's IP)

```
Supabase Studio:  http://100.x.x.x:8000
Grafana:          http://100.x.x.x:3000
Homepage:         http://100.x.x.x:3001
Portainer:        http://100.x.x.x:9000
SSH:              ssh pi@100.x.x.x
```

### Useful Commands (via Termux)

```bash
# SSH to Pi
ssh pi@100.x.x.x

# Ping Pi
ping 100.x.x.x

# Check Tailscale status on Pi (after SSH)
sudo tailscale status

# Test port connectivity
nc -zv 100.x.x.x 8000
```

---

**Last Updated**: October 2025

For issues or improvements to this guide, please open an issue in the project repository.
