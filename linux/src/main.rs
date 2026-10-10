use anyhow::{Context, Result};
use clap::{Parser, Subcommand};
use skeldri_linux::{
    new_shared_drawing_state, ControlPacket, DiscoveryService, DisplayManager, IpcClient,
    IpcRequest, IpcResponse, IpcServer, OverlayController, Server, VideoCapturePipeline,
};
use std::sync::Arc;
use tokio::sync::Mutex;
use tracing::{error, info};
use tracing_subscriber::EnvFilter;

#[derive(Parser)]
#[command(name = "skeldri")]
#[command(about = "Skeldri - iPad screen mirroring and annotation overlay for Omarchy/Linux")]
struct Cli {
    #[command(subcommand)]
    command: Option<Commands>,

    /// Run in daemon mode (default when no command provided)
    #[arg(short, long)]
    daemon: bool,

    /// TCP port to listen on
    #[arg(short, long, default_value_t = 52143)]
    port: u16,

    /// Host name to advertise via mDNS
    #[arg(long, default_value = "Omarchy (Linux)")]
    name: String,
}

#[derive(Subcommand)]
enum Commands {
    /// Get daemon status
    Status {
        #[arg(long)]
        json: bool,
    },
    /// Clear all annotations on host and connected iPad
    Clear,
    /// Toggle overlay annotation visibility on host
    Toggle,
    /// Switch active display stream
    SelectDisplay {
        id: u32,
    },
    /// Stop the background daemon
    Stop,
}

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Some(Commands::Status { json }) => {
            handle_status(json).await?;
        }
        Some(Commands::Clear) => {
            handle_clear().await?;
        }
        Some(Commands::Toggle) => {
            handle_toggle().await?;
        }
        Some(Commands::SelectDisplay { id }) => {
            handle_select_display(id).await?;
        }
        Some(Commands::Stop) => {
            handle_stop().await?;
        }
        None => {
            run_daemon(cli.port, cli.name).await?;
        }
    }

    Ok(())
}

async fn handle_status(json: bool) -> Result<()> {
    match IpcClient::send(&IpcRequest::Status).await {
        Ok(IpcResponse::Ok { data: Some(val) }) => {
            if json {
                println!("{}", serde_json::to_string_pretty(&val)?);
            } else {
                let connected = val.get("controlConnected").and_then(|v| v.as_bool()).unwrap_or(false);
                let client = val.get("clientName").and_then(|v| v.as_str()).unwrap_or("None");
                let overlay = val.get("overlayVisible").and_then(|v| v.as_bool()).unwrap_or(true);
                let strokes = val.get("strokeCount").and_then(|v| v.as_u64()).unwrap_or(0);
                let port = val.get("port").and_then(|v| v.as_u64()).unwrap_or(52143);

                println!("Skeldri Daemon: Active");
                println!("Port:           {}", port);
                println!("Status:         {}", if connected { format!("Connected ({})", client) } else { "Waiting for iPad...".to_string() });
                println!("Overlay:        {}", if overlay { "Visible" } else { "Hidden" });
                println!("Active Strokes: {}", strokes);
            }
            Ok(())
        }
        Ok(IpcResponse::Error { message }) => {
            eprintln!("Error from daemon: {}", message);
            std::process::exit(1);
        }
        Ok(_) => Ok(()),
        Err(e) => {
            if json {
                println!("{}", serde_json::json!({ "running": false, "error": e.to_string() }));
            } else {
                eprintln!("Skeldri daemon is not running ({}).", e);
            }
            std::process::exit(1);
        }
    }
}

async fn handle_clear() -> Result<()> {
    match IpcClient::send(&IpcRequest::Clear).await? {
        IpcResponse::Ok { .. } => {
            println!("Annotations cleared.");
            Ok(())
        }
        IpcResponse::Error { message } => {
            eprintln!("Failed to clear: {}", message);
            std::process::exit(1);
        }
    }
}

async fn handle_toggle() -> Result<()> {
    match IpcClient::send(&IpcRequest::Toggle).await? {
        IpcResponse::Ok { data } => {
            let visible = data.and_then(|d| d.get("visible").and_then(|v| v.as_bool())).unwrap_or(true);
            println!("Annotation overlay is now: {}", if visible { "Visible" } else { "Hidden" });
            Ok(())
        }
        IpcResponse::Error { message } => {
            eprintln!("Failed to toggle overlay: {}", message);
            std::process::exit(1);
        }
    }
}

async fn handle_select_display(id: u32) -> Result<()> {
    match IpcClient::send(&IpcRequest::SelectDisplay { id }).await? {
        IpcResponse::Ok { .. } => {
            println!("Switched to display ID {}.", id);
            Ok(())
        }
        IpcResponse::Error { message } => {
            eprintln!("Failed to switch display: {}", message);
            std::process::exit(1);
        }
    }
}

async fn handle_stop() -> Result<()> {
    let _ = IpcClient::send(&IpcRequest::Stop).await;
    println!("Skeldri daemon stopped.");
    Ok(())
}

async fn run_daemon(port: u16, host_name: String) -> Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(
            EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| EnvFilter::new("info,skeldri_linux=debug")),
        )
        .init();

    info!("Starting Skeldri Linux Daemon (Omarchy)...");

    // 1. Shared Drawing State
    let drawing_state = new_shared_drawing_state();

    // 2. Wayland Overlay Worker
    let (overlay_ctrl, overlay_worker) = OverlayController::new(Arc::clone(&drawing_state));
    let overlay_ctrl = Arc::new(overlay_ctrl);

    tokio::spawn(async move {
        if let Err(e) = overlay_worker.run().await {
            error!("Overlay worker error: {}", e);
        }
    });

    // 3. mDNS Bonjour discovery
    let _discovery = DiscoveryService::start(&host_name, port)
        .context("Failed to start mDNS discovery service")?;

    // 4. TCP Server
    let server = Arc::new(Server::new(port));

    // 5. Video Capture Pipeline
    let video_pipeline = Arc::new(VideoCapturePipeline::new(Arc::clone(&server)));

    // 6. Unix Socket IPC Server
    let ipc_server = IpcServer::new(
        Arc::clone(&server),
        Arc::clone(&drawing_state),
        Arc::clone(&overlay_ctrl),
        Arc::clone(&video_pipeline),
        port,
    );

    tokio::spawn(async move {
        if let Err(e) = ipc_server.run().await {
            error!("IPC server error: {}", e);
        }
    });

    let drawing_state_clone = Arc::clone(&drawing_state);
    let overlay_ctrl_clone = Arc::clone(&overlay_ctrl);
    let video_pipeline_clone = Arc::clone(&video_pipeline);
    let active_display_desc = Arc::new(Mutex::new(None));
    let active_display_clone = Arc::clone(&active_display_desc);

    // Initial display selection
    if let Ok(displays) = DisplayManager::get_available_displays().await {
        if let Some(first) = displays.first() {
            let mut guard = active_display_desc.lock().await;
            *guard = Some(first.clone());
        }
    }

    server.set_control_packet_handler(move |packet| {
        let drawing_state = Arc::clone(&drawing_state_clone);
        let overlay_ctrl = Arc::clone(&overlay_ctrl_clone);
        let video_pipeline = Arc::clone(&video_pipeline_clone);
        let active_display = Arc::clone(&active_display_clone);

        tokio::spawn(async move {
            match packet {
                ControlPacket::StrokeBegin { id, style, point } => {
                    let mut state = drawing_state.write().await;
                    state.begin(id, style, point);
                    drop(state);
                    overlay_ctrl.request_redraw();
                }
                ControlPacket::StrokePoints { id, points } => {
                    let mut state = drawing_state.write().await;
                    state.append(id, points);
                    drop(state);
                    overlay_ctrl.request_redraw();
                }
                ControlPacket::StrokeEnd { id } => {
                    let mut state = drawing_state.write().await;
                    state.finish(id);
                    drop(state);
                    overlay_ctrl.request_redraw();
                }
                ControlPacket::DeleteStrokes { ids } => {
                    let mut state = drawing_state.write().await;
                    state.delete(&ids);
                    drop(state);
                    overlay_ctrl.request_redraw();
                }
                ControlPacket::Clear {} => {
                    let mut state = drawing_state.write().await;
                    state.clear();
                    drop(state);
                    overlay_ctrl.request_redraw();
                }
                ControlPacket::CanvasSnapshot { strokes } => {
                    let mut state = drawing_state.write().await;
                    state.replace(strokes);
                    drop(state);
                    overlay_ctrl.request_redraw();
                }
                ControlPacket::SelectDisplay { id } => {
                    if let Ok(displays) = DisplayManager::get_available_displays().await {
                        if let Some(desc) = displays.into_iter().find(|d| d.id == id) {
                            info!("Switching active display to '{}' (ID {})", desc.name, desc.id);
                            let mut guard = active_display.lock().await;
                            *guard = Some(desc.clone());
                            drop(guard);
                            let _ = video_pipeline.start(&desc).await;
                        }
                    }
                }
                _ => {}
            }
        });
    });

    // Watch for client connections to start/stop video streaming
    let mut connection_rx = server.subscribe_connection_changes();
    let video_pipeline_watch = Arc::clone(&video_pipeline);
    let active_display_watch = Arc::clone(&active_display_desc);

    tokio::spawn(async move {
        while connection_rx.changed().await.is_ok() {
            let is_connected = *connection_rx.borrow();
            if is_connected {
                let guard = active_display_watch.lock().await;
                if let Some(desc) = guard.as_ref() {
                    info!("Client connected. Starting video stream...");
                    let _ = video_pipeline_watch.start(desc).await;
                }
            } else {
                info!("Client disconnected. Stopping video stream...");
                video_pipeline_watch.stop().await;
            }
        }
    });

    info!("Skeldri daemon running on port {}. Press Ctrl+C to terminate.", port);
    server.start().await?;

    Ok(())
}
