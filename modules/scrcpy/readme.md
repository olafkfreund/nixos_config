# Connecting to Android Devices with scrcpy

## 1. Enable Developer Options and USB Debugging on Android

1. Open **Settings** on your Android device.
2. Scroll down and tap **About phone**.
3. Find **Build number** and tap it 7 times to enable Developer Options.
4. Go back to **Settings** > **System** > **Developer options**.
5. Enable **USB debugging**.

## 2. Connect via USB Cable

1. Connect your Android device to your computer with a USB cable.
2. On your computer, run:

   ```sh
   adb devices
   ```

   - Accept the prompt on your phone to allow USB debugging if it appears.

3. Start scrcpy:

   ```sh
   scrcpy
   ```

## 3. Connect via Wi-Fi (Wireless)

1. With your device still connected via USB, find your phone's IP address:
   - **Settings** > **About phone** > **Status** > **IP address**
2. In your terminal, run:

   ```sh
   adb tcpip 5555
   ```

3. Disconnect the USB cable.
4. Connect to your device over Wi-Fi (replace `<DEVICE_IP>` with your phone's IP):

   ```sh
   adb connect <DEVICE_IP>:5555
   scrcpy
   ```

## Notes

- If `adb devices` shows "unauthorized", check your phone for a prompt and accept it.
- Both your computer and phone must be on the same Wi-Fi network for wireless connection.
- You can always reconnect via USB and repeat the steps if needed.
