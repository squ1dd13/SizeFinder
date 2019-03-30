#import <MobileCoreServices/MobileCoreServices.h>
#import <AudioToolbox/AudioToolbox.h>

Class CloseBoxClass;

//pow(1*10, 6) == 1000000
void MB(NSNumber **original) {
	*original = @([*original doubleValue] / 1000000);
}

void MBtoKB(NSNumber **original) {
	*original = @([*original doubleValue] * 1000);
}

void GB(NSNumber **megabytes) {
	*megabytes = @([*megabytes doubleValue] / 1000);
}

@interface LSResourceProxy
@property (nonatomic, copy, null_unspecified) NSString *localizedName;
@end

@interface LSBundleProxy : LSResourceProxy
@property (nonatomic, readonly, null_unspecified) NSString *bundleIdentifier;
@property (nonatomic, readonly, null_unspecified) NSString *localizedShortName;
@property (nonatomic, readonly, null_unspecified) NSURL *bundleURL;
@end

@interface _LSDiskUsage : NSObject
@property (nonatomic, readonly) NSNumber *dynamicUsage;
@property (nonatomic, readonly) NSNumber *onDemandResourcesUsage;
@property (nonatomic, readonly) NSNumber *sharedUsage;
@property (nonatomic, readonly) NSNumber *staticUsage;
@end

@interface LSApplicationProxy : LSBundleProxy
+ (id)applicationProxyForIdentifier:(id)arg1;
@property (nonatomic, readonly) NSNumber *staticDiskUsage;
@end

@interface LSApplicationWorkspace : NSObject
+ (nonnull instancetype)defaultWorkspace;
- (nullable NSArray<LSApplicationProxy *> *)allInstalledApplications;
@end

%hook CloseBoxView

// Yeah, layoutSubviews. I couldn't care less.
-(void)layoutSubviews {
	%orig;
	UIView *view;
	UIView *selfView;
	selfView = self;
	if([[[UIDevice currentDevice] systemVersion] floatValue] >= 12.0){
		view = MSHookIvar<UIView *>(self, "_materialView");
	}
	else{
		view = selfView;
	}
	if([[[UIDevice currentDevice] systemVersion] floatValue] < 11.0){
		UIView *background = MSHookIvar<UIView *>(self, "_backgroundView");
		background.frame = CGRectMake(background.frame.origin.x, background.frame.origin.y, 40, background.frame.size.height);
		UIView *whiteBackground = MSHookIvar<UIView *>(self, "_whiteTintView");
		whiteBackground.frame = CGRectMake(whiteBackground.frame.origin.x, whiteBackground.frame.origin.y, 40, whiteBackground.frame.size.height);
	}
	selfView.frame = CGRectMake(selfView.frame.origin.x, selfView.frame.origin.y, 40, selfView.frame.size.height);
	for(UIView *something in [view subviews]) {
		if([something respondsToSelector:@selector(image)]) {
			//get the usage from the application bundle ID held by the application property in SBIcon
			//the reason for the ternary if statement in the middle is because sometimes there is an extra UIView between the icon view and the label, which causes crashes
			NSNumber *appDiskUsage = [[LSApplicationProxy applicationProxyForIdentifier:[[[([[selfView superview] respondsToSelector:@selector(icon)]) ? [selfView superview] : [[selfView superview] superview] icon] application] bundleIdentifier]] valueForKey:@"staticDiskUsage"];

			MB(&appDiskUsage); //convert to mb

			//put it into a string with the unit so the user knows what they are looking at
			NSString *stringSize = [NSString stringWithFormat:@"%.0fmb", round([appDiskUsage doubleValue])];
			//if the app is less than 0.5 megabytes it will be rounded down to 0, so we need to fix that by converting to kb
			if([stringSize isEqualToString:@"0mb"]) {
				MBtoKB(&appDiskUsage);
				stringSize = [NSString stringWithFormat:@"%.0fkb", [appDiskUsage doubleValue]];
			}

			if([stringSize length] >= 6) {
				GB(&appDiskUsage);
				stringSize = [NSString stringWithFormat:@"%.2fgb", [appDiskUsage doubleValue]];
			}

			NSString *string = stringSize;

			something.hidden = YES;
			//other stuff makes iOS 12 crash, this is stupid
			if([[view subviews] count] == 4){
				UILabel *sizeLabel = [[UILabel alloc] initWithFrame:selfView.bounds];
				[sizeLabel setCenter:CGPointMake(selfView.frame.size.width / 2, selfView.frame.size.height / 2)];
				sizeLabel.textAlignment = NSTextAlignmentCenter;
				sizeLabel.adjustsFontSizeToFitWidth = YES;
				sizeLabel.text = string;
				[sizeLabel setFont:[UIFont systemFontOfSize:([string length] >= 5) ? 10 : 13]];
				CGSize sizeOfString = [string sizeWithAttributes:@{ NSFontAttributeName : sizeLabel.font }];
				NSLog(@"String width %f for string %@", sizeOfString.width, string);
				if(sizeOfString.width >= 34) {
					NSLog(@"Shrinking font to 12pt to improve appearance.");
					sizeLabel.font = [UIFont systemFontOfSize:([string containsString:@"4"] && [string length] >= 5) ? 10 : 12];
				}
				[view addSubview:sizeLabel];
			}

		}
	}
}
%end

%ctor{
	if([[[UIDevice currentDevice] systemVersion] floatValue] < 11.0){
		CloseBoxClass = objc_getClass("SBCloseBoxView");
	}
	else{
		CloseBoxClass = objc_getClass("SBXCloseBoxView");
	}
	%init(_ungrouped, CloseBoxView = CloseBoxClass);
}