//
//  iTunesPlugin.m
//  iTunesPluginHost
//
//  Created by Daniel Kennett on 01/02/2013.
//  Copyright (c) 2013 Daniel Kennett. All rights reserved.
//

#import "iTunesPlugin.h"
#import "iTunesVisualAPI.h"
#import "dlfcn.h"
#import "iTunesVisualPlugin.h"
#import "iTunesVisualPluginInternal.h"

#if __has_feature(objc_arc)
#error This class does not support ARC.
#endif

typedef OSStatus (*iTunesPluginMainMachO)(OSType message, PluginMessageInfo *messageInfo, void *refCon);

@interface iTunesPlugin ()

-(OSStatus)handleMessage:(OSType)message withInfo:(PlayerMessageInfo *)info;

@property (nonatomic, readwrite, strong) NSBundle *pluginBundle;
@property (nonatomic, readwrite, strong) NSArray *visualizers;

@end

OSStatus HostAppProc(void *appCookie, OSType message, struct PlayerMessageInfo *messageInfo) {
	iTunesPlugin *plugin = appCookie;
	return [plugin handleMessage:message withInfo:messageInfo];
}

@implementation iTunesPlugin {
	// These should ONLY be touched on +[iTunesPlugin pluginQueue];
	void *pluginHandle;
	void *pluginMainFunctionHandle;
	void *pluginMainRefCon;
}

static dispatch_queue_t pluginQueue;

+(void)initialize {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		pluginQueue = dispatch_queue_create("org.danielkennett.iTunesPluginHost", DISPATCH_QUEUE_SERIAL);
	});
}

+(dispatch_queue_t)pluginQueue {
	return pluginQueue;
}

-(id)initWithBundle:(NSBundle *)bundle {
	self = [super init];
	if (self) {
		self.visualizers = [[NSArray new] autorelease];
		self.pluginBundle = bundle;
	}
	return self;
}

-(void)dealloc {

	self.visualizers = nil;
	self.pluginBundle = nil;

	void *outgoingPluginHandle = pluginHandle;
	void *outgoingPluginMainFunctionHandle = pluginMainFunctionHandle;
	void *outgoingPluginMainRefCon = pluginMainRefCon;

	pluginHandle = NULL;
	pluginMainFunctionHandle = NULL;
	pluginMainRefCon = NULL;

	dispatch_async([iTunesPlugin pluginQueue], ^{
		PluginMessageInfo info;
		memset(&info, 0, sizeof(PluginMessageInfo));
		iTunesPluginMainMachO pluginMain = outgoingPluginMainFunctionHandle;
		pluginMain(kPluginPrepareToQuitMessage, &info, outgoingPluginMainRefCon);
		pluginMain(kPluginCleanupMessage, &info, outgoingPluginMainRefCon);

		if (outgoingPluginHandle != NULL) {
			if (dlclose(outgoingPluginHandle) != 0) {
				const char *error = dlerror();
				NSLog(@"%@", @(error));
			}
		}
	});

	[super dealloc];
}

-(void)load:(dispatch_block_t)callback {

	dispatch_async([iTunesPlugin pluginQueue], ^{
		
		pluginHandle = dlopen([self.pluginBundle.executablePath UTF8String], RTLD_LAZY | RTLD_LOCAL);
		const char *error = dlerror();
		if (error != NULL) {
			NSLog(@"%@", @(error));
			return;
		}

		pluginMainFunctionHandle = dlsym(pluginHandle, "iTunesPluginMainMachO");
		error = dlerror();
		if (error != NULL || pluginMainFunctionHandle == NULL) {
			NSLog(@"%@", @(error));
			return;
		}

		PluginMessageInfo info;
		memset(&info, 0, sizeof(PluginMessageInfo));
		info.u.initMessage.appProc = HostAppProc;
		info.u.initMessage.majorVersion = 10;
		info.u.initMessage.minorVersion = 4;
		info.u.initMessage.appCookie = (void *)self;

		iTunesPluginMainMachO pluginMain = pluginMainFunctionHandle;
		pluginMain(kPluginInitMessage, &info, NULL);
		pluginMainRefCon = info.u.initMessage.refCon;

		if (callback) dispatch_async(dispatch_get_main_queue(), callback);
	});
}

#pragma mark - Handling Messages 

-(OSStatus)handleMessage:(OSType)message withInfo:(PlayerMessageInfo *)info {

	switch (message) {
		case kPlayerRegisterVisualPluginMessage:
			return [self handleRegisterVisualPluginMessage:info->u.registerVisualPluginMessage];
			break;

		default:
			NSLog(@"Got message!");
			break;
	}

	return noErr;
}

-(OSStatus)handleRegisterVisualPluginMessage:(PlayerRegisterVisualPluginMessage)message {

	NSAssert(dispatch_get_current_queue() == pluginQueue, @"Callback on wrong queue!");
	iTunesVisualPlugin *visualiser = [[[iTunesVisualPlugin alloc] initWithMessage:message] autorelease];
	if (visualiser) {
		dispatch_async(dispatch_get_main_queue(), ^{
			self.visualizers = [self.visualizers arrayByAddingObject:visualiser];
		});
	}

	return noErr;
}

@end
