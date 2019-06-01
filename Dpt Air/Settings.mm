//
//  Settings.m
//  Dpt Air
//
//  Created by Yu Li on 2019-05-29.
//  Copyright © 2019 Yu Li. All rights reserved.
//

#import "Settings.h"
#import "common.h"
#include <dptrp1.h>
#import "AppDelegate.h"
#import <IOBluetooth/IOBluetooth.h>

@interface Settings ()

@end

@implementation Settings

- (void)viewDidLoad
{
    [self findBluetoothDevices];
    [self.bluetoothTable.enclosingScrollView setHorizontalScrollElasticity:NSScrollElasticityNone];
}

- (IBAction)onSelectSyncFolderButtonClicked:(id)sender
{
    NSOpenPanel *op = [NSOpenPanel openPanel];
    op.canChooseFiles = NO;
    op.canChooseDirectories = YES;
    op.canCreateDirectories = YES;
    [op runModal];
    NSURL* url = [op.URLs firstObject];
    [url withSecured:^(NSURL * _Nonnull url) {
        [NSUserDefaults.standardUserDefaults setURL:url forKey:@"sync_dir"];
    }];
}

- (IBAction)onSelectDigitalPaperAppPath:(id)sender
{
    NSOpenPanel *op = [NSOpenPanel openPanel];
    op.canChooseFiles = YES;
    op.canChooseDirectories = NO;
    op.canCreateDirectories = NO;
    [op runModal];
    NSURL* url = [op.URLs firstObject];
    [url withSecured:^(NSURL * _Nonnull url) {
        [NSUserDefaults.standardUserDefaults setURL:url forKey:@"sony_dpa_launcher"];
    }];
}

- (IBAction)onSelectPrivateKeyPath:(id)sender
{
    NSOpenPanel *op = [NSOpenPanel openPanel];
    op.canChooseFiles = YES;
    op.canChooseDirectories = NO;
    op.canCreateDirectories = NO;
    [op runModal];
    NSURL* url = [op.URLs firstObject];
    [url withSecured:^(NSURL * _Nonnull url) {
        [NSUserDefaults.standardUserDefaults setURL:url forKey:@"private_key"];
    }];
}

- (IBAction)onSelectDeviceIdPath:(id)sender
{
    NSOpenPanel *op = [NSOpenPanel openPanel];
    op.canChooseFiles = YES;
    op.canChooseDirectories = NO;
    op.canCreateDirectories = NO;
    [op runModal];
    NSURL* url = [op.URLs firstObject];
    [url withSecured:^(NSURL * _Nonnull url) {
        [NSUserDefaults.standardUserDefaults setURL:url forKey:@"device_id"];
    }];
}

- (void)findBluetoothDevices
{
    NSArray* devices = IOBluetoothDevice.favoriteDevices;
    NSString* bluetooth_device = [NSUserDefaults.standardUserDefaults stringForKey:@"bluetooth_device"];
    [devices enumerateObjectsUsingBlock:^(IOBluetoothDevice* obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString* buttonEnabled;
        NSString* buttonTitle;
        id buttonTarget = self;
        if ([bluetooth_device isEqualToString:obj.nameOrAddress]) {
            buttonTitle = @"In Use";
            buttonEnabled = nil; // xib uses isNotNil negater
        } else {
            buttonTitle = @"Select";
            buttonEnabled = @"YES";
        }
        NSMutableDictionary* dic = [[NSMutableDictionary alloc] init];
        dic[@"name"] = obj.nameOrAddress;
        dic[@"buttonTitle"] = buttonTitle;
        dic[@"buttonEnabled"] = buttonEnabled;
        dic[@"buttonTarget"] = buttonTarget;
        [self.bluetoothDevices addObject:dic];
    }];
}

- (void)handleBluetoothSelectButtonClicked:(NSMutableDictionary*)deviceObject
{
    [NSUserDefaults.standardUserDefaults setValue:deviceObject[@"name"] forKey:@"bluetooth_device"];
    deviceObject[@"buttonTitle"] = @"In Use";
    deviceObject[@"buttonEnabled"] = nil;
}


@end
