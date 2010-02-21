import processing.serial.*;


PFont Courier, HelveticaBold, DialNumbers;
color red, white, grey, black, blue, green;

GUIManager GUI;

Serial[] controllers = new Serial[6];

VSlider[] sliders = new VSlider[18];
Button[] buttons = new Button[18];

int[] positions = new int[18];

void setup() {
  size(800,480, JAVA2D);
  smooth();
  colorMode(HSB);

  Courier = loadFont("Courier-Bold-11.vlw");  
  HelveticaBold = loadFont("Helvetica-Bold-30.vlw");
  DialNumbers = loadFont("Helvetica-Bold-30.vlw");
  red = color(0,170,255);
  blue = color(140,150,200);
  green = color(80,170,255);
  white = color(0,0,255);
  grey = color(0,0,100);
  black = color(0,0,0);
  
  GUI = new GUIManager();
  
  //println(Serial.list());
  
  controllers[0] = new Serial(this, Serial.list()[3], 9600);
  controllers[1] = new Serial(this, Serial.list()[1], 9600);
  controllers[2] = new Serial(this, Serial.list()[4], 9600);
  
  controllers[0].bufferUntil('!');
  controllers[1].bufferUntil('!');
  controllers[2].bufferUntil('!');
  
  buildSliders();
}

void mouseMoved() {
  GUI.update(mouseX, mouseY, false);
}
void mousePressed() {
  //GUI.update(mouseX, mouseY, false);
  GUI.update(mouseX, mouseY, true);
}

void keyPressed() {
  if(key == 'a') {
  setPosition(0,0, positions[0]+1);   
  setPosition(0,0, positions[0]+1);   
  }
}

void draw() {
  background(0);
  
  fill(grey);
  rectMode(CENTER);
  for(int i=0; i<3; i++) {
    rect((i+.5) * width/3 * 18/19. + 16, height/2, width/3. * .93, height);
  }
  
  GUI.draw();
  
  if(frameCount%1 == 0)
    updatePositions();
  
  noStroke();
  for(int i=0; i<18; i++) {
      int n = floor(i/6);
      int m = i%6;
      VSlider s = (VSlider)GUI.clickables.get(i);
      
      //positions[i] = getPosition(n,m);

      fill(blue);
      ellipse(s.center.x, map(positions[i], s.min, s.max, s.center.y + s.height/2 -s.width/2, s.center.y - s.height/2 + s.width/2), s.width*.5, s.width*.5);
  
      textFont(Courier);
      textAlign(CENTER, CENTER);
      fill(white);
      text(positions[i], s.center.x, height-20);
      
      textFont(HelveticaBold);
      text(i%6, s.center.x, height-40);
  }
}

void buildSliders() {
  float groupWidth = width/controllers.length;
  sliders[00] = new VSlider(30, height*.75, -100, 100, 35 + 00*width/19., height/2, new SliderAction() { void act(float value) { setPosition(0,0, int(value)); } });
  sliders[01] = new VSlider(30, height*.75, -1000, 1000, 35 + 01*width/19., height/2, new SliderAction() { void act(float value) { setPosition(0,1, int(value)); } });
  sliders[02] = new VSlider(30, height*.75, -4000, 4000, 35 + 02*width/19., height/2, new SliderAction() { void act(float value) { setPosition(0,2, int(value)); } });
  sliders[03] = new VSlider(30, height*.75, -1000, 1000, 35 + 03*width/19., height/2, new SliderAction() { void act(float value) { setPosition(0,3, int(value)); } });
  sliders[04] = new VSlider(30, height*.75, -1000, 1000, 35 + 04*width/19., height/2, new SliderAction() { void act(float value) { setPosition(0,4, int(value)); } });
  sliders[05] = new VSlider(30, height*.75, -4000, 4000, 35 + 05*width/19., height/2, new SliderAction() { void act(float value) { setPosition(0,5, int(value)); } });
  sliders[06] = new VSlider(30, height*.75, -1000, 1000, 35 + 06*width/19., height/2, new SliderAction() { void act(float value) { setPosition(1,0, int(value)); } });
  sliders[07] = new VSlider(30, height*.75, -1000, 1000, 35 + 07*width/19., height/2, new SliderAction() { void act(float value) { setPosition(1,1, int(value)); } });
  sliders[8]  = new VSlider(30, height*.75, -4000, 4000, 35 +  8*width/19., height/2, new SliderAction() { void act(float value) { setPosition(1,2, int(value)); } });
  sliders[9]  = new VSlider(30, height*.75, -1000, 1000, 35 +  9*width/19., height/2, new SliderAction() { void act(float value) { setPosition(1,3, int(value)); } });
  sliders[10] = new VSlider(30, height*.75, -1000, 1000, 35 + 10*width/19., height/2, new SliderAction() { void act(float value) { setPosition(1,4, int(value)); } });
  sliders[11] = new VSlider(30, height*.75, -4000, 4000, 35 + 11*width/19., height/2, new SliderAction() { void act(float value) { setPosition(1,5, int(value)); } });
  sliders[12] = new VSlider(30, height*.75, -1000, 1000, 35 + 12*width/19., height/2, new SliderAction() { void act(float value) { setPosition(2,0, int(value)); } });
  sliders[13] = new VSlider(30, height*.75, -1000, 1000, 35 + 13*width/19., height/2, new SliderAction() { void act(float value) { setPosition(2,1, int(value)); } });
  sliders[14] = new VSlider(30, height*.75, -4000, 4000, 35 + 14*width/19., height/2, new SliderAction() { void act(float value) { setPosition(2,2, int(value)); } });
  sliders[15] = new VSlider(30, height*.75, -1000, 1000, 35 + 15*width/19., height/2, new SliderAction() { void act(float value) { setPosition(2,3, int(value)); } });
  sliders[16] = new VSlider(30, height*.75, -1000, 1000, 35 + 16*width/19., height/2, new SliderAction() { void act(float value) { setPosition(2,4, int(value)); } });
  sliders[17] = new VSlider(30, height*.75, -4000, 4000, 35 + 17*width/19., height/2, new SliderAction() { void act(float value) { setPosition(2,5, int(value)); } });  

  buttons[00] = new Button(new XY(35 + 00*width/19., 30), 40, 40, "C", new Action() { void act(float x, float y) { calibrate(0,0); } });
  buttons[01] = new Button(new XY(35 + 01*width/19., 30), 40, 40, "C", new Action() { void act(float x, float y) { calibrate(0,1); } });
  buttons[02] = new Button(new XY(35 + 02*width/19., 30), 40, 40, "C", new Action() { void act(float x, float y) { calibrate(0,2); } });
  buttons[03] = new Button(new XY(35 + 03*width/19., 30), 40, 40, "C", new Action() { void act(float x, float y) { calibrate(0,3); } });
  buttons[04] = new Button(new XY(35 + 04*width/19., 30), 40, 40, "C", new Action() { void act(float x, float y) { calibrate(0,4); } });
  buttons[05] = new Button(new XY(35 + 05*width/19., 30), 40, 40, "C", new Action() { void act(float x, float y) { calibrate(0,5); } });
  buttons[06] = new Button(new XY(35 + 06*width/19., 30), 40, 40, "C", new Action() { void act(float x, float y) { calibrate(1,0); } });
  buttons[07] = new Button(new XY(35 + 07*width/19., 30), 40, 40, "C", new Action() { void act(float x, float y) { calibrate(1,1); } });
  buttons[8]  = new Button(new XY(35 + 8*width/19., 30), 40, 40, "C", new Action() { void act(float x, float y) { calibrate(1,2); } });
  buttons[9]  = new Button(new XY(35 + 9*width/19., 30), 40, 40, "C", new Action() { void act(float x, float y) { calibrate(1,3); } });
  buttons[10] = new Button(new XY(35 + 10*width/19., 30), 40, 40, "C", new Action() { void act(float x, float y) { calibrate(1,4); } });
  buttons[11] = new Button(new XY(35 + 11*width/19., 30), 40, 40, "C", new Action() { void act(float x, float y) { calibrate(1,5); } });
  buttons[12] = new Button(new XY(35 + 12*width/19., 30), 40, 40, "C", new Action() { void act(float x, float y) { calibrate(2,0); } });
  buttons[13] = new Button(new XY(35 + 13*width/19., 30), 40, 40, "C", new Action() { void act(float x, float y) { calibrate(2,1); } });
  buttons[14] = new Button(new XY(35 + 14*width/19., 30), 40, 40, "C", new Action() { void act(float x, float y) { calibrate(2,2); } });
  buttons[15] = new Button(new XY(35 + 15*width/19., 30), 40, 40, "C", new Action() { void act(float x, float y) { calibrate(2,3); } });
  buttons[16] = new Button(new XY(35 + 16*width/19., 30), 40, 40, "C", new Action() { void act(float x, float y) { calibrate(2,4); } });
  buttons[17] = new Button(new XY(35 + 17*width/19., 30), 40, 40, "C", new Action() { void act(float x, float y) { calibrate(2,5); } });  

  for(int i=0; i<sliders.length; i++) {
    GUI.clickables.add(sliders[i]);
  }
  
  for(int i=0; i<buttons.length; i++) {
    GUI.clickables.add(buttons[i]);
  }
  
}


// SERIAL COMMUNICATION METHODS
// ============================

void updatePositions() {
  for(int i=0; i<3; i++) {
    String out = "";
    for(int j=0; j<6; j++) {
      out = out + "G" + j + "*";
    }
    controllers[i].write(out);
  }  
}

void serialEvent(Serial p) {
  // Figure out with controller this is
  int controller = -1;
  for(int i=0; i<3; i++) {
    if(p == controllers[i]) controller = i;  
  }
  
  char command;
  int actuator;
  int value;
  
  String inString = controllers[controller].readString();
  String[] t = split(inString, "*");
  if(t.length > 1) inString = t[1]; else inString = "!!!";
  command = inString.charAt(0);

  if(command == 'P') {
    actuator = Integer.parseInt(inString.substring(1,2));
    value = Integer.parseInt(inString.substring(2, inString.length()-1));
    positions[controller*6 + actuator] = value;
  }
  else if(command == 'M') {
   println("received: " + inString); 
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
  /*
  int timeout = 100;
  while(timeout >= 0 && controllers[controller].available() <= 0) {
    delay(1);
    timeout--;
  }
  if(timeout <= 0) return false;
  
  String response = "";
  while(controllers[controller].available() > 0) {
    response = controllers[controller].readStringUntil('!');
  }
  println(response);
  if(response == null) return false; else return true;
  */
}







