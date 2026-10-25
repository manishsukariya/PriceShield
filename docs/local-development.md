# Local development

## Backend

Start the backend from `backend`:

```powershell
npm run dev
```

## Flutter on the USB-connected phone

In VS Code, open **Run and Debug**, select **PriceShield: USB phone with local API**, then press **F5**.

The configuration uses this computer's current LAN address:

```text
http://192.168.0.107:3000
```

Keep the phone and computer on the same Wi-Fi network. Update `.vscode/launch.json` when the computer's LAN address changes.

For this debug build only, the Flutter API client also uses the same local URL
if the app is launched without the VS Code configuration. A full restart or
hot restart is required after changing the URL. Release builds still require
an explicitly supplied API URL.
