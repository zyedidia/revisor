module arch.init;

version (arm64) {
    public import arch.arm64.init;
} else version (amd64) {
    public import arch.amd64.init;
}
