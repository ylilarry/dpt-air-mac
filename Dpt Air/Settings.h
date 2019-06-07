//
//  Settings.h
//  Dpt Air
//
//  Created by Yu Li on 2019-05-29.
//  Copyright © 2019 Yu Li. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface SettingsView : NSView
@end

@interface TextPopoverViewController : NSViewController
@property IBOutlet NSTextField* label;
@end

@interface TextPopover : NSPopover
@property NSString* text;
@end

@interface Settings : NSViewController

@property IBOutlet NSArrayController* bluetoothDevices;
@property IBOutlet NSTableView* bluetoothTable;
@property IBOutlet NSTableView* rollbackTable;
@property IBOutlet NSArrayController* rollbackHistory;
@property IBOutlet TextPopover* textPopover;

@end

NS_ASSUME_NONNULL_END
