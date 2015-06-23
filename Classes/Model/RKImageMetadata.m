//
//  RKImageMetadata.m
//  Reddit
//
//  Created by James Lee on 6/21/15.
//  Copyright (c) 2015 James. All rights reserved.
//

#import "RKImageMetadata.h"

@interface RKImageMetadata()
@property (nonatomic, strong, readwrite) NSArray *resolutions;
@end

@implementation RKImageMetadata

+ (NSDictionary *)JSONKeyPathsByPropertyKey
{
    NSDictionary *keyPaths = @{
                               @"sourceURL": @"source.url",
                               @"sourceSize": @"source",
                               @"resolutions": @"resolutions",
                               };
    return keyPaths;
}


+ (NSValueTransformer *)sourceURLImagesJSONTransformer
{
    return [MTLValueTransformer transformerWithBlock:^id(NSString *sourceURLString) {
        
        NSString *escapedURL = [sourceURLString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        return [NSURL URLWithString:escapedURL];
        
    }];
}

+ (NSValueTransformer *)resolutionsURLImagesJSONTransformer
{
    return [MTLValueTransformer transformerWithBlock:^id(NSArray *resolutionsJSON) {
        
        return nil;
    }];
}

+ (NSValueTransformer *)sourceSizeJSONTransformer
{
    return [MTLValueTransformer transformerWithBlock:^id(NSDictionary *sourceJSON) {
        
        CGFloat width = [sourceJSON[@"width"] floatValue];
        CGFloat height = [sourceJSON[@"height"] floatValue];
        
        return [NSValue valueWithCGSize:CGSizeMake(width, height)];
        
    }];
}

@end
