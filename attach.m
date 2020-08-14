#include <IOKit/IOKitLib.h>
#include <IOKit/IOCFSerialize.h>
#include <CoreFoundation/CoreFoundation.h>
#include <assert.h>
#include <sys/param.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>

// based on debug_image_mount

int main(int argc, char **argv) {
    if(!argv[1]) {
        fprintf(stderr, "Usage: attach file.dmg\n");
        return 1;
    }

    char *abspath = realpath(argv[1], NULL);
    if(!abspath) {
        fprintf(stderr, "couldn't resolve file: %s\n", strerror(errno));
        return 1;
    }

    io_service_t service = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOHDIXController"));
    assert(service);
    io_connect_t connect;
    assert(!IOServiceOpen(service, mach_task_self(), 0, &connect));

    CFStringRef uuid = CFUUIDCreateString(NULL, CFUUIDCreate(kCFAllocatorDefault));
    CFMutableDictionaryRef props = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFDictionarySetValue(props, CFSTR("hdik-unique-identifier"), uuid);
    CFDataRef path = CFDataCreateWithBytesNoCopy(kCFAllocatorDefault, (UInt8 *) abspath, strlen(abspath), kCFAllocatorNull);
    assert(path);
    CFDictionarySetValue(props, CFSTR("image-path"), path);
    /*
    int fd = open(abspath, 0);
    assert(fd != -1);
    void *nsfd = [NSNumber numberWithInt:fd];
    CFDictionarySetValue(props, CFSTR("image-fd"), nsfd);
    */
    //CFDataRef props_data = IOCFSerialize(props, 0);
    CFDataRef props_data = CFPropertyListCreateData(kCFAllocatorDefault, props, 0x64, 0LL, 0LL);
    assert(props_data);

    struct HDIImageCreateBlock64 {
        uint32_t magic;
        uint32_t one;
        char *props;
        uint64_t props_size;
        char ignored[0xf8 - 16];
    } stru;
    memset(&stru, 0, sizeof(stru));
    stru.magic = 0xbeeffeed;
    stru.one = 1;
    stru.props = (char *) CFDataGetBytePtr(props_data);
    stru.props_size = CFDataGetLength(props_data);
    assert(offsetof(struct HDIImageCreateBlock64, props) == 8);
    //printf("%s\n", stru.props);
    //printf("%lld\n", stru.props_size);
    uint32_t val;
    size_t val_size = sizeof(val);

    kern_return_t ret = IOConnectCallStructMethod(connect, 0, &stru, 0x100, &val, &val_size);
    if(ret) {
        fprintf(stderr, "returned %x\n", ret);
        return 1;
    }
    assert(val_size == sizeof(val));
    
    CFMutableDictionaryRef pmatch = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFDictionarySetValue(pmatch, CFSTR("hdik-unique-identifier"), uuid);
    CFMutableDictionaryRef matching = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFDictionarySetValue(matching, CFSTR("IOPropertyMatch"), pmatch);
    service = IOServiceGetMatchingService(kIOMasterPortDefault, matching);
    if(!service) {
        fprintf(stderr, "successfully attached, but didn't find top entry in IO registry\n");
        return 1;
    }

    bool ok = false;
    io_iterator_t iter;
    assert(!IORegistryEntryCreateIterator(service, kIOServicePlane, kIORegistryIterateRecursively, &iter));
    while( (service = IOIteratorNext(iter)) ) {
        CFStringRef bsd_name = IORegistryEntryCreateCFProperty(service, CFSTR("BSD Name"), NULL, 0);
        if(bsd_name) {
            char buf[MAXPATHLEN];
            assert(CFStringGetCString(bsd_name, buf, sizeof(buf), kCFStringEncodingUTF8));
            puts(buf);
            ok = true;
        }
    }

    if(!ok) {
        fprintf(stderr, "successfully attached, but didn't find BSD name in IO registry\n");
        return 1;
    }
    return 0;
}