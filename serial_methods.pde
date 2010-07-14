  void updatePositions() {
    for(int i=0; i<3; i++) {
      String out = "";
      for(int j=0; j<6; j++) {
        out = out + "G" + j + "*";
      }
      try {
        controllers[i].write(out);
      }
      catch (Exception e) { };
    }  
}

void serialEvent(Serial p) {
  // Figure out with controller this is
  int module = -1;
  for(int i=0; i<3; i++) {
    if(p == controllers[i]) module = i;  
  }
  
  if(module > -1) {
    char command;
    int actuator;
    int value;
    
    String inString = controllers[module].readString();
    String[] t = split(inString, "*");
    if(t.length > 1) inString = t[1]; else inString = "!!!";
    command = inString.charAt(0);
  
    if(command == 'P') {
      actuator = Integer.parseInt(inString.substring(1,2));
      value = Integer.parseInt(inString.substring(2, inString.length()-1));
      
        if(actuator == 0 || actuator == 3) house.modules[module].legs[actuator < 3 ? 0 : 1].frontAct.updateLength(value);
        if(actuator == 1 || actuator == 4) house.modules[module].legs[actuator < 3 ? 0 : 1].backAct.updateLength(value);
        if(actuator == 2 || actuator == 5) house.modules[module].legs[actuator < 3 ? 0 : 1].vertAct.updateLength(value);
    }
    else if(command == 'M') {
     //println("received: " + inString); 
    }
  }
  else {
    char command;
    float value;
    String inString = auxBoard.readString();
    String[] t = split(inString, "*");
    if(t.length > 1) inString = t[1]; else inString = "!!!";
    command = inString.charAt(0);
    value = Float.parseFloat(inString.substring(1, inString.length()-1));
    switch(command) {
      case 'H':
        info.heading = value;
        break;
      case 'X':
        info.tiltX = value;
        break;
      case 'Y':
        info.tiltY = value;
        break;
      case 'C':
        info.current = value;
        break;
      default: break;
    }
    /*
    arrayCopy(powerHistory, 1, powerHistory, 0, powerHistory.length - 1);
    String inString = auxBoard.readString();
    powerHistory[powerHistory.length-1] = Float.parseFloat(inString.substring(0, inString.length()-1));  
    */
  }
}

boolean calibrate(int controller, int actuator) {
  try {
    controllers[controller].write("C" + actuator + "*");
  }
  catch (Exception e) {
    println("Can't calibrate! Unable to communicate with serial port.");
  }
  return true;
}

boolean setPosition(int controller, int actuator, int value) {
  String out = "M" + actuator + value + "*";
  out += out;
  try {
    controllers[controller].write(out);
    return true;
  }
  catch (Exception e) {
     println("Could not write to the serial port!");
     return false;
  }
}
