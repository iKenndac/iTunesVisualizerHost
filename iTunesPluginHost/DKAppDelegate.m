//
//  DKAppDelegate.m
//  iTunesPluginHost
//
//  Created by Daniel Kennett on 01/02/2013.
//  Copyright (c) 2013 Daniel Kennett. All rights reserved.
//

#import "DKAppDelegate.h"
#import "iTunesPluginHost.h"

@interface DKAppDelegate ()
@property (nonatomic, readwrite, strong) iTunesPluginHost *host;
@end

@implementation DKAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	// Insert code here to initialize your application
	self.host = [iTunesPluginHost new];
	iTunesPlugin *plugin = [self.host.plugins lastObject];
	iTunesVisualPlugin *visualPlugin = [plugin.visualisers lastObject];
	[visualPlugin activateInView:self.window.contentView];
}

-(void)applicationWillTerminate:(NSNotification *)notification {
	self.host = nil;
}

@end
