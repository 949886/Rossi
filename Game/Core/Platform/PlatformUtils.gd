class_name PlatformUtils extends Object

static func is_mobile_native_platform() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")

static func is_web_platform() -> bool:
	return OS.has_feature("web")

static func is_mobile_web_browser() -> bool:
	if not is_web_platform():
		return false

	var result = JavaScriptBridge.eval("""
		(() => {
			const ua = navigator.userAgent || "";
			const mobileUa = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini|Mobile/i.test(ua);
			const touchPoints = navigator.maxTouchPoints || 0;
			const shortSide = Math.min(window.screen.width || 0, window.screen.height || 0);
			return mobileUa || (touchPoints > 1 && shortSide > 0 && shortSide <= 1024);
		})()
	""", true)
	return bool(result)

static func is_mobile_platform() -> bool:
	return is_mobile_native_platform() or is_mobile_web_browser()

static func is_desktop_native_platform() -> bool:
	return OS.has_feature("windows") or OS.has_feature("macos") or OS.has_feature("linuxbsd")

static func is_desktop_web_browser() -> bool:
	return is_web_platform() and not is_mobile_web_browser()

static func is_desktop_platform() -> bool:
	return is_desktop_native_platform() or is_desktop_web_browser()
