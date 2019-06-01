//
//  common.h
//  Dpt Air
//
//  Created by Yu Li on 2019-06-01.
//  Copyright © 2019 Yu Li. All rights reserved.
//

#ifndef common_h
#define common_h

#import <Cocoa/Cocoa.h>

@interface NSURL(Dpt)
- (void)withSecured:(void (^_Nonnull)(NSURL* __nonnull url))fn;
+ (NSURL * _Nonnull)applicationDocumentsDirectory;
@end

#endif /* common_h */
