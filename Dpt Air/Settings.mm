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

@implementation SettingsView

- (BOOL)performKeyEquivalent:(NSEvent *)event
{
    if (event.modifierFlags & NSEventModifierFlagCommand) {
        unsigned code = event.keyCode;
        if (code == 13) {
            /* Cmd + W */
            [self.window close];
            return YES;
        }
    }
    return [super performKeyEquivalent:event];
}

@end

@implementation Settings

- (void)viewWillAppear
{
    [super viewWillAppear];
    [self refreshBluetoothDevices];
    [self refreshRollbackHistory];
    [self.bluetoothTable.enclosingScrollView setHorizontalScrollElasticity:NSScrollElasticityNone];
    [self.rollbackTable.enclosingScrollView setHorizontalScrollElasticity:NSScrollElasticityNone];
}

- (void)viewWillDisappear
{
    [super viewWillDisappear];
    /* Without this, the UI locks for a long time when window exits.
        The reason is unclear. Maybe cocoa needs to do some clean up */
    [self.rollbackHistory setContent:nil];
}

- (IBAction)onSelectSyncFolderButtonClicked:(id)sender
{
    NSOpenPanel *op = [NSOpenPanel openPanel];
    op.canChooseFiles = NO;
    op.canChooseDirectories = YES;
    op.canCreateDirectories = YES;
    [op runModal];
    [[op.URLs firstObject] withSecured:^(NSURL * _Nonnull safeurl) {
        [NSUserDefaults.standardUserDefaults setURL:safeurl forKey:@"sync_dir"];
    }];
}

- (void)refreshRollbackHistory
{
    NSURL* sync_dir = NSApp.appDelegate.unsafe_sync_dir;
    if (! sync_dir) {
        return;
    }
    /* set git path */
    NSString* gitpath = [NSBundle.mainBundle pathForResource:@"git" ofType:nil];
    NSApp.appDelegate.dpt->setGitPath(std::string(gitpath.UTF8String));
    /* set sync dir */
    NSApp.appDelegate.dpt->setSyncDir(std::string(sync_dir.path.UTF8String));
    
    [self.rollbackHistory setContent:nil];
    
    [sync_dir withSecured:^(NSURL * _Nonnull _) {
        NSApp.appDelegate.dpt->updateGitCommits();
    }];
    NSISO8601DateFormatter* iso8601_dateFormatter = [[NSISO8601DateFormatter alloc] init];
    NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateStyle = NSDateFormatterMediumStyle;
    dateFormatter.timeStyle = NSDateFormatterMediumStyle;
    dateFormatter.locale = NSLocale.currentLocale;
    NSMutableArray<NSDictionary*>* buffer = [NSMutableArray array];
    for (auto const& gc : NSApp.appDelegate.dpt->listGitCommits(100))
    {
        NSString* iso8601_date = [NSString stringWithUTF8String:gc->iso8601_time.c_str()];
        NSDate* date = [iso8601_dateFormatter dateFromString:iso8601_date];
        NSString* time = [dateFormatter stringFromDate:date];
        NSString* commit = [NSString stringWithUTF8String:gc->commit.c_str()];
        NSString* title = [NSString stringWithUTF8String:gc->title.c_str()];
        NSString* message = [NSString stringWithUTF8String:gc->message.c_str()];
        [buffer addObject:@{@"commit":commit, @"time": time, @"title": title, @"message":message, @"buttonTarget": self}];
    }
    [self.rollbackHistory setContent:buffer];
}

- (IBAction)onSelectDigitalPaperAppPath:(id)sender
{
    NSOpenPanel *op = [NSOpenPanel openPanel];
    op.canChooseFiles = YES;
    op.canChooseDirectories = NO;
    op.canCreateDirectories = NO;
    [op runModal];
    [[op.URLs firstObject] withSecured:^(NSURL * _Nonnull url) {
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
    [[op.URLs firstObject] withSecured:^(NSURL * _Nonnull url) {
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
    [url withSecured:^(NSURL * _Nonnull safe) {
        [NSUserDefaults.standardUserDefaults setURL:safe forKey:@"device_id"];
    }];
}

- (void)refreshBluetoothDevices
{
    NSArray* devices = IOBluetoothDevice.pairedDevices;
    NSString* bluetooth_device = [NSUserDefaults.standardUserDefaults stringForKey:@"bluetooth_device"];
    [self.bluetoothDevices setContent:nil];
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
    [self refreshBluetoothDevices];
}

- (IBAction)showSenderToolTip:(id)sender
{
    NSHelpManager *helpManager = [NSHelpManager sharedHelpManager];
    [helpManager setContextHelp:[[NSAttributedString alloc] initWithString:[sender toolTip]] forObject:sender];
    [helpManager showContextHelpForObject:sender locationHint:[NSEvent mouseLocation]];
    [helpManager removeContextHelpForObject:sender];
}

- (IBAction)onExtractButtonClicked:(NSDictionary*)obj
{
    NSString* commit = obj[@"commit"];
    NSSavePanel *op = [NSSavePanel savePanel];
//    op.title = @"Select a Directory t the Checkpoint"
    op.canCreateDirectories = YES;
    op.canSelectHiddenExtension = YES;
    [op beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse result) {
        if (result == NSModalResponseOK) {
            [NSFileManager.defaultManager createDirectoryAtURL:op.URL withIntermediateDirectories:NO attributes:nil error:nil];
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [NSApp.appDelegate.unsafe_sync_dir withSecured:^(NSURL * _Nonnull _) {
                    NSApp.appDelegate.dpt->extractGitCommit(std::string(commit.UTF8String), std::string(op.URL.path.UTF8String));
                }];
                [NSWorkspace.sharedWorkspace performSelectorOnMainThread:@selector(openURL:) withObject:op.URL waitUntilDone:YES];
            });
        }
    }];
}

- (IBAction)onInfoButtonClicked:(NSTableCellView*)sender dict:(NSDictionary*)obj
{
    NSString* commit = obj[@"commit"];
    NSString* message = obj[@"message"];
    NSString* time = obj[@"time"];
    self.textPopover.text = [NSString stringWithFormat:@"Commit: %@\nTime: %@\nMessage:\n\n%@", commit, time, message];
    [self.textPopover showRelativeToRect:sender.frame ofView:sender preferredEdge:NSRectEdgeMinX];
}

@end

@implementation TextPopover
- (void)showRelativeToRect:(NSRect)positioningRect ofView:(NSView *)positioningView preferredEdge:(NSRectEdge)preferredEdge
{
    TextPopoverViewController* vc = (TextPopoverViewController*)self.contentViewController;
    vc.label.stringValue = self.text;
    [super showRelativeToRect:positioningRect ofView:positioningView preferredEdge:preferredEdge];
}
@end

@implementation TextPopoverViewController
@end
