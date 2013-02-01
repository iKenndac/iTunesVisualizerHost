//
//  iTunesVisualPlugin.h
//  iTunesPluginHost
//
//  Created by Daniel Kennett on 01/02/2013.
//  Copyright (c) 2013 Daniel Kennett. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface iTunesVisualPlugin : NSObject

-(void)showConfiguration;

-(void)playbackStarted;
-(void)playbackStopped;
-(void)coverArtChanged:(NSImage *)coverArt;
-(void)playbackPositionUpdated:(NSTimeInterval)position;

-(void)activateInView:(NSView *)view;
-(void)deactivate;

@end
