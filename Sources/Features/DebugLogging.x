// Developer Logging — the diagnostic/starter feature.
//
// Logs the class name of every view controller as it appears, both to the
// console (filter "[UNKNW]") and to a file you can pull off the device without a
// Mac: Library/Application Support/UNKNW/classes.log (via iMazing / 3uTools).
// Use it to discover the real Instagram class names to hook — including the beta
// update screen's class.

#import "../UNKNW.h"

static void UNKNWAppendClassLog(NSString *line) {
    static NSString *path = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSURL *appSupport = [NSFileManager.defaultManager URLForDirectory:NSApplicationSupportDirectory
                                                                 inDomain:NSUserDomainMask
                                                        appropriateForURL:nil create:YES error:nil];
        NSURL *dir = [appSupport URLByAppendingPathComponent:@"UNKNW" isDirectory:YES];
        [NSFileManager.defaultManager createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:nil];
        path = [[dir URLByAppendingPathComponent:@"classes.log"] path];
    });
    if (!path) return;
    NSString *entry = [line stringByAppendingString:@"\n"];
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:path];
    if (!fh) { [entry writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil]; return; }
    @try { [fh seekToEndOfFile]; [fh writeData:[entry dataUsingEncoding:NSUTF8StringEncoding]]; }
    @catch (__unused NSException *e) {}
    @finally { [fh closeFile]; }
}

%group UNKNWDebugLogging

%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    NSString *line = [NSString stringWithFormat:@"viewDidAppear → %@", NSStringFromClass([self class])];
    UNKNWLog(@"%@", line);
    UNKNWAppendClassLog(line);
}

%end

%end

void UNKNWInitDebugLogging(void) {
    %init(UNKNWDebugLogging);
}
