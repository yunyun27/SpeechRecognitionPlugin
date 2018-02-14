var SpeechRecognitionError = function() {
    this.error = null;
    this.message = null;
};

SpeechRecognitionError['no-speech'] = 0;
SpeechRecognitionError['aborted'] = 1;
SpeechRecognitionError['audio-capture'] = 2;
SpeechRecognitionError['network'] = 3;
SpeechRecognitionError['not-allowed'] = 4;
SpeechRecognitionError['service-not-allowed'] = 5;
SpeechRecognitionError['bad-grammar'] = 6;
SpeechRecognitionError['language-not-supported'] = 7;
SpeechRecognitionError['iflytek-apikey-error'] = 8;
SpeechRecognitionError['iflytek-init-error'] = 9;

module.exports = SpeechRecognitionError;
