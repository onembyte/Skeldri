use serde::{Deserialize, Deserializer, Serialize, Serializer};
use uuid::Uuid;

pub const CURRENT_PROTOCOL_VERSION: u32 = 2;
pub const CONTROL_PAYLOAD_LIMIT: usize = 1_048_576; // 1 MiB
pub const VIDEO_PAYLOAD_LIMIT: usize = 16_777_216;  // 16 MiB

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(u8)]
pub enum WirePacketType {
    Control = 1,
    VideoConfiguration = 2,
    VideoFrame = 3,
}

impl TryFrom<u8> for WirePacketType {
    type Error = u8;

    fn try_from(value: u8) -> Result<Self, Self::Error> {
        match value {
            1 => Ok(WirePacketType::Control),
            2 => Ok(WirePacketType::VideoConfiguration),
            3 => Ok(WirePacketType::VideoFrame),
            other => Err(other),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ConnectionChannel {
    Control,
    Video,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum DrawingTool {
    Pen,
    Highlighter,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct StrokeStyle {
    pub tool: DrawingTool,
    pub red: f32,
    pub green: f32,
    pub blue: f32,
    pub alpha: f32,
    pub normalized_width: f32,
}

impl Default for StrokeStyle {
    fn default() -> Self {
        Self {
            tool: DrawingTool::Pen,
            red: 1.0,
            green: 0.0,
            blue: 0.0,
            alpha: 1.0,
            normalized_width: 0.005,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct StrokePoint {
    pub x: f32,
    pub y: f32,
    pub timestamp: f64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub pressure: Option<f32>,
}

impl StrokePoint {
    pub fn sanitized(&self) -> Self {
        Self {
            x: self.x.clamp(0.0, 1.0),
            y: self.y.clamp(0.0, 1.0),
            timestamp: self.timestamp,
            pressure: self.pressure.map(|p| p.clamp(0.0, 1.0)),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Stroke {
    pub id: Uuid,
    pub style: StrokeStyle,
    pub points: Vec<StrokePoint>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct DisplayDescriptor {
    pub id: u32,
    pub name: String,
    pub width: i32,
    pub height: i32,
}

impl DisplayDescriptor {
    pub fn aspect_ratio(&self) -> f64 {
        if self.height > 0 {
            self.width as f64 / self.height as f64
        } else {
            1.0
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct VideoConfiguration {
    #[serde(rename = "streamID")]
    pub stream_id: Uuid,
    pub width: i32,
    pub height: i32,
    #[serde(with = "base64_bytes")]
    pub sps: Vec<u8>,
    #[serde(with = "base64_bytes")]
    pub pps: Vec<u8>,
}

mod base64_bytes {
    use super::*;
    use base64::prelude::*;

    pub fn serialize<S>(bytes: &[u8], serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        let encoded = BASE64_STANDARD.encode(bytes);
        serializer.serialize_str(&encoded)
    }

    pub fn deserialize<'de, D>(deserializer: D) -> Result<Vec<u8>, D::Error>
    where
        D: Deserializer<'de>,
    {
        let s = String::deserialize(deserializer)?;
        BASE64_STANDARD
            .decode(&s)
            .map_err(serde::de::Error::custom)
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct VideoFrameHeader {
    #[serde(rename = "streamID")]
    pub stream_id: Uuid,
    pub presentation_time: f64,
    pub is_keyframe: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum ControlPacket {
    Hello {
        version: u32,
        channel: ConnectionChannel,
        client: String,
    },
    IncompatibleVersion {
        expected: u32,
    },
    Ping {
        id: Uuid,
        #[serde(rename = "sentAt")]
        sent_at: f64,
    },
    Pong {
        id: Uuid,
        #[serde(rename = "sentAt")]
        sent_at: f64,
    },
    Displays {
        #[serde(rename = "_0")]
        displays: Vec<DisplayDescriptor>,
    },
    Display {
        #[serde(rename = "_0")]
        display: DisplayDescriptor,
    },
    SelectDisplay {
        id: u32,
    },
    StrokeBegin {
        id: Uuid,
        style: StrokeStyle,
        point: StrokePoint,
    },
    StrokePoints {
        id: Uuid,
        points: Vec<StrokePoint>,
    },
    StrokeEnd {
        id: Uuid,
    },
    DeleteStrokes {
        ids: Vec<Uuid>,
    },
    Clear {},
    CanvasSnapshot {
        #[serde(rename = "_0")]
        strokes: Vec<Stroke>,
    },
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_control_packet_hello_serde() {
        let packet = ControlPacket::Hello {
            version: 2,
            channel: ConnectionChannel::Control,
            client: "iPad".to_string(),
        };
        let json = serde_json::to_string(&packet).unwrap();
        assert_eq!(
            json,
            r#"{"hello":{"version":2,"channel":"control","client":"iPad"}}"#
        );
        let decoded: ControlPacket = serde_json::from_str(&json).unwrap();
        assert_eq!(decoded, packet);
    }

    #[test]
    fn test_control_packet_displays_serde() {
        let descriptor = DisplayDescriptor {
            id: 7,
            name: "Studio Display".to_string(),
            width: 2560,
            height: 1440,
        };
        let packet = ControlPacket::Displays {
            displays: vec![descriptor],
        };
        let json = serde_json::to_string(&packet).unwrap();
        assert_eq!(
            json,
            r#"{"displays":{"_0":[{"id":7,"name":"Studio Display","width":2560,"height":1440}]}}"#
        );
        let decoded: ControlPacket = serde_json::from_str(&json).unwrap();
        assert_eq!(decoded, packet);
    }

    #[test]
    fn test_control_packet_clear_serde() {
        let packet = ControlPacket::Clear {};
        let json = serde_json::to_string(&packet).unwrap();
        assert_eq!(json, r#"{"clear":{}}"#);
        let decoded: ControlPacket = serde_json::from_str(&json).unwrap();
        assert_eq!(decoded, packet);
    }

    #[test]
    fn test_video_configuration_base64_serde() {
        let stream_id = Uuid::new_v4();
        let config = VideoConfiguration {
            stream_id,
            width: 1920,
            height: 1080,
            sps: vec![0x67, 0x42, 0x00, 0x1f],
            pps: vec![0x68, 0xce, 0x3c, 0x80],
        };
        let json = serde_json::to_string(&config).unwrap();
        assert!(json.contains("\"sps\":\"Z0IAHw==\""));
        assert!(json.contains("\"pps\":\"aM48gA==\""));
        let decoded: VideoConfiguration = serde_json::from_str(&json).unwrap();
        assert_eq!(decoded, config);
    }

    #[test]
    fn test_stroke_point_sanitization() {
        let bad_point = StrokePoint {
            x: 1.5,
            y: -0.2,
            timestamp: 100.0,
            pressure: Some(2.0),
        };
        let clean = bad_point.sanitized();
        assert_eq!(clean.x, 1.0);
        assert_eq!(clean.y, 0.0);
        assert_eq!(clean.pressure, Some(1.0));
    }
}
