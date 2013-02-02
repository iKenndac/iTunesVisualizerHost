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

@protocol iTunesVisualPluginDelegate <NSObject>

@end

@interface iTunesVisualPlugin : NSObject

@property (nonatomic, readwrite, strong) NSImage *coverArt;

-(void)showConfiguration;

-(void)playbackStartedWithMetaData:(NSDictionary *)metadata audioFormat:(AudioStreamBasicDescription)format;
-(void)playbackStopped;
-(void)playbackPositionUpdated:(NSTimeInterval)position;

-(void)activateInView:(NSView *)view;
-(void)deactivate;


@end
