void seqlick2()
{
  // Initialize variables
  unsigned int numTrials = 0;
  byte seqIdx = 0;
  const byte seqMaxIdx = 1;
  byte posIdx;
  byte optoType;

  // Specify motor speed and acceleration
  lickportStage.setMaxSpeed(8600*75); // in 0.6104steps/s (8600 ~= 1mm/s); was 262467
  lickportStage.setAcceleration(860*2); // in 6104steps/s^2 (860 ~= 1m/s^2); was 205*5 or 1025

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
    sat.delayContinue(isLickPinHigh, iti.fixedDur + iti.randomDur);
    sat.sendData("nolickITI", nolickStartTime, millis() - nolickStartTime);

    // Trial starts
    sat.sendData("trialNum", millis(), ++numTrials);
    numPulseOn(numTrials);            // start sending trial number TTL
    tone(rig.framePin, frameRate);    // start frame triggers
    if (optoType == 0)
      triggerOpto(optoType);          // trigger opto stim at cue onset
    sat.sendData("cue", millis(), cueDur);
    triggerCue(cueDur);               // trigger auditory cue

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
        byte transType = seqTransType[seqIdx][i - 1];
        
        if (transType == 0)
          lickportMove(posList[posIdx]); // moves in a line
        else
          lickportMoveArc(posList[lastPosIdx], posList[posIdx]); // moves in an arc
        
        delay(fixPosDelay);
        lickCount = 0;
        delay(addPosDelay * transType);
        
        // Wait for next lick
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

  // SESSION ENDS
  sat.sendData("sessionEnd", millis(), protocolId);
  lickportMove(restPos);
}
