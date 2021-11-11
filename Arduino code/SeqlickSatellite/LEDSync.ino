void ledSync() {

  unsigned long lightDur = 2000;
  unsigned long delayVal;
  byte ledPin = 10;

  pinMode(13, OUTPUT);
  pinMode(ledPin, OUTPUT);
  pinMode(rig.numPin, OUTPUT);

  // SESSION STARTS
  sat.sendData("sessionStart", millis(), protocolId);

  while (protocolId) {
    // Random delay
    delayVal = random(5000, 10000);
    sat.sendData("ledOff", millis(), delayVal);
    sat.delay(delayVal);

    // Flash LED
    numPulseOn(lightDur);
    digitalWrite(ledPin, HIGH);
    digitalWrite(13, HIGH);
    sat.sendData("ledOn", millis(), lightDur);
    sat.delay(lightDur);
    digitalWrite(ledPin, LOW);
    digitalWrite(13, LOW);
  }

  // SESSION ENDS
  sat.sendData("sessionEnd", millis(), protocolId);
}
