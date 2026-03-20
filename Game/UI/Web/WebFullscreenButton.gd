extends Control

@export var web_only := true
var _supports_browser_fullscreen := false

func _ready() -> void:
	_supports_browser_fullscreen = _check_fullscreen_support()

	if OS.has_feature("web") and web_only:
		visible = false
		_ensure_dom_fullscreen_button()
	else:
		visible = not web_only or _supports_browser_fullscreen

func _exit_tree() -> void:
	if OS.has_feature("web") and web_only:
		_remove_dom_fullscreen_button()

func _check_fullscreen_support() -> bool:
	if not OS.has_feature("web"):
		return not web_only

	var result = JavaScriptBridge.eval("""
		(() => {
			const doc = document;
			const elem = doc.querySelector('canvas') || doc.documentElement;
			const request = elem.requestFullscreen || elem.webkitRequestFullscreen || elem.msRequestFullscreen;
			const exit = doc.exitFullscreen || doc.webkitExitFullscreen || doc.msExitFullscreen;
			const enabled = doc.fullscreenEnabled ?? doc.webkitFullscreenEnabled ?? true;
			const ua = navigator.userAgent || "";
			const platform = navigator.platform || "";
			const maxTouchPoints = navigator.maxTouchPoints || 0;
			const isIOS = /iPhone|iPad|iPod/i.test(ua);
			const isIPad = /iPad/i.test(ua) || (platform === "MacIntel" && maxTouchPoints > 1);
			if (isIOS && !isIPad) {
				return false;
			}
			return Boolean(request && exit && enabled);
		})()
	""", true)
	return bool(result)

func _ensure_dom_fullscreen_button() -> void:
	if not _supports_browser_fullscreen:
		return

	JavaScriptBridge.eval("""
		(() => {
			if (window.__rossiFullscreenButton) {
				window.__rossiFullscreenButton.ensure();
				return;
			}

			const BUTTON_ID = "rossi-fullscreen-button";

			const isSupported = () => {
				const doc = document;
				const ua = navigator.userAgent || "";
				const platform = navigator.platform || "";
				const maxTouchPoints = navigator.maxTouchPoints || 0;
				const isIOS = /iPhone|iPad|iPod/i.test(ua);
				const isIPad = /iPad/i.test(ua) || (platform === "MacIntel" && maxTouchPoints > 1);
				if (isIOS && !isIPad) {
					return false;
				}
				const elem = doc.querySelector("canvas") || doc.documentElement;
				const request = elem.requestFullscreen || elem.webkitRequestFullscreen || elem.msRequestFullscreen;
				const exit = doc.exitFullscreen || doc.webkitExitFullscreen || doc.msExitFullscreen;
				const enabled = doc.fullscreenEnabled ?? doc.webkitFullscreenEnabled ?? true;
				return Boolean(request && exit && enabled);
			};

			const iconSvg = () => {
				return `
				<svg viewBox="0 0 52 52" aria-hidden="true">
					<g stroke="white" stroke-width="3" fill="none" stroke-linecap="round" stroke-linejoin="round">
						<path d="M22 22 L11 11 M11 11 L19 11 M11 11 L11 19" />
						<path d="M30 22 L41 11 M41 11 L33 11 M41 11 L41 19" />
						<path d="M22 30 L11 41 M11 41 L19 41 M11 41 L11 33" />
						<path d="M30 30 L41 41 M41 41 L33 41 M41 41 L41 33" />
					</g>
				</svg>`;
			};

			const updateVisibility = () => {
				const button = document.getElementById(BUTTON_ID);
				if (!button) {
					return;
				}
				const isFullscreen = Boolean(document.fullscreenElement || document.webkitFullscreenElement || null);
				button.style.display = isFullscreen ? "none" : "flex";
			};

			const ensure = () => {
				let button = document.getElementById(BUTTON_ID);
				if (!isSupported()) {
					if (button) {
						button.remove();
					}
					return;
				}
				if (!button) {
					button = document.createElement("button");
					button.id = BUTTON_ID;
					button.type = "button";
					button.setAttribute("aria-label", "Toggle fullscreen");
					Object.assign(button.style, {
						position: "fixed",
						top: "12px",
						right: "12px",
						width: "52px",
						height: "52px",
						border: "none",
						borderRadius: "8px",
						background: "rgba(0, 0, 0, 0.55)",
						padding: "0",
						display: "flex",
						alignItems: "center",
						justifyContent: "center",
						zIndex: "9999",
						cursor: "pointer",
						WebkitTapHighlightColor: "transparent"
					});
					button.onpointerdown = () => {
						button.style.background = "rgba(51, 51, 51, 0.8)";
					};
					button.onpointerup = () => {
						button.style.background = "rgba(0, 0, 0, 0.55)";
					};
					button.onpointercancel = () => {
						button.style.background = "rgba(0, 0, 0, 0.55)";
					};
					button.onmouseenter = () => {
						button.style.background = "rgba(31, 31, 31, 0.7)";
					};
					button.onmouseleave = () => {
						button.style.background = "rgba(0, 0, 0, 0.55)";
					};
					button.onclick = () => {
						const doc = document;
						const target = doc.querySelector("canvas") || doc.documentElement;
						const fullscreenElement = doc.fullscreenElement || doc.webkitFullscreenElement || null;
						const request = target.requestFullscreen || target.webkitRequestFullscreen || target.msRequestFullscreen;
						if (!fullscreenElement) {
							if (request) {
								request.call(target);
							}
						}
						setTimeout(updateVisibility, 50);
					};
					button.innerHTML = iconSvg();
					document.body.appendChild(button);
				}
				updateVisibility();
			};

			const remove = () => {
				const button = document.getElementById(BUTTON_ID);
				if (button) {
					button.remove();
				}
			};

			document.addEventListener("fullscreenchange", updateVisibility);
			document.addEventListener("webkitfullscreenchange", updateVisibility);

			window.__rossiFullscreenButton = { ensure, remove, updateVisibility };
			ensure();
		})()
	""", true)

func _remove_dom_fullscreen_button() -> void:
	JavaScriptBridge.eval("""
		(() => {
			if (window.__rossiFullscreenButton) {
				window.__rossiFullscreenButton.remove();
			}
		})()
	""", true)
