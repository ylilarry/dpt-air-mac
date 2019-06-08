//
//  AppDelegate.m
//  Dpt Air
//
//  Created by Yu Li on 2019-05-27.
//  Copyright © 2019 Yu Li. All rights reserved.
//

#import "AppDelegate.h"
#include <memory>
#include <dptrp1.h>
#import <IOBluetooth/IOBluetooth.h>
#import <IOBluetoothUI/IOBluetoothUI.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <CoreFoundation/CoreFoundation.h>
#import "common.h"

@implementation NSApplication(Dpt)
- (AppDelegate*)appDelegate
{
    return self.delegate;
}
@end

@implementation AppDelegate

- (NSURL*)unsafe_sync_dir
{
    return [NSUserDefaults.standardUserDefaults URLForKey:@"sync_dir"];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    using namespace std;
    using namespace dpt;
    self.dpt_lock = [[NSLock alloc] init];
    self.status_title = @"DP";
    self.shared_app_dir = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:@"group.com.dpt-air"];
    self.dpt = make_shared<Dpt>();
    NSURL* log_file_path = [self.shared_app_dir URLByAppendingPathComponent:@"dpt-air.log"];
    self.log_file = make_shared<std::ofstream>(std::string(log_file_path.path.UTF8String), std::ios_base::out);
    self.dpt->setLogger(*self.log_file);
    self.dpt->setMessager([=](string const& msg) {
        [self performSelectorOnMainThread:@selector(setMessage:) withObject:[NSString stringWithUTF8String:msg.c_str()] waitUntilDone:YES];
    });
    self.dpt_authenticated = NO;
    self.statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSSquareStatusItemLength];
    self.statusItem.button.title = @"DP";
    self.statusItem.menu = self.statusItemMenu;
    [self autoDetectSettings];
//    [NSUserDefaults.standardUserDefaults addSuiteNamed:@"group.com.dpt-air"];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        while(true) {
            NSInteger enabled = [NSUserDefaults.standardUserDefaults integerForKey:@"enable_scheduled_sync"];
            if (enabled) {
                [self performSelectorOnMainThread:@selector(syncAll:) withObject:self waitUntilDone:YES];
                NSInteger mins = [NSUserDefaults.standardUserDefaults integerForKey:@"scheduled_sync_interval"];
                [NSThread sleepForTimeInterval:MAX(mins*60, 60)];
            } else {
                [NSThread sleepForTimeInterval:60];
            }
        }
    });
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSUserDefaults* shared_defaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.com.dpt-air"];
        while(true) {
            NSArray<NSString*>* arr = [shared_defaults objectForKey:@"to_open"];
            if (arr.count > 0) {
                IOBluetoothDevice* device = [self autoConnectBluetooth];
                self.message = @"Waiting for Bluetooth Connection...";
                while (! device.isConnected) {
                    [NSThread sleepForTimeInterval:1];
                }
                NSURL* url = [NSURL URLWithString:arr.firstObject];
                self.message = [NSString stringWithFormat:@"Sending %@ to DPT-RP1...", url.lastPathComponent];
                [self.statusItem performSelectorOnMainThread:@selector(popUpStatusItemMenu:) withObject:self.statusItemMenu waitUntilDone:NO];
                [self.dpt_lock lock];
                [self startCheckingDptBusyStatus];
                try {
                    NSURL* sync_dir = [NSUserDefaults.standardUserDefaults URLForKey:@"sync_dir"];
                    NSURL* private_key = [NSUserDefaults.standardUserDefaults URLForKey:@"private_key"];
                    NSURL* device_id = [NSUserDefaults.standardUserDefaults URLForKey:@"device_id"];
                    [sync_dir withSecured:^(NSURL * _Nonnull _) {
                        [private_key withSecured:^(NSURL * _Nonnull __) {
                            [device_id withSecured:^(NSURL * _Nonnull ___) {
                                [self authenticateDPT];
                                self.dpt->dptQuickUploadAndOpen(std::string(url.path.UTF8String));
                            }];
                        }];
                    }];
                    NSURL* shared_dir = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:@"group.com.dpt-air"];
                    NSURL* tmp_dir = [shared_dir URLByAppendingPathComponent:@"tmp" isDirectory:YES];
                    [NSFileManager.defaultManager removeItemAtURL:tmp_dir error:nil];
                } catch(...) {
                    
                }
                [self.dpt_lock unlock];
                NSLog(@"%@", url);
            }
            [shared_defaults setObject:[NSArray array] forKey:@"to_open"];
            [NSThread sleepForTimeInterval:1];
        }
    });
//    [shared_defaults
//         addObserver:self forKeyPath:@"to_open"
//         options:NSKeyValueObservingOptionInitial|NSKeyValueObservingOptionNew
//         context:nil];
    [NSUserDefaults.standardUserDefaults
         addObserver:self forKeyPath:@"enable_sync_on_change"
         options:NSKeyValueObservingOptionInitial|NSKeyValueObservingOptionNew
         context:nil];
    [NSUserDefaults.standardUserDefaults
        addObserver:self forKeyPath:@"sync_dir"
        options:NSKeyValueObservingOptionInitial|NSKeyValueObservingOptionNew
        context:nil];
    [NSUserDefaults.standardUserDefaults
         addObserver:self forKeyPath:@"private_key"
         options:NSKeyValueObservingOptionInitial|NSKeyValueObservingOptionNew
         context:nil];
    [NSUserDefaults.standardUserDefaults
         addObserver:self forKeyPath:@"device_id"
         options:NSKeyValueObservingOptionInitial|NSKeyValueObservingOptionNew
         context:nil];
    [NSUserDefaults.standardUserDefaults
     addObserver:self forKeyPath:@"bluetooth_device"
     options:NSKeyValueObservingOptionInitial|NSKeyValueObservingOptionNew
     context:nil];
    [NSUserDefaults.standardUserDefaults
     addObserver:self forKeyPath:@"message"
     options:NSKeyValueObservingOptionInitial|NSKeyValueObservingOptionNew
     context:nil];
    [NSUserDefaults.standardUserDefaults
     addObserver:self forKeyPath:@"scheduled_sync_interval"
     options:NSKeyValueObservingOptionInitial|NSKeyValueObservingOptionNew
     context:nil];
    [self checkReady];
    self.message = @"Ready to Sync";
}

- (void)authenticateDPT
{
    NSURL* sync_dir = [NSUserDefaults.standardUserDefaults URLForKey:@"sync_dir"];
    NSURL* private_key = [NSUserDefaults.standardUserDefaults URLForKey:@"private_key"];
    NSURL* device_id = [NSUserDefaults.standardUserDefaults URLForKey:@"device_id"];
    self.dpt->setClientIdPath(std::string(device_id.path.UTF8String));
    self.dpt->setPrivateKeyPath(std::string(private_key.path.UTF8String));
    self.dpt->setSyncDir(std::string(sync_dir.path.UTF8String));
    NSString* gitpath = [NSBundle.mainBundle pathForResource:@"git" ofType:nil];
    self.dpt->setGitPath(std::string(gitpath.UTF8String));
    self.dpt->setupSyncDir();
    self.dpt->authenticate();
}

- (void)checkReady
{
    NSURL* sync_dir = [NSUserDefaults.standardUserDefaults URLForKey:@"sync_dir"];
    NSURL* private_key = [NSUserDefaults.standardUserDefaults URLForKey:@"private_key"];
    NSURL* device_id = [NSUserDefaults.standardUserDefaults URLForKey:@"device_id"];
    NSURL* bluetooth_device = [NSUserDefaults.standardUserDefaults URLForKey:@"bluetooth_device"];
    self.setup_ready = sync_dir && private_key && device_id && bluetooth_device;
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context
{
    if ([keyPath isEqualToString:@"sync_dir"]
        || [keyPath isEqualToString:@"private_key"]
        || [keyPath isEqualToString:@"device_id"]
        || [keyPath isEqualToString:@"bluetooth_device"])
    {
        [self checkReady];
    }
}

- (IBAction)displaySettingsWindow:(id)sender
{
    [self.settings.view.window setLevel:NSNormalWindowLevel];
    [self.settings.view.window orderFrontRegardless];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

- (IBAction)launchDPA:(id)sender
{
    NSURL* url = [NSUserDefaults.standardUserDefaults URLForKey:@"sony_dpa_launcher"];
    [NSWorkspace.sharedWorkspace launchApplicationAtURL:url options:NSWorkspaceLaunchAsync configuration:@{} error:nil];
}

- (IOBluetoothDevice*)autoConnectBluetooth
{
    NSArray* devices = IOBluetoothDevice.pairedDevices;
    NSString* bluetooth_device = [NSUserDefaults.standardUserDefaults stringForKey:@"bluetooth_device"];
    __block IOBluetoothDevice* rtv;
    [devices enumerateObjectsUsingBlock:^(IOBluetoothDevice* obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([bluetooth_device isEqualToString:obj.nameOrAddress]) {
            // found our device
            self.message = [NSString stringWithFormat:@"Pairing %@...", obj.nameOrAddress];
            if (! obj.isConnected) {
                NSURL* tmp = [NSUserDefaults.standardUserDefaults URLForKey:@"sync_dir"];
                [tmp withSecured:^(NSURL * _Nonnull sync_dir) {
                    NSURL* data_dir = NSURL.applicationDocumentsDirectory;
                    NSURL* bt_file = [data_dir URLByAppendingPathComponent:@"bluetooth"];
                    /* we will write our bluetooth_device name */
                    NSError* error;
                    [bluetooth_device writeToURL:bt_file atomically:YES encoding:NSUTF8StringEncoding error:&error];
                    if (error) { NSLog(@"%@", error); }
                }];
                BOOL success = [NSWorkspace.sharedWorkspace
                                launchAppWithBundleIdentifier:@"com.dpt-air.Dpt-Air-Bluetooth-Helper"
                                options:NSWorkspaceLaunchWithoutAddingToRecents
                                additionalEventParamDescriptor:nil
                                launchIdentifier:nil];
                assert(success);
            }
            rtv = obj;
            *stop = YES; // break
        }
    }];
    return rtv;
}

- (void)startCheckingDptBusyStatus
{
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
        int i = 0;
        while(true) {
            if ([self.dpt_lock tryLock]) {
                // locked, not busy
                [self.dpt_lock unlock];
                self.dpt_busy = NO;
                break;
            }
            self.dpt_busy = YES;
            // failed to get lock, busy
            NSString* new_title = self.status_title;
            for (int j = 0; j < i; j++) {
                new_title = [new_title stringByAppendingString:@"."];
            }
            [self.statusItem.button performSelectorOnMainThread:@selector(setTitle:) withObject:new_title waitUntilDone:YES];
            i++;
            i %= 3;
            [NSThread sleepForTimeInterval:1];
        }
        [self.statusItem.button performSelectorOnMainThread:@selector(setTitle:) withObject:self.status_title waitUntilDone:YES];
    });
}

- (IBAction)syncAll:(id)sender
{
    /* attemp to connect to bluetooth */
    IOBluetoothDevice* device = [self autoConnectBluetooth];
    
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        self.message = @"Waiting for Bluetooth Connection...";
        while (! device.isConnected) {
            [NSThread sleepForTimeInterval:1];
        }
        
        [self.dpt_lock lock];
        [self startCheckingDptBusyStatus];
        
        try {
            NSURL* sync_dir = [NSUserDefaults.standardUserDefaults URLForKey:@"sync_dir"];
            NSURL* private_key = [NSUserDefaults.standardUserDefaults URLForKey:@"private_key"];
            NSURL* device_id = [NSUserDefaults.standardUserDefaults URLForKey:@"device_id"];
            [sync_dir withSecured:^(NSURL * _Nonnull _) {
                [private_key withSecured:^(NSURL * _Nonnull __) {
                    [device_id withSecured:^(NSURL * _Nonnull ___) {
                        [self authenticateDPT];
                        self.dpt->safeSyncAllFiles();
                    }];
                }];
            }];
        } catch(...) {
            
        }
        [self.dpt_lock unlock];
    });
}

- (void)autoDetectSettings
{
    NSURL* user_home = [NSFileManager.defaultManager homeDirectoryForCurrentUser];
    NSURL* sony_dpt_app_data_path = [user_home URLByAppendingPathComponent:@"Library/Application Support/Sony Corporation/Digital Paper App/DigitalPaperApp/"];
    NSURL* last_used_id_loc = [sony_dpt_app_data_path URLByAppendingPathComponent:@"lastworkspaceid.dat"];
    NSString* client_id = [[NSString alloc] initWithContentsOfURL:last_used_id_loc encoding:NSUTF8StringEncoding error:nil];
    if (! client_id) {
        return;
    }
    NSURL* client_data_loc = [sony_dpt_app_data_path URLByAppendingPathComponent:client_id];
    NSURL* device_id_file = [client_data_loc URLByAppendingPathComponent:@"deviceid.dat"];
    NSURL* private_key_file = [client_data_loc URLByAppendingPathComponent:@"privatekey.dat"];
    if (private_key_file && device_id_file) {
        [NSUserDefaults.standardUserDefaults setURL:private_key_file forKey:@"private_key"];
        [NSUserDefaults.standardUserDefaults setURL:device_id_file forKey:@"device_id"];
    }
}

- (IBAction)terminateApp:(id)sender
{
    [NSApp terminate:sender];
}

- (IBAction)openSyncFolderInFinder:(id)sender
{
    NSURL* sync_dir = [NSUserDefaults.standardUserDefaults URLForKey:@"sync_dir"];
    [sync_dir withSecured:^(NSURL * _Nonnull url) {
        [[NSWorkspace sharedWorkspace] openURL: sync_dir];
    }];
}

@end
