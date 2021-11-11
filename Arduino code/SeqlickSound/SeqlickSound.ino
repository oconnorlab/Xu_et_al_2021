#include <Audio.h>
#include <Wire.h>
#include <SPI.h>
#include <SD.h>
#include <SerialFlash.h>
#include <Satellites.h>


// GUItool: begin automatically generated code
AudioPlaySdWav           playSdWav1;     //xy=145,586
AudioPlaySdRaw           playSdRaw1;     //xy=145,628
AudioSynthToneSweep      tonesweep1;     //xy=147,501
AudioSynthWaveform       waveform1;      //xy=151,462
AudioSynthNoiseWhite     noise1;         //xy=160,424
AudioMixer4              mixer1;         //xy=345,501
AudioMixer4              mixer2;         //xy=346,620
AudioMixer4              mixer3;         //xy=557,615
AudioOutputI2S           i2s1;           //xy=735,650
AudioConnection          patchCord1(playSdWav1, 0, mixer2, 0);
AudioConnection          patchCord2(playSdRaw1, 0, mixer2, 1);
AudioConnection          patchCord3(tonesweep1, 0, mixer1, 2);
AudioConnection          patchCord4(waveform1, 0, mixer1, 1);
AudioConnection          patchCord5(noise1, 0, mixer1, 0);
AudioConnection          patchCord6(mixer1, 0, mixer3, 0);
AudioConnection          patchCord7(mixer2, 0, mixer3, 1);
AudioConnection          patchCord8(mixer3, 0, i2s1, 0);
AudioControlSGTL5000     sgtl5000_1;     //xy=600,424
// GUItool: end automatically generated code


// Use these with the Teensy Audio Shield
#define SDCARD_CS_PIN    10
#define SDCARD_MOSI_PIN  7
#define SDCARD_SCK_PIN   14

char* sdFileList[] = {
  "ZABER1.WAV", "ZABER2.WAV", "ZABER3.WAV", "ZABER4.WAV",
  "ZABER5.WAV", "ZABER6.WAV", "ZABER7.WAV", "ZABER8.WAV",
  "ZABER9.WAV", "ZABER10.WAV", "ZABER11.WAV", "ZABER12.WAV",
  "SDTEST1.WAV", "SDTEST2.WAV", "SDTEST3.WAV", "SDTEST4.WAV"
};


// Satellite object
Satellites sat;


// Trigger pins
/*
  Audio uses 9, 11, 13, 18, 19, 22, 23
  Volume pot uses 15 (A1)
  SD card uses 7, 10, 12, 14
  Memory chip uses 6, 7, 12, 14
*/
byte numTrigger = 11;
byte triggerPin[] = {0, 1, 2, 3, 4, 5, 8, 16, 17, 20, 21};
bool isTriggered[11];
bool isMotor = false;

// Timing
elapsedMillis epItvl;
unsigned long randItvl;


void setup() {

  // Configure hardware
  AudioMemory(10);

  sgtl5000_1.enable();
  sgtl5000_1.lineOutLevel(29); // 29: 1.29 Volts p-p  (default); 17: 2.53 Volts p-p
  sgtl5000_1.volume(0.5);

  SPI.setMOSI(SDCARD_MOSI_PIN);
  SPI.setSCK(SDCARD_SCK_PIN);
  while (!SD.begin(SDCARD_CS_PIN)) {
    Serial.println("Unable to access the SD card");
    delay(500);
  }

  // Initialize settings
  noise1.amplitude(0);

  waveform1.begin(WAVEFORM_SINE);
  waveform1.frequency(15000);
  waveform1.amplitude(0);

  mixer1.gain(0, 0.25);
  mixer1.gain(1, 0.25);
  mixer1.gain(2, 0.25);
  mixer1.gain(3, 0.25);

  mixer2.gain(0, 0.25);
  mixer2.gain(1, 0.25);
  mixer2.gain(2, 0.25);
  mixer2.gain(3, 0.25);

  mixer3.gain(0, 0.25);
  mixer3.gain(1, 0.25);
  mixer3.gain(2, 0.25);
  mixer3.gain(3, 0.25);


  // Satellite communication
  Serial.begin(115200);
  sat.attachReader(myReader);

  // Trigger
  for (int i = 0; i < numTrigger; i++) {
    pinMode(triggerPin[i], INPUT);
    isTriggered[i] = false;
  }

  randomSeed(28);
}


void loop() {

  sat.serialReadCmd();

  byte k;

  // Pure tone
  k = 0;
  if (!isTriggered[k] && digitalRead(triggerPin[k]) == HIGH) {
    AudioNoInterrupts();
    waveform1.phase(90);
    waveform1.amplitude(1);
    AudioInterrupts();
    isTriggered[k] = true;
  }
  else if (digitalRead(triggerPin[k]) == LOW) {
    waveform1.amplitude(0);
    isTriggered[k] = false;
  }

  // Play random motor sound at random interval
  if (isMotor && epItvl > randItvl) {
    epItvl = epItvl - randItvl;

    int fileIdx = random(0, 12);
    playSdWav1.play(sdFileList[fileIdx]);
    //    Serial.print("Playing file: ");
    //    Serial.println(sdFileList[fileIdx]);

    randItvl = random(150, 300);
  }
}
