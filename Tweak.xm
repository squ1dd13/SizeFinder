#import <MobileCoreServices/MobileCoreServices.h>
#import <AudioToolbox/AudioToolbox.h>


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

@interface SBXCloseBoxView : UIView
@property (nonatomic, assign) UILabel *sizeLabel;
@end

%hook SBXCloseBoxView
%property (nonatomic, assign) UILabel *sizeLabel;

-(void)layoutSubviews {
	%orig;
	self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, 40, self.frame.size.height);
	for(UIView *something in [self subviews]) {
		if([something respondsToSelector:@selector(image)]) {
			//get the usage from the application bundle ID held by the application property in SBIcon
			//the reason for the ternary if statement in the middle is because sometimes there is an extra UIView between the icon view and the label, which causes crashes
			NSNumber *appDiskUsage = [[LSApplicationProxy applicationProxyForIdentifier:[[[([[self superview] respondsToSelector:@selector(icon)]) ? [self superview] : [[self superview] superview] icon] application] bundleIdentifier]] valueForKey:@"staticDiskUsage"];

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
			if(!self.sizeLabel) {
				self.sizeLabel = [[UILabel alloc] initWithFrame:self.bounds];
				[self.sizeLabel setCenter:CGPointMake(self.frame.size.width / 2, self.frame.size.height / 2)];
				self.sizeLabel.textAlignment = NSTextAlignmentCenter;
				self.sizeLabel.adjustsFontSizeToFitWidth = YES;
				self.sizeLabel.text = string;
				[self.sizeLabel setFont:[UIFont systemFontOfSize:([string length] >= 5) ? 10 : 13]];
				CGSize sizeOfString = [string sizeWithAttributes:@{ NSFontAttributeName : self.sizeLabel.font }];
				NSLog(@"String width %f for string %@", sizeOfString.width, string);
				if(sizeOfString.width >= 34) {
					NSLog(@"Shrinking font to 12pt to improve appearance.");
					self.sizeLabel.font = [UIFont systemFontOfSize:([string containsString:@"4"] && [string length] >= 5) ? 10 : 12];
				}
				[self addSubview:self.sizeLabel];
			}

		}
	}
}
%end
