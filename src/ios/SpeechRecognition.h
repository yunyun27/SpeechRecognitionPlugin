#import <Cordova/CDV.h>
#import <Speech/Speech.h>

#import "iflyMSC/IFlySpeechRecognizer.h"
#import "iflyMSC/IFlySpeechRecognizerDelegate.h"

@interface SpeechRecognition : CDVPlugin  <IFlySpeechRecognizerDelegate>

@property (nonatomic, strong) CDVInvokedUrlCommand * command;
@property (nonatomic, strong) CDVPluginResult* pluginResult;
@property (nonatomic, strong) SFSpeechRecognizer *sfSpeechRecognizer;
@property (nonatomic, strong) AVAudioEngine *audioEngine;
@property (nonatomic, strong) SFSpeechAudioBufferRecognitionRequest *recognitionRequest;
@property (nonatomic, strong) SFSpeechRecognitionTask *recognitionTask;

@property (nonatomic, strong) IFlySpeechRecognizer* IFlyRecognizer;
@property (nonatomic, strong) NSMutableString* curResult;

- (void) init:(CDVInvokedUrlCommand*)command;
- (void) start:(CDVInvokedUrlCommand*)command;
- (void) stop:(CDVInvokedUrlCommand*)command;
- (void) abort:(CDVInvokedUrlCommand*)command;

@end
