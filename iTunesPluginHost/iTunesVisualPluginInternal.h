//
//  iTunesVisualPlugin.h
//  iTunesPluginHost
//
//  Created by Daniel Kennett on 01/02/2013.
//  Copyright (c) 2013 Daniel Kennett. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "iTunesVisualAPI.h"

@interface iTunesVisualPlugin (iTunesVisualPluginInternal)

-(id)initWithMessage:(PlayerRegisterVisualPluginMessage)message;

@end
