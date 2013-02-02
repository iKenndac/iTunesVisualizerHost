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
@property (nonatomic, readwrite, strong) NSArray *visualisers;

@end

OSStatus HostAppProc(void *appCookie, OSType message, struct PlayerMessageInfo *messageInfo) {
	iTunesPlugin *plugin = appCookie;
	return [plugin handleMessage:message withInfo:messageInfo];
}

@implementation iTunesPlugin {
	void *pluginHandle;
	void *pluginMainFunctionHandle;
	void *pluginMainRefCon;
}

-(id)initWithBundle:(NSBundle *)bundle {
	self = [super init];
	if (self) {
		self.visualisers = [[NSArray new] autorelease];
		self.pluginBundle = bundle;
	}
	return self;
}

-(void)dealloc {

	self.visualisers = nil;

	PluginMessageInfo info;
	memset(&info, 0, sizeof(PluginMessageInfo));
	iTunesPluginMainMachO pluginMain = pluginMainFunctionHandle;
	pluginMain(kPluginPrepareToQuitMessage, &info, pluginMainRefCon);
	pluginMain(kPluginCleanupMessage, &info, pluginMainRefCon);

	if (pluginHandle != NULL) {
		if (dlclose(pluginHandle) != 0) {
			const char *error = dlerror();
			NSLog(@"%@", @(error));
		}
	}
	pluginHandle = NULL;
	pluginMainFunctionHandle = NULL;

	self.pluginBundle = nil;

	[super dealloc];
}

-(void)load {

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
	void *ref = NULL;
	pluginMain(kPluginInitMessage, &info, ref);
	pluginMainRefCon = info.u.initMessage.refCon;
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

	iTunesVisualPlugin *visualiser = [[iTunesVisualPlugin alloc] initWithMessage:message];
	if (visualiser) self.visualisers = [self.visualisers arrayByAddingObject:visualiser];
	[visualiser release];

	return noErr;
}

@end
