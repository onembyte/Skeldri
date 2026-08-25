use crate::protocol::DisplayDescriptor;
use anyhow::{Context, Result};
use serde::Deserialize;
use tokio::process::Command;
use tracing::{debug, warn};

#[derive(Debug, Deserialize)]
#[allow(dead_code)]
struct HyprlandMonitor {
    id: u32,
    name: String,
    width: i32,
    height: i32,
    #[serde(default)]
    focused: bool,
}

pub struct DisplayManager;

impl DisplayManager {
    pub async fn get_available_displays() -> Result<Vec<DisplayDescriptor>> {
        match Command::new("hyprctl")
            .arg("monitors")
            .arg("-j")
            .output()
            .await
        {
            Ok(output) if output.status.success() => {
                let stdout = String::from_utf8_lossy(&output.stdout);
                let monitors: Vec<HyprlandMonitor> = serde_json::from_str(&stdout)
                    .context("Failed to parse hyprctl monitors JSON")?;

                let descriptors = monitors
                    .into_iter()
                    .map(|m| DisplayDescriptor {
                        id: m.id,
                        name: m.name,
                        width: m.width,
                        height: m.height,
                    })
                    .collect();

                debug!("Discovered displays via hyprctl: {:?}", descriptors);
                Ok(descriptors)
            }
            Ok(output) => {
                warn!(
                    "hyprctl monitors exited with status {}: {}",
                    output.status,
                    String::from_utf8_lossy(&output.stderr)
                );
                Ok(Self::fallback_displays())
            }
            Err(e) => {
                warn!("Failed to execute hyprctl: {}. Using fallback display.", e);
                Ok(Self::fallback_displays())
            }
        }
    }

    fn fallback_displays() -> Vec<DisplayDescriptor> {
        vec![DisplayDescriptor {
            id: 0,
            name: "Primary Display".to_string(),
            width: 1920,
            height: 1080,
        }]
    }
}
