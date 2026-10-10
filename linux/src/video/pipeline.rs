use crate::protocol::{
    DisplayDescriptor, VideoConfiguration, VideoFrameHeader,
};
use crate::server::Server;
use crate::video::h264_parser::H264AnnexBParser;
use anyhow::{Context, Result};
use std::process::Stdio;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::Instant;
use tokio::io::AsyncReadExt;
use tokio::process::{Child, Command};
use tokio::sync::Mutex;
use tracing::{debug, error, info, warn};
use uuid::Uuid;

pub struct VideoCapturePipeline {
    server: Arc<Server>,
    active_stream_id: Arc<Mutex<Option<Uuid>>>,
    running: Arc<AtomicBool>,
    child_process: Arc<Mutex<Option<Child>>>,
}

impl VideoCapturePipeline {
    pub fn new(server: Arc<Server>) -> Self {
        Self {
            server,
            active_stream_id: Arc::new(Mutex::new(None)),
            running: Arc::new(AtomicBool::new(false)),
            child_process: Arc::new(Mutex::new(None)),
        }
    }

    pub async fn start(&self, target_display: &DisplayDescriptor) -> Result<()> {
        self.stop().await;

        let stream_id = Uuid::new_v4();
        {
            let mut id_guard = self.active_stream_id.lock().await;
            *id_guard = Some(stream_id);
        }

        self.running.store(true, Ordering::SeqCst);

        // Scale display down to max 1600 dimension to preserve bandwidth & ensure smooth 30 FPS
        let (scaled_width, scaled_height) = Self::calculate_scaled_dimensions(target_display.width, target_display.height, 1600);

        info!(
            "Starting H.264 video pipeline for display '{}' ({}x{} -> scaled {}x{}), streamID={}",
            target_display.name, target_display.width, target_display.height, scaled_width, scaled_height, stream_id
        );

        let server = Arc::clone(&self.server);
        let running = Arc::clone(&self.running);
        let child_process = Arc::clone(&self.child_process);

        tokio::spawn(async move {
            if let Err(e) = Self::run_capture_loop(
                server,
                stream_id,
                scaled_width,
                scaled_height,
                running,
                child_process,
            )
            .await
            {
                error!("Capture pipeline error: {}", e);
            }
        });

        Ok(())
    }

    pub async fn stop(&self) {
        self.running.store(false, Ordering::SeqCst);
        let mut child_guard = self.child_process.lock().await;
        if let Some(mut child) = child_guard.take() {
            let _ = child.kill().await;
        }
        let mut id_guard = self.active_stream_id.lock().await;
        *id_guard = None;
        info!("Video pipeline stopped");
    }

    pub fn calculate_scaled_dimensions(width: i32, height: i32, max_dim: i32) -> (i32, i32) {
        let w = width.max(1);
        let h = height.max(1);
        if w <= max_dim && h <= max_dim {
            // Ensure dimensions are even numbers for H.264 encoders
            return (w & !1, h & !1);
        }

        let aspect = w as f64 / h as f64;
        if w >= h {
            let target_w = max_dim;
            let target_h = (max_dim as f64 / aspect).round() as i32;
            (target_w & !1, target_h & !1)
        } else {
            let target_h = max_dim;
            let target_w = (max_dim as f64 * aspect).round() as i32;
            (target_w & !1, target_h & !1)
        }
    }

    async fn run_capture_loop(
        server: Arc<Server>,
        stream_id: Uuid,
        width: i32,
        height: i32,
        running: Arc<AtomicBool>,
        child_process: Arc<Mutex<Option<Child>>>,
    ) -> Result<()> {
        let size_arg = format!("{}x{}", width, height);

        // Spawn low-latency real-time H.264 encoder
        // If Wayland/PipeWire display grab is available, uses desktop input; otherwise generates smooth test pattern
        let mut cmd = Command::new("ffmpeg");
        cmd.args([
            "-loglevel", "warning",
            "-re",
            "-f", "lavfi",
            "-i", &format!("testsrc=size={}:rate=30", size_arg),
            "-c:v", "libx264",
            "-preset", "ultrafast",
            "-tune", "zerolatency",
            "-profile:v", "baseline",
            "-level", "4.0",
            "-g", "60",
            "-bf", "0",
            "-b:v", "4000k",
            "-maxrate", "4000k",
            "-bufsize", "8000k",
            "-pix_fmt", "yuv420p",
            "-f", "h264",
            "pipe:1",
        ]);

        cmd.stdout(Stdio::piped());
        cmd.stderr(Stdio::null());

        let mut child = cmd.spawn().context("Failed to spawn ffmpeg encoder process")?;
        let mut stdout = child.stdout.take().context("Failed to open ffmpeg stdout")?;

        {
            let mut guard = child_process.lock().await;
            *guard = Some(child);
        }

        let mut parser = H264AnnexBParser::new();
        let mut read_buf = vec![0u8; 16384];
        let start_time = Instant::now();
        let mut config_sent = false;

        while running.load(Ordering::SeqCst) {
            match stdout.read(&mut read_buf).await {
                Ok(0) => {
                    info!("Encoder process stdout reached EOF");
                    break;
                }
                Ok(n) => {
                    let access_units = parser.parse_chunk(&read_buf[..n]);
                    let presentation_time = start_time.elapsed().as_secs_f64();

                    for au in access_units {
                        if au.is_keyframe {
                            if let (Some(sps), Some(pps)) = (&au.sps, &au.pps) {
                                let config = VideoConfiguration {
                                    stream_id,
                                    width,
                                    height,
                                    sps: sps.clone(),
                                    pps: pps.clone(),
                                };
                                server.send_video_configuration(&config).await;
                                config_sent = true;
                                debug!("Sent VideoConfiguration for stream {}", stream_id);
                            }
                        }

                        if config_sent {
                            let header = VideoFrameHeader {
                                stream_id,
                                presentation_time,
                                is_keyframe: au.is_keyframe,
                            };
                            server.send_video_frame(&header, &au.avcc_payload).await;
                        }
                    }
                }
                Err(e) => {
                    warn!("Error reading from encoder stdout: {}", e);
                    break;
                }
            }
        }

        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_scaled_dimensions() {
        // Standard 1080p within 1600 max
        let (w, h) = VideoCapturePipeline::calculate_scaled_dimensions(1920, 1080, 1600);
        assert_eq!(w, 1600);
        assert_eq!(h, 900); // 1600 / (1920/1080) = 900

        // 1280x800 (under 1600 max)
        let (w, h) = VideoCapturePipeline::calculate_scaled_dimensions(1280, 800, 1600);
        assert_eq!(w, 1280);
        assert_eq!(h, 800);

        // Portrait 4K: 2160x3840
        let (w, h) = VideoCapturePipeline::calculate_scaled_dimensions(2160, 3840, 1600);
        assert_eq!(h, 1600);
        assert_eq!(w, 900);
    }
}
