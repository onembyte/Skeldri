use skeldri_linux::protocol::{
    ConnectionChannel, ControlPacket, PacketFramer,
    StrokePoint, StrokeStyle, WirePacketType, CURRENT_PROTOCOL_VERSION,
};
use skeldri_linux::Server;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::Arc;
use std::time::Duration;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpStream;
use tokio::time::{sleep, timeout};
use uuid::Uuid;

#[tokio::test]
async fn test_full_client_server_lifecycle() {
    let port = 52199; // test port
    let server = Arc::new(Server::new(port));

    let stroke_counter = Arc::new(AtomicUsize::new(0));
    let counter_clone = Arc::clone(&stroke_counter);

    server.set_control_packet_handler(move |packet| match packet {
        ControlPacket::StrokeBegin { .. } => {
            counter_clone.fetch_add(1, Ordering::SeqCst);
        }
        ControlPacket::StrokePoints { points, .. } => {
            counter_clone.fetch_add(points.len(), Ordering::SeqCst);
        }
        _ => {}
    });

    let server_clone = Arc::clone(&server);
    tokio::spawn(async move {
        let _ = server_clone.start().await;
    });

    // Wait for server to bind
    sleep(Duration::from_millis(100)).await;

    // 1. Connect Control Channel
    let mut control_stream = TcpStream::connect(("127.0.0.1", port)).await.unwrap();

    // Send Hello for Control
    let hello = ControlPacket::Hello {
        version: CURRENT_PROTOCOL_VERSION,
        channel: ConnectionChannel::Control,
        client: "Test iPad".to_string(),
    };
    let hello_bytes = serde_json::to_vec(&hello).unwrap();
    let framed_hello = PacketFramer::frame(WirePacketType::Control, &hello_bytes);
    control_stream.write_all(&framed_hello).await.unwrap();

    // Receive initial displays message from server
    let mut framer = PacketFramer::for_control();
    let mut buf = [0u8; 4096];

    let displays_packet = timeout(Duration::from_secs(2), async {
        loop {
            let n = control_stream.read(&mut buf).await.unwrap();
            let packets = framer.append(&buf[..n]).unwrap();
            for p in packets {
                if p.packet_type == WirePacketType::Control {
                    if let Ok(ControlPacket::Displays { displays }) =
                        serde_json::from_slice::<ControlPacket>(&p.payload)
                    {
                        return displays;
                    }
                }
            }
        }
    })
    .await
    .expect("Timed out waiting for displays packet");

    assert!(!displays_packet.is_empty());

    // Send Ping and expect Pong
    let ping_id = Uuid::new_v4();
    let ping = ControlPacket::Ping {
        id: ping_id,
        sent_at: 1000.0,
    };
    let ping_bytes = serde_json::to_vec(&ping).unwrap();
    control_stream
        .write_all(&PacketFramer::frame(WirePacketType::Control, &ping_bytes))
        .await
        .unwrap();

    let pong_id = timeout(Duration::from_secs(2), async {
        loop {
            let n = control_stream.read(&mut buf).await.unwrap();
            let packets = framer.append(&buf[..n]).unwrap();
            for p in packets {
                if p.packet_type == WirePacketType::Control {
                    if let Ok(ControlPacket::Pong { id, .. }) =
                        serde_json::from_slice::<ControlPacket>(&p.payload)
                    {
                        return id;
                    }
                }
            }
        }
    })
    .await
    .expect("Timed out waiting for pong packet");

    assert_eq!(pong_id, ping_id);

    // Send Stroke Begin and Stroke Points
    let stroke_id = Uuid::new_v4();
    let stroke_begin = ControlPacket::StrokeBegin {
        id: stroke_id,
        style: StrokeStyle::default(),
        point: StrokePoint {
            x: 0.5,
            y: 0.5,
            timestamp: 1001.0,
            pressure: Some(0.8),
        },
    };
    control_stream
        .write_all(&PacketFramer::frame(
            WirePacketType::Control,
            &serde_json::to_vec(&stroke_begin).unwrap(),
        ))
        .await
        .unwrap();

    let stroke_points = ControlPacket::StrokePoints {
        id: stroke_id,
        points: vec![
            StrokePoint {
                x: 0.51,
                y: 0.51,
                timestamp: 1002.0,
                pressure: Some(0.8),
            },
            StrokePoint {
                x: 0.52,
                y: 0.52,
                timestamp: 1003.0,
                pressure: Some(0.8),
            },
        ],
    };
    control_stream
        .write_all(&PacketFramer::frame(
            WirePacketType::Control,
            &serde_json::to_vec(&stroke_points).unwrap(),
        ))
        .await
        .unwrap();

    // Give handler time to process
    sleep(Duration::from_millis(100)).await;
    assert_eq!(stroke_counter.load(Ordering::SeqCst), 3); // 1 begin + 2 points

    // 2. Connect Video Channel
    let mut video_stream = TcpStream::connect(("127.0.0.1", port)).await.unwrap();

    // Send Hello for Video
    let video_hello = ControlPacket::Hello {
        version: CURRENT_PROTOCOL_VERSION,
        channel: ConnectionChannel::Video,
        client: "Test iPad".to_string(),
    };
    video_stream
        .write_all(&PacketFramer::frame(
            WirePacketType::Control,
            &serde_json::to_vec(&video_hello).unwrap(),
        ))
        .await
        .unwrap();

    sleep(Duration::from_millis(50)).await;

    // Send video configuration from server
    let stream_id = Uuid::new_v4();
    let config = skeldri_linux::protocol::VideoConfiguration {
        stream_id,
        width: 1280,
        height: 800,
        sps: vec![0x67, 0x42, 0x00, 0x1f],
        pps: vec![0x68, 0xce, 0x3c, 0x80],
    };
    server.send_video_configuration(&config).await;

    let mut video_framer = PacketFramer::for_video();
    let mut video_buf = [0u8; 4096];

    let received_config = timeout(Duration::from_secs(2), async {
        loop {
            let n = video_stream.read(&mut video_buf).await.unwrap();
            let packets = video_framer.append(&video_buf[..n]).unwrap();
            for p in packets {
                if p.packet_type == WirePacketType::VideoConfiguration {
                    return serde_json::from_slice::<skeldri_linux::protocol::VideoConfiguration>(
                        &p.payload,
                    )
                    .unwrap();
                }
            }
        }
    })
    .await
    .expect("Timed out waiting for video configuration");

    assert_eq!(received_config, config);
}
