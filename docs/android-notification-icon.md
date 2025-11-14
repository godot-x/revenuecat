# Android Notification Icon Customization

By default, Firebase Cloud Messaging displays a white square as the notification icon. To fix this, you need to add a custom notification icon.

## Requirements

- Icon must be a **white silhouette** on a transparent background
- Use a simple, flat design (no gradients or colors)
- Recommended size: **24x24 dp** (mdpi: 24x24, hdpi: 36x36, xhdpi: 48x48, xxhdpi: 72x72, xxxhdpi: 96x96)

## Steps

### 1. Create your notification icon

- Use a tool like [Android Asset Studio](https://devxz.com/android-asset-studio/icons-notification)
- Or create manually using image editing software
- Export as PNG with transparency

### 2. Add the icon to your Android build template

```
android/build/res/
├── drawable-mdpi/
│   └── ic_notification.png      (24x24)
├── drawable-hdpi/
│   └── ic_notification.png      (36x36)
├── drawable-xhdpi/
│   └── ic_notification.png      (48x48)
├── drawable-xxhdpi/
│   └── ic_notification.png      (72x72)
└── drawable-xxxhdpi/
    └── ic_notification.png      (96x96)
```

### 3. Configure the icon in AndroidManifest.xml

Edit `android/build/AndroidManifest.xml`:

```xml
<application>
    <!-- Add inside <application> tag -->
    <meta-data
        android:name="com.google.firebase.messaging.default_notification_icon"
        android:resource="@drawable/ic_notification" />
    
    <!-- Optional: Set notification color (accent color) -->
    <meta-data
        android:name="com.google.firebase.messaging.default_notification_color"
        android:resource="@color/notification_color" />
</application>
```

### 4. (Optional) Define the notification color

Create or edit `android/build/res/values/colors.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="notification_color">#FF6200EE</color>
</resources>
```

## Tip

If you don't see the `res` folder structure in your Android build template, create it manually following the structure above.

