#include <MobileCoreServices/MobileCoreServices.h>

@interface CloseBox : UIView
-(id)delegate;
@end

@interface LSApplicationProxy
+(id)applicationProxyForIdentifier:(id)arg1;
@property (nonatomic, readonly) NSNumber *staticDiskUsage;
@property (nonatomic, readonly, null_unspecified) NSString *bundleIdentifier;
@end

static int iOSVersion;

typedef unsigned SizeUnit;
#define B 1
#define KB 1000
#define MB 1000000
#define GB 1000000000

unsigned convert(const unsigned value, const SizeUnit from, const SizeUnit to) {
	const unsigned bytesValue = value * int(from);
	return bytesValue / to;
}

unsigned autoConvert(unsigned value, const SizeUnit from, SizeUnit &to) {
	//Convert to bytes so we needn't worry about the initial unit.
	value = convert(value, from, B);

	if(value < KB) {
		to = B;
		return value;
	}

	if(KB <= value && value < MB) {
		to = KB;
		return convert(value, B, KB);
	}

	if(MB <= value && value < GB) {
		to = MB;
		return convert(value, B, MB);
	}

	to = GB;
	return convert(value, B, GB);
}

NSString *getUnitString(const SizeUnit unit) {
	switch(unit) {
		case(B): return @"B";
		case(KB): return @"KB";
		case(MB): return @"MB";
		case(GB): return @"GB";
		default: return @"FU";
	}
}

%hook CloseBox

-(void)didMoveToSuperview {
	%orig;
#define self ((CloseBox *)self)
	UIView *view = iOSVersion > 11 ? [self valueForKey:@"_materialView"] : self;
	bool hasLabel = [[[view subviews] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self isMemberOfClass: %@", [UILabel class]]] count] > 0;
	if(hasLabel) {
		//Don't bother going further.
		return;
	}

	//10 and below have some random crap that we need to get rid of.
	if(iOSVersion < 11){
		UIView *background = [self valueForKey:@"_backgroundView"];
		background.frame = CGRectMake(background.frame.origin.x, background.frame.origin.y, 40, background.frame.size.height);
		UIView *whiteBackground = [self valueForKey:@"_whiteTintView"];
		whiteBackground.frame = CGRectMake(whiteBackground.frame.origin.x, whiteBackground.frame.origin.y, 40, whiteBackground.frame.size.height);
	}

	self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, 40, self.frame.size.height);

	//Hide all subviews that are UIImageViews, because there are multiple 'X' images (just in case one of them breaks or sth ofc).
	NSArray *imageViews = [[view subviews] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id subview, NSDictionary *bindings) {
		//KILL IT
    	return [subview isMemberOfClass:[UIImageView class]];
	}]];
	
	[imageViews makeObjectsPerformSelector:@selector(setAlpha:) withObject:@(0.0)];

	//The close box's delegate is the icon view that leads us to the SBApplication which is stored here in 'application'.
	id iconView = [self delegate];
	id application = [[iconView performSelector:@selector(icon)] performSelector:@selector(application)];
	//Get the bundle ID from the SBApplication and create an application proxy. The proxy gives us a bunch of info about the app.
	NSString *bundleIdentifier = [application performSelector:@selector(bundleIdentifier)];
	LSApplicationProxy *proxy = [LSApplicationProxy applicationProxyForIdentifier:bundleIdentifier];

	//This SizeUnit (unsigned int) will store the unit that the automatic converter converted our byte value ([proxy staticDiskUsage]) to.
	SizeUnit unit;
	unsigned appDiskUsage = autoConvert([[proxy staticDiskUsage] intValue], B, unit);
	NSString *string = [NSString stringWithFormat:@"%u%@", appDiskUsage, getUnitString(unit)];

	UILabel *sizeLabel = [[UILabel alloc] initWithFrame:self.bounds];
	[sizeLabel setCenter:CGPointMake(self.frame.size.width / 2, self.frame.size.height / 2)];
	sizeLabel.textAlignment = NSTextAlignmentCenter;
	sizeLabel.adjustsFontSizeToFitWidth = YES;
	sizeLabel.text = string;

	//I can't really explain the sizing, because I wrote this nearly a year ago and forgot to comment this. I remember it took a long time though.
	[sizeLabel setFont:[UIFont systemFontOfSize:([string length] >= 5) ? 9 : 12]];
	CGSize sizeOfString = [string sizeWithAttributes:@{ NSFontAttributeName : sizeLabel.font }];
	if(sizeOfString.width > 33) {
		//Width over 33? We can't have that.
		const int fontSize = ([string containsString:@"4"] && [string length] > 4) ? 9 : 11;
		sizeLabel.font = [UIFont systemFontOfSize:fontSize];
	}

	[view addSubview:sizeLabel];
#undef self
}

%end

%ctor {
	//Having the integer value is useful, as comparing the float value of [[UIDevice currentDevice] systemVersion] to another float is very unreliable.
	//For starters, x.y.z is not a valid float, and besides - float comparison is unreliable.
	iOSVersion = [[[[UIDevice currentDevice] systemVersion] componentsSeparatedByString:@"."][0] intValue];

	Class boxClass = objc_getClass(iOSVersion < 11 ? "SBCloseBoxView" : "SBXCloseBoxView");
	%init(CloseBox = boxClass);
}

