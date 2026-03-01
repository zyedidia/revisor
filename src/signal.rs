pub struct Signal {
    pub signaled: bool,
}

impl Signal {
    pub fn new() -> Self {
        Signal { signaled: false }
    }
}
