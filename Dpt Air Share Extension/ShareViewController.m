//
//  ShareViewController.m
//  Dpt Air Share Extension
//
//  Created by Yu Li on 2019-06-03.
//  Copyright © 2019 Yu Li. All rights reserved.
//

#import "ShareViewController.h"
#import <Quartz/Quartz.h>

@interface ShareViewController ()

@end

@implementation ShareViewController

- (NSString *)nibName {
    return @"ShareViewController";
}



- (void)loadView {
    [super loadView];

    // Insert code here to customize the view
    NSExtensionItem *item = self.extensionContext.inputItems.firstObject;
    NSLog(@"self.extensionContext = %@", self.extensionContext);
    NSNumber* __block await_count = 0;
    NSMutableArray<NSString*>* __block to_open = [[NSMutableArray alloc] init];
    [item.attachments enumerateObjectsUsingBlock:^(NSItemProvider * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        *stop = YES;
        // TODO: handle multiple files
        BOOL has_pdf = [obj hasRepresentationConformingToTypeIdentifier:kUTTypePDF fileOptions:0];
        if (! has_pdf) { return; }
        NSLog(@"obj %@", obj);
        @synchronized(await_count) {
            await_count = [NSNumber numberWithInt:await_count.intValue + 1];
        }
        NSLog(@"count %@", await_count);
        [obj loadItemForTypeIdentifier:(NSString*)kUTTypeURL options:nil
                     completionHandler:^(NSURL* file_original_url, NSError * _Nullable error)
         {
            [obj loadInPlaceFileRepresentationForTypeIdentifier:(NSString*)kUTTypePDF
                                       completionHandler:^(NSURL * _Nullable file_path, BOOL is_inplace, NSError * _Nullable error)
            {
                if (error) {
                    NSLog(@"Error: %@", error);
                }
                NSURL* shared_dir = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:@"group.com.dpt-air"];
                NSURL* tmp_dir = [shared_dir URLByAppendingPathComponent:@"tmp" isDirectory:YES];
                NSArray* split = [file_original_url.lastPathComponent componentsSeparatedByString:@"."];
                NSString* filename = [split objectAtIndex:split.count-2];
                NSURL* dest = [tmp_dir URLByAppendingPathComponent:[filename stringByAppendingString:@".pdf"]];
                NSLog(@"dest: %@", dest);
                [NSFileManager.defaultManager createDirectoryAtURL:tmp_dir withIntermediateDirectories:NO attributes:nil error:nil];
                [NSFileManager.defaultManager copyItemAtURL:file_path toURL:dest error:nil];
                @synchronized(to_open) {
                    [to_open addObject:dest.absoluteString];
                }
                @synchronized(await_count) {
                    await_count = [NSNumber numberWithInt:await_count.intValue - 1];
                    NSLog(@"count %@", await_count);
                }
            }];
        }];
    }];
    dispatch_async(dispatch_get_main_queue(), ^{
        int count;
        do {
            [NSThread sleepForTimeInterval:0.001];
            @synchronized (await_count) {
                count = await_count.intValue;
            }
        } while(count > 0);
        NSUserDefaults* shared_defaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.com.dpt-air"];
        @synchronized (to_open) {
            [shared_defaults setObject:to_open forKey:@"to_open"];
            NSLog(@"to_open:%@", to_open);
        }
    });
    
    /* check if main app is running */
    NSArray<NSRunningApplication*>* app = [NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.dpt-air.Dpt-Air"];
    if (app.count != 0) {
        [self send:self];
    }
}

- (IBAction)send:(id)sender {
    NSExtensionItem *outputItem = [[NSExtensionItem alloc] init];
    // Complete implementation by setting the appropriate value on the output item
    
    NSArray *outputItems = @[outputItem];
    [self.extensionContext completeRequestReturningItems:outputItems completionHandler:nil];
}

- (IBAction)cancel:(id)sender {
    NSError *cancelError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:nil];
    [self.extensionContext cancelRequestWithError:cancelError];
}

@end

