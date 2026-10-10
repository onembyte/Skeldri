use skeldri_linux::drawing::new_shared_drawing_state;
use skeldri_linux::ipc::{IpcClient, IpcRequest, IpcResponse, IpcServer};
use skeldri_linux::overlay::OverlayController;
use skeldri_linux::video::VideoCapturePipeline;
use skeldri_linux::Server;
use std::sync::Arc;
use std::time::Duration;
use tokio::time::sleep;

#[tokio::test]
async fn test_ipc_commands_lifecycle() {
    let port = 52197;
    let server = Arc::new(Server::new(port));
    let drawing_state = new_shared_drawing_state();
    let (overlay_ctrl, _) = OverlayController::new(Arc::clone(&drawing_state));
    let overlay_ctrl = Arc::new(overlay_ctrl);
    let video_pipeline = Arc::new(VideoCapturePipeline::new(Arc::clone(&server)));

    let ipc_server = IpcServer::new(
        Arc::clone(&server),
        Arc::clone(&drawing_state),
        Arc::clone(&overlay_ctrl),
        Arc::clone(&video_pipeline),
        port,
    );

    tokio::spawn(async move {
        let _ = ipc_server.run().await;
    });

    sleep(Duration::from_millis(100)).await;

    // Test 1: Query Status
    let status_resp = IpcClient::send(&IpcRequest::Status).await.unwrap();
    if let IpcResponse::Ok { data: Some(data) } = status_resp {
        assert_eq!(data["port"], port);
        assert_eq!(data["running"], true);
    } else {
        panic!("Expected valid Ok response with status data");
    }

    // Test 2: Toggle Visibility
    let toggle_resp = IpcClient::send(&IpcRequest::Toggle).await.unwrap();
    if let IpcResponse::Ok { data: Some(data) } = toggle_resp {
        assert_eq!(data["visible"], false); // started true, now false
    } else {
        panic!("Expected valid Ok response from toggle");
    }

    // Test 3: Clear Canvas
    let clear_resp = IpcClient::send(&IpcRequest::Clear).await.unwrap();
    assert!(matches!(clear_resp, IpcResponse::Ok { .. }));
}
