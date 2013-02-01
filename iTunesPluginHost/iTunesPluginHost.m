//
//  iTunesPluginHost.m
//  iTunesPluginHost
//
//  Created by Daniel Kennett on 01/02/2013.
//  Copyright (c) 2013 Daniel Kennett. All rights reserved.
//

#import "iTunesPluginHost.h"
#import "iTunesPlugin.h"

@interface iTunesPluginHost ()

@property (nonatomic, readwrite, strong) NSArray *plugins;

@end

@implementation iTunesPluginHost

-(id)init {

	if (self = [super init]) {

		NSMutableArray *foundPlugins = [NSMutableArray new];
		NSFileManager *fm = [NSFileManager defaultManager];

		NSString *directoryPath = [@"~/Library/iTunes/iTunes Plug-ins" stringByExpandingTildeInPath];
		NSDirectoryEnumerator *pluginEnumerator = [fm enumeratorAtPath:directoryPath];


		NSString *currentSubPath = nil;
		while (currentSubPath = [pluginEnumerator nextObject]) {

			NSString *currentPath = [directoryPath stringByAppendingPathComponent:currentSubPath];

			BOOL directory = NO;
			[fm fileExistsAtPath:currentPath isDirectory:&directory];

			if (directory) {

				NSBundle *bundle = [NSBundle bundleWithPath:currentPath];
				NSString *type = [[bundle infoDictionary] valueForKey:@"CFBundlePackageType"];

				if ([type isEqualToString:@"hvpl"]) {
					[foundPlugins addObject:[[iTunesPlugin alloc] initWithBundle:bundle]];
					NSLog(@"Found plugin: %@", [[bundle infoDictionary] valueForKey:@"CFBundleName"]);
				}

				[pluginEnumerator skipDescendants];
			}
		}

		self.plugins = [NSArray arrayWithArray:foundPlugins];
		[self loadPlugins];
	}

	return self;
}

-(void)loadPlugins {

	for (iTunesPlugin *plugin in self.plugins)
		[plugin load];
	
}


@end
