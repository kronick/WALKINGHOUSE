import java.util.Calendar.*;
import java.util.Date.*;

import processing.serial.*;

float BASE_FRAMERATE = 10;  // Used as a standard to compensate walking speed at other framerates.

// Viewmode constants
static final int MAP_VIEW = 1;
static final int ROUTE_VIEW = 2;
static final int DRIVE_VIEW = 3;
static final int SUN_VIEW = 4;
static final int CALIBRATE_VIEW = 5;
static final int ACTUATOR_VIEW = 6;
static final int STATS_VIEW = 7;

static final int FRAME_RATE = 60;
static final int FOOT_DIAMETER = 30;

static final float MODULE_LENGTH = 124; //124
static final float MODULE_WIDTH = 124; //124

color red, white, grey, black, blue, green;

House house;

ArrayList colony;

GUIManager GUI;
Dial headingDial;
ArcBar turnRateBar, deviance;

boolean debug = false;

boolean debugTargets = false;

float zeroDist;

PFont Courier, HelveticaBold, DialNumbers;

float zoom = 1;
float zoomGoal = 1;
XYZ viewCenter;
float viewRotation = 0;
int viewMode = MAP_VIEW;

ScrollEvent mWheel;

PImage bgMap;

boolean turbo = false;
boolean follow = false;

XMLElement config;

Serial[] controllers = new Serial[3];
Serial auxBoard;

float[] powerHistory = new float[1000];

int timerStart = 0;

void setup() {
  size(800,480, JAVA2D); //800x480
  smooth();
  frameRate(FRAME_RATE);
  colorMode(HSB); 

  hint(ENABLE_NATIVE_FONTS); 
  Courier = loadFont("Courier-Bold-11.vlw");
  HelveticaBold = loadFont("Helvetica-Bold-40.vlw");
  DialNumbers = loadFont("Courier-Bold-16.vlw"); 

  red = color(0,170,255);
  blue = color(140,150,200);
  green = color(80,170,255);
  white = color(0,0,255);
  grey = color(0,0,100);
  black = color(0,0,0);
  
  boolean simulate = false;
  
  // Initialize serial communications
  // Change the indices if controllers are attached to other ports
  try {
    controllers[0] = new Serial(this, Serial.list()[3], 9600);
    controllers[1] = new Serial(this, Serial.list()[1], 9600);
    controllers[2] = new Serial(this, Serial.list()[4], 9600);
    
    //auxBoard = new Serial(this, Serial.list()[2], 9600);
  
    controllers[0].bufferUntil('!');
    controllers[1].bufferUntil('!');
    controllers[2].bufferUntil('!');

    //auxBoard.bufferUntil('!');
  }
  catch (Exception e) {
    println("Could not initialize serial ports! Running in simulation mode... ");
    simulate = true;
  }
  
  house = new House(new XYZ(0, 0,0), PI/2, 3, simulate);

  house.modules[2].legs[0].vertAct.counterFactor = 0.017;
  colony = new ArrayList();

  GUI = new GUIManager();

  viewCenter = new XYZ(width/2, height/2, 0);
  bgMap = loadImage("map.png");

  mWheel = new ScrollEvent();

  for(int i=0; i<powerHistory.length; i++) {
    powerHistory[i] = 0;
  }

  homeMenu();
}

void keyPressed() {
  if(key == 't') turbo = !turbo; 
  if(key == 'f') follow = !follow; 
  if(key == 'g') house.gaitState = 1; 
  if(key == TAB) {
    debug = !debug;
  } 

  if(key == 'w') waypointMenu();
  if(key == 'a') {
    House n = new House(new XYZ(random(-1500,1500), random(-1500,1500), 0), random(0,PI/2), (int)random(3,7), true);
    n.update();
    n.navMode = House.RANDOM_NAV;
    n.gaitState = 1;
    colony.add(n);
  }

  if(key == '1') debugTargets = false;
  if(key == '2') debugTargets = true;

  if(key == '=' || key == '+') {
    zoom *= 1.1;
  }
  if(key == '-' || key == '_') {
    zoom *= .9;
  }

  if(key == CODED) {
    switch(keyCode) {
    case UP:
      moveViewUp();
      break;
    case DOWN:
      moveViewDown();
      break;
    case LEFT:
      moveViewLeft();
      break;
    case RIGHT:
      moveViewRight();
      break; 
    } 
  }
}

void mouseMoved() {
  GUI.update(mouseX, mouseY, false);
}
void mousePressed() {
  //GUI.update(mouseX, mouseY, false);
  GUI.update(mouseX, mouseY, true);
}
void mouseDragged() {
  //GUI.update(mouseX, mouseY, true);
}


void draw() {
  // Send commands to asynchronously update actuator lengths
  updatePositions();
  
  // Try to set initial targets 
  for(int i=0; i<house.modules.length; i++) {
    for(int j=0; j<house.modules[i].legs.length; j++) {
      if(Float.isNaN(house.modules[i].legs[j].target.z)) {
        house.modules[i].legs[j].target = house.modules[i].legs[j].findFoot(
                                            house.modules[i].legs[j].frontAct.length,
                                            house.modules[i].legs[j].backAct.length,
                                            house.modules[i].legs[j].vertAct.length);
      }
    }
  }
  
  
  // Update the house(s)
  for(int t=0; t<(turbo ? 60 : 1); t++) {
    if(!house.calibrate) {
      house.update();
    }
    else {
      if(viewMode != ACTUATOR_VIEW)
        house.updateLegsOnly();      
    }
    for(int j=0; j<colony.size(); j++) {
      ((House)colony.get(j)).update();  
    }

    if(!house.simulate && viewMode != ACTUATOR_VIEW) {
       for(int i=0; i<house.modules.length; i++) {
         for(int j=0; j<house.modules[i].legs.length; j++) {
           house.modules[i].legs[j].moveTarget(new XYZ(0, 0, 0), true);
         }  
       }      
      
      // Send new targets to leg controllers
      for(int i=0; i<house.modules.length; i++) {
          String out = "";
          // Positions are sent only if the position has been read in from the controller already
          // this prevents movement on startup.
          if(house.modules[i].legs[0].frontAct.length != -1)
            out += "M0" + house.modules[i].legs[0].frontAct.getTargetCount() + "*";
          if(house.modules[i].legs[0].backAct.length != -1)
            out += "M1" + house.modules[i].legs[0].backAct.getTargetCount() + "*";
          if(house.modules[i].legs[0].vertAct.length != -1)
            out += "M2" + house.modules[i].legs[0].vertAct.getTargetCount() + "*";
          if(house.modules[i].legs[1].frontAct.length != -1)
            out += "M3" + house.modules[i].legs[1].frontAct.getTargetCount() + "*";
          if(house.modules[i].legs[1].backAct.length != -1)
            out += "M4" + house.modules[i].legs[1].backAct.getTargetCount() + "*";
          if(house.modules[i].legs[1].vertAct.length != -1)
            out += "M5" + house.modules[i].legs[1].vertAct.getTargetCount() + "*";
          
          // Values are sent twice for error-checking purposes
          if(house.modules[i].legs[0].frontAct.length != -1)          
            out += "M0" + house.modules[i].legs[0].frontAct.getTargetCount() + "*";
          if(house.modules[i].legs[0].backAct.length != -1)
            out += "M1" + house.modules[i].legs[0].backAct.getTargetCount() + "*";
          if(house.modules[i].legs[0].vertAct.length != -1)
            out += "M2" + house.modules[i].legs[0].vertAct.getTargetCount() + "*";
          if(house.modules[i].legs[1].frontAct.length != -1)
            out += "M3" + house.modules[i].legs[1].frontAct.getTargetCount() + "*";
          if(house.modules[i].legs[1].backAct.length != -1)
            out += "M4" + house.modules[i].legs[1].backAct.getTargetCount() + "*";
          if(house.modules[i].legs[1].vertAct.length != -1)
            out += "M5" + house.modules[i].legs[1].vertAct.getTargetCount() + "*";          
          try {  
            controllers[i].write(out);
          }
          catch (Exception e) { println("Could not send command to controller."); }
      }    
    }
  }
 

  // Move the viewport to track the house if the follow flag is set true
  if(follow) {
    viewCenter.x -= (viewCenter.x - (width/2 - house.center.x)) * .1;
    viewCenter.y -= (viewCenter.y - (height/2-house.center.y)) * .1;

    if(!house.holdHeading) {
      float compAngle = -house.angle + PI/2;
      float viewDiff = (viewRotation - compAngle);
      if(viewDiff > PI) viewDiff -= 2*PI;
      if(viewDiff < -PI) viewDiff += 2*PI;
      //println(degrees(viewDiff));
      viewRotation -= viewDiff * .05;
      while(viewRotation+PI/2 < 0) viewRotation += 2*PI;
      while(viewRotation+PI/2 > 2*PI) viewRotation -= 2*PI;
    }
    else {
      viewRotation = 0;
    }
  }

  background(80,20,100); 
  imageMode(CENTER);
  rectMode(CENTER);

  if(viewMode == MAP_VIEW || viewMode == ROUTE_VIEW || viewMode == DRIVE_VIEW) {
    // Draw the house
    // ====================================  
    pushMatrix();
    // Transform to local view
    translate(width/2, height/2);
    rotate(viewRotation);
    translate(-width/2, -height/2);
    translate((viewCenter.x-width/2)*zoom, (viewCenter.y-height/2)*zoom);     
    scale(zoom);
    translate(width/2/zoom, height/2/zoom);

    // Draw the background if applicable
    if(viewMode == MAP_VIEW || viewMode == ROUTE_VIEW) {
      pushMatrix();
      scale(14);
      image(bgMap, 0,0);
      popMatrix();    
    }

    // Draw a red circle at the starting point
    noFill(); 
    stroke(red); 
    strokeWeight(5);
    ellipse(0,0,20,20);

    // Draw breadcrumbs
    fill(0,0,255);
    noStroke();
    for(int i=0; i<house.breadcrumbs.size(); i++) {
      XYZ p = (XYZ)house.breadcrumbs.get(i);
      ellipse(p.x, p.y, abs((frameCount-.25*i)%80 - 40)/8 + 5, abs((frameCount-.25*i)%80 - 40)/8 + 5);
    }
    for(int j=0; j<colony.size(); j++) {
      House h = (House)colony.get(j);
      for(int i=0; i<h.breadcrumbs.size(); i++) {
        XYZ p = (XYZ)h.breadcrumbs.get(i);
        ellipse(p.x, p.y, abs((frameCount-.25*i)%80 - 40)/8 + 5, abs((frameCount-.25*i)%80 - 40)/8 + 5);
      }  
    }    
    // Draw waypoints
    if(viewMode == ROUTE_VIEW) {
      for(int i=0; i<house.waypoints.size(); i++) {
        if(i<house.waypoints.currentGoal-1)
          stroke(0,0,150);                // Grey out path already travelled
        else
          stroke(0,0,255);
        strokeWeight(3/zoom);  // Constant regardless of zoom level
        if(i<house.waypoints.size()-1)
          line(house.waypoints.get(i).x, house.waypoints.get(i).y, house.waypoints.get(i+1).x, house.waypoints.get(i+1).y);

        if(i==house.waypoints.currentGoal)
          fill(green);                  // Highlight current goal
        else if(i<house.waypoints.currentGoal)
          fill(140,100,100);                   // Grey out old goals
        else
          fill(blue);
        noStroke();
        ellipse(house.waypoints.get(i).x, house.waypoints.get(i).y, 50, 50);
      }  

    }


    for(int j=0; j<colony.size(); j++) {
      ((House)colony.get(j)).draw(House.TOP, 1);  
    }

    house.draw(House.TOP, 1);

    // Draw concentric circles around the house
    if(debug) {
      noFill();
      strokeWeight(1);
      for(int i=1; i<20; i++) {
        stroke(0,0,255, i%2 == 0 ? 100 : 50);           
        ellipse(house.center.x,house.center.y, 25 * i, 25 * i);
      } 
    }      
    popMatrix();

    pushMatrix();
    translate(width/2, 30);
    if(debug) { 
      image(house.drawDebug(), 0, 0); 
    }  
    popMatrix();
  }

  if(viewMode == SUN_VIEW) {
    stroke(white);
    strokeWeight(2);
    noFill();

    pushMatrix();
    float dialRadius = 150;
    translate(width/2, height/2);

    // Draw polar grid
    strokeWeight(2);
    ellipse(0, 0, dialRadius * 2, dialRadius * 2);
    strokeWeight(.75);
    for(int i = 0; i<=90; i+=10) {
      ellipse(0, 0, dialRadius * (1 - i/90.) * 2, dialRadius * (1 - i/90.) * 2);   
    }

    // Draw NSEW lines
    line(0, -dialRadius - 10, 0, dialRadius + 10);
    line(-dialRadius - 10, 0, dialRadius + 10, 0);

    fill(white);
    textFont(Courier);
    textAlign(CENTER, CENTER);
    text("N", 0, -dialRadius - 15);
    text("S", 0, dialRadius + 15);
    text("E", dialRadius + 15, 0);
    text("W", -dialRadius - 15, 0);  

    SunAngle sun = new SunAngle(-float(mouseY)/height*180+90,90-float(mouseX)/width*15);  // 42.375097,-71.105608 is cambridge, ma
    sun.datetime.add(Calendar.DAY_OF_YEAR, frameCount);
    sun.datetime.set(Calendar.MINUTE, 0);


    for(int i=0; i<60*24; i+=30) {
      sun.datetime.add(Calendar.MINUTE, 30);
      //sun.datetime.set(Calendar.MONTH, Calendar.SEPTEMBER);
      float alt = sun.getAltitude();
      float azi = sun.getAzimuth();

      noStroke();
      fill(alt > 0 ? red : blue);
      float r = dialRadius - alt/(PI/2)*dialRadius;

      ellipse(r *sin(azi), r*cos(azi), 15,15);

      ellipse(-dialRadius * 1.5, -alt/PI*2 * dialRadius, 15, 15);

      //ellipse(azi/(2*PI) * width, -alt/PI*2 * dialRadius, 15, 15);

      if(i%60 == 0) {
        fill(white);
        textFont(Courier);
        textAlign(CENTER,CENTER);
        text(sun.datetime.get(Calendar.HOUR_OF_DAY), r *sin(azi), r*cos(azi));
      }

    }
    popMatrix();

    fill(white);
    textFont(Courier);
    textAlign(LEFT);
    Date t = sun.datetime.getTime();
    text(t.toString(), 50, 50);
  }

  if(viewMode == ACTUATOR_VIEW) {
    fill(0,0,0);
    rectMode(CENTER);
    for(int i=0; i<6; i++) {
      rect((i+.5) * (width-80)/6, height/2, (width-80)/6. * .98, height);
    }
  }

  // Draw basic statistics
  fill(0,0,0,80);
  noStroke();
  rect(width/2 - 40, height-20, width-80, 40);
  fill(white);
  textFont(Courier);
  textAlign(LEFT, CENTER);
  text("Distance Walked: " + (new DecimalFormat("0.0")).format(house.distanceWalked/100) + " m", 10, 460);
  text("Steps Taken: " + house.stepCount, 10, 470);

  // Draw framerate counter and time
  textAlign(RIGHT,CENTER);
  int elapsed = (int)millis() - timerStart;
  text("T+"+nf(int(elapsed/360000.), 2) + ":" + nf(int(elapsed/60000.), 2) + "." + nf(int(elapsed/1000.), 2), width-90, height-30);
  text(hour() + ":" + (new DecimalFormat("00")).format(minute()) + "." + (new DecimalFormat("00")).format(second()), width-90, height-20);
  text((new DecimalFormat("00.0")).format(frameRate) + "fps", width-90, height-10);

  // Draw the GUI
  GUI.draw(); 

  if(viewMode == ACTUATOR_VIEW) {
    // Set targets to current positions so the house doesn't move when leaving this mode
    for(int i=0; i<house.modules.length; i++) {
      for(int j=0; j<house.modules[i].legs.length; j++) {
        house.modules[i].legs[j].moveTargetToFoot();
      }
    }    
    
    noStroke();
    int start = 0;
    for(int a=0; a<GUI.clickables.size(); a++) { 
      if((GUI.clickables.get(a)).getClass().getName() == "VSlider") {
        start = a;
        break;
      }
    }
    for(int i=0; i<18; i++) {
        int n = floor(i/6);
        int m = i%6;
        try {
          VSlider s = (VSlider)GUI.clickables.get(i+start);
        
          //positions[i] = getPosition(n,m);
    
          fill(blue);
          ellipse(s.center.x, map(house.modules[n].legs[floor(m/3)].getAct(m%3).getLengthCount(), s.min, s.max, s.center.y + s.height/2 -s.width/2, s.center.y - s.height/2 + s.width/2), s.width*.5, s.width*.5);
      
          textFont(Courier);
          textAlign(CENTER, CENTER);
          fill(white);
          text(house.modules[n].legs[floor(m/3)].getAct(m%3).getLengthCount(), s.center.x, height-80);
          text(i%3 == 0 ? "FRONT" : i%3 == 1 ? "BACK" : "TOP", s.center.x, 70);
          
          if(i%3 == 1) {
            textFont(HelveticaBold);
            text(ceil(i/3) + 1, s.center.x, height-53);
          }
        }
        catch(ClassCastException e) { break; }
    }    
  }
  
  if(viewMode == STATS_VIEW) {
    stroke(white);
    strokeWeight(3);
    beginShape();
    for(int i=0; i<powerHistory.length; i++) {
      vertex(i/powerHistory.length * width*.8, height-100-powerHistory[i]*height/100.);
    }  
    endShape();
  }
}

