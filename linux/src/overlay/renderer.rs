use crate::drawing::CoordinateMapper;
use crate::protocol::{DrawingTool, Stroke};
use tiny_skia::{
    Color, LineCap, LineJoin, Paint, PathBuilder, Pixmap, PixmapMut, Stroke as SkiaStroke,
    Transform,
};

pub struct StrokeRenderer {
    width: u32,
    height: u32,
    mapper: CoordinateMapper,
}

impl StrokeRenderer {
    pub fn new(width: u32, height: u32) -> Self {
        Self {
            width,
            height,
            mapper: CoordinateMapper::new(width as f32, height as f32),
        }
    }

    pub fn resize(&mut self, width: u32, height: u32) {
        self.width = width;
        self.height = height;
        self.mapper = CoordinateMapper::new(width as f32, height as f32);
    }

    /// Renders strokes onto a tiny-skia Pixmap.
    pub fn render(&self, strokes: &[Stroke], pixmap: &mut PixmapMut) {
        pixmap.fill(Color::TRANSPARENT);

        for stroke in strokes {
            if stroke.points.is_empty() {
                continue;
            }

            let style = &stroke.style;
            let mut paint = Paint::default();

            // Set color and alpha based on tool type
            let alpha = match style.tool {
                DrawingTool::Pen => style.alpha.clamp(0.0, 1.0),
                DrawingTool::Highlighter => (style.alpha * 0.4).clamp(0.0, 1.0),
            };

            if let Some(color) = Color::from_rgba(style.red, style.green, style.blue, alpha) {
                paint.set_color(color);
            } else {
                paint.set_color(Color::BLACK);
            }
            paint.anti_alias = true;

            let stroke_width = self.mapper.stroke_width_pixels(style);
            let mut skia_stroke = SkiaStroke::default();
            skia_stroke.width = stroke_width;
            skia_stroke.line_cap = LineCap::Round;
            skia_stroke.line_join = LineJoin::Round;

            let mut builder = PathBuilder::new();
            let first_pt = &stroke.points[0];
            let (x0, y0) = self.mapper.to_pixel_point(first_pt);
            builder.move_to(x0, y0);

            if stroke.points.len() == 1 {
                // For a single point tap, draw a short sub-pixel line so round caps create a clean dot
                builder.line_to(x0 + 0.1, y0);
            } else {
                for pt in &stroke.points[1..] {
                    let (x, y) = self.mapper.to_pixel_point(pt);
                    builder.line_to(x, y);
                }
            }

            if let Some(path) = builder.finish() {
                pixmap.stroke_path(&path, &paint, &skia_stroke, Transform::identity(), None);
            }
        }
    }

    /// Helper to create and render into a new Pixmap
    pub fn render_to_pixmap(&self, strokes: &[Stroke]) -> Option<Pixmap> {
        let mut pixmap = Pixmap::new(self.width, self.height)?;
        self.render(strokes, &mut pixmap.as_mut());
        Some(pixmap)
    }

    /// Converts tiny-skia premultiplied RGBA buffer into Wayland ARGB8888 / XRGB8888 (BGRA little-endian) buffer.
    pub fn convert_rgba_to_wl_argb(rgba_data: &[u8], argb_dest: &mut [u8]) {
        assert_eq!(rgba_data.len(), argb_dest.len());
        for (src, dst) in rgba_data.chunks_exact(4).zip(argb_dest.chunks_exact_mut(4)) {
            let r = src[0];
            let g = src[1];
            let b = src[2];
            let a = src[3];

            // In Wayland WL_SHM_FORMAT_ARGB8888 on little-endian x86/ARM:
            // Byte 0: Blue, Byte 1: Green, Byte 2: Red, Byte 3: Alpha
            dst[0] = b;
            dst[1] = g;
            dst[2] = r;
            dst[3] = a;
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::protocol::{StrokePoint, StrokeStyle};
    use uuid::Uuid;

    #[test]
    fn test_render_strokes_to_pixmap() {
        let renderer = StrokeRenderer::new(800, 600);
        let stroke = Stroke {
            id: Uuid::new_v4(),
            style: StrokeStyle {
                tool: DrawingTool::Pen,
                red: 1.0,
                green: 0.0,
                blue: 0.0,
                alpha: 1.0,
                normalized_width: 0.01,
            },
            points: vec![
                StrokePoint {
                    x: 0.1,
                    y: 0.1,
                    timestamp: 1.0,
                    pressure: None,
                },
                StrokePoint {
                    x: 0.2,
                    y: 0.2,
                    timestamp: 2.0,
                    pressure: None,
                },
            ],
        };

        let pixmap = renderer.render_to_pixmap(&[stroke]).unwrap();
        assert_eq!(pixmap.width(), 800);
        assert_eq!(pixmap.height(), 600);

        // Verify there is some drawn (non-zero) pixel in the canvas
        let non_zero_pixels = pixmap.data().iter().any(|&b| b > 0);
        assert!(non_zero_pixels);
    }

    #[test]
    fn test_rgba_to_argb_conversion() {
        let rgba = [255, 128, 64, 200]; // R=255, G=128, B=64, A=200
        let mut argb = [0u8; 4];
        StrokeRenderer::convert_rgba_to_wl_argb(&rgba, &mut argb);
        assert_eq!(argb, [64, 128, 255, 200]); // B=64, G=128, R=255, A=200
    }
}
