#import "CustomCloudSquare.h"

@implementation CustomCloudSquare

- (void)setPropertiesFromAnnotation:(PTAnnot *)annotation
{
    [super setPropertiesFromAnnotation:annotation];

    if ([annotation IsValid] && [annotation IsMarkup]) {
        PTMarkup *markup = [[PTMarkup alloc] initWithAnn:annotation];
        
        // Always make the rectangle cloudy
        [markup SetBorderEffect:e_ptCloudy];
    }
}

@end
