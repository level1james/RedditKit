//
//  RKImageMetadata.h
//  Reddit
//
//  Created by James Lee on 6/21/15.
//  Copyright (c) 2015 James. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIGeometry.h>
#import <Mantle/Mantle.h>

@interface RKImageMetadata : MTLModel <MTLJSONSerializing>

@property (nonatomic, copy, readonly) NSURL *sourceURL;
@property (nonatomic, assign, readonly) CGSize sourceSize;

@end
