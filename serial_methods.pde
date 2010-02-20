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
    
    if(actuator < 3 && module == 0) {
      if(actuator == 0 || actuator == 3) house.modules[module].legs[actuator < 3 ? 0 : 1].frontAct.updateLength(value);
      if(actuator == 1 || actuator == 4) house.modules[module].legs[actuator < 3 ? 0 : 1].backAct.updateLength(value);
      if(actuator == 2 || actuator == 5) house.modules[module].legs[actuator < 3 ? 0 : 1].vertAct.updateLength(value);
    }
  }
  else if(command == 'M') {
   //println("received: " + inString); 
  }
}

boolean calibrate(int controller, int actuator) {
  controllers[controller].write("C" + actuator + "*");
  return true;
}

boolean setPosition(int controller, int actuator, int value) {
  String out = "M" + actuator + value + "*";
  controllers[controller].write(out);
  println(out);
  return true;
}
