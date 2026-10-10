use crate::drawing::DrawingState;
use crate::overlay::renderer::StrokeRenderer;
use anyhow::{Context, Result};
use memmap2::MmapMut;
use std::os::fd::AsFd;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::Duration;
use tempfile::tempfile;
use tokio::sync::{mpsc, RwLock};
use tracing::{debug, error, info, warn};
use wayland_client::protocol::{
    wl_buffer, wl_compositor, wl_output, wl_region, wl_registry, wl_shm, wl_shm_pool, wl_surface,
};
use wayland_client::{Connection, Dispatch, EventQueue, QueueHandle};
use wayland_protocols_wlr::layer_shell::v1::client::{
    zwlr_layer_shell_v1, zwlr_layer_surface_v1,
};

pub struct WaylandState {
    pub compositor: Option<wl_compositor::WlCompositor>,
    pub shm: Option<wl_shm::WlShm>,
    pub layer_shell: Option<zwlr_layer_shell_v1::ZwlrLayerShellV1>,
    pub outputs: Vec<(u32, wl_output::WlOutput)>,
    pub surface: Option<wl_surface::WlSurface>,
    pub layer_surface: Option<zwlr_layer_surface_v1::ZwlrLayerSurfaceV1>,
    pub width: u32,
    pub height: u32,
    pub configured: bool,
}

impl Default for WaylandState {
    fn default() -> Self {
        Self::new()
    }
}

impl WaylandState {
    pub fn new() -> Self {
        Self {
            compositor: None,
            shm: None,
            layer_shell: None,
            outputs: Vec::new(),
            surface: None,
            layer_surface: None,
            width: 1920,
            height: 1080,
            configured: false,
        }
    }
}

impl Dispatch<wl_registry::WlRegistry, ()> for WaylandState {
    fn event(
        state: &mut Self,
        registry: &wl_registry::WlRegistry,
        event: wl_registry::Event,
        _: &(),
        _: &Connection,
        qh: &QueueHandle<Self>,
    ) {
        if let wl_registry::Event::Global {
            name,
            interface,
            version,
        } = event
        {
            match interface.as_str() {
                "wl_compositor" => {
                    state.compositor = Some(registry.bind::<wl_compositor::WlCompositor, _, _>(
                        name,
                        version.min(4),
                        qh,
                        (),
                    ));
                }
                "wl_shm" => {
                    state.shm = Some(registry.bind::<wl_shm::WlShm, _, _>(
                        name,
                        version.min(1),
                        qh,
                        (),
                    ));
                }
                "zwlr_layer_shell_v1" => {
                    state.layer_shell = Some(
                        registry.bind::<zwlr_layer_shell_v1::ZwlrLayerShellV1, _, _>(
                            name,
                            version.min(4),
                            qh,
                            (),
                        ),
                    );
                }
                "wl_output" => {
                    let output = registry.bind::<wl_output::WlOutput, _, _>(name, 1, qh, ());
                    state.outputs.push((name, output));
                }
                _ => {}
            }
        }
    }
}

impl Dispatch<wl_compositor::WlCompositor, ()> for WaylandState {
    fn event(
        _: &mut Self,
        _: &wl_compositor::WlCompositor,
        _: wl_compositor::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {}
}

impl Dispatch<wl_shm::WlShm, ()> for WaylandState {
    fn event(
        _: &mut Self,
        _: &wl_shm::WlShm,
        _: wl_shm::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {}
}

impl Dispatch<zwlr_layer_shell_v1::ZwlrLayerShellV1, ()> for WaylandState {
    fn event(
        _: &mut Self,
        _: &zwlr_layer_shell_v1::ZwlrLayerShellV1,
        _: zwlr_layer_shell_v1::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {}
}

impl Dispatch<wl_output::WlOutput, ()> for WaylandState {
    fn event(
        _: &mut Self,
        _: &wl_output::WlOutput,
        _: wl_output::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {}
}

impl Dispatch<wl_surface::WlSurface, ()> for WaylandState {
    fn event(
        _: &mut Self,
        _: &wl_surface::WlSurface,
        _: wl_surface::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {}
}

impl Dispatch<wl_region::WlRegion, ()> for WaylandState {
    fn event(
        _: &mut Self,
        _: &wl_region::WlRegion,
        _: wl_region::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {}
}

impl Dispatch<zwlr_layer_surface_v1::ZwlrLayerSurfaceV1, ()> for WaylandState {
    fn event(
        state: &mut Self,
        layer_surface: &zwlr_layer_surface_v1::ZwlrLayerSurfaceV1,
        event: zwlr_layer_surface_v1::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
        match event {
            zwlr_layer_surface_v1::Event::Configure {
                serial,
                width,
                height,
            } => {
                if width > 0 && height > 0 {
                    state.width = width;
                    state.height = height;
                }
                layer_surface.ack_configure(serial);
                state.configured = true;
                debug!("Layer surface configured: {}x{}", state.width, state.height);
            }
            zwlr_layer_surface_v1::Event::Closed => {
                info!("Layer surface closed by compositor");
            }
            _ => {}
        }
    }
}

impl Dispatch<wl_shm_pool::WlShmPool, ()> for WaylandState {
    fn event(
        _: &mut Self,
        _: &wl_shm_pool::WlShmPool,
        _: wl_shm_pool::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {}
}

impl Dispatch<wl_buffer::WlBuffer, ()> for WaylandState {
    fn event(
        _: &mut Self,
        buffer: &wl_buffer::WlBuffer,
        event: wl_buffer::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
        if let wl_buffer::Event::Release = event {
            buffer.destroy();
        }
    }
}

struct ShmBuffer {
    buffer: wl_buffer::WlBuffer,
    mmap: MmapMut,
}

impl ShmBuffer {
    fn new(
        shm: &wl_shm::WlShm,
        width: u32,
        height: u32,
        qh: &QueueHandle<WaylandState>,
    ) -> Result<Self> {
        let stride = width * 4;
        let size = (stride * height) as usize;

        let file = tempfile().context("Failed to create temporary shm file")?;
        file.set_len(size as u64)
            .context("Failed to truncate shm file")?;

        let mmap = unsafe { MmapMut::map_mut(&file).context("Failed to mmap shm file")? };

        let pool = shm.create_pool(file.as_fd(), size as i32, qh, ());
        let buffer = pool.create_buffer(
            0,
            width as i32,
            height as i32,
            stride as i32,
            wl_shm::Format::Argb8888,
            qh,
            (),
        );
        pool.destroy();

        Ok(Self { buffer, mmap })
    }
}

pub struct OverlayController {
    redraw_tx: mpsc::Sender<()>,
    visible: Arc<AtomicBool>,
}

impl OverlayController {
    pub fn new(drawing_state: Arc<RwLock<DrawingState>>) -> (Self, OverlayWorker) {
        let (redraw_tx, redraw_rx) = mpsc::channel(16);
        let visible = Arc::new(AtomicBool::new(true));

        let controller = Self {
            redraw_tx,
            visible: Arc::clone(&visible),
        };

        let worker = OverlayWorker {
            drawing_state,
            redraw_rx,
            visible,
        };

        (controller, worker)
    }

    pub fn request_redraw(&self) {
        let _ = self.redraw_tx.try_send(());
    }

    pub fn set_visible(&self, visible: bool) {
        self.visible.store(visible, Ordering::SeqCst);
        self.request_redraw();
    }

    pub fn is_visible(&self) -> bool {
        self.visible.load(Ordering::SeqCst)
    }
}

pub struct OverlayWorker {
    drawing_state: Arc<RwLock<DrawingState>>,
    redraw_rx: mpsc::Receiver<()>,
    visible: Arc<AtomicBool>,
}

impl OverlayWorker {
    pub async fn run(mut self) -> Result<()> {
        let conn = match Connection::connect_to_env() {
            Ok(c) => c,
            Err(e) => {
                warn!("Wayland connection failed (non-Wayland session?): {}", e);
                return Ok(());
            }
        };

        let mut event_queue: EventQueue<WaylandState> = conn.new_event_queue();
        let qh = event_queue.handle();
        let display = conn.display();

        let mut state = WaylandState::new();
        display.get_registry(&qh, ());

        // Initial roundtrip to gather globals
        event_queue.roundtrip(&mut state)?;

        let compositor = state
            .compositor
            .clone()
            .context("wl_compositor global not available")?;
        let shm = state
            .shm
            .clone()
            .context("wl_shm global not available")?;
        let layer_shell = state
            .layer_shell
            .clone()
            .context("zwlr_layer_shell_v1 global not available")?;

        let surface = compositor.create_surface(&qh, ());

        // Create 100% Click-Through Input Region (Empty region)
        let empty_region = compositor.create_region(&qh, ());
        surface.set_input_region(Some(&empty_region));
        empty_region.destroy();

        let layer_surface = layer_shell.get_layer_surface(
            &surface,
            None, // Anchor to primary output or default
            zwlr_layer_shell_v1::Layer::Overlay,
            "skeldri-overlay".to_string(),
            &qh,
            (),
        );

        // Configure layer surface: anchor to all four screen edges, full screen overlay
        layer_surface.set_anchor(
            zwlr_layer_surface_v1::Anchor::Top
                | zwlr_layer_surface_v1::Anchor::Bottom
                | zwlr_layer_surface_v1::Anchor::Left
                | zwlr_layer_surface_v1::Anchor::Right,
        );
        layer_surface.set_exclusive_zone(-1); // Never push other windows
        layer_surface.set_keyboard_interactivity(
            zwlr_layer_surface_v1::KeyboardInteractivity::None,
        );
        layer_surface.set_size(0, 0); // 0, 0 with 4 anchors means fill entire monitor

        surface.commit();
        event_queue.roundtrip(&mut state)?;

        // Wait until configured
        while !state.configured {
            event_queue.blocking_dispatch(&mut state)?;
        }

        let width = state.width.max(1);
        let height = state.height.max(1);
        info!("Wayland transparent overlay initialized at {}x{}", width, height);

        let renderer = StrokeRenderer::new(width, height);
        let mut pixmap = tiny_skia::Pixmap::new(width, height)
            .context("Failed to allocate initial tiny-skia Pixmap")?;

        // Render initial frame
        let mut shm_buf = ShmBuffer::new(&shm, width, height, &qh)?;
        renderer.render(&[], &mut pixmap.as_mut());
        StrokeRenderer::convert_rgba_to_wl_argb(pixmap.data(), &mut shm_buf.mmap);
        surface.attach(Some(&shm_buf.buffer), 0, 0);
        surface.damage_buffer(0, 0, width as i32, height as i32);
        surface.commit();
        event_queue.flush()?;

        loop {
            tokio::select! {
                Some(_) = self.redraw_rx.recv() => {
                    // Drain any queued redraw triggers to coalesce rapid drawing events
                    while self.redraw_rx.try_recv().is_ok() {}

                    let is_visible = self.visible.load(Ordering::SeqCst);
                    let strokes = if is_visible {
                        let guard = self.drawing_state.read().await;
                        guard.strokes().to_vec()
                    } else {
                        Vec::new()
                    };

                    renderer.render(&strokes, &mut pixmap.as_mut());
                    let mut next_buf = match ShmBuffer::new(&shm, width, height, &qh) {
                        Ok(b) => b,
                        Err(e) => {
                            error!("Failed to allocate next shm buffer: {}", e);
                            continue;
                        }
                    };

                    StrokeRenderer::convert_rgba_to_wl_argb(pixmap.data(), &mut next_buf.mmap);
                    surface.attach(Some(&next_buf.buffer), 0, 0);
                    surface.damage_buffer(0, 0, width as i32, height as i32);
                    surface.commit();

                    if let Err(e) = conn.flush() {
                        warn!("Wayland flush failed: {}", e);
                        break;
                    }
                }
                _ = tokio::time::sleep(Duration::from_millis(50)) => {
                    // Dispatch Wayland events periodically
                    if let Err(e) = event_queue.dispatch_pending(&mut state) {
                        debug!("Wayland event dispatch: {}", e);
                    }
                }
            }
        }

        Ok(())
    }
}
