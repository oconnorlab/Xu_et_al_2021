void jawProMapping()
{
  unsigned int numTrials = 0;
  String flags[70] = { "verticalMovement", "horizontalMovementR", "horizontalMovementL",
                        "forwardMovement", "probeA3", "probeA4", "probeA5", 
                        "probeA6", "probeB3", "probeB4", "probeB5", "probeB6", 
                        "probeC1", "probeC2", "probeC3", "probeC4", "probeC5", 
                        "probeC6", "probeD1", "probeD2", "probeD3", "probeD4", 
                        "probeD5", "probeD6", "probeE1", "probeE2", "probeE3", 
                        "probeE4", "probeE5", "probeE6", "probeF1", "probeF2", 
                        "probeF3", "probeF4", "probeF5", "probeF6", "tailPinch", 
                        "tailPinch", "probeF6", "probeF5", "probeF4", "probeF3", 
                        "probeF2", "probeF1", "probeE6", "probeE5", "probeE4", 
                        "probeE3", "probeE2", "probeE1", "probeD6", "probeD5", 
                        "probeD4", "probeD3", "probeD2", "probeD1", "probeC6", 
                        "probeC5", "probeC4", "probeC3", "probeC2", "probeC1", 
                        "probeB6", "probeB5", "probeB4", "probeB3", "probeA6", 
                        "probeA5", "probeA4", "probeA3" };


 // SESSION STARTS
 sat.sendData("sessionStart", millis(), protocolId);

 sat.delay(10000);

 while (protocolId) {
   // Check for session pause command from computer
   while (protocolPauseFlag)
     sat.delay(100);

   // Hold for coming trial until go trigger (i.e. lick is detected)
   lickCount = 0;
   sat.delayUntil(isLickOrAbort); 

   // Trial starts
   // First four trials are 30 s, 1 hz jaw movement trials
   // Trials 5 - 70 are 15s, 0.2 hz muscle probe trials
   // Give 10 ms pulse to numPin to delimit trial
   sat.sendData("trialNum", millis(), numTrials+1);
   numPulseOn(numTrials);
   sat.sendData(flags[numTrials++].c_str(), millis());

   switch (numTrials) {
    case 1 ... 4:
     digitalWrite(rig.camPin, HIGH);
     break;
    case 5 ... 70:
     break;
   }

   // 4 'prepatory' 1hz pips
   for (int i=0; i<4; i++) {
     triggerCue(cueDur);
     sat.delay(1000 - cueDur);
   }
    
   switch (numTrials) {
     case 1 ... 4:
      // 30s of 1hz pips, camera records after 10 pips 
      // log records every pip
      for (int i=0; i<11; i++) {
       sat.sendData("pip", millis());
       triggerCue(cueDur);
       sat.delay(1000 - cueDur);
      }
      sat.sendData("frameStart", millis());
      tone(rig.framePin, frameRate);
      for (int i=0; i<21; i++) {
       sat.sendData("pip", millis());
       triggerCue(cueDur);
       sat.delay(1000 - cueDur);
      }
      digitalWrite(rig.camPin, LOW);
      noTone(rig.framePin);
      break;
      // 30s of 1hz 'short' pips + 0.2Hz 'long' pips
      // log records 0.2Hz pips (for probing)
     case 5 ... 70:
      for (int i=0; i<4; i++) {
       triggerCue(cueDur/3);
       sat.delay(1000 - (cueDur/3));
       triggerCue(cueDur/3);
       sat.delay(1000 - (cueDur/3));
       triggerCue(cueDur/3);
       sat.delay(1000 - (cueDur/3));
       triggerCue(cueDur/3);
       sat.delay(1000 - (cueDur/3));
       sat.sendData("pip", millis());
       triggerCue(cueDur);
       sat.delay(1000 - cueDur);
      }
      break;
   }
     //Trial ends
 }

 // SESSION ENDS
 sat.sendData("sessionEnd", millis(), protocolId);
} 
