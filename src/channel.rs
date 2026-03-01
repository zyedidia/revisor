use std::collections::VecDeque;

pub struct Message {
    pub data: Vec<u8>,
    pub handles: Vec<u32>,
}

pub struct Channel {
    pub peer: u32, // handle ID of the peer endpoint
    pub queue: VecDeque<Message>,
}

impl Channel {
    pub fn new(peer: u32) -> Self {
        Channel {
            peer,
            queue: VecDeque::new(),
        }
    }
}
