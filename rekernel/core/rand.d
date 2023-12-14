module core.rand;

import core.lib;

bool get_rand(ubyte* buf, usize size) {
    int fd = open("/dev/urandom", O_RDONLY, 0);
    if (fd < 0)
        return false;
    read(fd, buf, size);
    close(fd);
    return true;
}
