SpeechRecognitionPlugin
=======================
This is a PhoneGap plugin for speech recognition on iOS devices.

On iOS 10 and above,  it uses the native SFSpeechRecognizer.

On iOS 9 and older,  it uses the iFlyTek iOS SDK, which requires an appId.

To get an appId, see info from iFlyTek's website:

https://console.xfyun.cn/

The appId should be specified in the PhoneGap config.xml as follows:
```
<preference name="appId" value="yourAppIdHere" />
```
