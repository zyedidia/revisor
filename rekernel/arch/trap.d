module arch.trap;

version (arm64) {
    public import arch.arm64.trap;
} else version (amd64) {
    public import arch.amd64.trap;
}
