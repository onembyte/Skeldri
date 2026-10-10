pub mod discovery;
pub mod drawing;
pub mod hyprland;
pub mod ipc;
pub mod overlay;
pub mod protocol;
pub mod server;
pub mod video;

pub use discovery::DiscoveryService;
pub use drawing::{new_shared_drawing_state, CoordinateMapper, DrawingState, SharedDrawingState};
pub use hyprland::DisplayManager;
pub use ipc::{DaemonStatus, IpcClient, IpcRequest, IpcResponse, IpcServer};
pub use overlay::{OverlayController, OverlayWorker, StrokeRenderer};
pub use protocol::*;
pub use server::Server;
pub use video::{H264AccessUnit, H264AnnexBParser, VideoCapturePipeline};
