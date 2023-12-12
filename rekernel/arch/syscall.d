module arch.syscall;

version (arm64) {
    public import arch.arm64.syscall;
} else version (amd64) {
    public import arch.amd64.syscall;
}
