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

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    using namespace std;
    using namespace dpt;
    self.m_dpt = make_shared<Dpt>();
    self.m_dpt->setMessager([=](string msg) {
        [self performSelectorOnMainThread:@selector(setMessage:) withObject:[NSString stringWithUTF8String:msg.c_str()] waitUntilDone:YES];
    });
    self.dpt_authenticated = NO;
    self.statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSSquareStatusItemLength];
    self.statusItem.button.title = @"DA";
    self.statusItem.menu = self.statusItemMenu;
    [self autoDetectSettings];
    [NSUserDefaultsController.sharedUserDefaultsController.values
        addObserver:self forKeyPath:@"sync_dir"
        options:NSKeyValueObservingOptionInitial|NSKeyValueObservingOptionNew
        context:nil];
    [NSUserDefaultsController.sharedUserDefaultsController.values
         addObserver:self forKeyPath:@"private_key"
         options:NSKeyValueObservingOptionInitial|NSKeyValueObservingOptionNew
         context:nil];
    [NSUserDefaultsController.sharedUserDefaultsController.values
         addObserver:self forKeyPath:@"device_key"
         options:NSKeyValueObservingOptionInitial|NSKeyValueObservingOptionNew
         context:nil];
    [NSUserDefaultsController.sharedUserDefaultsController.values
     addObserver:self forKeyPath:@"message"
     options:NSKeyValueObservingOptionInitial|NSKeyValueObservingOptionNew
     context:nil];
    [self checkReady];
}

- (void)authenticateDPT
{
    if (self.dpt_authenticated) { return; }
    NSURL* sync_dir = [NSUserDefaults.standardUserDefaults URLForKey:@"sync_dir"];
    NSURL* private_key = [NSUserDefaults.standardUserDefaults URLForKey:@"private_key"];
    NSURL* device_id = [NSUserDefaults.standardUserDefaults URLForKey:@"device_id"];
    self.m_dpt->setClientIdPath(std::string(device_id.path.UTF8String));
    self.m_dpt->setPrivateKeyPath(std::string(private_key.path.UTF8String));
    self.m_dpt->setSyncDir(std::string(sync_dir.path.UTF8String));
    self.m_dpt->authenticate();
    self.dpt_authenticated = YES;
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
                      ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context
{
    if ([keyPath isEqualToString:@"sync_dir"]
        || [keyPath isEqualToString:@"private_key"]
        || [keyPath isEqualToString:@"device_id"])
    {
        [self checkReady];
    }
}

- (IBAction)displaySettingsWindow:(id)sender
{
    [self.settings.view.window setLevel:NSFloatingWindowLevel];
    [self.settings.view.window makeKeyAndOrderFront:sender];
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
    NSArray* devices = IOBluetoothDevice.favoriteDevices;
    NSString* bluetooth_device = [NSUserDefaults.standardUserDefaults stringForKey:@"bluetooth_device"];
    __block IOBluetoothDevice* rtv;
    [devices enumerateObjectsUsingBlock:^(IOBluetoothDevice* obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([bluetooth_device isEqualToString:obj.nameOrAddress]) {
            // found our device
            NSLog(@"Pairing Bluetooth %@", obj.nameOrAddress);
            self.message = @"Pairing Bluetooth...";
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
                                options:NSWorkspaceLaunchAndHide|NSWorkspaceLaunchWithoutAddingToRecents
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

- (IBAction)syncAll:(id)sender
{
    /* attemp to connect to bluetooth */
    IOBluetoothDevice* device = [self autoConnectBluetooth];
    
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        self.message = @"Waiting for Bluetooth Connection...";
        while (! device.isConnected) {
            [NSThread sleepForTimeInterval:0.5];
        }
        if (self.dpt_busy) { return; }
        self.dpt_busy = YES;
        try {
            NSURL* sync_dir = [NSUserDefaults.standardUserDefaults URLForKey:@"sync_dir"];
            NSURL* private_key = [NSUserDefaults.standardUserDefaults URLForKey:@"private_key"];
            NSURL* device_id = [NSUserDefaults.standardUserDefaults URLForKey:@"device_id"];
            [sync_dir withSecured:^(NSURL * _Nonnull url) {
                [private_key withSecured:^(NSURL * _Nonnull url) {
                    [device_id withSecured:^(NSURL * _Nonnull url) {
                        [self authenticateDPT];
                        self.m_dpt->safeSyncAllFiles();
                    }];
                }];
            }];
        } catch(...) {
            
        }
        self.dpt_busy = NO;
    });
    NSString* original_title = self.statusItem.button.title;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
        int i = 0;
        while(self.dpt_busy) {
            NSString* new_title = original_title;
            for (int j = 0; j <= i; j++) {
                new_title = [new_title stringByAppendingString:@"."];
            }
            [self.statusItem.button performSelectorOnMainThread:@selector(setTitle:) withObject:new_title waitUntilDone:YES];
            i = (i + 1) % 3;
            [NSThread sleepForTimeInterval:1];
        }
        [self.statusItem.button performSelectorOnMainThread:@selector(setTitle:) withObject:original_title waitUntilDone:YES];
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

@end
