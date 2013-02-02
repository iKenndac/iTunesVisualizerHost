//
//  iTunesVisualPlugin.h
//  iTunesPluginHost
//
//  Created by Daniel Kennett on 01/02/2013.
//  Copyright (c) 2013 Daniel Kennett. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <CoreAudio/CoreAudioTypes.h>

static NSString * const kVisualiserTrackTitleKey = @"title";
static NSString * const kVisualiserTrackArtistKey = @"artist";
static NSString * const kVisualiserTrackAlbumKey = @"album";
static NSString * const kVisualiserTrackDurationKey = @"duration";
static NSString * const kVisualiserTrackPositionKey = @"position";

@class iTunesVisualPlugin;

@interface iTunesVisualPlugin : NSObject

@property (nonatomic, readonly, copy) NSString *pluginName;
@property (nonatomic, readonly) NSSize minSize;
@property (nonatomic, readonly) NSSize maxSize;
@property (nonatomic, readonly) NSUInteger pulseRateHz;
@property (nonatomic, readonly) NSInteger numWaveformChannels;
@property (nonatomic, readonly) NSInteger numSpectrumChannels;
@property (nonatomic, readonly) NumVersion version;

@property (nonatomic, readwrite, strong) NSImage *coverArt;

-(void)showConfiguration;

-(void)playbackStartedWithMetaData:(NSDictionary *)metadata audioFormat:(AudioStreamBasicDescription)format;
-(void)playbackStopped;
-(void)playbackPositionUpdated:(NSTimeInterval)position;

-(void)activateInView:(NSView *)view;
-(void)deactivate;

-(void)containerViewFrameChanged;

-(void)pushLeftAudioBuffer:(UInt8 *)left rightAudioBuffer:(UInt8 *)right;

@end
