//
//  iTunesVisualPlugin.m
//  iTunesPluginHost
//
//  Created by Daniel Kennett on 01/02/2013.
//  Copyright (c) 2013 Daniel Kennett. All rights reserved.
//

#import "iTunesVisualPlugin.h"
#import "iTunesVisualAPI.h"

#if __has_feature(objc_arc)
#error This class does not support ARC.
#endif

@interface iTunesVisualPlugin ()

@property (nonatomic, readwrite, copy) NSString *pluginName;

@property (nonatomic, readwrite) NSSize minSize;
@property (nonatomic, readwrite) NSSize maxSize;
@property (nonatomic, readwrite) NSInteger pulseRateHz;
@property (nonatomic, readwrite) NSInteger numWaveformChannels;
@property (nonatomic, readwrite) NSInteger numSpectrumChannels;
@property (nonatomic, readwrite) NumVersion version;

@property (nonatomic, readwrite) BOOL needsViewInvalidate;
@property (nonatomic, readwrite) BOOL wantsIdleMessages;
@property (nonatomic, readwrite) BOOL wantsConfigure;

@property (nonatomic, readwrite, strong) NSTimer *redrawTimer;
@property (nonatomic, readwrite, strong) NSView *pluginHostView;

@end

OSStatus HostVisualProc(void *appCookie, OSType message, struct PlayerMessageInfo *messageInfo) {
	iTunesVisualPlugin *visualiser = appCookie;
	//return [plugin handleMessage:message withInfo:messageInfo];
	return noErr;
}

@implementation iTunesVisualPlugin {
	VisualPluginProcPtr visualHandler;
	void *visualHandlerRefCon;
}

-(id)initWithMessage:(PlayerRegisterVisualPluginMessage)message {
	self = [super init];
	if (self) {
		NSString *nameStr = [[[NSString alloc] initWithBytes:message.name length:sizeof(ITUniStr255) encoding:NSUTF16LittleEndianStringEncoding] autorelease];
		self.pluginName = nameStr;
		self.minSize = CGSizeMake((CGFloat)message.minWidth, (CGFloat)message.minHeight);
		self.maxSize = CGSizeMake((CGFloat)message.maxWidth, (CGFloat)message.maxHeight);
		self.numSpectrumChannels = message.numSpectrumChannels;
		self.numWaveformChannels = message.numWaveformChannels;
		self.pulseRateHz = message.pulseRateInHz;
		self.version = message.pluginVersion;
		self.wantsIdleMessages = (message.options & kVisualWantsIdleMessages) == kVisualWantsIdleMessages;
		self.wantsConfigure = (message.options & kVisualWantsConfigure) == kVisualWantsConfigure;

		visualHandler = message.handler;

		BOOL is3dOnly = (message.options & kVisualUsesOnly3D) == kVisualUsesOnly3D;
		BOOL usesSubView = (message.options & kVisualUsesSubview) == kVisualUsesSubview;

		self.needsViewInvalidate = (is3dOnly == NO && usesSubView == NO);

		struct VisualPluginMessageInfo info;
		memset(&info, 0, sizeof(struct VisualPluginMessageInfo));
		info.u.initMessage.messageMajorVersion = 10;
		info.u.initMessage.messageMinorVersion = 4;
		info.u.initMessage.appCookie = (void *)self;

		NumVersion iTunesVersion;
		iTunesVersion.majorRev = 4;
		iTunesVersion.minorAndBugRev = 7;
		iTunesVersion.nonRelRev = 0;
		iTunesVersion.stage = 0;

		info.u.initMessage.appVersion = iTunesVersion;

		// Init the visual plugin
		visualHandler(kVisualPluginInitMessage, &info, message.registerRefCon);
		visualHandlerRefCon = info.u.initMessage.refCon;

		//Enable it
		visualHandler(kVisualPluginEnableMessage, &info, visualHandlerRefCon);

		[self addObserver:self forKeyPath:@"pluginHostView.frame" options:0 context:nil];

		self.redrawTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 / 60.0
															target:self
														  selector:@selector(drawPlugin:)
														  userInfo:nil
														   repeats:YES];

	}
	return self;
}

-(void)dealloc {

	[self.redrawTimer invalidate];
	self.redrawTimer = nil;

	[self removeObserver:self forKeyPath:@"pluginHostView.frame"];

	if (visualHandler != NULL) {
		struct VisualPluginMessageInfo info;
		memset(&info, 0, sizeof(struct VisualPluginMessageInfo));
		visualHandler(kVisualPluginCleanupMessage, &info, visualHandlerRefCon);
		visualHandlerRefCon = NULL;
		visualHandler = NULL;
	}

	self.pluginHostView = nil;
	self.pluginName = nil;
	
	[super dealloc];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"pluginHostView.frame"]) {
        if (self.pluginHostView != nil) {
			struct VisualPluginMessageInfo info;
			memset(&info, 0, sizeof(struct VisualPluginMessageInfo));
			visualHandler(kVisualPluginFrameChangedMessage, &info, visualHandlerRefCon);
		}
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

-(void)drawPlugin:(NSTimer *)aTimer {

	if (!self.pluginHostView) return;

	struct VisualPluginMessageInfo info;
	memset(&info, 0, sizeof(struct VisualPluginMessageInfo));
	visualHandler(kVisualPluginDrawMessage, &info, visualHandlerRefCon);

	if (self.needsViewInvalidate)
		[self.pluginHostView setNeedsDisplay:YES];

}

#pragma mark -

-(void)showConfiguration {
	if (self.wantsConfigure) {
		struct VisualPluginMessageInfo info;
		memset(&info, 0, sizeof(struct VisualPluginMessageInfo));
		visualHandler(kVisualPluginConfigureMessage, &info, visualHandlerRefCon);
	}
}

-(void)playbackStarted {
#warning Not implemented
}

-(void)playbackStopped {
	struct VisualPluginMessageInfo info;
	memset(&info, 0, sizeof(struct VisualPluginMessageInfo));
	visualHandler(kVisualPluginStopMessage, &info, visualHandlerRefCon);
}

-(void)coverArtChanged:(NSImage *)coverArt {
	struct VisualPluginMessageInfo info;
	memset(&info, 0, sizeof(struct VisualPluginMessageInfo));

	NSData *imageData = nil;

	if (coverArt == NULL) {
		info.u.coverArtMessage.coverArt = NULL;
		info.u.coverArtMessage.coverArtSize = 0;
		info.u.coverArtMessage.coverArtFormat = kVisualCoverArtFormatPNG;
	} else {

		NSData *tiffRep = [coverArt TIFFRepresentation];
		NSBitmapImageRep *rep = [NSBitmapImageRep imageRepWithData:tiffRep];
		imageData = [[rep representationUsingType:NSPNGFileType properties:nil] retain];

		info.u.coverArtMessage.coverArt = (CFDataRef)imageData;
		info.u.coverArtMessage.coverArtSize = (UInt32)imageData.length;
		info.u.coverArtMessage.coverArtFormat = kVisualCoverArtFormatPNG;
	}

	visualHandler(kVisualPluginCoverArtMessage, &info, visualHandlerRefCon);
	[imageData release];
}

-(void)playbackPositionUpdated:(NSTimeInterval)position {
	struct VisualPluginMessageInfo info;
	memset(&info, 0, sizeof(struct VisualPluginMessageInfo));
	info.u.setPositionMessage.positionTimeInMS = (UInt32)position * 1000;
	visualHandler(kVisualPluginSetPositionMessage, &info, visualHandlerRefCon);
}

-(void)activateInView:(NSView *)view {
	if (view == nil) return;
	self.pluginHostView = view;
	struct VisualPluginMessageInfo info;
	memset(&info, 0, sizeof(struct VisualPluginMessageInfo));
	info.u.activateMessage.view = view;
	visualHandler(kVisualPluginActivateMessage, &info, visualHandlerRefCon);
	[self drawPlugin:nil];
}

-(void)deactivate {
	struct VisualPluginMessageInfo info;
	memset(&info, 0, sizeof(struct VisualPluginMessageInfo));
	visualHandler(kVisualPluginDeactivateMessage, &info, visualHandlerRefCon);
	self.pluginHostView = nil;
}

@end
