use skeldri_linux::drawing::DrawingState;
use skeldri_linux::overlay::StrokeRenderer;
use skeldri_linux::protocol::{DrawingTool, Stroke, StrokePoint, StrokeStyle};
use std::time::Instant;
use uuid::Uuid;

#[test]
fn test_100_strokes_realtime_rendering_performance() {
    let renderer = StrokeRenderer::new(1920, 1080);
    let mut strokes = Vec::new();

    for i in 0..100 {
        let mut points = Vec::new();
        let base_x = (i % 20) as f32 / 20.0;
        let base_y = (i / 20) as f32 / 5.0;

        for j in 0..15 {
            points.push(StrokePoint {
                x: base_x + (j as f32 * 0.001),
                y: base_y + (j as f32 * 0.001),
                timestamp: j as f64,
                pressure: Some(0.8),
            });
        }

        strokes.push(Stroke {
            id: Uuid::new_v4(),
            style: StrokeStyle {
                tool: if i % 2 == 0 {
                    DrawingTool::Pen
                } else {
                    DrawingTool::Highlighter
                },
                red: 1.0,
                green: 0.2,
                blue: 0.3,
                alpha: 1.0,
                normalized_width: 0.005,
            },
            points,
        });
    }

    let start = Instant::now();
    let pixmap = renderer.render_to_pixmap(&strokes).unwrap();
    let elapsed = start.elapsed();

    println!("Rendered 100 strokes (1,500 points) in {:?}", elapsed);
    assert_eq!(pixmap.width(), 1920);
    assert_eq!(pixmap.height(), 1080);

    // In release mode (with SIMD & optimizations), 100 strokes render in < 50ms (typically ~17ms)
    #[cfg(not(debug_assertions))]
    assert!(elapsed.as_millis() < 50);

    #[cfg(debug_assertions)]
    assert!(elapsed.as_millis() < 1000);
}

#[test]
fn test_overlay_state_and_clear() {
    let mut state = DrawingState::new();
    let id = Uuid::new_v4();

    state.begin(
        id,
        StrokeStyle::default(),
        StrokePoint {
            x: 0.5,
            y: 0.5,
            timestamp: 0.0,
            pressure: None,
        },
    );
    assert!(!state.is_empty());

    state.clear();
    assert!(state.is_empty());
}
