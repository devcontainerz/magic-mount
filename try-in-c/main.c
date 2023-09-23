#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/mount.h>

void print_usage() {
    printf("Usage: ./mount-to-container <container> <hostpath> <containerpath>\n\n");
    printf("This mounts <hostpath> into <containerpath> into the running container <container>.\n");
}

int main(int argc, char *argv[]) {
    if (argc < 4 || strcmp(argv[1], "-h") == 0 || strcmp(argv[1], "--help") == 0) {
        print_usage();
        return 0;
    }

    const char *container = argv[1];
    const char *hostpath = argv[2];
    const char *contpath = argv[3];

    char realpath[PATH_MAX];
    if (realpath(hostpath, realpath) == NULL) {
        perror("Error resolving hostpath");
        return 1;
    }

    struct stat st;
    if (stat(realpath, &st) == -1) {
        perror("Error getting file system information");
        return 1;
    }

    char *filesystem = NULL;
    FILE *mounts = fopen("/proc/mounts", "r");
    if (mounts == NULL) {
        perror("Error opening /proc/mounts");
        return 1;
    }

    char line[1024];
    while (fgets(line, sizeof(line), mounts)) {
        char dev[1024], mount[1024], junk[1024];
        if (sscanf(line, "%s %s %s", dev, mount, junk) != 3) {
            continue;
        }

        if (strcmp(mount, realpath) == 0) {
            filesystem = strdup(dev);
            break;
        }
    }

    fclose(mounts);

    if (filesystem == NULL) {
        fprintf(stderr, "Error: Filesystem not found\n");
        return 1;
    }

    FILE *mountinfo = fopen("/proc/self/mountinfo", "r");
    if (mountinfo == NULL) {
        perror("Error opening /proc/self/mountinfo");
        return 1;
    }

    char subroot[1024];
    while (fgets(line, sizeof(line), mountinfo)) {
        char mount[1024];
        if (sscanf(line, "%*d %*d %*d %s %s %s", subroot, mount, junk) != 3) {
            continue;
        }

        if (strcmp(mount, realpath) == 0) {
            break;
        }
    }

    fclose(mountinfo);

    char *subpath = realpath + strlen(filesystem);
    int devdec = st.st_dev;

    // Perform equivalent Docker operations here

    // For example, to create a block device node:
    // mknod(device, S_IFBLK | 0600, devdec);

    // Mount the device to a temporary mount point

    // Mount the bind mount from the temporary mount point to the container path

    // Clean up

    return 0;
}
