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

-(OSStatus)handleMessage:(OSType)message withInfo:(PlayerMessageInfo *)info;

@end

OSStatus HostVisualProc(void *appCookie, OSType message, PlayerMessageInfo *messageInfo) {
	iTunesVisualPlugin *visualiser = appCookie;
	return [visualiser handleMessage:message withInfo:messageInfo];
}

@implementation iTunesVisualPlugin {
	VisualPluginProcPtr visualHandler;
	void *visualHandlerRefCon;
	NSImage *_art;
}

-(id)initWithMessage:(PlayerRegisterVisualPluginMessage)message {
	self = [super init];
	if (self) {
		self.pluginName = [self stringFromITUniStr:message.name];
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
		info.u.initMessage.appProc = HostVisualProc;

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
	self.coverArt = nil;

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

-(void)setCoverArt:(NSImage *)coverArt {
	[coverArt retain];
	[_art release];
	_art = coverArt;

	if (visualHandler != NULL) [self updateCoverArt:_art];
}

-(NSImage *)coverArt {
	return _art;
}

#pragma mark -

-(OSStatus)handleMessage:(OSType)message withInfo:(PlayerMessageInfo *)info {

	switch (message) {
		case kVisualPluginCoverArtMessage:
			[self updateCoverArt:_art];
			return noErr;
			break;

		default:
			NSLog(@"Got message!");
			break;
	}

	return noErr;
}

#pragma mark -

-(void)putString:(NSString *)str intoITUniStr:(ITUniStr255)uniStr {
	if (str == nil) return;
	NSString *trimmedString = str.length < 255 ? str : [str substringToIndex:255];
	CFIndex length = CFStringGetLength((CFStringRef)trimmedString);
	uniStr[0] = (UniChar)length;
	CFStringGetCharacters((CFStringRef)trimmedString, CFRangeMake(0, length), &uniStr[1]);
}

-(NSString *)stringFromITUniStr:(ITUniStr255)uniStr {
	NSUInteger length = uniStr[0];
	if (length == 0) return nil;
	return [[[NSString alloc] initWithCharacters:(const unichar *)uniStr + 1 length:length] autorelease];
}

#pragma mark -

-(void)showConfiguration {
	if (self.wantsConfigure) {
		struct VisualPluginMessageInfo info;
		memset(&info, 0, sizeof(struct VisualPluginMessageInfo));
		visualHandler(kVisualPluginConfigureMessage, &info, visualHandlerRefCon);
	}
}

-(void)playbackStartedWithMetaData:(NSDictionary *)metadata audioFormat:(AudioStreamBasicDescription)format {

	ITTrackInfo *trackInfo = malloc(sizeof(ITTrackInfo));
	memset(trackInfo, 0, sizeof(ITTrackInfo));
	trackInfo->validFields = 0;
	trackInfo->recordLength = sizeof(ITTrackInfo);

	NSString *trackName = metadata[kVisualiserTrackTitleKey];
	if (trackName.length > 0) {
		trackInfo->validFields |= kITTINameFieldMask;
		[self putString:trackName intoITUniStr:trackInfo->name];
	}

	NSString *albumName = metadata[kVisualiserTrackAlbumKey];
	if (albumName.length > 0) {
		trackInfo->validFields |= kITTIAlbumFieldMask;
		[self putString:albumName intoITUniStr:trackInfo->album];
	}

	NSString *artistName = metadata[kVisualiserTrackArtistKey];
	if (artistName.length > 0) {
		trackInfo->validFields |= kITTIArtistFieldMask;
		[self putString:artistName intoITUniStr:trackInfo->artist];
	}

	NSNumber *duration = metadata[kVisualiserTrackDurationKey];
	if (duration != nil) {
		trackInfo->validFields |= kITTITotalTimeFieldMask;
		trackInfo->totalTimeInMS = (UInt32)duration.doubleValue * 1000;
	}

	ITStreamInfo *streamInfo = malloc(sizeof(ITStreamInfo));
	memset(streamInfo, 0, sizeof(ITStreamInfo));

	VisualPluginMessageInfo info;
	memset(&info, 0, sizeof(VisualPluginMessageInfo));
	info.u.playMessage.audioFormat = format;
	info.u.playMessage.bitRate = 160;
	info.u.playMessage.volume = INT32_MAX;
	info.u.playMessage.streamInfo = streamInfo;
	info.u.playMessage.trackInfo = trackInfo;

	visualHandler(kVisualPluginPlayMessage, &info, visualHandlerRefCon);

	free(trackInfo);
	free(streamInfo);
}

-(void)playbackStopped {
	struct VisualPluginMessageInfo info;
	memset(&info, 0, sizeof(struct VisualPluginMessageInfo));
	visualHandler(kVisualPluginStopMessage, &info, visualHandlerRefCon);
}

-(void)updateCoverArt:(NSImage *)coverArt {
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
