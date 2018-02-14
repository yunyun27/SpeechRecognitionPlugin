#import "SpeechRecognition.h"
#import <Speech/Speech.h>

#import "iflyMSC/IFlySpeechError.h"
#import "iflyMSC/IFlySpeechUtility.h"
#import "iflyMSC/IFlySpeechConstant.h"
#import "iflyMSC/IFlySpeechRecognizerDelegate.h"
#import "iflyMSC/IFlySpeechRecognizer.h"

#import "ISRDataHelper.h"

@implementation SpeechRecognition

- (void) init:(CDVInvokedUrlCommand*)command
{
    self.audioEngine = [[AVAudioEngine alloc] init];

    // IFlyTek requires appid
    if (!NSClassFromString(@"SFSpeechRecognizer")) {
        NSString * key = [self.commandDelegate.settings objectForKey:[@"appId" lowercaseString]];
        if (key) {
            NSString *initString = [[NSString alloc] initWithFormat:@"appid=%@",key];
            [IFlySpeechUtility createUtility:initString];
            self.curResult = [[NSMutableString alloc]init];

             if (!self.IFlyRecognizer){
                self.IFlyRecognizer = [IFlySpeechRecognizer sharedInstance];
                self.IFlyRecognizer.delegate = self;
                if (self.IFlyRecognizer){
                    [self.IFlyRecognizer setParameter:@"0" forKey:@"ptt"]; // no punctuation
                    [self.IFlyRecognizer setParameter:@"0" forKey:@"nonum"]; // use character for digits
                }
                else {
                    [self sendErrorWithMessage:@"IFlyTek init error" andCode:9];
                }
            }
        }
        else {
            [self sendErrorWithMessage:@"IFlyTek apikey not found" andCode:8];
        }
    }
}

- (void) start:(CDVInvokedUrlCommand*)command
{
    self.command = command;
    NSMutableDictionary * event = [[NSMutableDictionary alloc]init];
    [event setValue:@"start" forKey:@"type"];
    self.pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:event];
    [self.pluginResult setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:self.pluginResult callbackId:self.command.callbackId];
    [self recognize];

}

- (void) recognize
{
    NSString * lang = [self.command argumentAtIndex:0];
    if (lang && [lang isEqualToString:@"en"]) {
        lang = @"en-US";
    }

    if (NSClassFromString(@"SFSpeechRecognizer")) {

        if (![self permissionIsSet]) {
            [SFSpeechRecognizer requestAuthorization:^(SFSpeechRecognizerAuthorizationStatus status){
                dispatch_async(dispatch_get_main_queue(), ^{

                    if (status == SFSpeechRecognizerAuthorizationStatusAuthorized) {
                        [self recordAndRecognizeWithLang:lang];
                    } else {
                        [self sendErrorWithMessage:@"Permission not allowed" andCode:4];
                    }

                });
            }];
        } else {
            [self recordAndRecognizeWithLang:lang];
        }
    } else {
        [self.curResult setString:@""]; // reset curResult
        [self.IFlyRecognizer startListening];

        // [self.iSpeechRecognition setDelegate:self];
        // [self.iSpeechRecognition setLocale:lang];
        // [self.iSpeechRecognition setFreeformType:ISFreeFormTypeDictation];
        // NSError *error;
        // if(![self.iSpeechRecognition listenAndRecognizeWithTimeout:10 error:&error]) {
        //     NSLog(@"ERROR: %@", error);
        // }
    }
}

- (void) recordAndRecognizeWithLang:(NSString *) lang
{
    NSLocale *locale = [[NSLocale alloc] initWithLocaleIdentifier:lang];
    self.sfSpeechRecognizer = [[SFSpeechRecognizer alloc] initWithLocale:locale];
    if (!self.sfSpeechRecognizer) {
        [self sendErrorWithMessage:@"The language is not supported" andCode:7];
    } else {

        // Cancel the previous task if it's running.
        if ( self.recognitionTask ) {
            [self.recognitionTask cancel];
            self.recognitionTask = nil;
        }

        [self initAudioSession];

        self.recognitionRequest = [[SFSpeechAudioBufferRecognitionRequest alloc] init];
        self.recognitionRequest.shouldReportPartialResults = [[self.command argumentAtIndex:1] boolValue];

        self.recognitionTask = [self.sfSpeechRecognizer recognitionTaskWithRequest:self.recognitionRequest resultHandler:^(SFSpeechRecognitionResult *result, NSError *error) {

            if (error) {
                NSLog(@"error");
                [self stopAndRelease];
                [self sendErrorWithMessage:error.localizedFailureReason andCode:error.code];
            }

            if (result) {
                NSMutableArray * alternatives = [[NSMutableArray alloc] init];
                int maxAlternatives = [[self.command argumentAtIndex:2] intValue];
                for ( SFTranscription *transcription in result.transcriptions ) {
                    if (alternatives.count < maxAlternatives) {
                        float confMed = 0;
                        for ( SFTranscriptionSegment *transcriptionSegment in transcription.segments ) {
                            NSLog(@"transcriptionSegment.confidence %f", transcriptionSegment.confidence);
                            confMed +=transcriptionSegment.confidence;
                        }
                        NSMutableDictionary * resultDict = [[NSMutableDictionary alloc]init];
                        [resultDict setValue:transcription.formattedString forKey:@"transcript"];
                        [resultDict setValue:[NSNumber numberWithBool:result.isFinal] forKey:@"final"];
                        [resultDict setValue:[NSNumber numberWithFloat:confMed/transcription.segments.count]forKey:@"confidence"];
                        [alternatives addObject:resultDict];
                    }
                }
                [self sendResults:@[alternatives]];
                if ( result.isFinal ) {
                    [self stopAndRelease];
                }
            }
        }];

        AVAudioFormat *recordingFormat = [self.audioEngine.inputNode outputFormatForBus:0];

        [self.audioEngine.inputNode installTapOnBus:0 bufferSize:1024 format:recordingFormat block:^(AVAudioPCMBuffer * _Nonnull buffer, AVAudioTime * _Nonnull when) {
            [self.recognitionRequest appendAudioPCMBuffer:buffer];
        }],

        [self.audioEngine prepare];
        [self.audioEngine startAndReturnError:nil];
    }
}

- (void) initAudioSession
{
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryRecord error:nil];
    [audioSession setMode:AVAudioSessionModeMeasurement error:nil];
    [audioSession setActive:YES withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
}

- (BOOL) permissionIsSet
{
    SFSpeechRecognizerAuthorizationStatus status = [SFSpeechRecognizer authorizationStatus];
    return status != SFSpeechRecognizerAuthorizationStatusNotDetermined;
}

// - (void)recognition:(ISSpeechRecognition *)speechRecognition didGetRecognitionResult:(ISSpeechRecognitionResult *)result
// {
//     NSMutableDictionary * resultDict = [[NSMutableDictionary alloc]init];
//     [resultDict setValue:result.text forKey:@"transcript"];
//     [resultDict setValue:[NSNumber numberWithBool:YES] forKey:@"final"];
//     [resultDict setValue:[NSNumber numberWithFloat:result.confidence]forKey:@"confidence"];
//     NSArray * alternatives = @[resultDict];
//     NSArray * results = @[alternatives];
//     [self sendResults:results];

// }

// -(void) recognition:(ISSpeechRecognition *)speechRecognition didFailWithError:(NSError *)error
// {
//     if (error.code == 28 || error.code == 23) {
//         [self sendErrorWithMessage:[error localizedDescription] andCode:7];
//     }
// }

#pragma mark IFlySpeechRecognizerDelegate
- (void) onError:(IFlySpeechError *) error
{
    if (error.errorCode != 0) {
        [self sendErrorWithMessage:error.errorDesc andCode:error.errorCode];
    }
}

- (void) onResults:(NSArray *) results isLast:(BOOL) isLast
{
    NSMutableString *result = [[NSMutableString alloc] init];
    NSMutableString *resultString = [[NSMutableString alloc]init];
    NSDictionary *dict = results[0];
    for (NSString *key in dict) {
        
        [result appendFormat:@"%@",key];
        
        NSString * resultFromJson =  [ISRDataHelper stringFromJson:result];
        [resultString appendString:resultFromJson];
        
    }
    if (isLast) { 
        //NSLog(@"result is:%@",self.curResult);

        NSMutableDictionary * resultDict = [[NSMutableDictionary alloc]init];
        [resultDict setValue: self.curResult forKey:@"transcript"];
        [resultDict setValue:[NSNumber numberWithBool:YES] forKey:@"final"];
        [resultDict setValue:[NSNumber numberWithFloat:0]forKey:@"confidence"];
        NSArray * alternatives = @[resultDict];
        NSArray * results = @[alternatives];
        [self sendResults:results];
    }
    
    [self.curResult appendString:resultString];    
}

-(void) sendResults:(NSArray *) results
{
    NSMutableDictionary * event = [[NSMutableDictionary alloc]init];
    [event setValue:@"result" forKey:@"type"];
    [event setValue:nil forKey:@"emma"];
    [event setValue:nil forKey:@"interpretation"];
    [event setValue:results forKey:@"results"];

    self.pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:event];
    [self.pluginResult setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:self.pluginResult callbackId:self.command.callbackId];
}

-(void) sendErrorWithMessage:(NSString *)errorMessage andCode:(NSInteger) code
{
    NSMutableDictionary * event = [[NSMutableDictionary alloc]init];
    [event setValue:@"error" forKey:@"type"];
    [event setValue:[NSNumber numberWithInteger:code] forKey:@"error"];
    [event setValue:errorMessage forKey:@"message"];
    self.pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:event];
    [self.pluginResult setKeepCallbackAsBool:NO];
    [self.commandDelegate sendPluginResult:self.pluginResult callbackId:self.command.callbackId];
}

-(void) stop:(CDVInvokedUrlCommand*)command
{
    [self stopOrAbort];
}

-(void) abort:(CDVInvokedUrlCommand*)command
{
    [self stopOrAbort];
}

-(void) stopOrAbort
{
    if (NSClassFromString(@"SFSpeechRecognizer")) {
        if (self.audioEngine.isRunning) {
            [self.audioEngine stop];
            [self.recognitionRequest endAudio];
        }
    } else {
        // [self.iSpeechRecognition cancel];
        [self.IFlyRecognizer stopListening];
    }
}

-(void) stopAndRelease
{
    [self.audioEngine stop];
    [self.audioEngine.inputNode removeTapOnBus:0];
    self.recognitionRequest = nil;
    self.recognitionTask = nil;
}

@end
