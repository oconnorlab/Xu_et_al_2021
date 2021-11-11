void seqlick3()
{
  // Initialize variables
  unsigned int numTrials = 0;
  byte seqIdx = 0;
  const byte seqMaxIdx = 1;
  byte posIdx;
  byte optoType;

  // Attach alternative lick detection interrupt functions
  detachInterrupt(digitalPinToInterrupt(rig.lickDetectorPin));
  attachInterrupt(digitalPinToInterrupt(rig.lickDetectorPinAUX), reportPLickAUX, CHANGE);
  attachInterrupt(digitalPinToInterrupt(rig.lickDetectorPin), reportELickAUX, CHANGE);

  // Specify motor speed and acceleration
  lickportStage.setMaxSpeed(8600*24); // in 0.6104steps/s (8600 ~= 1mm/s); i.e. 206408
  lickportStage.setAcceleration(860*0.715); // in 6104steps/s^2 (860 ~= 1m/s^2); i.e. 205*3

  // SESSION STARTS
  sat.sendData("sessionStart", millis(), protocolId);

  while (protocolId) {
    // Check for session pause command from computer
    while (protocolPauseFlag)
      sat.delay(100);

    // Initialize position
    posIdx = seqPosInd[seqIdx][0];
    lickportMove(posList[posIdx]);
    
    // Determine trial parameters
    iti.nextRandom();
    optoType = rig.choose(optoProbList, numOptoType);

    // ITI
    unsigned long nolickStartTime = millis();
    sat.delay(500);
    digitalWrite(rig.camPin, HIGH);
    sat.delayContinue(isLickPinHighAUX, iti.fixedDur + iti.randomDur);
    sat.sendData("nolickITI", nolickStartTime, millis() - nolickStartTime);

    // Trial starts
    sat.sendData("trialNum", millis(), ++numTrials);
    numPulseOn(numTrials);
    tone(rig.framePin, frameRate);

    // Present cue
    if (optoType == 0)
      triggerOpto(optoType); // trigger opto stim at cue onset
    sat.sendData("cue", millis(), cueDur);
    triggerCue(cueDur);

    lickCount = 0;
    if (sat.delayUntil(isLickOrAbort, respDur)) {
      // Iterate through positions
      for (int i = 1; i < getSeqLen(seqIdx); i++) {
        // Trigger opto stim at certain step
        if (optoType == 1 && i == optoMidStep)
          triggerOpto(optoType);

        // Positioning
        posIdx = seqPosInd[seqIdx][i];
        sat.sendData("posIndex", millis(), posIdx);
        sat.sendData("angle", millis(), posList[posIdx].getA());

        byte lastPosIdx = seqPosInd[seqIdx][i - 1];
        int posDiff = abs(int(lastPosIdx) - int(posIdx));
        
        if (posDiff == 1)
          lickportMove(posList[posIdx]); // moves in a line
        else
          lickportMoveArc(posList[lastPosIdx], posList[posIdx]); // moves in an arc
        
        delay(100 * posDiff); // 100 was the value for posDelay

        // Wait for next lick
        lickCount = 0;
        sat.delayUntil(isLickOrAbort);
      }

      // Deliver water
      sat.sendData("waterTrig", millis(), waterDelay);
      sat.delay(waterDelay);
      sat.sendData("water", millis(), waterDur);
      rig.deliverWater(waterDur);

      // Trigger opto stim during water consumption
      lickCount = 0;
      sat.delayUntil(isLickOrAbort);
      if (optoType == 2)
        triggerOpto(optoType);

      sat.delay(drinkDur);

      // Increment to the next sequence
      seqIdx++;
      if (seqIdx > seqMaxIdx)
        seqIdx = 0;
    }

    // Trial ends
    digitalWrite(rig.camPin, LOW);
    noTone(rig.framePin);
  }

  // Detach alternative lick detection interrupt functions
  detachInterrupt(digitalPinToInterrupt(rig.lickDetectorPin));
  detachInterrupt(digitalPinToInterrupt(rig.lickDetectorPinAUX));

  // Replace standard lick detection interrupt function
  attachInterrupt(digitalPinToInterrupt(rig.lickDetectorPin), reportLick, CHANGE);
  
  // SESSION ENDS
  sat.sendData("sessionEnd", millis(), protocolId);
  lickportMove(restPos);
}
