//
//  iTunesPlugin.h
//  iTunesPluginHost
//
//  Created by Daniel Kennett on 01/02/2013.
//  Copyright (c) 2013 Daniel Kennett. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "iTunesVisualPlugin.h"

@interface iTunesPlugin : NSObject

+(dispatch_queue_t)pluginQueue;

-(id)initWithBundle:(NSBundle *)bundle;
-(void)load:(dispatch_block_t)callback;

@property (nonatomic, readonly, strong) NSArray *visualizers;

@end
