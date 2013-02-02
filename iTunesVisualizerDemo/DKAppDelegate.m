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
	iTunesVisualPlugin *visualPlugin = [plugin.visualizers lastObject];
	[visualPlugin activateInView:self.window.contentView];

	NSDictionary *metadata = @{kVisualiserTrackDurationKey : @(30.0),
							kVisualiserTrackAlbumKey : @"Test Album",
							kVisualiserTrackArtistKey : @"Test Artist",
							kVisualiserTrackTitleKey : @"Test Title"};

	AudioStreamBasicDescription desc;
	memset(&desc, 0, sizeof(AudioStreamBasicDescription));
	desc.mSampleRate = (float)44100.0;
	desc.mBytesPerPacket = 2 * sizeof(SInt16);
	desc.mBytesPerFrame = desc.mBytesPerPacket;
	desc.mChannelsPerFrame = 2;
	desc.mFormatID = kAudioFormatLinearPCM;
	desc.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked | kAudioFormatFlagsNativeEndian;
	desc.mFramesPerPacket = 1;
	desc.mBitsPerChannel = 16;
	desc.mReserved = 0;

	visualPlugin.coverArt = [NSImage imageNamed:@"art"];
	[visualPlugin playbackStartedWithMetaData:metadata audioFormat:desc];
}

-(void)applicationWillTerminate:(NSNotification *)notification {
	self.host = nil;
}

@end
