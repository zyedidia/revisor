module arch.vm;

version (arm64) {
    public import arch.arm64.vm;
} else version (amd64) {
    public import arch.amd64.vm;
}
