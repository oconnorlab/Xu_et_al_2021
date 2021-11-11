// We define a function myReader (or use whatever name you like) to handle serial commands.
void myReader()
{
  // Get command information
  String cmdStr = sat.getCmdName();
  int idx = sat.getIndex();
  long val = sat.getValue();


  // Do specific things based on the command name, index and value
  if (idx == 1 && cmdStr.equals("white"))
  {
    noise1.amplitude(val / 100.0);
    sat.sendData("white noise set", millis(), val / 100.0);
  }
  else if (idx == 1 && cmdStr.equals("motor"))
  {
    isMotor = val;
    sat.sendData("Motor masking sound", millis(), isMotor);
  }
  else if (idx > 0 && idx < 5 && cmdStr.equals("mix1"))
  {
    mixer1.gain(idx-1, val / 100.0);
    sat.sendData("mixer1 gain set", millis(), val / 100.0);
  }
  else if (idx > 0 && idx < 5 && cmdStr.equals("mix2"))
  {
    mixer2.gain(idx-1, val / 100.0);
    sat.sendData("mixer2 gain set", millis(), val / 100.0);
  }
  else if (idx > 0 && idx < 5 && cmdStr.equals("mix3"))
  {
    mixer3.gain(idx-1, val / 100.0);
    sat.sendData("mixer3 gain set", millis(), val / 100.0);
  }
  else if (idx > 0 && idx < 5 && cmdStr.equals("wf1f"))
  {
    waveform1.frequency(val);
    sat.sendData("waveform1 frequency set", millis(), val);
  }
  else if (idx == 0 && cmdStr.equals("mem"))
  {
    sat.sendData(F("max memory blocks"), AudioMemoryUsageMax());
  }
  else if (idx == 0 && cmdStr.equals("cpu"))
  {
    sat.sendData(F("max cpu usage"), AudioProcessorUsageMax());
  }
  else if (idx == 1 && cmdStr.equals("lineOutLevel"))
  {
    sgtl5000_1.lineOutLevel(val); // 29: 1.29 Volts p-p  (default); 17: 2.53 Volts p-p
    sat.sendData(F("LineOutLevel set"), val);
  }
  else if (idx == 1 && cmdStr.equals("vol"))
  {
    sgtl5000_1.volume(val / 100.0);
    sat.sendData(F("Volume set"), val);
  }
}
