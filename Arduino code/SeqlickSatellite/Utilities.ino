// I/O
void reportLick() {
  if (rig.isLickOn()) {
    lickCount++;
    sat.sendData("lickOn");
  }
  else {
    sat.sendData("lickOff");
  }
}

void reportELickAUX() {
  if (rig.isLickOn()) {
    sat.sendData("lickOn");
  }
  else {
    sat.sendData("lickOff");
  }
}

void reportPLickAUX() {
  if (rig.isLickOnAUX()) {
    lickCount++;
    sat.sendData("lickOnAUX");
  }
  else {
    sat.sendData("lickOffAUX");
  }
}

bool isLickPinHigh() {
  return rig.isLickOn();
}

bool isLickPinHighAUX() {
  return rig.isLickOnAUX();
};


bool isLickOrAbort() {
  return lickCount > 0 || protocolId == 0;
}

void lickportMoveX(long val) {
  lickportStage.move(val, 1);
//  lickportServo.writeMicroseconds(constrain(1000 + 1000 - val / 10, 1000, 2000));
}

void lickportMoveY(long val) {
  lickportStage.move(val, 2);
  lickportServo.writeMicroseconds(constrain(1500 + val / 10, 1000, 2000));
}

void lickportMove(Position& p) {
  lickportMove(p.getX(), p.getY());
}

void lickportMove(long val1, long val2) {
  lickportStage.streamLine(val1, val2);
//  lickportServo.writeMicroseconds(constrain(1000 + 1000 - val1 / 10, 1000, 2000));
  lickportServo.writeMicroseconds(constrain(1500 + val2 / 10, 1000, 2000));
}

void lickportMoveArc(Position& p1, Position& p2) {
  lickportMoveArc(p1.getX(), p1.getY(), p2.getX(), p2.getY());
}

void lickportMoveArc(long val_11, long val_12, long val_21, long val_22) {
  lickportStage.streamArc2(val_11, val_12, val_21, val_22);
//  lickportServo.writeMicroseconds(constrain(1000 + 1000 - val_21 / 10, 1000, 2000));
  lickportServo.writeMicroseconds(constrain(1500 + val_22 / 10, 1000, 2000));
}

void numPulseOn(unsigned long num) {
  numTimer.begin(numPulseOff, num * 1000);
  digitalWrite(rig.numPin, HIGH);
}

void numPulseOff() {
  digitalWrite(rig.numPin, LOW);
}

void triggerCue(unsigned long dur) {
  rig.triggerSound(0, dur);
}

void triggerOpto(byte id) {
  rig.sendTTL(rig.wsPin, 1);
  sat.sendData("opto", millis() - 1, id);
}

void switchBlock(byte blk) {
  block = blk;
  if (blk == 0) {
    digitalWrite(10, LOW); // ledPin = 10
  }
  else if (blk == 1) {
    digitalWrite(10, HIGH);
  }
}



// Task
byte getSeqLen(byte seqIdx) {
  byte stepIdx = 0;
  while (stepIdx < seqMaxLen) {
    if (seqPosInd[seqIdx][stepIdx] != 255)
      stepIdx++;
    else
      break;
  }
  return stepIdx;
}



// Debugging
void doTest(unsigned long iter) {
  Serial3.println("/1 warnings clear");
  delay(100);
  lickportStage.read();

  Serial.print("test starts\n");
  int seqIdx;
  for (int j = 0; j < iter; j++) {
    seqIdx = j % 2;
    for (int i = 1; i < getSeqLen(seqIdx); i++) {
      // Positioning
      byte posIdx = seqPosInd[seqIdx][i];
      byte lastPosIdx = seqPosInd[seqIdx][i - 1];
      byte transType = seqTransType[seqIdx][i - 1];

      if (transType == 0)
        lickportMove(posList[posIdx]); // moves in a line
      else
        lickportMoveArc(posList[lastPosIdx], posList[posIdx]); // moves in an arc

      delay(fixPosDelay + addPosDelay * transType);

      lickportStage.read();
    }
    delay(500);
  }
}
