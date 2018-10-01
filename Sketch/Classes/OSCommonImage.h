//
//  OSCommonImage.h
//  ImageBitmapRep
//
//  Created by Alex Nichol on 10/23/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#ifndef ImageBitmapRep_OSCommonImage_h
#define ImageBitmapRep_OSCommonImage_h

#import <UIKit/UIKit.h>
#import "CGImageContainer.h"

typedef UIImage ANImageObj;

CGImageRef CGImageFromANImage (ANImageObj * anImageObj);
ANImageObj * ANImageFromCGImage (CGImageRef imageRef);

#endif
