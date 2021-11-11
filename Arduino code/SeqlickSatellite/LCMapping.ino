void LCMapping()
{
  unsigned int numTrials = 0;
  String flags[5] = { "verticalMovement", "horizontalMovement", "forwardMovement",
                      "tailPinch", "pawPinch"
                    };


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
    // Trials are 30 s, 1 hz beeps
    // Give 10 ms pulse to numPin to delimit trial
    sat.sendData("trialNum", millis(), numTrials+1);
    numPulseOn(numTrials);
    sat.sendData(flags[numTrials++].c_str(), millis());

    switch (numTrials) {
      case 1 ... 3:
        digitalWrite(rig.camPin, HIGH);
        break;
      case 4 ... 5:
        break;
    }

    // 4 'prepatory' 1hz pips
    for (int i = 0; i < 4; i++) {
      triggerCue(cueDur);
      sat.delay(1000 - cueDur);
    }

    switch (numTrials) {
      case 1 ... 3:
        // 30s of 1hz pips, camera records after 10 pips
        // log records every pip
        for (int i = 0; i < 11; i++) {
          sat.sendData("pip", millis());
          triggerCue(cueDur);
          sat.delay(1000 - cueDur);
        }
        sat.sendData("frameStart", millis());
        tone(rig.framePin, frameRate);
        for (int i = 0; i < 21; i++) {
          sat.sendData("pip", millis());
          triggerCue(cueDur);          
          sat.delay(1000 - cueDur);
        }
        digitalWrite(rig.camPin, LOW);
        noTone(rig.framePin);
        break;
      // 60s of 1hz pips, no camera recording
      case 4 ... 5:
        for (int i = 0; i < 13; i++) {
          triggerCue(cueDur / 2);
          sat.delay(2000 - (cueDur / 2));
          triggerCue(cueDur / 2);
          sat.delay(2000 - (cueDur / 2));
          triggerCue(cueDur / 2);
          sat.delay(2000 - (cueDur / 2));
          triggerCue(cueDur / 2);
          sat.delay(2000 - (cueDur / 2));
          sat.sendData("pip", millis());
          triggerCue(cueDur);
          sat.delay(2000 - cueDur);
        }
        break;
    }
    //Trial ends
  }

  // SESSION ENDS
  sat.sendData("sessionEnd", millis(), protocolId);
}
