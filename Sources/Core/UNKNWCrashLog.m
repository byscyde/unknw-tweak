// In-app crash capture.
//
// Instagram crashes on a background thread from an uncaught Objective-C
// exception (SIGABRT). The .ips report is awkward to pull on a phone, so we
// record the exception name, reason and stack straight into the UNKNW log
// (Library/Application Support/UNKNW/classes.log) — the same file the in-app
// Diagnostics screen shows — so it can be copied out in two taps.
//
// We also catch the fatal signals (the abort that follows the exception, plus
// native crashes) and dump a backtrace via async-signal-safe primitives.
//
// This only observes; it never swallows the crash (it re-raises), so behaviour
// is unchanged apart from the extra log lines.

#import "../UNKNW.h"
#import <execinfo.h>
#import <signal.h>
#import <fcntl.h>
#import <unistd.h>
#import <string.h>

static int unknw_crash_fd = -1;
static NSUncaughtExceptionHandler *unknw_prev_handler = NULL;

static NSString *UNKNWCrashLogPath(void) {
    NSURL *appSupport = [NSFileManager.defaultManager URLForDirectory:NSApplicationSupportDirectory
                                                             inDomain:NSUserDomainMask
                                                    appropriateForURL:nil create:YES error:nil];
    NSURL *dir = [appSupport URLByAppendingPathComponent:@"UNKNW" isDirectory:YES];
    [NSFileManager.defaultManager createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return [[dir URLByAppendingPathComponent:@"classes.log"] path];
}

static void UNKNWCrashAppend(NSString *text) {
    NSString *path = UNKNWCrashLogPath();
    if (!path) return;
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:path];
    if (!fh) { [text writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil]; return; }
    @try { [fh seekToEndOfFile]; [fh writeData:[text dataUsingEncoding:NSUTF8StringEncoding]]; }
    @catch (__unused NSException *e) {}
    @finally { [fh closeFile]; }
}

static void UNKNWExceptionHandler(NSException *ex) {
    NSString *s = [NSString stringWithFormat:
        @"\n=== UNKNW UNCAUGHT EXCEPTION @ %@ ===\nthread: %@\nname:   %@\nreason: %@\nstack:\n%@\n=== END ===\n",
        [NSDate date], [NSThread currentThread], ex.name, ex.reason,
        [ex.callStackSymbols componentsJoinedByString:@"\n"]];
    UNKNWCrashAppend(s);
    if (unknw_prev_handler) unknw_prev_handler(ex);
}

static void UNKNWSignalHandler(int sig) {
    if (unknw_crash_fd >= 0) {
        const char *hdr = "\n=== UNKNW FATAL SIGNAL ===\n";
        (void)write(unknw_crash_fd, hdr, strlen(hdr));
        char buf[48];
        int n = snprintf(buf, sizeof buf, "signal: %d\n", sig);
        if (n > 0) (void)write(unknw_crash_fd, buf, (size_t)n);
        void *frames[64];
        int c = backtrace(frames, 64);
        backtrace_symbols_fd(frames, c, unknw_crash_fd);
        const char *end = "=== END ===\n";
        (void)write(unknw_crash_fd, end, strlen(end));
    }
    signal(sig, SIG_DFL);
    raise(sig);
}

static void UNKNWArmHandlers(void) {
    // Chain, don't clobber, whatever handler is currently installed (FB installs
    // its own crash reporter, sometimes after us — re-arming wins the race).
    NSUncaughtExceptionHandler *cur = NSGetUncaughtExceptionHandler();
    if (cur != &UNKNWExceptionHandler) unknw_prev_handler = cur;
    NSSetUncaughtExceptionHandler(&UNKNWExceptionHandler);

    int sigs[] = { SIGABRT, SIGSEGV, SIGBUS, SIGILL, SIGTRAP, SIGFPE };
    for (unsigned i = 0; i < sizeof(sigs) / sizeof(sigs[0]); i++)
        signal(sigs[i], UNKNWSignalHandler);
}

void UNKNWInstallCrashLogger(void) {
    static BOOL done = NO;
    if (done) return;
    done = YES;

    NSString *path = UNKNWCrashLogPath();
    if (path) unknw_crash_fd = open(path.fileSystemRepresentation, O_WRONLY | O_CREAT | O_APPEND, 0644);

    UNKNWCrashAppend([NSString stringWithFormat:@"\n[UNKNW] launch %@ — crash logger armed\n", [NSDate date]]);
    UNKNWArmHandlers();

    // Re-arm shortly after launch to override any crash handler Instagram's
    // own frameworks install later.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ UNKNWArmHandlers(); });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(12 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ UNKNWArmHandlers(); });

    UNKNWLog(@"crash logger installed");
}
