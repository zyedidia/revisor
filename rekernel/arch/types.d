module arch.types;

version (arm64) {
    public import arch.arm64.types;
} else version (amd64) {
    public import arch.amd64.types;
}
