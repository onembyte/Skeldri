use anyhow::{Context, Result};
use mdns_sd::{ServiceDaemon, ServiceInfo};
use std::collections::HashMap;
use std::fs;
use std::path::PathBuf;
use tracing::{info, warn};
use uuid::Uuid;

pub struct DiscoveryService {
    daemon: ServiceDaemon,
    fullname: String,
    service_id: String,
}

impl DiscoveryService {
    pub fn get_or_create_service_id() -> String {
        let config_dir = dirs::config_dir()
            .unwrap_or_else(|| PathBuf::from("."))
            .join("skeldri");
        let id_file = config_dir.join("service_id");

        if let Ok(content) = fs::read_to_string(&id_file) {
            let trimmed = content.trim();
            if !trimmed.is_empty() {
                return trimmed.to_string();
            }
        }

        let new_id = Uuid::new_v4().to_string();
        if let Err(e) = fs::create_dir_all(&config_dir) {
            warn!("Failed to create config directory {:?}: {}", config_dir, e);
        } else if let Err(e) = fs::write(&id_file, &new_id) {
            warn!("Failed to write service_id to {:?}: {}", id_file, e);
        }
        new_id
    }

    pub fn start(service_name: &str, port: u16) -> Result<Self> {
        let daemon = ServiceDaemon::new().context("Failed to create mDNS daemon")?;
        let service_id = Self::get_or_create_service_id();

        let service_type = "_drawpad._tcp.local.";
        let host_name = format!("{}.local.", hostname());

        let mut properties = HashMap::new();
        properties.insert("id".to_string(), service_id.clone());
        properties.insert("protocol".to_string(), crate::protocol::CURRENT_PROTOCOL_VERSION.to_string());

        let my_service = ServiceInfo::new(
            service_type,
            service_name,
            &host_name,
            "",
            port,
            properties,
        )
        .context("Failed to create ServiceInfo for mDNS")?;

        let fullname = my_service.get_fullname().to_string();
        daemon
            .register(my_service)
            .context("Failed to register mDNS service")?;

        info!(
            "mDNS service registered: name='{}', port={}, id='{}'",
            service_name, port, service_id
        );

        Ok(Self {
            daemon,
            fullname,
            service_id,
        })
    }

    pub fn service_id(&self) -> &str {
        &self.service_id
    }
}

impl Drop for DiscoveryService {
    fn drop(&mut self) {
        if let Err(e) = self.daemon.unregister(&self.fullname) {
            warn!("Failed to unregister mDNS service {}: {}", self.fullname, e);
        }
    }
}

fn hostname() -> String {
    std::env::var("HOSTNAME")
        .or_else(|_| std::env::var("HOST"))
        .unwrap_or_else(|_| "omarchy".to_string())
}
