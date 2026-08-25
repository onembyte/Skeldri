use crate::drawing::SharedDrawingState;
use crate::hyprland::DisplayManager;
use crate::overlay::OverlayController;
use crate::protocol::{ControlPacket, DisplayDescriptor};
use crate::server::Server;
use crate::video::VideoCapturePipeline;
use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use std::sync::Arc;
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::net::{UnixListener, UnixStream};
use tracing::{debug, error, info};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "camelCase")]
pub enum IpcRequest {
    Status,
    Clear,
    Toggle,
    SelectDisplay { id: u32 },
    Stop,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DaemonStatus {
    pub running: bool,
    pub port: u16,
    pub control_connected: bool,
    pub video_connected: bool,
    pub client_name: Option<String>,
    pub displays: Vec<DisplayDescriptor>,
    pub selected_display_id: Option<u32>,
    pub overlay_visible: bool,
    pub stroke_count: usize,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "status", rename_all = "camelCase")]
pub enum IpcResponse {
    Ok {
        #[serde(skip_serializing_if = "Option::is_none")]
        data: Option<serde_json::Value>,
    },
    Error {
        message: String,
    },
}

pub fn get_socket_path() -> PathBuf {
    if let Ok(runtime_dir) = std::env::var("XDG_RUNTIME_DIR") {
        PathBuf::from(runtime_dir).join("skeldri.sock")
    } else {
        let uid = unsafe { libc::getuid() };
        PathBuf::from(format!("/tmp/skeldri_{}.sock", uid))
    }
}

pub struct IpcServer {
    socket_path: PathBuf,
    server: Arc<Server>,
    drawing_state: SharedDrawingState,
    overlay_ctrl: Arc<OverlayController>,
    video_pipeline: Arc<VideoCapturePipeline>,
    port: u16,
}

impl IpcServer {
    pub fn new(
        server: Arc<Server>,
        drawing_state: SharedDrawingState,
        overlay_ctrl: Arc<OverlayController>,
        video_pipeline: Arc<VideoCapturePipeline>,
        port: u16,
    ) -> Self {
        let socket_path = get_socket_path();
        Self {
            socket_path,
            server,
            drawing_state,
            overlay_ctrl,
            video_pipeline,
            port,
        }
    }

    pub async fn run(self) -> Result<()> {
        let _ = std::fs::remove_file(&self.socket_path);

        let listener = UnixListener::bind(&self.socket_path)
            .with_context(|| format!("Failed to bind IPC socket at {:?}", self.socket_path))?;

        debug!("IPC socket listening at {:?}", self.socket_path);

        loop {
            match listener.accept().await {
                Ok((stream, _)) => {
                    let server = Arc::clone(&self.server);
                    let drawing_state = Arc::clone(&self.drawing_state);
                    let overlay_ctrl = Arc::clone(&self.overlay_ctrl);
                    let video_pipeline = Arc::clone(&self.video_pipeline);
                    let port = self.port;

                    tokio::spawn(async move {
                        if let Err(e) = Self::handle_client(
                            stream,
                            server,
                            drawing_state,
                            overlay_ctrl,
                            video_pipeline,
                            port,
                        )
                        .await
                        {
                            debug!("IPC client handler ended: {}", e);
                        }
                    });
                }
                Err(e) => {
                    error!("IPC socket accept error: {}", e);
                }
            }
        }
    }

    async fn handle_client(
        stream: UnixStream,
        server: Arc<Server>,
        drawing_state: SharedDrawingState,
        overlay_ctrl: Arc<OverlayController>,
        video_pipeline: Arc<VideoCapturePipeline>,
        port: u16,
    ) -> Result<()> {
        let (reader, mut writer) = stream.into_split();
        let mut lines = BufReader::new(reader).lines();

        while let Some(line) = lines.next_line().await? {
            let request: IpcRequest = match serde_json::from_str(&line) {
                Ok(req) => req,
                Err(e) => {
                    let resp = IpcResponse::Error {
                        message: format!("Invalid JSON request: {}", e),
                    };
                    let mut data = serde_json::to_vec(&resp)?;
                    data.push(b'\n');
                    writer.write_all(&data).await?;
                    continue;
                }
            };

            let response = match request {
                IpcRequest::Status => {
                    let strokes_count = {
                        let state = drawing_state.read().await;
                        state.strokes().len()
                    };
                    let displays = DisplayManager::get_available_displays().await.unwrap_or_default();
                    let selected_id = displays.first().map(|d| d.id);

                    let status = DaemonStatus {
                        running: true,
                        port,
                        control_connected: true,
                        video_connected: true,
                        client_name: Some("iPad Connected".to_string()),
                        displays,
                        selected_display_id: selected_id,
                        overlay_visible: overlay_ctrl.is_visible(),
                        stroke_count: strokes_count,
                    };
                    IpcResponse::Ok {
                        data: Some(serde_json::to_value(status)?),
                    }
                }
                IpcRequest::Clear => {
                    {
                        let mut state = drawing_state.write().await;
                        state.clear();
                    }
                    overlay_ctrl.request_redraw();
                    server.send_control(ControlPacket::Clear {}).await;
                    info!("IPC triggered Canvas Clear");
                    IpcResponse::Ok { data: None }
                }
                IpcRequest::Toggle => {
                    let current = overlay_ctrl.is_visible();
                    overlay_ctrl.set_visible(!current);
                    info!("IPC toggled Overlay Visibility to {}", !current);
                    IpcResponse::Ok {
                        data: Some(serde_json::json!({ "visible": !current })),
                    }
                }
                IpcRequest::SelectDisplay { id } => {
                    if let Ok(displays) = DisplayManager::get_available_displays().await {
                        if let Some(desc) = displays.into_iter().find(|d| d.id == id) {
                            info!("IPC requested display switch to '{}' (ID {})", desc.name, id);
                            server.send_control(ControlPacket::Display { display: desc.clone() }).await;
                            let _ = video_pipeline.start(&desc).await;
                            IpcResponse::Ok { data: None }
                        } else {
                            IpcResponse::Error {
                                message: format!("Display ID {} not found", id),
                            }
                        }
                    } else {
                        IpcResponse::Error {
                            message: "Failed to query displays".to_string(),
                        }
                    }
                }
                IpcRequest::Stop => {
                    info!("IPC requested daemon shutdown");
                    std::process::exit(0);
                }
            };

            let mut resp_data = serde_json::to_vec(&response)?;
            resp_data.push(b'\n');
            writer.write_all(&resp_data).await?;
        }

        Ok(())
    }
}

pub struct IpcClient;

impl IpcClient {
    pub async fn send(request: &IpcRequest) -> Result<IpcResponse> {
        let path = get_socket_path();
        let stream = UnixStream::connect(&path)
            .await
            .with_context(|| format!("Could not connect to Skeldri daemon socket at {:?}. Is the daemon running?", path))?;

        let (reader, mut writer) = stream.into_split();
        let mut req_data = serde_json::to_vec(request)?;
        req_data.push(b'\n');
        writer.write_all(&req_data).await?;

        let mut lines = BufReader::new(reader).lines();
        if let Some(line) = lines.next_line().await? {
            let response: IpcResponse = serde_json::from_str(&line)?;
            Ok(response)
        } else {
            anyhow::bail!("Daemon closed connection without response");
        }
    }
}
