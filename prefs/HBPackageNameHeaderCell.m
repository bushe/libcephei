#import "HBPackageNameHeaderCell.h"
#import "../HBOutputForShellCommand.h"
#import <Preferences/PSSpecifier.h>
#import <version.h>

static CGFloat const kHBPackageNameTableCellCondensedFontSize = 25.f;
static CGFloat const kHBPackageNameTableCellHeaderFontSize = 42.f;
static CGFloat const kHBPackageNameTableCellSubtitleFontSize = 18.f;

static NSString *const kHBDebianControlFilePackageKey = @"Package";
static NSString *const kHBDebianControlFileNameKey = @"Name";
static NSString *const kHBDebianControlFileVersionKey = @"Version";
static NSString *const kHBDebianControlFileAuthorKey = @"Author";

@implementation HBPackageNameHeaderCell {
	BOOL _condensed;
	BOOL _showAuthor;
	BOOL _showVersion;

	NSDictionary *_packageDetails;
	NSString *_nameOverride;
	UIImage *_icon;

	UIColor *_condensedColor;
	UIColor *_headerColor;
	UIColor *_subtitleColor;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier specifier:(PSSpecifier *)specifier {
	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier specifier:specifier];

	if (self) {
		self.backgroundColor = [UIColor clearColor];
		self.backgroundView = IS_MODERN ? nil : [[[UIView alloc] init] autorelease];
		self.textLabel.textAlignment = NSTextAlignmentCenter;
		self.textLabel.adjustsFontSizeToFitWidth = NO;
		self.textLabel.adjustsLetterSpacingToFitWidth = NO;

		self.condensedColor = [self colorWithHexString:specifier.properties[@"condensedColor"]];
		self.headerColor = [self colorWithHexString:specifier.properties[@"headerColor"]];
		self.subtitleColor = [self colorWithHexString:specifier.properties[@"subtitleColor"]];

		_condensed = specifier.properties[@"condensed"] && ((NSNumber *)specifier.properties[@"condensed"]).boolValue;
		_showAuthor = !specifier.properties[@"showAuthor"] || ((NSNumber *)specifier.properties[@"showAuthor"]).boolValue;
		_showVersion = !specifier.properties[@"showVersion"] || ((NSNumber *)specifier.properties[@"showVersion"]).boolValue;
		_icon = [specifier.properties[@"iconImage"] retain];
		_nameOverride = [specifier.properties[@"packageNameOverride"] copy];

		_packageDetails = [@{
			kHBDebianControlFilePackageKey: specifier.properties[@"packageIdentifier"]
		} retain];

		[self updateData];
	}

	return self;
}

- (instancetype)initWithSpecifier:(PSSpecifier *)specifier {
	self = [self initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil specifier:specifier];
	return self;
}

- (void)layoutSubviews {
	[super layoutSubviews];

	CGRect labelFrame = self.textLabel.frame;
	labelFrame.origin.y += 30.f;
	labelFrame.size.height -= 30.f;
	self.textLabel.frame = labelFrame;
}

#pragma mark - PSHeaderFooterView

- (CGFloat)preferredHeightForWidth:(CGFloat)width {
	CGFloat height = _condensed ? 74.f : 94.f;

	if (_showAuthor) {
		height += 26.f;
	}

	if (_showVersion && !_condensed) {
		height += 26.f;
	}

	return height;
}

#pragma mark - Updating

- (void)updateData {
	[self _retrievePackageDetails];

	if ([_packageDetails.allValues containsObject:@""]) {
		// i hate pirate repos
		return;
	}

	if (![self.textLabel respondsToSelector:@selector(setAttributedText:)]) {
		// starting to realise the features we take for granted these days...
		self.textLabel.text = [NSString stringWithFormat:@"%@%@%@", _packageDetails[kHBDebianControlFileNameKey], _showVersion ? @" " : @"", _showVersion ? _packageDetails[kHBDebianControlFileVersionKey] : @""];
		return;
	}

	NSUInteger cleanedAuthorLocation = [(NSString *)_packageDetails[kHBDebianControlFileAuthorKey] rangeOfString:@" <"].location;
	NSString *cleanedAuthor = cleanedAuthorLocation == NSNotFound ? _packageDetails[kHBDebianControlFileAuthorKey] : [_packageDetails[kHBDebianControlFileAuthorKey] substringWithRange:NSMakeRange(0, cleanedAuthorLocation)];

	NSString *icon = _icon && _condensed ? @"ICON " : @""; // note: there's a zero width space here
	NSString *name = _packageDetails[kHBDebianControlFileNameKey];
	NSString *version = _showVersion ? [NSString stringWithFormat:_condensed ? @" %@" : [@"\n" stringByAppendingString:LOCALIZE(@"HEADER_VERSION", @"PackageNameHeaderCell", @"The subheading containing the package version.")], _packageDetails[kHBDebianControlFileVersionKey]] : @"";
	NSString *author = _showAuthor ? [NSString stringWithFormat:[@"\n" stringByAppendingString:LOCALIZE(@"HEADING_AUTHOR", @"PackageNameHeaderCell", @"The subheading containing the package author.")], cleanedAuthor] : @"";

	NSMutableAttributedString *attributedString = [[[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@%@%@%@", icon, name, version, author] attributes:@{
		NSKernAttributeName: [NSNull null], // this *enables* kerning, interestingly
	}] autorelease];

	NSUInteger location = 0, length = 0;

	if (_icon && _condensed) {
		NSTextAttachment *textAttachment = [[[NSTextAttachment alloc] init] autorelease];
		textAttachment.image = _icon;
		[attributedString replaceCharactersInRange:NSMakeRange(0, 4) withAttributedString:[NSAttributedString attributedStringWithAttachment:textAttachment]];
	}

	length = name.length;

	NSMutableParagraphStyle *paragraphStyle = [[[NSMutableParagraphStyle alloc] init] autorelease];
	paragraphStyle.lineSpacing = _condensed ? 10.f : 4.f;
	paragraphStyle.alignment = NSTextAlignmentCenter;

	if (_condensed) {
		location++;
		length++;

		[attributedString addAttributes:@{
			NSFontAttributeName: [UIFont systemFontOfSize:kHBPackageNameTableCellCondensedFontSize],
			NSBaselineOffsetAttributeName: @(6.f),
			NSParagraphStyleAttributeName: paragraphStyle,
			NSForegroundColorAttributeName: self.condensedColor
		} range:NSMakeRange(location, length + version.length + 1)];
	} else {
		[attributedString addAttributes:@{
			NSFontAttributeName: [UIFont fontWithName:@"HelveticaNeue-Light" size:kHBPackageNameTableCellHeaderFontSize],
			NSParagraphStyleAttributeName: paragraphStyle,
			NSForegroundColorAttributeName: self.headerColor
		} range:NSMakeRange(location, length)];
	}

	if (_showVersion) {
		location += length;
		length = version.length;

		[attributedString addAttributes:@{
			NSFontAttributeName: _condensed ? [UIFont fontWithName:@"HelveticaNeue-Light" size:kHBPackageNameTableCellCondensedFontSize] : [UIFont systemFontOfSize:kHBPackageNameTableCellSubtitleFontSize],
			NSForegroundColorAttributeName: self.condensedColor
		} range:NSMakeRange(location, length)];
	}

	if (_showAuthor) {
		location += length;
		length = author.length;

		[attributedString addAttributes:@{
			NSFontAttributeName: [UIFont systemFontOfSize:kHBPackageNameTableCellSubtitleFontSize],
			NSForegroundColorAttributeName: self.subtitleColor
		} range:NSMakeRange(location, length)];
	}

	self.textLabel.numberOfLines = 0;
	self.textLabel.attributedText = attributedString;
}

- (void)_retrievePackageDetails {
	NSString *identifier = _packageDetails[kHBDebianControlFilePackageKey];
	NSArray *packageData = [HBOutputForShellCommand([NSString stringWithFormat:@"/usr/bin/dpkg-query -f '${Name}\n==libcephei-divider==\n${Version}\n==libcephei-divider==\n${Author}' -W '%@'", identifier]) componentsSeparatedByString:@"\n==libcephei-divider==\n"];

	NSString *name = packageData[0] ?: @"";

	if (_nameOverride) {
		name = _nameOverride;
	}

	[_packageDetails release];

	_packageDetails = [@{
		kHBDebianControlFilePackageKey: identifier,
		kHBDebianControlFileNameKey: name,
		kHBDebianControlFileVersionKey: packageData[1] ?: @"",
		kHBDebianControlFileAuthorKey: packageData[2] ?: @"",
	} retain];
}

#pragma mark color setters/getters

- (void)setCondensedColor:(UIColor *)condensedColor {
	_condensedColor = condensedColor;
}

- (void)setHeaderColor:(UIColor *)headerColor {
	_headerColor = headerColor;
}

- (void)setSubtitleColor:(UIColor *)subtitleColor {
	_subtitleColor = subtitleColor;
}

- (UIColor *)condensedColor {
	return _condensedColor ?: [UIColor darkGrayColor];
}

- (UIColor *)headerColor {
	return _headerColor ?: [UIColor darkGrayColor];
}

- (UIColor *)subtitleColor {
	return _subtitleColor ?: [UIColor darkGrayColor];
}

#pragma mark helper methods
//http://stackoverflow.com/questions/3010216/how-can-i-convert-rgb-hex-string-into-uicolor-in-objective-c - thanks!
- (UIColor *)colorWithHexString:(NSString *)stringToConvert {
    NSString *noHashString = [stringToConvert stringByReplacingOccurrencesOfString:@"#" withString:@""]; // remove the #
    NSScanner *scanner = [NSScanner scannerWithString:noHashString];
    [scanner setCharactersToBeSkipped:[NSCharacterSet symbolCharacterSet]]; // remove + and $

    unsigned hex;
    if (![scanner scanHexInt:&hex]) return nil;
    int r = (hex >> 16) & 0xFF;
    int g = (hex >> 8) & 0xFF;
    int b = (hex) & 0xFF;

    return [UIColor colorWithRed:r / 255.0f green:g / 255.0f blue:b / 255.0f alpha:1.0f];
}

#pragma mark - Memory management

- (void)dealloc {
	[_packageDetails release];
	[_nameOverride release];
	[_icon release];

	[super dealloc];
}

@end
