// LickForWater protocol
void lickForWater()
{
  // Attach perch lick detection interrupt function
  attachInterrupt(digitalPinToInterrupt(rig.lickDetectorPinAUX), reportPLickAUX, CHANGE);
  
  // Report the start of training
  sat.sendData("lickForWaterStart");

  // Store the number of trials
  int numTrials = 0;

  // Loop for trials
  while (protocolId)
  {
    // No lick ITI
    iti.nextRandom();
    unsigned long nolickStartTime = millis();
    sat.delay(500);
    digitalWrite(rig.camPin, HIGH);
    sat.delayContinue(isLickPinHigh, iti.fixedDur + iti.randomDur);
    sat.sendData("nolickITI", nolickStartTime, millis() - nolickStartTime);

    // Trial starts
    sat.sendData("trialNum", millis(), ++numTrials);
    numPulseOn(numTrials);
    tone(rig.framePin, frameRate);

    // Present cue
    sat.sendData("cue", millis(), cueDur);
    triggerCue(cueDur);
    
    bool isLicked = sat.delayUntil(isLickPinHigh, 10000);

    // Deliver water reward if animal licked
    if (isLicked)
    {
      sat.sendData("waterTrig", millis(), waterDelay);
      sat.delay(waterDelay);
      sat.sendData("water", millis(), waterDur);
      rig.deliverWater(waterDur);
      sat.delay(drinkDur);

      // Trial ends
      digitalWrite(rig.camPin, LOW);
      noTone(rig.framePin);
    }
  }

  // Report the end of training
  sat.sendData("lickForWaterEnd");

  // Detach perch lick detection interrupt function
  detachInterrupt(digitalPinToInterrupt(rig.lickDetectorPinAUX));
}
