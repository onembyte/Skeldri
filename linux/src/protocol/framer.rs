use crate::protocol::models::{WirePacketType, CONTROL_PAYLOAD_LIMIT, VIDEO_PAYLOAD_LIMIT};
use byteorder::{BigEndian, ByteOrder};
use bytes::{Buf, BufMut, Bytes, BytesMut};
use thiserror::Error;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FramedPacket {
    pub packet_type: WirePacketType,
    pub payload: Bytes,
}

#[derive(Debug, Error, PartialEq, Eq)]
pub enum PacketFramerError {
    #[error("Invalid packet payload length: {0}")]
    InvalidLength(usize),
    #[error("Unknown wire packet type: {0}")]
    UnknownType(u8),
}

#[derive(Debug)]
pub struct PacketFramer {
    buffer: BytesMut,
    maximum_payload_length: usize,
}

impl Default for PacketFramer {
    fn default() -> Self {
        Self::new(CONTROL_PAYLOAD_LIMIT)
    }
}

impl PacketFramer {
    pub fn new(maximum_payload_length: usize) -> Self {
        Self {
            buffer: BytesMut::with_capacity(8192),
            maximum_payload_length,
        }
    }

    pub fn for_control() -> Self {
        Self::new(CONTROL_PAYLOAD_LIMIT)
    }

    pub fn for_video() -> Self {
        Self::new(VIDEO_PAYLOAD_LIMIT)
    }

    pub fn frame(packet_type: WirePacketType, payload: &[u8]) -> Bytes {
        let length = (payload.len() + 1) as u32; // payload + 1 byte for packet_type
        let mut buf = BytesMut::with_capacity(4 + 1 + payload.len());
        buf.put_u32(length);
        buf.put_u8(packet_type as u8);
        buf.put_slice(payload);
        buf.freeze()
    }

    pub fn append(&mut self, data: &[u8]) -> Result<Vec<FramedPacket>, PacketFramerError> {
        self.buffer.extend_from_slice(data);
        let mut packets = Vec::new();

        while self.buffer.len() >= 4 {
            let length = BigEndian::read_u32(&self.buffer[0..4]) as usize;

            if length < 1 || length > self.maximum_payload_length + 1 {
                return Err(PacketFramerError::InvalidLength(length));
            }

            let total_packet_size = 4 + length;
            if self.buffer.len() < total_packet_size {
                // Wait for more data to arrive
                break;
            }

            let raw_type = self.buffer[4];
            let packet_type = WirePacketType::try_from(raw_type)
                .map_err(|_| PacketFramerError::UnknownType(raw_type))?;

            // Extract the payload (from byte 5 to total_packet_size)
            let payload = Bytes::copy_from_slice(&self.buffer[5..total_packet_size]);
            packets.push(FramedPacket {
                packet_type,
                payload,
            });

            // Advance buffer past this packet
            self.buffer.advance(total_packet_size);
        }

        Ok(packets)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_complete_partial_and_multiple() {
        let first = PacketFramer::frame(WirePacketType::Control, b"one");
        let second = PacketFramer::frame(WirePacketType::VideoFrame, b"two");

        let mut parser = PacketFramer::new(100);

        // Feed partial first 2 bytes
        let p1 = parser.append(&first[0..2]).unwrap();
        assert!(p1.is_empty());

        // Feed rest of first packet
        let p2 = parser.append(&first[2..]).unwrap();
        assert_eq!(p2.len(), 1);
        assert_eq!(p2[0].packet_type, WirePacketType::Control);
        assert_eq!(p2[0].payload.as_ref(), b"one");

        // Feed two packets together
        let mut combined = first.to_vec();
        combined.extend_from_slice(&second);
        let p3 = parser.append(&combined).unwrap();
        assert_eq!(p3.len(), 2);
        assert_eq!(p3[0].payload.as_ref(), b"one");
        assert_eq!(p3[1].payload.as_ref(), b"two");
    }

    #[test]
    fn test_oversized_payload() {
        let mut framer = PacketFramer::new(1);
        let mut data = vec![0, 0, 0, 10]; // length 10 > limit (1 + 1)
        data.extend_from_slice(b"1234567890");
        assert!(matches!(
            framer.append(&data),
            Err(PacketFramerError::InvalidLength(10))
        ));
    }

    #[test]
    fn test_unknown_packet_type() {
        let mut framer = PacketFramer::new(10);
        // length = 2 (1 byte type + 1 byte payload), raw type = 99
        let data = vec![0, 0, 0, 2, 99, 1];
        assert!(matches!(
            framer.append(&data),
            Err(PacketFramerError::UnknownType(99))
        ));
    }
}
