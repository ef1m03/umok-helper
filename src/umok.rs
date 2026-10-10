// UMOK Helper: built-in branding, server and safe defaults for the UMOK online school build.
// Everything here is applied at startup from `load_custom_client()`, so no `custom.txt`
// and no user input are needed. Only the PUBLIC key of the server lives in this file.

use hbb_common::config;

/// Internal name: config directory, Windows service, install folder, exe name.
/// Must match [a-zA-Z0-9-]+ (see `validate_install_app_name`).
pub const APP_NAME: &str = "UMOK-Helper";
/// Human readable name shown in window titles and UI texts.
pub const DISPLAY_NAME: &str = "УМОК Помощник";

pub const RENDEZVOUS_SERVER: &str = "livekit.umokschool.ru";
pub const RELAY_SERVER: &str = "livekit.umokschool.ru";
pub const RS_PUB_KEY: &str = "aicTxDI3WmULCS0j4+bpt1ixak2s0t1pPPJxbGXxm5Y=";

pub const LINK_URL_PREFIX: &str = "https://lk.umokschool.ru/helper/link?id=";
pub const SOURCE_URL: &str = "https://github.com/ef1m03/umok-helper";

/// Forced server-side options (cannot be changed in the UI).
const OVERRIDE_SETTINGS: &[(&str, &str)] = &[
    ("custom-rendezvous-server", RENDEZVOUS_SERVER),
    ("relay-server", RELAY_SERVER),
    ("key", RS_PUB_KEY),
    ("api-server", ""),
    // Incoming sessions: only after the child clicks "Accept", no passwords at all.
    ("approve-mode", "click"),
    ("verification-method", "use-temporary-password"),
    // Dangerous or privacy-sensitive permissions are off.
    ("enable-remote-restart", "N"),
    ("enable-tunnel", "N"),
    ("enable-terminal", "N"),
    ("enable-camera", "N"),
    ("enable-remote-printer", "N"),
    ("enable-block-input", "N"),
    ("enable-privacy-mode", "N"),
    ("enable-lan-discovery", "N"),
    ("direct-server", "N"),
    ("allow-remote-config-modification", "N"),
    ("allow-auto-update", "N"),
    // File transfer stays allowed: handy for the teacher.
    ("enable-file-transfer", "Y"),
];

/// Forced local (per-user UI) options.
const OVERRIDE_LOCAL_SETTINGS: &[(&str, &str)] = &[
    // Never offer the stock RustDesk update.
    ("enable-check-update", "N"),
];

/// Local defaults the user may still change.
const DEFAULT_LOCAL_SETTINGS: &[(&str, &str)] = &[("lang", "ru")];

const BUILTIN_SETTINGS: &[(&str, &str)] = &[
    // There is no API server: do not try to register the device or log in.
    ("register-device", "N"),
    ("hide-server-settings", "Y"),
    ("disable-change-id", "Y"),
];

const HARD_SETTINGS: &[(&str, &str)] = &[("disable-account", "Y"), ("disable-ab", "Y")];

/// Kept intact in the binary (no immediate-store inlining) so a release can be checked with
/// `strings`/`grep` for the built-in server and key.
#[used]
static UMOK_BUILD_INFO: [&str; 4] = [APP_NAME, DISPLAY_NAME, RENDEZVOUS_SERVER, RS_PUB_KEY];

fn put(map: &std::sync::RwLock<std::collections::HashMap<String, String>>, kv: &[(&str, &str)]) {
    let mut map = map.write().unwrap();
    for (k, v) in kv {
        map.insert((*k).to_owned(), (*v).to_owned());
    }
}

pub fn apply() {
    *config::APP_NAME.write().unwrap() = APP_NAME.to_owned();
    *config::PROD_RENDEZVOUS_SERVER.write().unwrap() = RENDEZVOUS_SERVER.to_owned();
    put(&config::OVERWRITE_SETTINGS, OVERRIDE_SETTINGS);
    put(&config::OVERWRITE_LOCAL_SETTINGS, OVERRIDE_LOCAL_SETTINGS);
    put(&config::DEFAULT_LOCAL_SETTINGS, DEFAULT_LOCAL_SETTINGS);
    put(&config::BUILTIN_SETTINGS, BUILTIN_SETTINGS);
    put(&config::HARD_SETTINGS, HARD_SETTINGS);
}

#[cfg(test)]
mod tests {
    #[test]
    fn umok_defaults_applied() {
        super::apply();
        assert_eq!(crate::get_app_name(), super::APP_NAME);
        assert_eq!(
            hbb_common::config::Config::get_option("custom-rendezvous-server"),
            super::RENDEZVOUS_SERVER
        );
        assert_eq!(hbb_common::config::Config::get_option("key"), super::RS_PUB_KEY);
        assert_eq!(hbb_common::config::Config::get_option("approve-mode"), "click");
    }
}
