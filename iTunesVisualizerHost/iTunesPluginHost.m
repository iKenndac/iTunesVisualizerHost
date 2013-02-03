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

		NSMutableArray *foundPlugins = [NSMutableArray array];

		NSArray *homePaths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask | NSLocalDomainMask, YES);
		for (NSString *path in homePaths)
			[foundPlugins addObjectsFromArray:[self scanDirectoryForVisualisers:[path stringByAppendingPathComponent:@"iTunes/iTunes Plug-ins"]]];

		self.plugins = [NSArray arrayWithArray:foundPlugins];
		
		for (iTunesPlugin *plugin in self.plugins) {
			[plugin addObserver:self forKeyPath:@"visualizers" options:NSKeyValueObservingOptionPrior context:nil];
			[plugin load:nil];
		}
	}

	return self;
}

-(void)dealloc {
	for (iTunesPlugin *plugin in self.plugins)
		[plugin removeObserver:self forKeyPath:@"visualizers"];
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"visualizers"]) {

		if ([change[NSKeyValueChangeNotificationIsPriorKey] boolValue])
			[self willChangeValueForKey:@"visualizers"];
		else
			[self didChangeValueForKey:@"visualizers"];

    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

-(NSArray *)visualizers {
	return [self.plugins valueForKeyPath:@"@unionOfArrays.visualizers"];
}

-(NSArray *)scanDirectoryForVisualisers:(NSString *)directoryPath {

	NSFileManager *fm = [NSFileManager defaultManager];
	NSMutableArray *foundPlugins = [NSMutableArray new];
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

	return foundPlugins;
}

@end
