# Termux Configuration Guide

This guide explains how to configure Termux to accept external commands from NIM Builder.

## Why This Is Required

By default, Termux does not allow any external apps to execute commands. You must explicitly enable this feature by setting `allow-external-apps = true` in the Termux properties file.

## Step-by-Step Setup

### Step 1: Install Termux

**Recommended: F-Droid**
- Go to https://f-droid.org/
- Search for "Termux"
- Download and install the latest version

**Alternative: Play Store (Not Recommended)**
- The Play Store version is outdated and may not support external apps
- Only use if F-Droid is not available

### Step 2: Open Termux

Launch Termux from your app drawer. You should see a terminal prompt:

```
~ $
```

### Step 3: Create the Properties File

Run this command to create the properties file with the required setting:

```bash
echo "allow-external-apps = true" > ~/.termux/termux.properties
```

If you get a permission error, try:

```bash
termux-setup-storage
```

This will prompt for storage permission. After granting, try the echo command again.

### Step 4: Verify the Configuration

Check that the file was created correctly:

```bash
cat ~/.termux/termux.properties
```

You should see:
```
allow-external-apps = true
```

### Step 5: Restart Termux

Close Termux completely and reopen it to ensure the new settings take effect.

## Troubleshooting

### "Permission Denied" Error

If you cannot create the file:

1. Check if ~/.termux directory exists:
   ```bash
   ls -la ~/
   ```

2. Create directory if needed:
   ```bash
   mkdir -p ~/.termux
   ```

3. Try again:
   ```bash
   echo "allow-external-apps = true" > ~/.termux/termux.properties
   ```

### File Won't Save

Try using `vi` editor:

```bash
vi ~/.termux/termux.properties
```

Press `i` to enter insert mode, type:
```
allow-external-apps = true
```

Press `Esc`, then type `:wq` to save and exit.

### Still Not Working

1. Check Termux package is up to date:
   ```bash
   pkg update
   pkg upgrade
   ```

2. Reinstall if needed:
   ```bash
   pkg reinstall termux
   ```

## Testing the Integration

After configuration, test if NIM Builder can communicate with Termux:

1. Open NIM Builder
2. Go to Settings
3. Check that "Termux connected" is shown in the header

If you see "Termux not found", double-check the configuration.

## Technical Details

### The Intent

NIM Builder sends this intent to Termux:

```
Action: com.termux.RUN_COMMAND
Package: com.termux
```

With arguments:
- `command`: The command to execute
- `output_file`: Path to write output (optional)
- `background`: Run in background (optional)

### Output Handling

The app captures command output in two ways:

1. **Temporary file**: Output written to `/data/data/com.nimbuilder.app/cache/nim_builder_output_<timestamp>.txt`
2. **Broadcast**: Results sent via `com.termux.RUN_COMMAND_RESULT` broadcast

### Security Note

Enabling `allow-external-apps` allows ANY app to run commands in Termux. Only enable this for trusted apps like NIM Builder.

## Additional Termux Configuration

### Useful Settings

Edit `~/.termux/termux.properties` to add more settings:

```properties
# Allow external apps
allow-external-apps = true

# Use bell character
bell-character = vibrate

# Initial prompt
extra-keys = [['ESC','/','-','HOME','UP','END','PGDN'],['TAB','CTRL','ALT','DOWN','LEFT','RIGHT']]
```

### Installing Useful Packages

```bash
# Update packages
pkg update
pkg upgrade

# Install useful tools
pkg install git
pkg install python
pkg install nodejs
pkg install vim
```

## Uninstalling

To disable external apps:

```bash
rm ~/.termux/termux.properties
```

Or set to:
```properties
allow-external-apps = false
```