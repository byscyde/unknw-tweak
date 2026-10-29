// Shared diagnostic logger — appends to the UNKNW log shown in the Diagnostics
// screen (same file as Developer Logging), gated by the Developer Logging pref.

#import "../UNKNW.h"

void UNKNWDiagLog(NSString *line) {
    if (!line || !UNKNWPrefBool(kUNKNWDebugLoggingKey, NO)) return;
    NSURL *as = [NSFileManager.defaultManager URLForDirectory:NSApplicationSupportDirectory
                                                     inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
    NSURL *dir = [as URLByAppendingPathComponent:@"UNKNW" isDirectory:YES];
    [NSFileManager.defaultManager createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *path = [[dir URLByAppendingPathComponent:@"classes.log"] path];
    NSData *d = [[line stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding];
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:path];
    if (!fh) { [[line stringByAppendingString:@"\n"] writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil]; return; }
    @try { [fh seekToEndOfFile]; [fh writeData:d]; } @catch (__unused id e) {} @finally { [fh closeFile]; }
}
