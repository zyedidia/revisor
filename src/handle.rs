use std::collections::HashMap;

use crate::channel::Channel;
use crate::shm::SharedMemory;
use crate::signal::Signal;

pub enum Resource {
    Channel(Channel),
    SharedMemory(SharedMemory),
    Signal(Signal),
}

pub struct HandleTable {
    handles: HashMap<u32, Resource>,
    next_id: u32,
}

impl HandleTable {
    pub fn new() -> Self {
        HandleTable {
            handles: HashMap::new(),
            next_id: 1,
        }
    }

    pub fn insert(&mut self, resource: Resource) -> u32 {
        let id = self.next_id;
        self.next_id += 1;
        self.handles.insert(id, resource);
        id
    }

    pub fn get(&self, id: u32) -> Option<&Resource> {
        self.handles.get(&id)
    }

    pub fn get_mut(&mut self, id: u32) -> Option<&mut Resource> {
        self.handles.get_mut(&id)
    }

    #[allow(dead_code)]
    pub fn remove(&mut self, id: u32) -> Option<Resource> {
        self.handles.remove(&id)
    }

    pub fn handles_iter(&self) -> impl Iterator<Item = (&u32, &Resource)> {
        self.handles.iter()
    }
}
