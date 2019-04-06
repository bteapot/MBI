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


@interface NSView (AnchorPoint)

- (void)setAnchorPoint:(CGPoint)point;

@end

@implementation NSView (AnchorPoint)

- (void)setAnchorPoint:(CGPoint)point
{
	CALayer *layer = self.layer;
	
	CGPoint newPoint = CGPointMake(self.bounds.size.width * point.x, self.bounds.size.height * point.y);
	CGPoint oldPoint = CGPointMake(self.bounds.size.width * layer.anchorPoint.x, self.bounds.size.height * layer.anchorPoint.y);
	
	newPoint = CGPointApplyAffineTransform(newPoint, layer.affineTransform);
	oldPoint = CGPointApplyAffineTransform(oldPoint, layer.affineTransform);
	
	CGPoint position = layer.position;
	
	position.x -= oldPoint.x;
	position.x += newPoint.x;
	
	position.y -= oldPoint.y;
	position.y += newPoint.y;
	
	layer.position = position;
	layer.anchorPoint = point;
}

@end


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
@property (nonatomic, assign) BOOL badged;
@property (nonatomic, assign) BOOL hideOnZero;

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
		self.hideOnZero = [[NSUserDefaults standardUserDefaults] boolForKey:@"MBIHideOnZero"];
		
		self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
		self.statusItem.highlightMode = YES;
		
		NSStatusBarButton *button = self.statusItem.button;
		button.target = self;
		button.action = @selector(statusItemPressed);
		button.wantsLayer = YES;
		
		// hack for macOS 10.13
		button.opaqueAncestor.layer = [CALayer layer];
		
		self.textAttributes = @{
			NSFontAttributeName: [NSFont boldSystemFontOfSize:12],
			NSForegroundColorAttributeName: [NSColor blackColor],
		};
		
		self.zeroWidth = ceil([@"0" sizeWithAttributes:self.textAttributes].width);
		
		self.badgeColorHasMail = [NSColor blackColor];
		self.badgeColorNoMail = [[NSColor blackColor] colorWithAlphaComponent:0.3];
		
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			if (!self.badged) {
				[self updateBadgeWithCount:0];
			}
		});
		
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
	// indicate that badge count is set
	self.badged = YES;
	
	// save current count for future comparisons
	self.count = count;
	
	
	// drawing options
	NSStringDrawingOptions options = NSStringDrawingUsesLineFragmentOrigin;
	
	// new image
	NSImage *nsImage;
	
	// show status item?
	if (self.hideOnZero == NO || count > 0) {
		// text size
		NSString *text = [NSString stringWithFormat:@"%llu", (unsigned long long)count];
		CGRect textRect = [text boundingRectWithSize:NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX) options:options attributes:self.textAttributes context:nil];
		CGFloat width = (floor(textRect.size.width / self.zeroWidth) + 2) * self.zeroWidth + 4;
		
		if ((int)width % 2 != 0) {
			width -= 1;
		}
		
		// badge and text rects
		CGRect badgeRect = CGRectMake(0, 0, width, floor(textRect.size.height));
		textRect = CGRectMake((badgeRect.size.width - textRect.size.width) / 2, (badgeRect.size.height - textRect.size.height) / 2, textRect.size.width, textRect.size.height);
		
		
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
		nsImage = [[NSImage alloc] initWithCGImage:cgImage size:badgeRect.size];
		CGImageRelease(cgImage);
		nsImage.template = YES;
	}
	
	
	// animate count change
	[self.statusItem.button setAnchorPoint:CGPointMake(0.5, 0.5)];
	
	CALayer *layer = self.statusItem.button.layer;
	NSTimeInterval duration = 0.125;
	
	[CATransaction begin];
	[CATransaction setAnimationDuration:duration];
	[CATransaction setCompletionBlock:^{
		
		[CATransaction begin];
		[CATransaction setAnimationDuration:duration];
		[CATransaction setCompletionBlock:^{
			[layer removeAllAnimations];
			layer.transform = CATransform3DIdentity;
		}];
		
		self.statusItem.button.image = nsImage;
		[self.statusItem.button setAnchorPoint:CGPointMake(0.5, 0.5)];
		
		CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.x"];
		animation.duration = duration;
		animation.fromValue = @(M_PI_2);
		animation.toValue = @0;
		[layer addAnimation:animation forKey:@"expand"];
		layer.transform = CATransform3DMakeRotation(0, 1, 0, 0);
		
		[CATransaction commit];
	}];
	
	CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.x"];
	animation.duration = duration;
	animation.fromValue = @0;
	animation.toValue = @(M_PI_2);
	[layer addAnimation:animation forKey:@"collapse"];
	layer.transform = CATransform3DMakeRotation(M_PI_2, 1, 0, 0);
	
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
