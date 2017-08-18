//
//  ViewController.m
//  VisionTrack
//
//  Created by schubert on 2017/6/20.
//  Copyright © 2017年 schubertq. All rights reserved.
//

#import "ViewController.h"
#import <Vision/Vision.h>
#import <AVFoundation/AVFoundation.h>

@interface ViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate>
@property (weak, nonatomic) IBOutlet UIView *highlightView;
@property (weak, nonatomic) IBOutlet UIView *cameraView;
@property (nonatomic, strong) VNSequenceRequestHandler *visionSequenceHandler;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *cameraLayer;
@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) VNDetectedObjectObservation *lastObservation;

@end

@implementation ViewController

- (VNSequenceRequestHandler *)visionSequenceHandler {
    if (!_visionSequenceHandler) {
        _visionSequenceHandler = [[VNSequenceRequestHandler alloc] init];
    }
    return _visionSequenceHandler;
}

- (AVCaptureSession *)captureSession {
    if (!_captureSession) {
        _captureSession = [[AVCaptureSession alloc] init];
        _captureSession.sessionPreset = AVCaptureSessionPresetInputPriority;
//        _captureSession.sessionPreset = AVCaptureSessionPresetPhoto;
        AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionBack];
        AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:nil];
        [_captureSession addInput:input];
    }
    return _captureSession;
}

- (AVCaptureVideoPreviewLayer *)cameraLayer {
    if (!_cameraLayer) {
        _cameraLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.captureSession];
    }
    return _cameraLayer;
}

- (IBAction)resetAction:(id)sender {
    NSLog(@"reset");
    self.lastObservation = nil;
    self.highlightView.frame = CGRectZero;
}

- (IBAction)userTapped:(UITapGestureRecognizer *)sender {
    self.highlightView.frame = CGRectMake(0, 0, 120, 120);
    self.highlightView.center = [sender locationInView:self.view];
    
    CGRect originalRect = self.highlightView.frame;
    CGRect convertedRect = [self.cameraLayer metadataOutputRectOfInterestForRect:originalRect];
    convertedRect.origin.y = 1 - convertedRect.origin.y;
    
    VNDetectedObjectObservation *newObservation = [VNDetectedObjectObservation observationWithBoundingBox:convertedRect];
    self.lastObservation = newObservation;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.cameraView.frame = self.view.bounds;
    self.highlightView.layer.borderColor = [UIColor redColor].CGColor;
    self.highlightView.layer.borderWidth = 4;
    self.highlightView.backgroundColor = [UIColor clearColor];
    self.highlightView.frame = CGRectZero;
    
    [self.cameraView.layer addSublayer:self.cameraLayer];
    
    AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
    [output setSampleBufferDelegate:self queue:dispatch_queue_create("outputQueue", NULL)];
    [self.captureSession addOutput:output];
    [self.captureSession startRunning];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    CALayer *superlayer = self.cameraLayer.superlayer;
    self.cameraLayer.frame = superlayer.bounds;
}

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    VNDetectedObjectObservation *lastObservation = self.lastObservation;
    
    VNTrackObjectRequest *request = [[VNTrackObjectRequest alloc] initWithDetectedObjectObservation:lastObservation completionHandler:^(VNRequest * _Nonnull request, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            VNDetectedObjectObservation *newObservation = [request.results firstObject];
            self.lastObservation = newObservation;
            
            if (newObservation.confidence < 0.3) {
                self.highlightView.frame = CGRectZero;
                return;
            }
            
            CGRect transformedRect = newObservation.boundingBox;
            transformedRect.origin.y = 1 - transformedRect.origin.y;
            CGRect convertedRect = [self.cameraLayer rectForMetadataOutputRectOfInterest:transformedRect];
            
            self.highlightView.frame = convertedRect;
        });
    }];
    
    request.trackingLevel = VNRequestTrackingLevelAccurate;
    
    NSError *error = nil;
    [self.visionSequenceHandler performRequests:@[request] onCVPixelBuffer:pixelBuffer error:&error];
    if (error) {
        NSLog(@"%@", error.localizedDescription);
    }
}

@end
