//
//  MBIController.m
//  MBI
//
//  Created by Денис Либит on 26.04.2016.
//  Copyright © 2016 Денис Либит. All rights reserved.
//

#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
#import "MBIController.h"
#import "MVMailBundle.h"


@interface MBIController (MBI)

+ (void)registerBundle;

@end


@interface MBIController ()

@property (nonatomic, assign) NSUInteger count;
@property (nonatomic, strong) NSStatusItem *statusItem;
@property (nonatomic, strong) NSDictionary *textAttributes;
@property (nonatomic, assign) CGFloat zeroWidth;
@property (nonatomic, strong) NSColor *badgeColorHasMail;
@property (nonatomic, strong) NSColor *badgeColorNoMail;

@end


@implementation MBIController

#pragma mark - Lifecycle

//
// -----------------------------------------------------------------------------
+ (void)initialize
{
	Class mvMailBundleClass = NSClassFromString(@"MVMailBundle");
	
	if (!mvMailBundleClass) {
		return;
	}
	
	#pragma GCC diagnostic push
	#pragma GCC diagnostic ignored "-Wdeprecated"
	class_setSuperclass(self, mvMailBundleClass);
	#pragma GCC diagnostic pop
	
	[self sharedInstance];
	[self registerBundle];
}

//
// -----------------------------------------------------------------------------
+ (instancetype)sharedInstance
{
	static dispatch_once_t onceToken;
	static MBIController *instance;
	dispatch_once(&onceToken, ^{
		instance = [[MBIController alloc] init];
	});
	
	return instance;
}

//
// -----------------------------------------------------------------------------
- (instancetype)init
{
	self = [super init];
	
	if (self) {
		self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
		self.statusItem.title = nil;
		self.statusItem.image = nil;
		self.statusItem.highlightMode = YES;
		self.statusItem.button.target = self;
		self.statusItem.button.action = @selector(statusItemPressed);
		self.statusItem.button.wantsLayer = YES;
		
		self.textAttributes = @{
			NSFontAttributeName: [NSFont boldSystemFontOfSize:12],
			NSForegroundColorAttributeName: [NSColor blackColor],
		};
		
		self.zeroWidth = ceil([@"0" sizeWithAttributes:self.textAttributes].width);
		
		self.badgeColorHasMail = [NSColor blackColor];
		self.badgeColorNoMail = [[NSColor blackColor] colorWithAlphaComponent:0.3];
		
		[self updateBadgeWithCount:0];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mailboxDisplayCountDidChange) name:@"MailboxDisplayCountDidChange" object:nil];
	}
	
	return self;
}

//
// -----------------------------------------------------------------------------
- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[[NSStatusBar systemStatusBar] removeStatusItem:self.statusItem];
}


#pragma mark - Count change notification

//
// -----------------------------------------------------------------------------
- (void)mailboxDisplayCountDidChange
{
	NSApplication *sharedApp = [NSApplication sharedApplication];
	NSArray *accounts = [sharedApp valueForKey:@"accounts"];
	NSUInteger count = 0;
	
	for (id account in accounts) {
		count += [[account valueForKeyPath:@"inboxMailbox.displayCount"] integerValue];
	}
	
	if (count != self.count) {
		[self updateBadgeWithCount:count];
	}
}


#pragma mark - Status item

//
// -----------------------------------------------------------------------------
- (void)updateBadgeWithCount:(NSUInteger)count
{
	// save current count for future comparisons
	self.count = count;
	
	
	// drawing options
	NSStringDrawingOptions options = NSStringDrawingUsesLineFragmentOrigin;
	
	// text size
	NSString *text = [NSString stringWithFormat:@"%llu", (unsigned long long)count];
	CGRect textRect = [text boundingRectWithSize:NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX) options:options attributes:self.textAttributes context:nil];
	CGFloat minWidth = ceil(1 + textRect.size.width / self.zeroWidth) * self.zeroWidth;
	
	// badge and text rects
	CGRect badgeRect = CGRectMake(0, 0, ceil(MAX(textRect.size.width, minWidth)) + 6, ceil(textRect.size.height) + 2);
	textRect = CGRectMake(ceil((badgeRect.size.width - textRect.size.width) / 2), ceil((badgeRect.size.height - textRect.size.height) / 2), textRect.size.width, textRect.size.height);
	
	
	// image mask
	CGColorSpaceRef grayColorspace = CGColorSpaceCreateDeviceGray();
	CGContextRef maskContext = CGBitmapContextCreate(NULL, badgeRect.size.width, badgeRect.size.height, 8, badgeRect.size.width * 4, grayColorspace, kCGImageAlphaNone);
	CGColorSpaceRelease(grayColorspace);
	
	NSGraphicsContext *maskGraphicsContext = [NSGraphicsContext graphicsContextWithGraphicsPort:maskContext flipped:NO];
	[NSGraphicsContext saveGraphicsState];
	[NSGraphicsContext setCurrentContext:maskGraphicsContext];
	
	// white background
	[[NSColor whiteColor] setFill];
	NSRectFill(badgeRect);
	
	// draw text
	[text drawWithRect:textRect options:options attributes:self.textAttributes];
	
	// pop context
	[NSGraphicsContext restoreGraphicsState];
	
	// create an image mask
	CGImageRef alphaMask = CGBitmapContextCreateImage(maskContext);
	CGContextRelease(maskContext);
	
	
	// image
	CGColorSpaceRef rgbColorspace = CGColorSpaceCreateDeviceRGB();
	CGContextRef imageContext = CGBitmapContextCreate(NULL, badgeRect.size.width, badgeRect.size.height, 8, badgeRect.size.width * 4, rgbColorspace, kCGImageAlphaPremultipliedLast);
	CGColorSpaceRelease(rgbColorspace);
	
	NSGraphicsContext *imageGraphicsContext = [NSGraphicsContext graphicsContextWithGraphicsPort:imageContext flipped:NO];
	[NSGraphicsContext saveGraphicsState];
	[NSGraphicsContext setCurrentContext:imageGraphicsContext];
	
	// clip context with mask
	CGContextSaveGState(imageContext);
	CGContextClipToMask(imageContext, badgeRect, alphaMask);
	CGImageRelease(alphaMask);
	
	// badge color
	if (count == 0) {
		[self.badgeColorNoMail setFill];
	} else {
		[self.badgeColorHasMail setFill];
	}
	
	// draw the badge
	CGFloat radius = badgeRect.size.height / 2;
	NSBezierPath *badge = [NSBezierPath bezierPathWithRoundedRect:badgeRect xRadius:radius yRadius:radius];
	[badge fill];
	
	// pop context
	CGContextRestoreGState(imageContext);
	[NSGraphicsContext restoreGraphicsState];
	
	// take image
	CGImageRef cgImage = CGBitmapContextCreateImage(imageContext);
	CGContextRelease(imageContext);
	
	// set image
	NSImage *nsImage = [[NSImage alloc] initWithCGImage:cgImage size:badgeRect.size];
	CGImageRelease(cgImage);
	nsImage.template = YES;
	
	
	// animate count change
	CALayer *layer = self.statusItem.button.layer;
	NSTimeInterval duration = 0.125;
	
	[CATransaction begin];
	[CATransaction setAnimationDuration:duration];
	[CATransaction setCompletionBlock:^{
		
		[CATransaction begin];
		[CATransaction setAnimationDuration:duration];
		
		self.statusItem.button.image = nsImage;
		
		CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.x"];
		animation.duration = duration;
		animation.fromValue = @(M_PI_2);
		animation.toValue = @0;
		animation.removedOnCompletion = NO;
		[layer addAnimation:animation forKey:@"expand"];
		
		[CATransaction commit];
	}];
	
	CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.x"];
	animation.duration = duration;
	animation.fromValue = @0;
	animation.toValue = @(M_PI_2);
	animation.removedOnCompletion = NO;
	[layer addAnimation:animation forKey:@"collapse"];
	
	[CATransaction commit];
}

//
// -----------------------------------------------------------------------------
- (void)statusItemPressed
{
	NSApplication *application = [NSApplication sharedApplication];
	
	if (application.active) {
		[application hide:self];
	} else {
		[application activateIgnoringOtherApps:YES];
	}
}

@end
