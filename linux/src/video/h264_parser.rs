use bytes::{BufMut, Bytes, BytesMut};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum NalUnitType {
    Unspecified,
    SliceNonIdr, // 1
    SliceDataA,  // 2
    SliceDataB,  // 3
    SliceDataC,  // 4
    SliceIdr,    // 5 (Keyframe)
    Sei,         // 6
    Sps,         // 7
    Pps,         // 8
    Aud,         // 9
    Other(u8),
}

impl From<u8> for NalUnitType {
    fn from(val: u8) -> Self {
        match val & 0x1F {
            0 => NalUnitType::Unspecified,
            1 => NalUnitType::SliceNonIdr,
            2 => NalUnitType::SliceDataA,
            3 => NalUnitType::SliceDataB,
            4 => NalUnitType::SliceDataC,
            5 => NalUnitType::SliceIdr,
            6 => NalUnitType::Sei,
            7 => NalUnitType::Sps,
            8 => NalUnitType::Pps,
            9 => NalUnitType::Aud,
            other => NalUnitType::Other(other),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct NalUnit {
    pub unit_type: NalUnitType,
    pub data: Vec<u8>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct H264AccessUnit {
    pub is_keyframe: bool,
    pub sps: Option<Vec<u8>>,
    pub pps: Option<Vec<u8>>,
    /// AVCC formatted access unit (each NAL unit prefixed with 4-byte big-endian length)
    pub avcc_payload: Bytes,
}

#[derive(Debug, Default)]
pub struct H264AnnexBParser {
    buffer: Vec<u8>,
    last_sps: Option<Vec<u8>>,
    last_pps: Option<Vec<u8>>,
}

impl H264AnnexBParser {
    pub fn new() -> Self {
        Self {
            buffer: Vec::with_capacity(65536),
            last_sps: None,
            last_pps: None,
        }
    }

    /// Appends incoming Annex B byte stream chunks and extracts completed Access Units.
    pub fn parse_chunk(&mut self, chunk: &[u8]) -> Vec<H264AccessUnit> {
        self.buffer.extend_from_slice(chunk);
        let mut access_units = Vec::new();

        // Split buffer into NAL units based on Annex B start codes (0x000001 or 0x00000001)
        let nalus = Self::extract_nal_units(&self.buffer);
        if nalus.len() < 2 {
            // Need more data to determine access unit boundaries
            return access_units;
        }

        // Group NAL units into complete Access Units (ending before the last incomplete or next slice)
        let mut current_nalus: Vec<NalUnit> = Vec::new();
        let mut is_keyframe = false;
        let mut found_sps = None;
        let mut found_pps = None;

        let total_extracted = nalus.len();
        // Keep the last NAL in the buffer if it might be incomplete
        for nalu in nalus.into_iter().take(total_extracted - 1) {
            match nalu.unit_type {
                NalUnitType::Sps => {
                    self.last_sps = Some(nalu.data.clone());
                    found_sps = Some(nalu.data.clone());
                }
                NalUnitType::Pps => {
                    self.last_pps = Some(nalu.data.clone());
                    found_pps = Some(nalu.data.clone());
                }
                NalUnitType::SliceIdr => {
                    is_keyframe = true;
                    current_nalus.push(nalu);
                }
                NalUnitType::SliceNonIdr => {
                    current_nalus.push(nalu);
                }
                NalUnitType::Sei | NalUnitType::Aud => {
                    current_nalus.push(nalu);
                }
                _ => {}
            }

            // When we encounter a slice, we can form an access unit
            if !current_nalus.is_empty() {
                let avcc_payload = Self::package_avcc(&current_nalus);
                access_units.push(H264AccessUnit {
                    is_keyframe,
                    sps: found_sps.take().or_else(|| {
                        if is_keyframe {
                            self.last_sps.clone()
                        } else {
                            None
                        }
                    }),
                    pps: found_pps.take().or_else(|| {
                        if is_keyframe {
                            self.last_pps.clone()
                        } else {
                            None
                        }
                    }),
                    avcc_payload,
                });
                current_nalus.clear();
                is_keyframe = false;
            }
        }

        // Clear parsed data from buffer, retaining only unparsed tail
        if let Some(last_start) = Self::find_last_start_code(&self.buffer) {
            self.buffer = self.buffer[last_start..].to_vec();
        } else {
            self.buffer.clear();
        }

        access_units
    }

    /// Converts a list of NAL units into length-prefixed AVCC access unit data.
    pub fn package_avcc(nalus: &[NalUnit]) -> Bytes {
        let total_size: usize = nalus.iter().map(|n| 4 + n.data.len()).sum();
        let mut buf = BytesMut::with_capacity(total_size);

        for nalu in nalus {
            buf.put_u32(nalu.data.len() as u32);
            buf.put_slice(&nalu.data);
        }

        buf.freeze()
    }

    fn extract_nal_units(data: &[u8]) -> Vec<NalUnit> {
        let mut nalus = Vec::new();
        let mut i = 0;
        let mut start_indices = Vec::new();

        while i + 3 <= data.len() {
            if data[i] == 0 && data[i + 1] == 0 {
                if data[i + 2] == 1 {
                    // 3-byte start code: 0x000001
                    start_indices.push((i, i + 3));
                    i += 3;
                    continue;
                } else if i + 4 <= data.len() && data[i + 2] == 0 && data[i + 3] == 1 {
                    // 4-byte start code: 0x00000001
                    start_indices.push((i, i + 4));
                    i += 4;
                    continue;
                }
            }
            i += 1;
        }

        for idx in 0..start_indices.len() {
            let (_, content_start) = start_indices[idx];
            let content_end = if idx + 1 < start_indices.len() {
                start_indices[idx + 1].0
            } else {
                data.len()
            };

            if content_start < content_end {
                let nalu_bytes = data[content_start..content_end].to_vec();
                let unit_type = NalUnitType::from(nalu_bytes[0]);
                nalus.push(NalUnit {
                    unit_type,
                    data: nalu_bytes,
                });
            }
        }

        nalus
    }

    fn find_last_start_code(data: &[u8]) -> Option<usize> {
        let mut i = data.len().saturating_sub(4);
        while i > 0 {
            if data[i] == 0 && data[i + 1] == 0 {
                if data[i + 2] == 1 || (i + 3 < data.len() && data[i + 2] == 0 && data[i + 3] == 1) {
                    return Some(i);
                }
            }
            i -= 1;
        }
        None
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use byteorder::{BigEndian, ByteOrder};

    #[test]
    fn test_nal_type_extraction() {
        assert_eq!(NalUnitType::from(0x67), NalUnitType::Sps); // 0x67 & 0x1F = 7
        assert_eq!(NalUnitType::from(0x68), NalUnitType::Pps); // 0x68 & 0x1F = 8
        assert_eq!(NalUnitType::from(0x65), NalUnitType::SliceIdr); // 0x65 & 0x1F = 5
        assert_eq!(NalUnitType::from(0x41), NalUnitType::SliceNonIdr); // 0x41 & 0x1F = 1
    }

    #[test]
    fn test_annex_b_to_avcc_parsing() {
        let mut parser = H264AnnexBParser::new();

        // Construct Annex B stream: [SPS] [PPS] [IDR] [Start code for next]
        let mut stream = Vec::new();
        // SPS: 0x00000001 67 42 00 1f
        stream.extend_from_slice(&[0x00, 0x00, 0x00, 0x01, 0x67, 0x42, 0x00, 0x1f]);
        // PPS: 0x00000001 68 ce 3c 80
        stream.extend_from_slice(&[0x00, 0x00, 0x00, 0x01, 0x68, 0xce, 0x3c, 0x80]);
        // IDR: 0x00000001 65 88 84 00
        stream.extend_from_slice(&[0x00, 0x00, 0x00, 0x01, 0x65, 0x88, 0x84, 0x00]);
        // Next NAL start code
        stream.extend_from_slice(&[0x00, 0x00, 0x00, 0x01, 0x41, 0x9a]);

        let access_units = parser.parse_chunk(&stream);
        assert_eq!(access_units.len(), 1);

        let au = &access_units[0];
        assert!(au.is_keyframe);
        assert_eq!(au.sps, Some(vec![0x67, 0x42, 0x00, 0x1f]));
        assert_eq!(au.pps, Some(vec![0x68, 0xce, 0x3c, 0x80]));

        // Check AVCC length prefix for IDR slice
        assert_eq!(au.avcc_payload.len(), 4 + 4); // 4-byte length + 4 bytes NAL data
        let length = BigEndian::read_u32(&au.avcc_payload[0..4]);
        assert_eq!(length, 4);
        assert_eq!(&au.avcc_payload[4..8], &[0x65, 0x88, 0x84, 0x00]);
    }
}
