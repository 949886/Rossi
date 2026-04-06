using Godot;

public static class PlatformUtils
{
    public static bool IsMobileNativePlatform()
    {
        return OS.HasFeature("mobile") || OS.HasFeature("android") || OS.HasFeature("ios");
    }

    public static bool IsWebPlatform()
    {
        return OS.HasFeature("web");
    }

    public static bool IsMobileWebBrowser()
    {
        if (!IsWebPlatform())
            return false;

        var result = JavaScriptBridge.Eval(
            """
            (() => {
                const ua = navigator.userAgent || "";
                const mobileUa = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini|Mobile/i.test(ua);
                const touchPoints = navigator.maxTouchPoints || 0;
                const shortSide = Math.min(window.screen.width || 0, window.screen.height || 0);
                return mobileUa || (touchPoints > 1 && shortSide > 0 && shortSide <= 1024);
            })()
            """,
            true
        );

        return result.VariantType == Variant.Type.Bool && result.AsBool();
    }

    public static bool IsMobilePlatform()
    {
        return IsMobileNativePlatform() || IsMobileWebBrowser();
    }

    public static bool IsDesktopNativePlatform()
    {
        return OS.HasFeature("windows") || OS.HasFeature("macos") || OS.HasFeature("linuxbsd");
    }

    public static bool IsDesktopWebBrowser()
    {
        return IsWebPlatform() && !IsMobileWebBrowser();
    }

    public static bool IsDesktopPlatform()
    {
        return IsDesktopNativePlatform() || IsDesktopWebBrowser();
    }
}
