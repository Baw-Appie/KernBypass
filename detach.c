#include <assert.h>
#include <stdio.h>
//#include <sys/disk.h>
#include <sys/ioctl.h>
#define DKIOCEJECT                            _IO('d', 21)
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>

int main(int argc, char **argv) {
    if(!argv[1]) {
        fprintf(stderr, "Usage: detach diskN\n");
        return 1;
    }

    char *p = argv[1];
    if(p[0] != '/') {
        asprintf(&p, "/dev/%s", p);
    }

    int fd = open(p, O_RDONLY);
    if(fd == -1) {
        fprintf(stderr, "Could not open: %s\n", strerror(errno));
        return 1;
    }

    int ret = ioctl(fd, DKIOCEJECT);
    if(ret == -1) {
        fprintf(stderr, "Could not ioctl(DKIOCEJECT): %s\n", strerror(errno));
    }

    return 0;
}