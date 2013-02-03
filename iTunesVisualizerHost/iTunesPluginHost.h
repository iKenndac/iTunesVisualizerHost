//
//  iTunesPluginHost.h
//  iTunesPluginHost
//
//  Created by Daniel Kennett on 01/02/2013.
//  Copyright (c) 2013 Daniel Kennett. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "iTunesPlugin.h"

@interface iTunesPluginHost : NSObject

@property (nonatomic, readonly, strong) NSArray *plugins;
@property (nonatomic, readonly, strong) NSArray *visualizers;

@end
