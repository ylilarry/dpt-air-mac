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


namespace dpt {
    class Dpt;
}


@interface AppDelegate : NSObject <NSApplicationDelegate>

    @property (weak) IBOutlet NSWindow *window;
    @property NSStatusItem* statusItem;
    @property IBOutlet NSMenu* statusItemMenu;
    @property std::shared_ptr<dpt::Dpt> m_dpt;
    @property IBOutlet Settings* settings;
    @property BOOL dpt_authenticated;
    @property BOOL dpt_busy;
    @property BOOL setup_ready;
    @property NSString* message;
    @property std::shared_ptr<std::ofstream> log_file;
    @property NSURL* shared_app_dir;
@end
