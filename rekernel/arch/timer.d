module arch.timer;

version (arm64) {
    public import arch.arm64.timer;
} else version (amd64) {
    public import arch.amd64.timer;
}
