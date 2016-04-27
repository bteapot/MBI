//
//  MVMailBundle.h
//  MBI
//
//  Created by Денис Либит on 26.04.2016.
//  Copyright © 2016 Денис Либит. All rights reserved.
//

@interface MVMailBundle : NSObject

+ (id)composeAccessoryViewOwnerClassName;
+ (BOOL)hasComposeAccessoryViewOwner;
+ (id)preferencesPanelName;
+ (id)preferencesOwnerClassName;
+ (BOOL)hasPreferencesPanel;
+ (id)sharedInstance;
+ (void)registerBundle;
+ (id)composeAccessoryViewOwners;
+ (id)allBundles;
- (void)dealloc;

@end
