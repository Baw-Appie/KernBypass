#include <stdio.h>
#import <Foundation/Foundation.h>
#include <CommonCrypto/CommonCrypto.h>

#include "config.h"
#include "kernel.h"
#include "vnode_utils.h"
#include "utils.h"

#include <sys/syscall.h>
#include <sys/snapshot.h>
#include <dirent.h>
#include <sys/stat.h>

@import Darwin.POSIX.spawn;


void hardlink_var(const char *path) {
    char src[1024];
    const char *relapath = path + strlen(FINAL_FAKEVARDIR);
    snprintf(src, sizeof(src), "/private/var/%s", relapath);
    printf("Linking: %s -> %s\n", src, path);
    //uint64_t vp1 = 0, vp2 = 0;
    //copyFileInMemory((char *)path, src, &vp1, &vp2);
    copy_file_in_memory((char *)path, src, true);
}

void listdir(const char *name, int indent) {
    DIR *dir;
    struct dirent *entry;

    if (!(dir = opendir(name)))
        return;
    
    char path[1024];
    int childs = 0;
    while ((entry = readdir(dir)) != NULL) {
        snprintf(path, sizeof(path), "%s/%s", name, entry->d_name);
        if (entry->d_type == DT_DIR) {
            if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0)
                continue;
            printf("%*s[%s]\n", indent, "", entry->d_name);
            listdir(path, indent + 2);
            childs += 1;
        } else {
            hardlink_var(path);
            printf("%*s- %s\n", indent, "", entry->d_name);
            childs += 1;
        }
    }
    if (childs == 0) {
    if (indent == 0) {
        printf("FATAL! Empty fakevar root!!\n");
        return; 
    }
        hardlink_var(name);
    }
    closedir(dir);
}

#ifndef USE_DEV_FAKEVAR

void run_cmd(char *cmd)
{
    pid_t pid;
    char *argv[] = {"sh", "-c", cmd, NULL};
    int status;
    
    status = posix_spawn(&pid, "/bin/sh", NULL, NULL, argv, NULL);
    if (status == 0) {
        if (waitpid(pid, &status, 0) == -1) {
            perror("waitpid");
        }
    }
}
static void easy_spawn(const char* args[]) {
    pid_t pid;
    int status;
    posix_spawn(&pid, args[0], NULL, NULL, (char* const*)args, NULL);
    waitpid(pid, &status, WEXITED);
}

int mount_dmg(const char *mountpoint) {
    printf("attaching our fakevar dmg %s\n", FAKEVAR_DMG);
    FILE* fp = popen("attach "FAKEVAR_DMG, "r");
    usleep(1000*1000*2);
    char buf[100] = {0};
    size_t ret = fread(buf, 1, sizeof(buf) - 1, fp);
    if (ret <= 0) {
        printf("attach "FAKEVAR_DMG);
        printf("failed to attach dmg!\n");
        return 1;
    }
    printf("got attach command output (%zu bytes): %s\n", ret, buf);
    while (buf[--ret] == '\n')
        ;
    buf[ret+1] = 0;
        
    
    char *diskpath = strrchr(buf, '\n') + 1;
    if (!(diskpath-1) || strncmp(diskpath, "disk", 4) != 0) {
        printf("Unexpected attach output: %s", diskpath);
        return 1;
    }
    printf("parsed attached disk path %s\n", diskpath);
    
    int err;
    /*
    typedef struct {
        char     *fspec;
        uid_t     hfs_uid;
        gid_t     hfs_gid;
        mode_t    hfs_mask;
        u_int32_t hfs_encoding;
        struct    timezone hfs_timezone;
        int       flags;
        int       journal_tbuffer_size;
        int       journal_flags;
        int       journal_disable;
    } hfs_mount_args;
    hfs_mount_args arg = { 0 };
    arg.fspec = diskpath;
    arg.hfs_uid = 501;
    arg.hfs_gid = 501;
    arg.hfs_mask = 0755;
    int err = mount("hfs", FAKEROOTDIR"/private/var", 0, &arg);
    if(err != 0){
        printf("mount fakevar fs error = %d\n", err);
        return 1;
    }*/
    char command[1000] = { 0 };
    snprintf(command, sizeof(command), "fsck_hfs /dev/%s", diskpath);
    printf("Executing command: %s\n", command);
    run_cmd(command);
    // err = system(command);
    // if (err != 0) {
    //     printf("fsck fakevar dmg failed!!\n");
    //     return 1;
    // }
    //snprintf(command, sizeof(command), "mount -t hfs /dev/%s %s", diskpath, FAKEROOTDIR"/private/var");
    snprintf(command, sizeof(command), "mount -t hfs /dev/%s %s", diskpath, mountpoint);
    printf("Executing command: %s\n", command);
    run_cmd(command);
    // err = system(command);
    // if(err != 0){
    //     printf("mount devfs error = %d\n", err);
    //     return 1;
    // }
    
    return 0;
}

int link_folders() {
    int fd = open("/var/", O_RDONLY);
    // fs_snapshot_mount(fd, "/var/fakevarmnt", "kernbypass-fakevar", 0);
    int err = fs_snapshot_mount(fd, "/var/fakevarmnt", "kernbypass-fakevar", 0);
    if(err != 0) {
        printf("kernbypass-fakevar mount error %d\n", err);
        return 0;
    }

    // if (mount_dmg(FAKEROOTDIR"/private/var") != 0) {
    //     printf("mount dmg fail!\n");
    //     return 1;
    // }
    // copy_file_in_memory(FAKEROOTDIR"/private/var/", "/private/fakevardir/", true);
    copy_file_in_memory(FAKEROOTDIR"/private/var", "/var/fakevarmnt/fakevardir", true);
    // copy_file_in_memory(FAKEROOTDIR"/private/var/containers", "/private/var/containers", true);
    // copy_file_in_memory(FAKEROOTDIR"/private/var/cache", "/private/var/cache", true);
    listdir(FAKEROOTDIR"/private/var", 0);
    return 0;
}

#else

int link_folders() {
    /*mkdir(FAKEVAR_TMPMOUNT, 0755);
    
    printf("Mounting fakevar dmg %s\n", FINAL_FAKEVARDIR);
    if (mount_dmg(FAKEVAR_TMPMOUNT) != 0) {
        printf("mount dmg fail!\n");
        return 1;
    }*/
    
    //forceWritablePath(FAKEROOTDIR);
    /*printf("Making final fakevar dir: %s\n", FINAL_FAKEVARDIR);
    if (mkdir(FINAL_FAKEVARDIR, 0755)) {
        return 1;
    }*/

    //printf("Copyiny fakevar dir from: %s\n", FAKEVAR_TMPMOUNT);
    //system("cp -r -a "FAKEVAR_TMPMOUNT"/* "FINAL_FAKEVARDIR"/");
    printf("Copyiny fakevar dir from: %s\n", FAKEVARDIR);
    //system("cp -r "FAKEVARDIR"/* "FINAL_FAKEVARDIR"/");
    if (copy_dir(FAKEVARDIR, FINAL_FAKEVARDIR)) {
        return 1;
    }

    printf("Linking fakevar dir!\n");
    listdir(FINAL_FAKEVARDIR, 0);
    
    printf("Linking fakevar to var!\n");
    copy_file_in_memory(FAKEROOTDIR"/private/var", FINAL_FAKEVARDIR, true);
    return 0;
}

#endif

void prepareFakeVar() {
    mkdir("/var/fakevarmnt", 755);
    mkdir("/var/fakevardir", 755);
    mkdir("/var/fakevardir/audit", 755);
    mkdir("/var/fakevardir/backups", 755);
    mkdir("/var/fakevardir/buddy", 755);
    mkdir("/var/fakevardir/cache", 755);
    mkdir("/var/fakevardir/containers", 755);
    mkdir("/var/fakevardir/containers/Bundle", 755);
    mkdir("/var/fakevardir/containers/Bundle/Application", 755);
    mkdir("/var/fakevardir/containers/Bundle/Framework", 755);
    mkdir("/var/fakevardir/containers/Bundle/PluginKitPlugin", 755);
    mkdir("/var/fakevardir/containers/Bundle/VPNPlugin", 755);
    mkdir("/var/fakevardir/containers/Data", 755);
    mkdir("/var/fakevardir/containers/Shared", 755);
    mkdir("/var/fakevardir/empty", 755);
    mkdir("/var/fakevardir/folders", 755);
    mkdir("/var/fakevardir/hardware", 755);
    mkdir("/var/fakevardir/installd", 755);
    mkdir("/var/fakevardir/iomfb_bics_daemon", 755);
    mkdir("/var/fakevardir/keybags", 755);
    mkdir("/var/fakevardir/Keychains", 755);
    mkdir("/var/fakevardir/local", 755);
    mkdir("/var/fakevardir/lock", 755);
    mkdir("/var/fakevardir/log", 755);
    mkdir("/var/fakevardir/logs", 755);
    mkdir("/var/fakevardir/Managed Preferences", 755);
    mkdir("/var/fakevardir/mobile", 755);
    mkdir("/var/fakevardir/MobileAsset", 755);
    mkdir("/var/fakevardir/MobileDevice", 755);
    mkdir("/var/fakevardir/msgs", 755);
    mkdir("/var/fakevardir/networkd", 755);
    mkdir("/var/fakevardir/preferences", 755);
    mkdir("/var/fakevardir/root", 755);
    mkdir("/var/fakevardir/run", 755);
    mkdir("/var/fakevardir/select", 755);
    mkdir("/var/fakevardir/spool", 755);
    mkdir("/var/fakevardir/staged_system_apps", 755);
    mkdir("/var/fakevardir/tmp", 755);
    mkdir("/var/fakevardir/vm", 755);
    mkdir("/var/fakevardir/wireless", 755);
    int fd = open("/var/", O_RDONLY);

    // if(!is_empty("/var/fakevarmnt")) {
    //     easy_spawn((const char *[]){"/sbin/umount", "-f", "/var/fakevarmnt", NULL});
    // }
    int err1 = fs_snapshot_delete(fd, "kernbypass-fakevar", 0);
    if(err1 != 0) {
        printf("kernbypass-fakevar delete error %d\n", err1);
    }
    int err2 = fs_snapshot_create(fd, "kernbypass-fakevar", 0);
    if(err2 != 0) {
        printf("kernbypass-fakevar create error %d\n", err2);
    }
}

int main(int argc, char *argv[], char *envp[]) {

    prepareFakeVar();
    
    if(!is_empty(FAKEROOTDIR) && access(FAKEROOTDIR"/private/var/containers/Bundle", F_OK) == 0){
        printf("error already mounted\n");
        return 1;
    }
    
    int err = init_kernel();
    if (err) {
        return 1;
    }
    
    if (is_empty(FAKEROOTDIR)){

        int fd = open("/", O_RDONLY);
        
        printf("open root directory fd = %d\n", fd);
        
        printf("trying to mount kernbypass snapshot...");
        err = fs_snapshot_mount(fd, FAKEROOTDIR, "kernbypass", 0);
        
        if(err != 0){
            printf("failed to mount kernbypass snapshot(error %d), fallbacking to orig-fs\n", err);

            err = fs_snapshot_mount(fd, FAKEROOTDIR, "orig-fs", 0);
            if(err != 0){
                printf("mount snapshot error = %d\n", err);
                return 1;
            }
        }
        
        err = mount("devfs", FAKEROOTDIR"/dev", 0, 0);
        
        if(err != 0){
            printf("mount devfs error = %d\n", err);
            return 1;
        }
        
        close(fd);
    }
    
    return link_folders();
}