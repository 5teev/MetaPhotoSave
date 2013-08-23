//
//  MPSAViewController.m
//  MetaPhotoSaveApp
//
//  Created by Steve Milano on 8/19/13.
//  Copyright (c) 2013 SEDIFY, Inc. All rights reserved.
//

#import "MPSAViewController.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <CoreLocation/CoreLocation.h>
#import <ImageIO/ImageIO.h>

@interface MPSAViewController ()
- (IBAction)tapPhotoButton:(UIButton *)sender;
- (void) initCameraView;
- (void) dismissCameraView;


- (void) saveImage:(UIImage *)imageToSave withInfo:(NSDictionary *)info;

@property (nonatomic,retain) UIImagePickerController * imagePickerController;

@end

@implementation MPSAViewController
@synthesize imagePickerController = _imagePickerController;
- (IBAction)tapPhotoButton:(UIButton *)sender
{
    [self initCameraView];
}

- (void) initCameraView
{
    if ( !self.imagePickerController ) {
        _imagePickerController = [[UIImagePickerController alloc] init];
    }
    self.imagePickerController.sourceType = UIImagePickerControllerSourceTypeCamera;
    self.imagePickerController.allowsEditing = NO;
    self.imagePickerController.delegate = self;
    [self presentViewController:self.imagePickerController animated:YES completion:^{
        // nothing yet… or ever?
        // Note: this can be nil, but you never know when you might need a completion block….
    }];
}

/**
 The camera is dismissed the same way, whether a photo is taken or not.
 */
- (void) dismissCameraView
{
    [self dismissViewControllerAnimated:YES completion:^{
        // nil out the image picker (in practice, we probably wouldn't need it anymore)
        self.imagePickerController.delegate = nil;
        self.imagePickerController = nil;
    }];
}

#pragma mark -
#pragma mark UIImagePickerDelegate methods
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    // must dismiss camera
    [self dismissCameraView];

    UIImage *image = [info objectForKey:@"UIImagePickerControllerOriginalImage"];
    
    // compare the info here with the info when the photo is saved:
    // this one lacks the GPS block, the saved image does not!
    NSLog(@"image %@\ninfo: %@",image, info);
    
    [self saveImage:image withInfo:info];
    
}

/**
 This method doesn't acquire an image, so just dismiss camera;
 */
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [self dismissCameraView];
}

#pragma mark image saving methods
/**
 A method to save a UIImage received from the camera, with the metadata "info" provided by the UIImagePickerViewController. Based on code in my answer at
 
 http://stackoverflow.com/questions/7965299/write-uiimage-along-with-metadata-exif-gps-tiff-in-iphones-photo-library/11038316#11038316

 
 @param imageToSave The raw image as received from the UIImagePickerViewController
 
 @param info The default metadata as received from the UIImagePickerViewController. NOTE: Lacks GPS data.
 
 @discussion This method receives `info` from the UIImagePickerViewController, which lacks GPS data. Before saving, it adds a GPS block based on a location (in this case a fake location).
 */
- (void) saveImage:(UIImage *)imageToSave withInfo:(NSDictionary *)info
{
    // Get the image metadata (EXIF & TIFF)
    NSMutableDictionary * imageMetadata = [[info objectForKey:UIImagePickerControllerMediaMetadata] mutableCopy];
    
    // add (fake) GPS data
    CLLocationCoordinate2D coordSF = CLLocationCoordinate2DMake(37.732711,-122.45224);
    
    // arbitrary altitude and accuracy
    double altitudeSF = 15.0;
    double accuracyHorizontal = 1.0;
    double accuracyVertical = 1.0;
    NSDate * nowDate = [NSDate date];
    // create CLLocation for image
    CLLocation * loc = [[CLLocation alloc] initWithCoordinate:coordSF altitude:altitudeSF horizontalAccuracy:accuracyHorizontal verticalAccuracy:accuracyVertical timestamp:nowDate];
    
    // this is in case we try to acquire actual location instead of faking it with the code right above
    if ( loc ) {
        [imageMetadata setObject:[self gpsDictionaryForLocation:loc] forKey:(NSString*)kCGImagePropertyGPSDictionary];
    }
    
    // Get the assets library
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    
    // create a completion block for when we process the image
   ALAssetsLibraryWriteImageCompletionBlock imageWriteCompletionBlock =
    ^(NSURL *newURL, NSError *error) {
        if (error) {
            NSLog( @"Error writing image with metadata to Photo Library: %@", error );
        } else {
            NSLog( @"Wrote image %@ with metadata %@ to Photo Library",newURL,imageMetadata);
        }
    };
    
    // Save the new image to the Camera Roll, using the completion block defined just above
    [library writeImageToSavedPhotosAlbum:[imageToSave CGImage]
                                 metadata:imageMetadata
                          completionBlock:imageWriteCompletionBlock];
}

/**
 A convenience method to generate the {GPS} portion of a photo's EXIF data from a CLLLocation.
 
 @param location the location to base the NSDictionary on
 
 @return NSDictionary containing {GPS} block for a photo's EXIF data
 */
- (NSDictionary *) gpsDictionaryForLocation:(CLLocation *)location
{
    CLLocationDegrees exifLatitude  = location.coordinate.latitude;
    CLLocationDegrees exifLongitude = location.coordinate.longitude;
    
    NSString * latRef;
    NSString * longRef;
    if (exifLatitude < 0.0) {
        exifLatitude = exifLatitude * -1.0f;
        latRef = @"S";
    } else {
        latRef = @"N";
    }
    
    if (exifLongitude < 0.0) {
        exifLongitude = exifLongitude * -1.0f;
        longRef = @"W";
    } else {
        longRef = @"E";
    }
    
    NSMutableDictionary *locDict = [[NSMutableDictionary alloc] init];

    // requires ImageIO
    [locDict setObject:location.timestamp forKey:(NSString*)kCGImagePropertyGPSTimeStamp];
    [locDict setObject:latRef forKey:(NSString*)kCGImagePropertyGPSLatitudeRef];
    [locDict setObject:[NSNumber numberWithFloat:exifLatitude] forKey:(NSString *)kCGImagePropertyGPSLatitude];
    [locDict setObject:longRef forKey:(NSString*)kCGImagePropertyGPSLongitudeRef];
    [locDict setObject:[NSNumber numberWithFloat:exifLongitude] forKey:(NSString *)kCGImagePropertyGPSLongitude];
    [locDict setObject:[NSNumber numberWithFloat:location.horizontalAccuracy] forKey:(NSString*)kCGImagePropertyGPSDOP];
    [locDict setObject:[NSNumber numberWithFloat:location.altitude] forKey:(NSString*)kCGImagePropertyGPSAltitude];
    
    return locDict;
    
}


- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    // initialize UIImagePickerController early so it loads faster when button is pressed
    self.imagePickerController = [[UIImagePickerController alloc] init];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
