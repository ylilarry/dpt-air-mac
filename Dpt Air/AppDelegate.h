//
//  AppDelegate.h
//  Dpt Air
//
//  Created by Yu Li on 2019-05-27.
//  Copyright © 2019 Yu Li. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include <memory>
#include <iostream>
#import "Settings.h"
#include <dptrp1/dptrp1.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>
@property (weak) IBOutlet NSWindow *window;
@property NSStatusItem* statusItem;
@property IBOutlet NSMenu* statusItemMenu;
@property std::shared_ptr<dpt::Dpt> dpt;
@property IBOutlet Settings* settings;
@property BOOL dpt_authenticated;
@property NSLock* dpt_lock;
@property BOOL dpt_busy;
@property BOOL setup_ready;
@property NSString* status_title;
@property NSString* message;
@property std::shared_ptr<std::ofstream> log_file;
@property NSURL* shared_app_dir;
- (NSURL*)unsafe_sync_dir;
@end

@interface NSApplication(Dpt)
- (AppDelegate*)appDelegate;
@end
