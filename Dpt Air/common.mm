//
//  common.m
//  Dpt Air
//
//  Created by Yu Li on 2019-06-01.
//  Copyright © 2019 Yu Li. All rights reserved.
//

#import "common.h"


@implementation NSURL(Dpt)
- (void)withSecured:(void (^_Nonnull)(NSURL* __nonnull url))fn;
{
    NSData* data;
    NSURL* safe;
    NSError* error;
    BOOL stale = FALSE;
    // get saved data
    data = [NSUserDefaults.standardUserDefaults valueForKey:self.absoluteString];
    // decode
    safe = [NSURL URLByResolvingBookmarkData:data options:NSURLBookmarkResolutionWithSecurityScope relativeToURL:nil bookmarkDataIsStale:&stale error:nil];
    // re-encode until not stale
    if (stale || safe == nil) {
        // re-encode
        data = [self bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope includingResourceValuesForKeys:nil relativeToURL:nil error:&error];
        // verify
        safe = [NSURL URLByResolvingBookmarkData:data options:NSURLBookmarkResolutionWithSecurityScope relativeToURL:nil bookmarkDataIsStale:&stale error:nil];
        if (error) { NSLog(@"%@", error); }
    }
    // callback
    [safe startAccessingSecurityScopedResource];
    fn(safe);
    [safe stopAccessingSecurityScopedResource];
    // save
    [NSUserDefaults.standardUserDefaults setValue:data forKey:self.absoluteString];
}

+ (NSURL *)applicationDocumentsDirectory
{
    return [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:@"group.com.dpt-air"];
}
@end
