//
//  main.m
//  Dpt Air Bluetooth Helper
//
//  Created by Yu Li on 2019-06-01.
//  Copyright © 2019 Yu Li. All rights reserved.
//

#import <Cocoa/Cocoa.h>

int main(int argc, const char * argv[]) {
    
    NSURL* shared_dir = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:@"group.com.dpt-air"];
    NSURL* bluetooth_file = [shared_dir URLByAppendingPathComponent:@"bluetooth"];
    NSString* bluetooth_id = [[NSString alloc] initWithContentsOfURL:bluetooth_file encoding:NSUTF8StringEncoding error:nil];
    
    NSDictionary* error;

    NSString* script = [[NSString alloc] initWithFormat:@"\
                        set DeviceName to \"%@\"\n\
                        tell application \"System Events\" to tell process \"SystemUIServer\"\n\
                        set bt to (first menu bar item whose description is \"bluetooth\") of menu bar 1\n\
                        click bt\n\
                        if exists menu item DeviceName of menu of bt then\n\
                        tell (first menu item whose title is DeviceName) of menu of bt\n\
                        click\n\
                        tell menu 1\n\
                        if exists menu item \"Connect to Network\" then\n\
                        click menu item \"Connect to Network\"\n\
                        return \"Connecting...\"\n\
                        else\n\
                        key code 53 -- hit Escape to close BT menu\n\
                        return \"No connect button; is it already connected?\"\n\
                        end if\n\
                        end tell\n\
                        end tell\n\
                        else\n\
                        key code 53 -- hit Escape to close BT menu\n\
                        return \"Cannot find that device, check the name\"\n\
                        end if\n\
                        end tell\n\
                        return input", bluetooth_id];
    
    NSLog(@"%@", script);

    [[[NSAppleScript alloc] initWithSource:script] executeAndReturnError:&error];

    if (error) {
        NSLog(@"Error: %@", error);
    }
}
