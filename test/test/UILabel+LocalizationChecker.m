//
//  UILabel+LocalizationChecker.m
//  test
//
//  Created by Hector Zarate / Tomasz Wyszomirski on 2/22/13.
//

#import "UILabel+LocalizationChecker.h"
#import "LocalizationChecker.h"
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

static const char *kIsFaultyKey = "IsFaulty";

@implementation UILabel (LocalizationChecker)

// What happens when text is called from IB ?

+ (void) initialize {
    if (self == [UILabel class]) {
        [self setup];
    }
}

+ (void)setup {
    // swizzle setText
    Method originalMethod = class_getInstanceMethod(self, @selector(setText:));
    
    Method mine = class_getInstanceMethod(self, @selector(swappedSetText:));
    method_exchangeImplementations(originalMethod, mine);
    
    // swizzle setValue:forKey:
    Method originalSetValueMethod = class_getInstanceMethod(self, @selector(awakeFromNib));
    Method mineSetValueMethod = class_getInstanceMethod(self, @selector(swappedAwakeFromNib));
    method_exchangeImplementations(originalSetValueMethod, mineSetValueMethod);
}

- (void)swappedSetText:(NSString *)text {
    objc_setAssociatedObject(self, kIsFaultyKey, @NO, OBJC_ASSOCIATION_RETAIN);
    
    if ([[LocalizationChecker sharedLocalizationChecker] isStringLocalized:text] == NO) {
        objc_setAssociatedObject(self, kIsFaultyKey, @YES, OBJC_ASSOCIATION_RETAIN);
        NSLog(@"Non-localized string \"%@\" in: %@", text, [[self class] methodNameFromStackTrace]);
        
        [self setBackgroundColorImpl:[UIColor redColor]];
    } else {
        id oldColor = objc_getAssociatedObject(self, "hackaton");
        [self setBackgroundColor:oldColor];
    }
    
    [self swappedSetText:text];
}

- (void)swappedAwakeFromNib
{
    if ([self isKindOfClass:[UILabel class]])
    {
        [self swappedAwakeFromNib];
        
        if ([[LocalizationChecker sharedLocalizationChecker] isStringLocalized:self.text] == NO) {
            objc_setAssociatedObject(self, "hackaton", self.backgroundColor, OBJC_ASSOCIATION_RETAIN);
            [self setBackgroundColor:[UIColor redColor]];
        }
    }
}
- (void)setBackgroundColor:(UIColor *)backgroundColor {
    
    id r =  objc_getAssociatedObject(self, kIsFaultyKey);
    BOOL isFaulty = [r boolValue];
    if (isFaulty) {
        //do some logging?
    } else {
        [self setBackgroundColorImpl:backgroundColor];
    }
}

- (void)setHidden:(BOOL)hidden {
    if (![LocalizationChecker sharedLocalizationChecker].showsFaultyWhenViewHidden) {
        self.layer.hidden = hidden;
    }
}

- (void)setBackgroundColorImpl:(UIColor *)backgroundColor {
    self.layer.backgroundColor = backgroundColor.CGColor;
}

+ (NSString *)methodNameFromStackTrace {
    NSArray *stackTrace = [NSThread callStackSymbols];
    if (stackTrace.count <= 2) {
        return nil;
    }
    NSString *stackLine = stackTrace[2];
    stackLine = [stackLine stringByReplacingOccurrencesOfString:@" +" withString:@" "
                                                        options:NSRegularExpressionSearch
                                                          range:NSMakeRange(0, stackLine.length)];
    NSArray *stackComponents = [stackLine componentsSeparatedByString:@" "];
    stackComponents = [stackComponents subarrayWithRange:NSMakeRange(3, 2)];
    return [stackComponents componentsJoinedByString:@" "];
}

@end
