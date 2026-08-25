use crate::protocol::{Stroke, StrokePoint, StrokeStyle};
use std::sync::Arc;
use tokio::sync::RwLock;
use uuid::Uuid;

#[derive(Debug, Clone, Default)]
pub struct DrawingState {
    strokes: Vec<Stroke>,
}

impl DrawingState {
    pub fn new() -> Self {
        Self {
            strokes: Vec::new(),
        }
    }

    pub fn begin(&mut self, id: Uuid, style: StrokeStyle, point: StrokePoint) {
        if self.strokes.iter().any(|s| s.id == id) {
            return;
        }
        self.strokes.push(Stroke {
            id,
            style,
            points: vec![point.sanitized()],
        });
    }

    pub fn append(&mut self, id: Uuid, points: Vec<StrokePoint>) {
        if let Some(stroke) = self.strokes.iter_mut().find(|s| s.id == id) {
            stroke.points.extend(points.into_iter().map(|p| p.sanitized()));
        }
    }

    pub fn finish(&mut self, _id: Uuid) {
        // Identity and order are already final.
    }

    pub fn delete(&mut self, ids: &[Uuid]) {
        self.strokes.retain(|s| !ids.contains(&s.id));
    }

    pub fn undo(&mut self) -> Option<Uuid> {
        self.strokes.pop().map(|s| s.id)
    }

    pub fn clear(&mut self) {
        self.strokes.clear();
    }

    pub fn replace(&mut self, snapshot: Vec<Stroke>) {
        self.strokes = snapshot;
    }

    pub fn strokes(&self) -> &[Stroke] {
        &self.strokes
    }

    pub fn is_empty(&self) -> bool {
        self.strokes.is_empty()
    }
}

pub type SharedDrawingState = Arc<RwLock<DrawingState>>;

pub fn new_shared_drawing_state() -> SharedDrawingState {
    Arc::new(RwLock::new(DrawingState::new()))
}

#[derive(Debug, Clone, Copy)]
pub struct CoordinateMapper {
    pub display_width: f32,
    pub display_height: f32,
}

impl CoordinateMapper {
    pub fn new(display_width: f32, display_height: f32) -> Self {
        Self {
            display_width,
            display_height,
        }
    }

    pub fn to_pixel_point(&self, point: &StrokePoint) -> (f32, f32) {
        let clean = point.sanitized();
        (
            clean.x * self.display_width,
            clean.y * self.display_height,
        )
    }

    pub fn stroke_width_pixels(&self, style: &StrokeStyle) -> f32 {
        let min_dim = self.display_width.min(self.display_height);
        (style.normalized_width * min_dim).max(1.0)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_drawing_state_mutations() {
        let mut state = DrawingState::new();
        let id1 = Uuid::new_v4();
        let p1 = StrokePoint {
            x: 0.1,
            y: 0.2,
            timestamp: 1.0,
            pressure: None,
        };

        state.begin(id1, StrokeStyle::default(), p1.clone());
        assert_eq!(state.strokes().len(), 1);
        assert_eq!(state.strokes()[0].points.len(), 1);

        let p2 = StrokePoint {
            x: 0.3,
            y: 0.4,
            timestamp: 2.0,
            pressure: None,
        };
        state.append(id1, vec![p2]);
        assert_eq!(state.strokes()[0].points.len(), 2);

        let id2 = Uuid::new_v4();
        state.begin(id2, StrokeStyle::default(), p1);
        assert_eq!(state.strokes().len(), 2);

        state.delete(&[id1]);
        assert_eq!(state.strokes().len(), 1);
        assert_eq!(state.strokes()[0].id, id2);

        state.undo();
        assert!(state.is_empty());
    }

    #[test]
    fn test_coordinate_mapper() {
        let mapper = CoordinateMapper::new(1920.0, 1080.0);
        let pt = StrokePoint {
            x: 0.5,
            y: 0.5,
            timestamp: 0.0,
            pressure: None,
        };
        let (px, py) = mapper.to_pixel_point(&pt);
        assert_eq!(px, 960.0);
        assert_eq!(py, 540.0);

        let style = StrokeStyle {
            normalized_width: 0.01,
            ..Default::default()
        };
        let width = mapper.stroke_width_pixels(&style);
        assert_eq!(width, 10.8); // 0.01 * 1080
    }
}
