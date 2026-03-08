#include <fcntl.h>
#include <poll.h>
#include <stdint.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/mount.h>
#include <sys/reboot.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <sys/sysmacros.h>
#include <sys/wait.h>
#include <unistd.h>

/* ---- ioctl definitions (must match revisor_arena.c) ---- */
struct revisor_region {
	uint64_t offset;
	uint64_t size;
};

#define REVISOR_CREATE_REGION _IOW('R', 1, struct revisor_region)
#define REVISOR_DOORBELL      _IO('R', 2)
#define REVISOR_GET_SIZE      _IOR('R', 3, uint64_t)

/* ---- Arena layout (must match gokvm/machine/arena.go) ---- */
#define H2G_HDR_OFF    0x0000
#define G2H_HDR_OFF    0x0040
#define METADATA_OFF   0x1000
#define H2G_DATA_OFF   0x10000
#define G2H_DATA_OFF   0x110000
#define RING_DATA_SZ   0x100000

#define RING_WRITE_IDX 0
#define RING_READ_IDX  4
#define RING_SIZE      8

/* Ring buffer message types (must match revisor/proxy.go) */
#define MSG_DATA          0
#define MSG_DATA_WITH_FDS 1

/* Metadata magic (must match revisor/metadata.go) */
#define METADATA_MAGIC 0x52455649

/* Maximum args/handles */
#define MAX_ARGS    128
#define MAX_SHMEM   16
#define MAX_SOCKET  16

/* ---- Metadata structures ---- */
struct metadata_header {
	uint32_t magic;
	uint32_t version;
	uint32_t argc;
	uint32_t num_shmem;
	uint32_t num_socket;
	uint32_t argv_off;
	uint32_t shmem_off;
	uint32_t socket_off;
};

struct shmem_entry {
	uint32_t guest_fd;
	uint32_t arena_offset;
	uint32_t size;
};

struct socket_entry {
	uint32_t guest_fd;
};

/* ---- Utility functions ---- */

static void setup_console(void)
{
	mknod("/dev/console", S_IFCHR | 0600, makedev(5, 1));
	int fd = open("/dev/console", O_RDWR);
	if (fd >= 0) {
		dup2(fd, 0);
		dup2(fd, 1);
		dup2(fd, 2);
		if (fd > 2)
			close(fd);
	}
}

static void msg(const char *s)
{
	write(1, s, strlen(s));
}

static void msg_num(const char *prefix, uint32_t n)
{
	msg(prefix);
	char buf[16];
	int i = 15;
	buf[i--] = '\n';
	if (n == 0) {
		buf[i--] = '0';
	} else {
		while (n > 0 && i >= 0) {
			buf[i--] = '0' + (n % 10);
			n /= 10;
		}
	}
	write(1, buf + i + 1, 15 - i);
}

/* ---- Ring buffer primitives ---- */

static inline uint32_t ring_load(volatile void *addr)
{
	return __atomic_load_n((volatile uint32_t *)addr, __ATOMIC_ACQUIRE);
}

static inline void ring_store(volatile void *addr, uint32_t val)
{
	__atomic_store_n((volatile uint32_t *)addr, val, __ATOMIC_RELEASE);
}

static uint32_t ring_read_h2g(volatile uint8_t *arena, uint8_t *buf,
			      uint32_t bufsz)
{
	volatile uint8_t *hdr = arena + H2G_HDR_OFF;
	volatile uint8_t *data = arena + H2G_DATA_OFF;

	uint32_t wi = ring_load(hdr + RING_WRITE_IDX);
	uint32_t ri = ring_load(hdr + RING_READ_IDX);
	uint32_t sz = *(volatile uint32_t *)(hdr + RING_SIZE);
	uint32_t avail = wi - ri;

	if (avail < 4)
		return 0;

	uint32_t mlen = 0;
	for (uint32_t i = 0; i < 4; i++)
		mlen |= (uint32_t)data[(ri + i) % sz] << (i * 8);
	ri += 4;

	if (mlen > avail - 4 || mlen > bufsz)
		return 0;

	for (uint32_t i = 0; i < mlen; i++)
		buf[i] = data[(ri + i) % sz];
	ri += mlen;

	ring_store(hdr + RING_READ_IDX, ri);
	return mlen;
}

static int ring_write_g2h(volatile uint8_t *arena, const uint8_t *buf,
			  uint32_t len)
{
	volatile uint8_t *hdr = arena + G2H_HDR_OFF;
	volatile uint8_t *data = arena + G2H_DATA_OFF;

	uint32_t wi = ring_load(hdr + RING_WRITE_IDX);
	uint32_t ri = ring_load(hdr + RING_READ_IDX);
	uint32_t sz = *(volatile uint32_t *)(hdr + RING_SIZE);
	uint32_t avail = sz - (wi - ri);

	if (4 + len > avail)
		return -1;

	for (uint32_t i = 0; i < 4; i++)
		data[(wi + i) % sz] = (len >> (i * 8)) & 0xFF;
	wi += 4;

	for (uint32_t i = 0; i < len; i++)
		data[(wi + i) % sz] = buf[i];
	wi += len;

	ring_store(hdr + RING_WRITE_IDX, wi);
	return 0;
}

/* ---- Phase 3: ring buffer echo test ---- */

static int phase3_main(volatile uint8_t *arena, int arena_fd)
{
	msg("revisor: phase 3 echo test\n");

	uint8_t buf[256];
	uint32_t n = 0;
	for (int tries = 0; tries < 1000000; tries++) {
		n = ring_read_h2g(arena, buf, sizeof(buf) - 1);
		if (n > 0)
			break;
	}

	if (n == 0) {
		msg("revisor: no message from host\n");
		reboot(RB_POWER_OFF);
		return 1;
	}

	buf[n] = '\0';
	msg("revisor: got from host: ");
	msg((char *)buf);
	msg("\n");

	uint8_t reply[300];
	const char *prefix = "echo: ";
	uint32_t plen = strlen(prefix);
	memcpy(reply, prefix, plen);
	memcpy(reply + plen, buf, n);
	ring_write_g2h(arena, reply, plen + n);

	ioctl(arena_fd, REVISOR_DOORBELL);
	msg("revisor: doorbell sent, waiting for host notification...\n");

	uint32_t event_count = 0;
	int ret = read(arena_fd, &event_count, sizeof(event_count));
	if (ret == sizeof(event_count))
		msg("revisor: got irq notification from host\n");
	else
		msg("revisor: read failed\n");

	return 0;
}

/* ---- Phase 4: IPC proxy ---- */

/* Send data + fds via sendmsg on a Unix socket. */
static int send_with_fds(int sockfd, const void *data, uint32_t len,
			 int *fds, int nfds)
{
	struct iovec iov = { .iov_base = (void *)data, .iov_len = len };
	struct msghdr mh = { .msg_iov = &iov, .msg_iovlen = 1 };

	char cmsgbuf[CMSG_SPACE(MAX_SHMEM * sizeof(int))];
	if (nfds > 0) {
		mh.msg_control = cmsgbuf;
		mh.msg_controllen = CMSG_SPACE(nfds * sizeof(int));
		struct cmsghdr *cmsg = CMSG_FIRSTHDR(&mh);
		cmsg->cmsg_level = SOL_SOCKET;
		cmsg->cmsg_type = SCM_RIGHTS;
		cmsg->cmsg_len = CMSG_LEN(nfds * sizeof(int));
		memcpy(CMSG_DATA(cmsg), fds, nfds * sizeof(int));
	}

	return sendmsg(sockfd, &mh, 0);
}

/* Handle a MSG_DATA_WITH_FDS message from the H2G ring. */
static void handle_data_with_fds(volatile uint8_t *arena, int arena_fd,
				 int ipc_fd, uint8_t *buf, uint32_t n)
{
	if (n < 6)
		return;

	uint32_t data_len = buf[1] | (buf[2] << 8) | (buf[3] << 16) | (buf[4] << 24);
	if (5 + data_len + 1 > n)
		return;

	uint8_t *data = buf + 5;
	uint8_t num_fds = buf[5 + data_len];
	uint8_t *fd_data = buf + 5 + data_len + 1;

	int fds[MAX_SHMEM];
	int nfds = 0;

	for (int i = 0; i < num_fds && i < MAX_SHMEM; i++) {
		uint32_t arena_off = fd_data[0] | (fd_data[1] << 8) |
				     (fd_data[2] << 16) | (fd_data[3] << 24);
		uint32_t size = fd_data[4] | (fd_data[5] << 8) |
				(fd_data[6] << 16) | (fd_data[7] << 24);
		fd_data += 8;

		/* Page-align offset and size for REVISOR_CREATE_REGION. */
		uint64_t aligned_off = arena_off & ~0xFFFULL;
		uint64_t aligned_size = ((arena_off + size - aligned_off) + 0xFFF) & ~0xFFFULL;

		struct revisor_region reg = {
			.offset = aligned_off,
			.size = aligned_size,
		};

		int region_fd = ioctl(arena_fd, REVISOR_CREATE_REGION, &reg);
		if (region_fd < 0) {
			msg("revisor: REVISOR_CREATE_REGION failed\n");
			continue;
		}

		fds[nfds++] = region_fd;
	}

	if (nfds > 0)
		send_with_fds(ipc_fd, data, data_len, fds, nfds);
	else if (data_len > 0)
		write(ipc_fd, data, data_len);

	for (int i = 0; i < nfds; i++)
		close(fds[i]);
}

/* Guest-side IPC proxy loop. */
static void run_proxy(volatile uint8_t *arena, int arena_fd, int ipc_fd)
{
	struct pollfd fds[2];
	fds[0].fd = arena_fd;
	fds[0].events = POLLIN;
	fds[1].fd = ipc_fd;
	fds[1].events = POLLIN;

	uint8_t buf[65536];

	for (;;) {
		int ret = poll(fds, 2, -1);
		if (ret < 0)
			break;

		/* Host -> guest: read H2G ring messages. */
		if (fds[0].revents & POLLIN) {
			uint32_t event_count;
			read(arena_fd, &event_count, sizeof(event_count));

			uint32_t n;
			while ((n = ring_read_h2g(arena, buf, sizeof(buf))) > 0) {
				if (n < 1)
					continue;
				if (buf[0] == MSG_DATA && n > 1) {
					write(ipc_fd, buf + 1, n - 1);
				} else if (buf[0] == MSG_DATA_WITH_FDS) {
					handle_data_with_fds(arena, arena_fd,
							     ipc_fd, buf, n);
				}
			}
		}

		/* Guest -> host: read from plugin-container socket. */
		if (fds[1].revents & POLLIN) {
			ssize_t n = read(ipc_fd, buf + 1, sizeof(buf) - 1);
			if (n <= 0)
				break;

			buf[0] = MSG_DATA;
			ring_write_g2h(arena, buf, 1 + n);
			ioctl(arena_fd, REVISOR_DOORBELL);
		}

		if (fds[1].revents & (POLLHUP | POLLERR))
			break;
	}
}

static int phase4_main(volatile uint8_t *arena, int arena_fd,
		       uint64_t arena_size)
{
	struct metadata_header *hdr =
		(struct metadata_header *)(arena + METADATA_OFF);

	msg("revisor: phase 4 init\n");
	msg_num("revisor: argc=", hdr->argc);
	msg_num("revisor: num_shmem=", hdr->num_shmem);
	msg_num("revisor: num_socket=", hdr->num_socket);

	if (hdr->argc > MAX_ARGS) {
		msg("revisor: too many args\n");
		return 1;
	}

	/* Parse argv strings. */
	char *argv[MAX_ARGS + 1];
	char *p = (char *)(arena + METADATA_OFF + hdr->argv_off);
	for (uint32_t i = 0; i < hdr->argc; i++) {
		argv[i] = p;
		p += strlen(p) + 1;
	}
	argv[hdr->argc] = (char *)0;

	msg("revisor: argv[0]=");
	msg(argv[0]);
	msg("\n");

	/* Reconstruct shmem fds: create memfds and copy data from arena. */
	struct shmem_entry *shmem =
		(struct shmem_entry *)(arena + METADATA_OFF + hdr->shmem_off);

	for (uint32_t i = 0; i < hdr->num_shmem && i < MAX_SHMEM; i++) {
		int fd = syscall(319, "revisor-shmem", 0); /* memfd_create */
		if (fd < 0) {
			msg("revisor: memfd_create failed\n");
			continue;
		}
		ftruncate(fd, shmem[i].size);

		void *mem = mmap((void *)0, shmem[i].size,
				 PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
		if (mem == MAP_FAILED) {
			msg("revisor: mmap memfd failed\n");
			close(fd);
			continue;
		}

		memcpy(mem, (void *)(arena + shmem[i].arena_offset),
		       shmem[i].size);
		munmap(mem, shmem[i].size);

		if ((uint32_t)fd != shmem[i].guest_fd) {
			dup2(fd, shmem[i].guest_fd);
			close(fd);
		}

		msg_num("revisor: shmem fd=", shmem[i].guest_fd);
	}

	/* Reconstruct socket fds: create socketpairs. */
	struct socket_entry *sockets =
		(struct socket_entry *)(arena + METADATA_OFF + hdr->socket_off);

	int proxy_fds[MAX_SOCKET]; /* our end of each socketpair */
	int ipc_proxy_fd = -1;

	for (uint32_t i = 0; i < hdr->num_socket && i < MAX_SOCKET; i++) {
		int sv[2];
		if (socketpair(AF_UNIX, SOCK_STREAM, 0, sv) < 0) {
			msg("revisor: socketpair failed\n");
			proxy_fds[i] = -1;
			continue;
		}

		/* sv[1] goes to plugin-container at the expected fd number. */
		if ((uint32_t)sv[1] != sockets[i].guest_fd) {
			dup2(sv[1], sockets[i].guest_fd);
			close(sv[1]);
		}

		proxy_fds[i] = sv[0];
		msg_num("revisor: socket fd=", sockets[i].guest_fd);

		/* Use the first socket as the IPC proxy fd. */
		if (ipc_proxy_fd < 0)
			ipc_proxy_fd = sv[0];
	}

	if (ipc_proxy_fd < 0) {
		msg("revisor: no IPC socket, skipping proxy\n");
		/* In test mode, just print what we parsed and exit. */
		msg("revisor: phase 4 metadata parsed successfully\n");
		return 0;
	}

	/* Fork: parent runs proxy, child execs plugin-container. */
	pid_t pid = fork();
	if (pid < 0) {
		msg("revisor: fork failed\n");
		return 1;
	}

	if (pid == 0) {
		/* Child: close proxy ends, exec plugin-container. */
		for (uint32_t i = 0; i < hdr->num_socket && i < MAX_SOCKET; i++) {
			if (proxy_fds[i] >= 0)
				close(proxy_fds[i]);
		}

		msg("revisor: execing ");
		msg(argv[0]);
		msg("\n");

		execv(argv[0], argv);

		msg("revisor: execv failed\n");
		_exit(1);
	}

	/* Parent: close child's fd ends, run proxy loop. */
	for (uint32_t i = 0; i < hdr->num_socket && i < MAX_SOCKET; i++)
		close(sockets[i].guest_fd);

	msg("revisor: starting proxy loop\n");
	run_proxy(arena, arena_fd, ipc_proxy_fd);

	/* Wait for child. */
	int status;
	waitpid(pid, &status, 0);
	msg("revisor: child exited\n");

	return 0;
}

/* ---- Main ---- */

int main(void)
{
	mount("dev", "/dev", "devtmpfs", 0, (void *)0);
	setup_console();
	mount("proc", "/proc", "proc", 0, (void *)0);
	mount("sys", "/sys", "sysfs", 0, (void *)0);

	msg("revisor: guest init running\n");

	/* Open the arena device. */
	int arena_fd = open("/dev/revisor-arena", O_RDWR);
	if (arena_fd < 0) {
		msg("revisor: failed to open /dev/revisor-arena\n");
		reboot(RB_POWER_OFF);
		return 1;
	}

	/* Query arena size. */
	uint64_t arena_size = 0;
	if (ioctl(arena_fd, REVISOR_GET_SIZE, &arena_size) < 0 ||
	    arena_size == 0) {
		msg("revisor: REVISOR_GET_SIZE failed, using default\n");
		arena_size = 0x1000000; /* 16 MiB fallback */
	}

	/* mmap the full arena. */
	volatile uint8_t *arena = mmap((void *)0, arena_size,
		PROT_READ | PROT_WRITE, MAP_SHARED, arena_fd, 0);
	if (arena == MAP_FAILED) {
		msg("revisor: failed to mmap arena\n");
		reboot(RB_POWER_OFF);
		return 1;
	}

	int ret;

	/* Check for Phase 4 metadata magic. */
	uint32_t magic = *(volatile uint32_t *)(arena + METADATA_OFF);
	if (magic == METADATA_MAGIC) {
		ret = phase4_main(arena, arena_fd, arena_size);
	} else {
		ret = phase3_main(arena, arena_fd);
	}

	reboot(RB_POWER_OFF);
	return ret;
}
