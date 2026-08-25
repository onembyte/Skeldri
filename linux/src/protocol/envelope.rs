use crate::protocol::models::VideoFrameHeader;
use byteorder::{BigEndian, ByteOrder};
use bytes::{BufMut, Bytes, BytesMut};
use thiserror::Error;

#[derive(Debug, Error, PartialEq, Eq)]
pub enum VideoEnvelopeError {
    #[error("Envelope data truncated")]
    Truncated,
    #[error("Invalid JSON header")]
    InvalidHeader,
}

pub struct VideoEnvelope;

impl VideoEnvelope {
    pub fn encode(header: &VideoFrameHeader, access_unit: &[u8]) -> Result<Bytes, serde_json::Error> {
        let metadata = serde_json::to_vec(header)?;
        let metadata_len = metadata.len() as u32;

        let total_size = 4 + metadata.len() + access_unit.len();
        let mut buf = BytesMut::with_capacity(total_size);

        buf.put_u32(metadata_len);
        buf.put_slice(&metadata);
        buf.put_slice(access_unit);

        Ok(buf.freeze())
    }

    pub fn decode(data: &[u8]) -> Result<(VideoFrameHeader, Bytes), VideoEnvelopeError> {
        if data.len() < 4 {
            return Err(VideoEnvelopeError::Truncated);
        }

        let metadata_len = BigEndian::read_u32(&data[0..4]) as usize;
        if data.len() < 4 + metadata_len {
            return Err(VideoEnvelopeError::Truncated);
        }

        let metadata_slice = &data[4..4 + metadata_len];
        let header: VideoFrameHeader = serde_json::from_slice(metadata_slice)
            .map_err(|_| VideoEnvelopeError::InvalidHeader)?;

        let access_unit = Bytes::copy_from_slice(&data[4 + metadata_len..]);
        Ok((header, access_unit))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use uuid::Uuid;

    #[test]
    fn test_video_envelope_round_trip() {
        let header = VideoFrameHeader {
            stream_id: Uuid::new_v4(),
            presentation_time: 42.5,
            is_keyframe: true,
        };
        let access_unit = vec![1, 2, 3, 4, 5];

        let encoded = VideoEnvelope::encode(&header, &access_unit).unwrap();
        let (decoded_header, decoded_au) = VideoEnvelope::decode(&encoded).unwrap();

        assert_eq!(decoded_header, header);
        assert_eq!(decoded_au.as_ref(), access_unit.as_slice());
    }

    #[test]
    fn test_video_envelope_truncated() {
        assert_eq!(
            VideoEnvelope::decode(&[0, 0, 0]),
            Err(VideoEnvelopeError::Truncated)
        );

        let mut short_data = vec![0, 0, 0, 100]; // claims 100 bytes of header
        short_data.extend_from_slice(b"short");
        assert_eq!(
            VideoEnvelope::decode(&short_data),
            Err(VideoEnvelopeError::Truncated)
        );
    }
}
