use crate::hyprland::DisplayManager;
use crate::protocol::{
    ConnectionChannel, ControlPacket, DisplayDescriptor, PacketFramer,
    VideoConfiguration, VideoEnvelope, VideoFrameHeader, WirePacketType,
    CURRENT_PROTOCOL_VERSION,
};
use anyhow::{Context, Result};
use bytes::Bytes;
use std::net::SocketAddr;
use std::sync::Arc;
use std::time::Duration;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::{TcpListener, TcpStream};
use tokio::sync::{mpsc, watch, Mutex, RwLock};
use tokio::time::timeout;
use tracing::{debug, error, info, warn};

pub type ControlPacketHandler = Arc<dyn Fn(ControlPacket) + Send + Sync>;

pub struct ServerState {
    pub displays: Vec<DisplayDescriptor>,
    pub selected_display_id: Option<u32>,
    pub control_connected: bool,
    pub video_connected: bool,
}

pub struct Server {
    port: u16,
    state: Arc<RwLock<ServerState>>,
    control_tx: Arc<Mutex<Option<mpsc::Sender<Bytes>>>>,
    video_tx: Arc<Mutex<Option<mpsc::Sender<Bytes>>>>,
    state_watch_tx: watch::Sender<bool>,
    state_watch_rx: watch::Receiver<bool>,
    on_control_packet: Arc<std::sync::RwLock<Option<ControlPacketHandler>>>,
}

impl Server {
    pub fn new(port: u16) -> Self {
        let (state_watch_tx, state_watch_rx) = watch::channel(false);
        Self {
            port,
            state: Arc::new(RwLock::new(ServerState {
                displays: Vec::new(),
                selected_display_id: None,
                control_connected: false,
                video_connected: false,
            })),
            control_tx: Arc::new(Mutex::new(None)),
            video_tx: Arc::new(Mutex::new(None)),
            state_watch_tx,
            state_watch_rx,
            on_control_packet: Arc::new(std::sync::RwLock::new(None)),
        }
    }

    pub fn set_control_packet_handler<F>(&self, handler: F)
    where
        F: Fn(ControlPacket) + Send + Sync + 'static,
    {
        let mut guard = self.on_control_packet.write().unwrap();
        *guard = Some(Arc::new(handler));
    }

    pub fn subscribe_connection_changes(&self) -> watch::Receiver<bool> {
        self.state_watch_rx.clone()
    }

    pub async fn start(self: Arc<Self>) -> Result<()> {
        let addr = SocketAddr::from(([0, 0, 0, 0], self.port));
        let listener = TcpListener::bind(addr)
            .await
            .with_context(|| format!("Failed to bind TCP server on port {}", self.port))?;

        info!("Skeldri TCP server listening on {}", addr);

        // Refresh displays on startup
        if let Ok(displays) = DisplayManager::get_available_displays().await {
            let mut state = self.state.write().await;
            state.selected_display_id = displays.first().map(|d| d.id);
            state.displays = displays;
        }

        loop {
            match listener.accept().await {
                Ok((stream, peer_addr)) => {
                    debug!("Accepted new TCP connection from {}", peer_addr);
                    let server = Arc::clone(&self);
                    tokio::spawn(async move {
                        server.handle_new_connection(stream, peer_addr).await;
                    });
                }
                Err(e) => {
                    error!("Error accepting TCP connection: {}", e);
                }
            }
        }
    }

    async fn handle_new_connection(&self, mut stream: TcpStream, peer_addr: SocketAddr) {
        let mut framer = PacketFramer::for_control();
        let mut buffer = [0u8; 4096];

        // Read the first packet with a 5-second timeout for the Hello handshake
        let hello_packet = match timeout(Duration::from_secs(5), async {
            loop {
                let n = stream.read(&mut buffer).await.ok()?;
                if n == 0 {
                    return None;
                }
                let packets = framer.append(&buffer[..n]).ok()?;
                if let Some(packet) = packets.into_iter().next() {
                    return Some(packet);
                }
            }
        })
        .await
        {
            Ok(Some(packet)) => packet,
            Ok(None) => {
                debug!("Connection closed by {} before hello", peer_addr);
                return;
            }
            Err(_) => {
                warn!("Timed out waiting for hello packet from {}", peer_addr);
                return;
            }
        };

        if hello_packet.packet_type != WirePacketType::Control {
            warn!("First packet from {} was not a control packet", peer_addr);
            return;
        }

        let message: ControlPacket = match serde_json::from_slice(&hello_packet.payload) {
            Ok(msg) => msg,
            Err(e) => {
                warn!("Failed to parse hello packet JSON from {}: {}", peer_addr, e);
                return;
            }
        };

        match message {
            ControlPacket::Hello {
                version,
                channel,
                client,
            } => {
                if version != CURRENT_PROTOCOL_VERSION {
                    warn!(
                        "Incompatible protocol version {} from client '{}' ({})",
                        version, client, peer_addr
                    );
                    let rejection = ControlPacket::IncompatibleVersion {
                        expected: CURRENT_PROTOCOL_VERSION,
                    };
                    if let Ok(data) = serde_json::to_vec(&rejection) {
                        let framed = PacketFramer::frame(WirePacketType::Control, &data);
                        let _ = stream.write_all(&framed).await;
                    }
                    return;
                }

                info!(
                    "Client '{}' from {} connected to {:?} channel",
                    client, peer_addr, channel
                );

                match channel {
                    ConnectionChannel::Control => {
                        self.run_control_channel(stream, peer_addr, framer).await;
                    }
                    ConnectionChannel::Video => {
                        self.run_video_channel(stream, peer_addr).await;
                    }
                }
            }
            _ => {
                warn!(
                    "Unexpected initial packet from {}: {:?}",
                    peer_addr, message
                );
            }
        }
    }

    async fn run_control_channel(
        &self,
        stream: TcpStream,
        peer_addr: SocketAddr,
        mut framer: PacketFramer,
    ) {
        let (tx, mut rx) = mpsc::channel::<Bytes>(64);
        {
            let mut guard = self.control_tx.lock().await;
            *guard = Some(tx);
        }

        {
            let mut state = self.state.write().await;
            state.control_connected = true;
        }
        let _ = self.state_watch_tx.send(true);

        // Send initial display descriptors
        self.publish_displays().await;

        let (mut reader, mut writer) = stream.into_split();

        let writer_task = tokio::spawn(async move {
            while let Some(msg) = rx.recv().await {
                if let Err(e) = writer.write_all(&msg).await {
                    debug!("Control channel write failed: {}", e);
                    break;
                }
            }
        });

        let mut read_buf = [0u8; 8192];
        loop {
            match reader.read(&mut read_buf).await {
                Ok(0) => {
                    info!("Control channel closed by peer {}", peer_addr);
                    break;
                }
                Ok(n) => match framer.append(&read_buf[..n]) {
                    Ok(packets) => {
                        for packet in packets {
                            if packet.packet_type == WirePacketType::Control {
                                if let Ok(ctrl) = serde_json::from_slice::<ControlPacket>(&packet.payload) {
                                    self.handle_control_packet(ctrl).await;
                                }
                            }
                        }
                    }
                    Err(e) => {
                        warn!("Packet framing error on control channel from {}: {}", peer_addr, e);
                        break;
                    }
                },
                Err(e) => {
                    debug!("Control channel read error from {}: {}", peer_addr, e);
                    break;
                }
            }
        }

        writer_task.abort();

        {
            let mut guard = self.control_tx.lock().await;
            *guard = None;
        }
        {
            let mut state = self.state.write().await;
            state.control_connected = false;
        }
        let _ = self.state_watch_tx.send(false);
    }

    async fn run_video_channel(&self, mut stream: TcpStream, peer_addr: SocketAddr) {
        let (tx, mut rx) = mpsc::channel::<Bytes>(2); // Single frame / low queue for low latency
        {
            let mut guard = self.video_tx.lock().await;
            *guard = Some(tx);
        }

        {
            let mut state = self.state.write().await;
            state.video_connected = true;
        }
        let _ = self.state_watch_tx.send(true);

        info!("Video channel active for peer {}", peer_addr);

        while let Some(frame_data) = rx.recv().await {
            if let Err(e) = stream.write_all(&frame_data).await {
                debug!("Video channel write failed to {}: {}", peer_addr, e);
                break;
            }
        }

        info!("Video channel closed for peer {}", peer_addr);

        {
            let mut guard = self.video_tx.lock().await;
            *guard = None;
        }
        {
            let mut state = self.state.write().await;
            state.video_connected = false;
        }
        let _ = self.state_watch_tx.send(false);
    }

    async fn handle_control_packet(&self, packet: ControlPacket) {
        match &packet {
            ControlPacket::Ping { id, sent_at } => {
                self.send_control(ControlPacket::Pong {
                    id: *id,
                    sent_at: *sent_at,
                })
                .await;
            }
            ControlPacket::SelectDisplay { id } => {
                let mut state = self.state.write().await;
                if state.displays.iter().any(|d| d.id == *id) {
                    state.selected_display_id = Some(*id);
                    let desc_opt = state.displays.iter().find(|d| d.id == *id).cloned();
                    drop(state);
                    if let Some(desc) = desc_opt {
                        self.send_control(ControlPacket::Display { display: desc }).await;
                    }
                }
            }
            _ => {}
        }

        let handler = {
            let guard = self.on_control_packet.read().unwrap();
            guard.clone()
        };

        if let Some(handler) = handler {
            handler(packet);
        }
    }

    pub async fn send_control(&self, packet: ControlPacket) {
        if let Ok(json) = serde_json::to_vec(&packet) {
            let framed = PacketFramer::frame(WirePacketType::Control, &json);
            let guard = self.control_tx.lock().await;
            if let Some(tx) = &*guard {
                let _ = tx.send(framed).await;
            }
        }
    }

    pub async fn publish_displays(&self) {
        let (displays, selected) = {
            let state = self.state.read().await;
            (state.displays.clone(), state.selected_display_id)
        };

        self.send_control(ControlPacket::Displays { displays: displays.clone() }).await;

        if let Some(id) = selected {
            if let Some(desc) = displays.into_iter().find(|d| d.id == id) {
                self.send_control(ControlPacket::Display { display: desc }).await;
            }
        }
    }

    pub async fn send_video_configuration(&self, config: &VideoConfiguration) {
        if let Ok(json) = serde_json::to_vec(config) {
            let framed = PacketFramer::frame(WirePacketType::VideoConfiguration, &json);
            let guard = self.video_tx.lock().await;
            if let Some(tx) = &*guard {
                let _ = tx.send(framed).await;
            }
        }
    }

    pub async fn send_video_frame(&self, header: &VideoFrameHeader, access_unit: &[u8]) {
        if let Ok(envelope) = VideoEnvelope::encode(header, access_unit) {
            let framed = PacketFramer::frame(WirePacketType::VideoFrame, &envelope);
            let guard = self.video_tx.lock().await;
            if let Some(tx) = &*guard {
                // Drop previous frame if channel is full to prevent lag buildup
                let _ = tx.try_send(framed);
            }
        }
    }
}
