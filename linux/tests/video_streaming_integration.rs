use skeldri_linux::protocol::{
    ConnectionChannel, ControlPacket, DisplayDescriptor, PacketFramer, VideoEnvelope,
    WirePacketType, CURRENT_PROTOCOL_VERSION,
};
use skeldri_linux::{Server, VideoCapturePipeline};
use std::sync::Arc;
use std::time::Duration;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpStream;
use tokio::time::{sleep, timeout};

#[tokio::test]
async fn test_video_capture_and_streaming_integration() {
    let port = 52198;
    let server = Arc::new(Server::new(port));

    let server_clone = Arc::clone(&server);
    tokio::spawn(async move {
        let _ = server_clone.start().await;
    });

    sleep(Duration::from_millis(100)).await;

    // Connect mock iPad to Video channel
    let mut video_stream = TcpStream::connect(("127.0.0.1", port)).await.unwrap();

    let hello = ControlPacket::Hello {
        version: CURRENT_PROTOCOL_VERSION,
        channel: ConnectionChannel::Video,
        client: "Test iPad Video".to_string(),
    };
    let hello_bytes = serde_json::to_vec(&hello).unwrap();
    let framed = PacketFramer::frame(WirePacketType::Control, &hello_bytes);
    video_stream.write_all(&framed).await.unwrap();

    sleep(Duration::from_millis(100)).await;

    // Start video pipeline
    let pipeline = VideoCapturePipeline::new(Arc::clone(&server));
    let display = DisplayDescriptor {
        id: 0,
        name: "Test Display".to_string(),
        width: 1280,
        height: 800,
    };

    pipeline.start(&display).await.unwrap();

    // Read video configuration and frames from the stream
    let mut framer = PacketFramer::for_video();
    let mut buf = [0u8; 8192];
    let mut received_config = false;
    let mut received_frame = false;

    let result = timeout(Duration::from_secs(5), async {
        loop {
            let n = video_stream.read(&mut buf).await.unwrap();
            if n == 0 {
                break;
            }
            let packets = framer.append(&buf[..n]).unwrap();
            for p in packets {
                match p.packet_type {
                    WirePacketType::VideoConfiguration => {
                        let config: skeldri_linux::protocol::VideoConfiguration =
                            serde_json::from_slice(&p.payload).unwrap();
                        assert_eq!(config.width, 1280);
                        assert_eq!(config.height, 800);
                        assert!(!config.sps.is_empty());
                        assert!(!config.pps.is_empty());
                        received_config = true;
                    }
                    WirePacketType::VideoFrame => {
                        let (header, access_unit) = VideoEnvelope::decode(&p.payload).unwrap();
                        assert!(header.presentation_time >= 0.0);
                        assert!(!access_unit.is_empty());
                        received_frame = true;
                    }
                    _ => {}
                }

                if received_config && received_frame {
                    return true;
                }
            }
        }
        false
    })
    .await;

    pipeline.stop().await;

    assert!(result.is_ok(), "Timed out waiting for video configuration and frames");
    assert!(result.unwrap(), "Expected both video configuration and video frame to arrive");
}
