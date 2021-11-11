void stimulation()
{
  // Initialize variables
  unsigned int numTrials = 0;

  // SESSION STARTS
  sat.sendData("sessionStart", millis(), protocolId);

  // Loop for trials
  while (protocolId)
  {
    // Check for session pause command from server
    while (protocolPauseFlag)
      sat.delay(100);

    // Create video file
    digitalWrite(rig.camPin, HIGH);
    
    sat.delay(1000);

    // Start recording
    sat.sendData("trialNum", millis(), ++numTrials);
    numPulseOn(numTrials);
    tone(rig.framePin, frameRate);
    
    sat.delay(2000);

    // Trigger WaveSurfer
    rig.sendTTL(rig.wsPin, 1);
    
    sat.delay(3000-1);

    // Stop recording and close video file
    noTone(rig.framePin);
    digitalWrite(rig.camPin, LOW);
    
    sat.delay(7000);
  }

  // SESSION ENDS
  sat.sendData("sessionEnd", millis(), protocolId);
  lickportMove(restPos);
}
