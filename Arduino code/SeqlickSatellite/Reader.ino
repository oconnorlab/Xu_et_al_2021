void myReader()
{
  // Get command information
  String cmdStr = sat.getCmdName();
  int idx = sat.getIndex();
  long val = sat.getValue();

  // Do specific things based on the command name, index and value

  if (idx == 0 && cmdStr.equals("RIG")) {
    sat.sendData(F("Seqlick Many 2021.4.26"));
  }
  else if (idx == 1 && cmdStr.equals("NUM")) {
    numPulseOn(val);
    sat.sendData(F("Number TTL sent"), millis(), val);
  }
  else if (idx == 1 && cmdStr.equals("CAM")) {
    tone(rig.framePin, frameRate);
    rig.sendTTL(rig.camPin, val);
    noTone(rig.framePin);
    sat.sendData(F("Camera trigger sent"), millis(), val);
  }
  else if (idx == 1 && cmdStr.equals("WS")) {
    rig.sendTTL(rig.wsPin, val);
    sat.sendData(F("WaveSurfer trigger sent"), millis(), val);
  }
  else if (idx == 0 && cmdStr.equals("home")) {
    // Reset lickport stage to its min/home
    lickportStage.home();
    sat.sendData(F("Lickport stage reset to home"));
  }
  else if (idx == 1 && cmdStr.equals("w")) {
    rig.deliverWater(val);
    sat.sendData(F("Water valve open ms"), millis(), val);
  }
  else if (idx == 1 && cmdStr.equals("t")) {
    triggerCue(val);
    sat.sendData(F("Cue triggered"), millis(), val);
  }
  else if (idx == 1 && cmdStr.equals("px")) {
    // Change the lickport position
    lickportMoveX(val);
    sat.sendData(F("Lickport X position"), millis(), val);
  }
  else if (idx == 1 && cmdStr.equals("py")) {
    // Change the lickport position
    lickportMoveY(val);
    sat.sendData(F("Lickport Y position"), millis(), val);
  }
  else if (idx == 1 && cmdStr.equals("P")) {
    // Change the lickport position
    if (val < posListLen) {
      lickportMove(posList[val]);
      sat.sendData(F("Lickport position index"), millis(), val);
      printPosition(posList[val]);
    }
    else {
      sat.sendData(F("Invalid lickport position index"), millis(), val);
    }
  }
  else if (idx == 1 && cmdStr.equals("PID")) {
    protocolId = val;
    sat.sendData(F("protocolId"), millis(), protocolId);
  }
  else if (idx == 0 && cmdStr.equals("PPF")) {
    protocolPauseFlag = !protocolPauseFlag;
    sat.sendData(F("protocolPauseFlag"), millis(), protocolPauseFlag);
  }
  else if (idx >= 1 && idx <= 2 && cmdStr.equals("REF")) {
    lickportStage.setRef(val, idx);
    if (idx == 1)
      sat.sendData(F("refX"), millis(), lickportStage.getRef(idx));
    else if (idx == 2)
      sat.sendData(F("refY"), millis(), lickportStage.getRef(idx));
  }
  else if (idx > 0 && idx <= posListLen && cmdStr.equals("PosX")) {
    posList[idx - 1].setX(val);
    sat.sendData(F("x"), millis(), posList[idx - 1].getX());
  }
  else if (idx > 0 && idx <= posListLen && cmdStr.equals("PosY")) {
    posList[idx - 1].setY(val);
    sat.sendData(F("y"), millis(), posList[idx - 1].getY());
  }
  else if (idx > 0 && idx <= posListLen && cmdStr.equals("PosA")) {
    posList[idx - 1].setA(val);
    sat.sendData(F("a"), millis(), posList[idx - 1].getA());
  }
  else if (idx > 0 && idx <= posListLen && cmdStr.equals("PosR")) {
    posList[idx - 1].setR(val);
    sat.sendData(F("r"), millis(), posList[idx - 1].getR());
  }
  else if (idx == 1 && cmdStr.equals("PosAA")) {
    for (int i = 0; i < posListLen; i++)
      posList[i].setA(val);
    sat.sendData(F("aa"), millis(), posList[0].getA());
  }
  else if (idx == 1 && cmdStr.equals("PosRR")) {
    for (int i = 0; i < posListLen; i++)
      posList[i].setR(val);
    sat.sendData(F("rr"), millis(), posList[0].getR());
  }
  else if (idx==1 && cmdStr.equals("Blk")) {
    block = val;
    sat.sendData(F("blockType"), millis(), val);
  }
  else if (idx > 0 && idx < seqMaxLen - 1 && cmdStr.equals("Seq0")) {
    seqPosInd[0][idx - 1] = val;
    seqPosInd[0][idx] = 255;
    sat.sendData(F("seqListPosIndex"), millis(), seqPosInd[0][idx - 1]);
  }
  else if (idx > 0 && idx < seqMaxLen - 1 && cmdStr.equals("Seq1")) {
    seqPosInd[1][idx - 1] = val;
    seqPosInd[1][idx] = 255;
    sat.sendData(F("seqListPosIndex"), millis(), seqPosInd[1][idx - 1]);
  }
  else if (idx > 0 && idx < seqMaxLen - 1 && cmdStr.equals("TT0")) {
    seqTransType[0][idx - 1] = val;
    sat.sendData(F("transType0"), millis(), seqTransType[0][idx - 1]);
  }
  else if (idx > 0 && idx < seqMaxLen - 1 && cmdStr.equals("TT1")) {
    seqTransType[1][idx - 1] = val;
    sat.sendData(F("transType1"), millis(), seqTransType[1][idx - 1]);
  }
  else if (idx == 1 && cmdStr.equals("TTA")) {
    for (int i = 0; i < numSeq; i++)
      for (int j = 0; j < seqMaxLen; j++) {
        seqTransType[i][j] = val;
      }
    sat.sendData(F("transTypeAll"), millis(), val);
  }
  else if (idx == 1 && cmdStr.equals("SeqList")) {
    sat.sendData(F("seqIndex"), millis(), val);
    for (int i = 0; i < getSeqLen(val); i++) {
      sat.sendData(F("posIndex"), millis(), seqPosInd[val][i]);
      printPosition(posList[seqPosInd[val][i]]);
      sat.sendData(F("T"), millis(), seqTransType[val][i]);
      delay(5);
    }
  }
  else if (idx >= 1 && idx <= 4 && cmdStr.equals("ITI")) {
    unsigned long *p = &(iti.fixedDur);
    *(p + idx - 1) = val;
    if (idx == 4)
      printItiStruct();
  }
  else if (idx == 1 && cmdStr.equals("CUD")) {
    cueDur = val;
    sat.sendData(F("cueDur"), millis(), cueDur);
  }
  else if (idx == 1 && cmdStr.equals("RSD")) {
    respDur = val;
    sat.sendData(F("respDur"), millis(), respDur);
  }
  else if (idx == 1 && cmdStr.equals("WDL")) {
    waterDelay = val;
    sat.sendData(F("waterDelay"), millis(), waterDelay);
  }
  else if (idx == 1 && cmdStr.equals("WDR")) {
    waterDur = val;
    sat.sendData(F("waterDur"), millis(), waterDur);
  }
  else if (idx == 1 && cmdStr.equals("DKD")) {
    drinkDur = val;
    sat.sendData(F("drinkDur"), millis(), drinkDur);
  }
  else if (idx >= 1 && idx <= numOptoType && cmdStr.equals("OPTO")) {
    byte *p = optoProbList;
    *(p + idx - 1) = val;
    if (idx == numOptoType)
      sat.sendData(F("optoProbList"), millis(), optoProbList, numOptoType);
  }
  else if (idx == 1 && cmdStr.equals("OMS")) {
    optoMidStep = val;
    sat.sendData(F("optoMidStep"), millis(), optoMidStep);
  }
  else if (idx == 1 && cmdStr.equals("test")) {
    doTest(val);
  }
}



void printItiStruct()
{
  sat.sendData(F("itiFixedDur"), millis(), iti.fixedDur);
  sat.sendData(F("itiMeanDur"), millis(), iti.meanRandDur);
  sat.sendData(F("itiUpperLim"), millis(), iti.upperRandLim);
  sat.sendData(F("itiLowerLim"), millis(), iti.lowerRandLim);
}

void printPosition(Position& p)
{
  sat.sendData(F("x"), millis(), p.getX());
  sat.sendData(F("y"), millis(), p.getY());
  sat.sendData(F("a"), millis(), p.getA());
  sat.sendData(F("r"), millis(), p.getR());
}
