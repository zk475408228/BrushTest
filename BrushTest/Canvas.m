//
//  Canvas.m
//  BrushTest
//
//  Created by Coding on 8/23/16.
//  Copyright © 2016 Coding. All rights reserved.
//

#import "Canvas.h"
#import "DrawingLayer.h"
#import "Brush.h"
#import "UIColor+FGTColor.h"
#import "GPUImage.h"

@implementation Canvas

- (instancetype)initWithSize:(CGSize)size
{
    self= [super init];
    _canvasName = [NSString stringWithFormat:@"%@",[NSDate date]];
    _canvasSize = size;
    _backgroundColor = [UIColor whiteColor];
    _drawingLayers = [NSMutableArray array];
     _currentDrawingLayer = [DrawingLayer drawingLayerWithSize:_canvasSize];
    _layer = [CALayer layer];
    _layer.frame = CGRectMake(0, 0, _canvasSize.width, _canvasSize.height);
    [_drawingLayers addObject:_currentDrawingLayer];
    _currentBrush = [Brush BrushWithColor:[UIColor redColor] width:26 type:BrushTypeCircle];
    UIGraphicsBeginImageContextWithOptions(_canvasSize, NO, 0.0);
    return self;
}

+ (instancetype) canvasWithDictionary:(NSDictionary *)dict
{
    Canvas* canvas = [[Canvas alloc] init];
    canvas.canvasName = dict[@"name"];
    canvas.canvasSize = CGSizeFromString(dict[@"size"]);
    uint32_t i = [dict[@"color"] unsignedIntValue];
    canvas.backgroundColor = [UIColor colorWithUint32:i];
    canvas.currentBrush = [Brush BrushWithDictionary:dict[@"brush"]];
    canvas.layer = [CALayer layer];
    canvas.layer.frame = CGRectMake(0, 0, canvas.canvasSize.width, canvas.canvasSize.height);
    NSArray *array = dict[@"layers"];
    NSMutableArray *layerArray = [NSMutableArray array];
    UIGraphicsBeginImageContextWithOptions(canvas.canvasSize, NO, 0.0);
    for (NSDictionary *dict in array) {
        DrawingLayer *layer = [DrawingLayer drawingLayerWithDictionary:dict size:canvas.canvasSize];
        [[UIColor clearColor] set];
        UIRectFill(CGRectMake(0, 0, canvas.canvasSize.width, canvas.canvasSize.height));
        [layerArray addObject:layer];
    }
    UIGraphicsEndImageContext();
    canvas.drawingLayers = layerArray;
    
    canvas.currentDrawingLayer = canvas.drawingLayers[canvas.drawingLayers.count-1];
    return canvas;
}

- (instancetype)initWithSize:(CGSize)size backgroundColor:(UIColor *)color
{
    self=  [self initWithSize:size];
    _backgroundColor = color;
    return self;
}
- (void)addLayer:(DrawingLayer *)layer
{
    [_drawingLayers addObject:layer];
    self.currentDrawingLayer = layer;
}

- (void)addLayer
{
    DrawingLayer *layer = [DrawingLayer drawingLayerWithSize:_canvasSize];
    [self addLayer:layer];
    self.currentDrawingLayer = layer;
}

- (void)addLayerAboveCurrentDrawingLayer
{
    DrawingLayer *layer = [DrawingLayer drawingLayerWithSize:_canvasSize];
    NSUInteger index = [_drawingLayers indexOfObject:_currentDrawingLayer];
    [_drawingLayers insertObject:layer atIndex:index+1];
    self.currentDrawingLayer = layer;
}

- (void)clear
{
    [_currentDrawingLayer clear];

}
- (void)undo
{
    [_currentDrawingLayer undo];
}

- (void)redo
{
    [_currentDrawingLayer redo];

}

- (u_long)layerCount{
    return _drawingLayers.count;
}
- (void) newStrokeIfNull
{
    [_currentDrawingLayer newStrokeWithBrushIfNull:_currentBrush];
}
- (void) newStroke
{
    [_currentDrawingLayer newStrokeWithBrush:_currentBrush];
   
    //UIGraphicsBeginImageContextWithOptions(_canvasSize, NO, 0.0);
    //[_image drawAtPoint:CGPointZero];
}
- (void) addStroke
{
    [_currentDrawingLayer addStroke];
}

- (void) addPoint:(CGPoint)point
{
    [_currentDrawingLayer updateStrokeWithPoint:point];
}

- (void) setCurrentDrawingLayer:(DrawingLayer *)layer
{
    if(_currentDrawingLayer != layer){
        _currentDrawingLayer = layer;
        UIGraphicsEndImageContext();
        UIGraphicsBeginImageContextWithOptions(_canvasSize, NO, 0.0);
        [_currentDrawingLayer.layer renderInContext:UIGraphicsGetCurrentContext()];
//        CGContextSetBlendMode(UIGraphicsGetCurrentContext(), _currentDrawingLayer.blendMode);
//        [_currentDrawingLayer drawInContext];
//        _image = UIGraphicsGetImageFromCurrentImageContext();
//        layer.layer.contents = (id)_image.CGImage;
    }
}

- (NSDictionary *)dictionary
{
    NSMutableArray *layerArray= [NSMutableArray array];
    for (DrawingLayer *layer in _drawingLayers) {
        NSDictionary *dict = layer.dictionary;
        [layerArray addObject:dict];
    }
    NSDictionary *dict = @{ @"name":_canvasName, @"size":NSStringFromCGSize(_canvasSize), @"color":[_backgroundColor number], @"brush":_currentBrush.dictionary, @"layers":layerArray};
    return dict;
}

- (void)mergeAllLayers
{
    [[UIColor whiteColor] set];
    UIRectFill(CGRectMake(0, 0, _canvasSize.width, _canvasSize.height));
    self.currentDrawingLayer = _drawingLayers[0];
    CGImageRef cgimage = (__bridge CGImageRef)self.currentDrawingLayer.layer.contents;
    UIImage *image = [UIImage imageWithCGImage:cgimage scale:[UIScreen mainScreen].scale orientation:UIImageOrientationUp];
    [image drawAtPoint:CGPointZero blendMode:_currentDrawingLayer.blendMode alpha:_currentDrawingLayer.alpha];
    while (_drawingLayers.count >1) {
        DrawingLayer *dlayer = _drawingLayers[1];
        CGImageRef cgimage = (__bridge CGImageRef)dlayer.layer.contents;
        UIImage *image = [UIImage imageWithCGImage:cgimage scale:[UIScreen mainScreen].scale orientation:UIImageOrientationUp];
        [image drawAtPoint:CGPointZero blendMode:dlayer.blendMode alpha:dlayer.alpha];
        [dlayer.layer removeFromSuperlayer];
        [_drawingLayers removeObjectAtIndex:1];
    }
    _currentDrawingLayer.layer.contents = (id)UIGraphicsGetImageFromCurrentImageContext().CGImage;

    
}

- (void)mergeCurrentToDownLayerWithIndex:(NSUInteger)index
{
    
    NSAssert(index > 0, @"index of drawing layer = 0");
    self.currentDrawingLayer = _drawingLayers[index-1];
    DrawingLayer *dlayer = _drawingLayers[index];
    [[UIColor whiteColor] set];
    UIRectFill(CGRectMake(0, 0, _canvasSize.width, _canvasSize.height));
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    //CGContextSetBlendMode(context, _currentDrawingLayer.blendMode);
    CGContextSetAlpha(context, _currentDrawingLayer.alpha);
    [_currentDrawingLayer.layer renderInContext:context];
     CGContextSetAlpha(context, dlayer.alpha);
   // CGContextSetBlendMode(context, dlayer.blendMode);
    [dlayer.layer renderInContext:context];
    CGContextRestoreGState(context);
//    CGImageRef cgimage = (__bridge CGImageRef)dlayer.layer.contents;
//    UIImage *image = [UIImage imageWithCGImage:cgimage scale:[UIScreen mainScreen].scale orientation:UIImageOrientationUp];
//    [image drawAtPoint:CGPointZero blendMode:dlayer.blendMode alpha:dlayer.alpha];
     [dlayer.layer removeFromSuperlayer];
    [_drawingLayers removeObjectAtIndex:index];
    _currentDrawingLayer.layer.contents = (id)UIGraphicsGetImageFromCurrentImageContext().CGImage;

}

- (NSUInteger) indexOfDrawingLayer:(DrawingLayer *)dlayer
{
    return [_drawingLayers indexOfObject:dlayer];
}

-(void)dealloc
{
    UIGraphicsEndImageContext();
}

- (void)updateLayer{
    
    UIGraphicsBeginImageContextWithOptions(_canvasSize, NO, 0.0);
    [[UIColor whiteColor] set];
    UIRectFill(CGRectMake(0, 0, _canvasSize.width, _canvasSize.height));
    for(DrawingLayer *dlayer in _drawingLayers){
        if(!dlayer.visible) continue;
        CGImageRef cgimage = (__bridge CGImageRef)dlayer.layer.contents;
        UIImage *image = [UIImage imageWithCGImage:cgimage scale:[UIScreen mainScreen].scale orientation:UIImageOrientationUp];
        [image drawAtPoint:CGPointZero blendMode:dlayer.blendMode alpha:dlayer.alpha];
        
    }
    _layer.contents = (id) UIGraphicsGetImageFromCurrentImageContext().CGImage;
    UIGraphicsEndImageContext();
}
//- (void)updateLayer
//{
//    NSMutableArray *picArray = [NSMutableArray array];
//    
//    UIGraphicsBeginImageContextWithOptions(_canvasSize, NO, 0.0);
//    [[UIColor whiteColor] set];
//    UIRectFill(CGRectMake(0, 0, _canvasSize.width, _canvasSize.height));
//    UIImage *back = UIGraphicsGetImageFromCurrentImageContext();
//    UIGraphicsEndImageContext();
//    GPUImagePicture *backpic = [[GPUImagePicture alloc]initWithImage:back];
//    DrawingLayer *layer0 = _drawingLayers[0];
//    CGImageRef cgimage = (__bridge CGImageRef)layer0.layer.contents;
//    GPUImagePicture *curPic = [[GPUImagePicture alloc]initWithCGImage:cgimage];
//    GPUImageOutput<GPUImageInput>  *curfilter =[[GPUImageDifferenceBlendFilter alloc] init];
//    [curfilter forceProcessingAtSize:CGSizeMake(_canvasSize.width*2, _canvasSize.height*2)];
//    //[curfilter useNextFrameForImageCapture];
//    [backpic addTarget:curfilter];
//    [curPic addTarget:curfilter];
//    [picArray addObject:backpic];
//    [picArray addObject:curPic];
//            int i = 1;
//        while(i< _drawingLayers.count){
//            DrawingLayer *dlayer= _drawingLayers[i];
//            if(!dlayer.visible){
//                i++;
//                continue;
//            }
//            GPUImageOutput<GPUImageInput>  *filter =[[GPUImageDifferenceBlendFilter alloc] init];
//            [filter forceProcessingAtSize:CGSizeMake(_canvasSize.width*2, _canvasSize.height*2)];
//            //[filter useNextFrameForImageCapture];
//            [curfilter addTarget:filter];
//            CGImageRef cgimage = (__bridge CGImageRef)dlayer.layer.contents;
//            GPUImagePicture *pic = [[GPUImagePicture alloc]initWithCGImage:cgimage];
//            [pic addTarget:filter];
//            [picArray addObject:pic];
//            curfilter = filter;
//            i++;
//        }
//    [curfilter useNextFrameForImageCapture];
//    for (GPUImagePicture *pic in picArray) {
//        [pic processImage];
//    }
//    _layer.contents = (id)[curfilter imageFromCurrentFramebuffer].CGImage;
//}

//- (void)updateLayer
//{
////    GPUImageMultiplyBlendFilter *bf = [[GPUImageMultiplyBlendFilter alloc] init];
////    GPUImagePicture *pic = [[GPUImagePicture alloc]initWithImage:image];
////    [pic addTarget:bf atTextureLocation:0];
////    UIGraphicsBeginImageContextWithOptions(_canvasSize, NO, 0.0);
////    [[UIColor whiteColor] set];
////    UIRectFill(CGRectMake(0, 0, _canvasSize.width, _canvasSize.height));
////    for(DrawingLayer *dlayer in _drawingLayers) {
////        CGImageRef cgimage = (__bridge CGImageRef)dlayer.layer.contents;
////        UIImage *image = [UIImage imageWithCGImage:cgimage scale:[UIScreen mainScreen].scale orientation:UIImageOrientationUp];
////        [image drawAtPoint:CGPointZero blendMode:dlayer.blendMode alpha:dlayer.alpha];
////    }
////    _layer.contents = (id)UIGraphicsGetImageFromCurrentImageContext().CGImage;
////    
////    UIGraphicsEndImageContext();
//    
//    UIImage *back;
//        UIGraphicsBeginImageContextWithOptions(_canvasSize, NO, 0.0);
//        [[UIColor whiteColor] set];
//    UIRectFill(CGRectMake(0, 0, _canvasSize.width, _canvasSize.height));
//    back = UIGraphicsGetImageFromCurrentImageContext();
//        UIGraphicsEndImageContext();
//    CGImageRef cgimage = (__bridge CGImageRef)_currentDrawingLayer.layer.contents;
//    GPUImagePicture *pic = [[GPUImagePicture alloc]initWithCGImage:cgimage];
//    GPUImageOutput<GPUImageInput>  *filter =[[GPUImageColorBurnBlendFilter alloc] init];;
//    GPUImagePicture *backPicture = [ [GPUImagePicture alloc] initWithImage:back];
////    GPUImageDifferenceBlendFilter *filter = [[GPUImageDifferenceBlendFilter alloc] init];
//    
//    [filter forceProcessingAtSize:_canvasSize];
//    [filter useNextFrameForImageCapture];
//    [backPicture addTarget:filter];
//    
////    GPUImageSketchFilter *disFilter = [[GPUImageSketchFilter alloc] init];
////    [disFilter forceProcessingAtSize:back.size];
////    [disFilter useNextFrameForImageCapture];
//    [pic addTarget:filter];
//    [pic processImage];
//    [backPicture processImage];
////    for(DrawingLayer *dlayer in _drawingLayers) {
////        CGImageRef cgimage = (__bridge CGImageRef)dlayer.layer.contents;
////        GPUImagePicture *pic = [[GPUImagePicture alloc]initWithCGImage:cgimage];
////        GPUImageDifferenceBlendFilter *bfi = [[GPUImageDifferenceBlendFilter alloc] init];
////        [bfi forceProcessingAtSize:back.size];
////        [bfi useNextFrameForImageCapture];
////        [pic addTarget:curfilter];
////        [curfilter addTarget:bfi];
////        curfilter = bfi;
////        
////        [pic processImage];
////        [curfilter useNextFrameForImageCapture];
////    }
////    
////    UIImage *image = [filter imageFromCurrentFramebuffer];
//     _layer.contents = (id)[filter imageFromCurrentFramebuffer].CGImage;
//
//}
@end
