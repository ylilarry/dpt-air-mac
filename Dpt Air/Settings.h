//
//  Settings.h
//  Dpt Air
//
//  Created by Yu Li on 2019-05-29.
//  Copyright © 2019 Yu Li. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface Settings : NSViewController

@property IBOutlet NSArrayController* bluetoothDevices;
@property IBOutlet NSTableView* bluetoothTable;

@end

NS_ASSUME_NONNULL_END
