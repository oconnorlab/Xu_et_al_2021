#include <Satellites.h>
#include <ManyRig.h>
#include <ZaberMotor.h>
#include <Servo.h>

Satellites sat;
ManyRig rig;
ZaberMotor lickportStage(Serial3);
Servo lickportServo;
IntervalTimer numTimer;

byte protocolId = 0;
bool protocolPauseFlag = false;
byte block;

volatile unsigned long lickCount = 0;

const byte posListLen = 32;
Position posList[posListLen];
Position restPos(80000L, 0L);

const byte numSeq = 2;
const byte seqMaxLen = 32;
byte seqPosInd[numSeq][seqMaxLen];
byte seqTransType[numSeq][seqMaxLen];

unsigned int frameRate = 400;

Interval iti;                   // fixed and random inter-trial interval
unsigned int cueDur = 100;      // duration of cue
unsigned long respDur = 600000; // duration of response window
unsigned int posDelay = 50;     // time for movement to settle
unsigned int fixPosDelay = 80;  // fixed refractory period for positioning and licking
unsigned int addPosDelay = 20;  // additional refractory period for positioning
unsigned int waterDelay = 250;  // delay of water delivery after lick
unsigned int waterDur = 150;    // duration of water valve opening
unsigned int drinkDur = 2000;   // duration for animal to consume water

const byte numOptoType = 4;
byte optoProbList[] = {0, 0, 0, 100}; // probability of triggering opto at cue, mid-seq, cons and no trigger
byte optoMidStep = 4;                 // at which step to trigger mid-seq opto


void setup() {
  // Initialize serial port
  Serial.begin(115200);
  Serial3.begin(115200);

  // Attach the function to handle serial commands
  sat.attachReader(myReader);

  // Setup external interrupt and callback function
  attachInterrupt(digitalPinToInterrupt(rig.lickDetectorPin), reportLick, CHANGE);
 
  
  // Lick port control (0.1905um/step for LSM*B-T4A series)
  lickportStage.isReverse[0] = true;
  lickportStage.setRef(0, 1);
  lickportStage.setRef(25000, 2);
  lickportStage.setJitter(0); // was 10
  lickportStage.setMaxSpeed(8600*75); // in 0.6104steps/s (8600 ~= 1mm/s); was 262467
  lickportStage.setAcceleration(860*2); // in 6104steps/s^2 (860 ~= 1m/s^2); was 205*5 or 1025

  lickportServo.attach(rig.servoPin);

  lickportMove(restPos);

  // Initialize parameters
  for (int i = 0; i < posListLen; i++) {
    posList[i].setX(60000L);
    posList[i].setY(0L);
  }
  for (int i = 0; i < numSeq; i++)
    for (int j = 0; j < seqMaxLen; j++) {
      seqPosInd[i][j] = 255;
      seqTransType[i][j] = 0;
    }
}


void loop() {
  // Read any incoming serial command
  sat.serialReadCmd();

  // Execute training protocols
  switch (protocolId) {
    case 1:
      stimulation(); break;
    case 2:
      jawProMapping(); break;
    case 3:
      seqlick(); break;
    case 4:
      LCMapping(); break;
    case 5:
      seqlick2(); break;
    case 6:
      ledSync(); break;
    case 7:
      lickForWater(); break;
    case 8:
      seqlick3(); break;
    case 9:
      seqlickBlock(); break;
    default:
      break;
  }
}
