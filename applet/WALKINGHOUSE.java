import processing.core.*; 
import processing.xml.*; 

import java.util.Calendar.*; 
import java.util.Date.*; 
import processing.serial.*; 

import java.applet.*; 
import java.awt.*; 
import java.awt.image.*; 
import java.awt.event.*; 
import java.io.*; 
import java.net.*; 
import java.text.*; 
import java.util.*; 
import java.util.zip.*; 
import java.util.regex.*; 

public class WALKINGHOUSE extends PApplet {






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

int red, white, grey, black, blue, green;

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

public void setup() {
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

  house.modules[2].legs[0].vertAct.counterFactor = 0.017f;
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

public void keyPressed() {
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
    zoom *= 1.1f;
  }
  if(key == '-' || key == '_') {
    zoom *= .9f;
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

public void mouseMoved() {
  GUI.update(mouseX, mouseY, false);
}
public void mousePressed() {
  //GUI.update(mouseX, mouseY, false);
  GUI.update(mouseX, mouseY, true);
}
public void mouseDragged() {
  //GUI.update(mouseX, mouseY, true);
}


public void draw() {
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
    viewCenter.x -= (viewCenter.x - (width/2 - house.center.x)) * .1f;
    viewCenter.y -= (viewCenter.y - (height/2-house.center.y)) * .1f;

    if(!house.holdHeading) {
      float compAngle = -house.angle + PI/2;
      float viewDiff = (viewRotation - compAngle);
      if(viewDiff > PI) viewDiff -= 2*PI;
      if(viewDiff < -PI) viewDiff += 2*PI;
      //println(degrees(viewDiff));
      viewRotation -= viewDiff * .05f;
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
      ellipse(p.x, p.y, abs((frameCount-.25f*i)%80 - 40)/8 + 5, abs((frameCount-.25f*i)%80 - 40)/8 + 5);
    }
    for(int j=0; j<colony.size(); j++) {
      House h = (House)colony.get(j);
      for(int i=0; i<h.breadcrumbs.size(); i++) {
        XYZ p = (XYZ)h.breadcrumbs.get(i);
        ellipse(p.x, p.y, abs((frameCount-.25f*i)%80 - 40)/8 + 5, abs((frameCount-.25f*i)%80 - 40)/8 + 5);
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
    strokeWeight(.75f);
    for(int i = 0; i<=90; i+=10) {
      ellipse(0, 0, dialRadius * (1 - i/90.f) * 2, dialRadius * (1 - i/90.f) * 2);   
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

    SunAngle sun = new SunAngle(-PApplet.parseFloat(mouseY)/height*180+90,90-PApplet.parseFloat(mouseX)/width*15);  // 42.375097,-71.105608 is cambridge, ma
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

      ellipse(-dialRadius * 1.5f, -alt/PI*2 * dialRadius, 15, 15);

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
      rect((i+.5f) * (width-80)/6, height/2, (width-80)/6.f * .98f, height);
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
  text("T+"+nf(PApplet.parseInt(elapsed/360000.f), 2) + ":" + nf(PApplet.parseInt(elapsed/60000.f), 2) + "." + nf(PApplet.parseInt(elapsed/1000.f), 2), width-90, height-30);
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
          ellipse(s.center.x, map(house.modules[n].legs[floor(m/3)].getAct(m%3).getLengthCount(), s.min, s.max, s.center.y + s.height/2 -s.width/2, s.center.y - s.height/2 + s.width/2), s.width*.5f, s.width*.5f);
      
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
      vertex(i/powerHistory.length * width*.8f, height-100-powerHistory[i]*height/100.f);
    }  
    endShape();
  }
}

// TODO: Move PID loop to the microcontroller once hardware is set up

public class Actuator {
  public float length;
  public float goalLength;
  public float speed;
  
  public float midlength;
  
  public float maxLength;
  public float minLength;
  public float maxSpeed;
  
  public PID control;
  public float power;
  
  private float drift; 
  private float noise;
  
  public float counterFactor;
  
  public boolean simulate;
  
  Actuator(float imaxLength, float iminLength, float imaxSpeed, float counterFactor, boolean simulate){
    this.maxLength = imaxLength;
    this.minLength = iminLength;
    this.maxSpeed = imaxSpeed;
    this.counterFactor = counterFactor;
    this.simulate = simulate;
    
    if(simulate)
      this.length = (this.maxLength - this.minLength) / 2 + this.minLength;  // Default to half-extended
    else
      this.length = -1;
    
    this.midlength = (this.maxLength - this.minLength) / 2 + this.minLength;
      
    //this.length = this.minLength;
    this.goalLength = this.length;
    
    this.noise = 0;
    this.drift = 0;
    
    //this.control = new PID(.1,.00001,0,10);
    this.control = new PID(1*this.maxSpeed, .0005f*this.maxSpeed, 0.0f, 100000*this.maxSpeed);
    this.power = 0;
  }
  
  public boolean setPos(float goal) {
    if(goal > this.minLength && goal < this.maxLength) {
      this.goalLength = goal;  
      return true;
    }
    else {
      if(goal < this.minLength) this.goalLength = this.minLength;
      if(goal > this.maxLength) this.goalLength = this.maxLength;
      return false;
    }
  }
  
  public void updateLength(int count) {
    // This method gets called upon receipt of serial data with a position update
    this.length = this.minLength + count * this.counterFactor;
    // Initialize goal if this is the first data received
    if(this.goalLength == -1) this.goalLength = this.length;
  }
  public int getTargetCount() {
    return PApplet.parseInt((this.goalLength-this.minLength) / this.counterFactor);  
  }
  public int getLengthCount() {
    return PApplet.parseInt((this.length-this.minLength) / this.counterFactor);  
  }  
  
  public boolean possible(float goal) {
    if(goal > this.minLength && goal < this.maxLength)
      return true;
    else 
      return false;
  }      
  
  public void setDrift(float d) {
    this.drift = d;  
  }
  public void setNoise(float n) {
    this.noise = n;
  }
  
  public void updatePos() {
    // This should be done asynchronously when new serial data is received
    // What's below just provides simulated data and is run only if the parent leg/house is being simulated
    if(simulate) {
      this.length += this.drift;
      this.power = control.update(this.length, this.goalLength);
      if(abs(this.power) > this.maxSpeed * frameRateFactor())
        this.power = (this.power < 0 ? -1 : 1) * this.maxSpeed * frameRateFactor();
      this.power *= (1-random(0,this.noise));
      this.length += this.power;
    }
    
  }
  
  public PGraphics draw(float xscale, float yscale) {
      PGraphics i = createGraphics(PApplet.parseInt(this.maxLength * xscale * 1.2f), PApplet.parseInt(yscale * 3 * 1.2f), JAVA2D);
      i.beginDraw();
      i.smooth();
      i.colorMode(HSB);   
      // Draw max extension
      i.noFill();
      i.stroke(0,0,255); //white
      i.strokeWeight(1);
      i.rect(0, 0, this.maxLength * xscale, yscale);

      // Draw current length
      i.noStroke();
      i.fill(70,140,220);  // light green
      i.rect(0,0, this.length*xscale, yscale);

      // Draw line at goal
      i.stroke(150,140,220); // light blue
      i.strokeWeight(1);
      i.line(this.goalLength * xscale, 0, this.goalLength*xscale, 3*yscale);
      
      // Draw body outline
      i.fill(0,0,50);  // light red
      i.noStroke();
      i.rect(0,0, this.minLength * xscale, 3 * yscale);
      
      // Draw power meter
      i.pushMatrix();
      i.translate(1.5f*yscale, 1.5f*yscale);
      i.noFill();
      i.stroke(0,0,255);
      i.ellipse(0, 0, yscale*3, yscale*3);
      if(this.power < 0)
        i.fill(0,150,255);
      else
        i.fill(80,150,255);
      i.noStroke();
      pushMatrix();
      if(this.power < 0) i.scale(1,-1);
      i.arc(0, 0, yscale*3, yscale*3, PI, abs(this.power) / this.maxSpeed * PI + PI);
      popMatrix();
      
      i.endDraw();
      return i;      
  }
    
}
class Dial implements Clickable
{
  public float needlePosition;
  public float needleGoal;
  
  private float radius;
  private float min;
  private float max;
  
  public float centerX, centerY;
  public XY center;
  public boolean hovering = false;
  
  public String name;
  public DialAction onClick;
  
  PGraphics img;
  
  public ArrayList attached;
  
  Dial(float iradius, float imin, float imax, float icenterX, float icenterY, DialAction ionClick) {
    this.radius = iradius;
    this.min = imin;
    this.max = imax;
    
    this.needlePosition = 0;
    this.needleGoal = 0;

    this.center = new XY(icenterX, icenterY);
    
    this.attached = new ArrayList();
    
    this.onClick = ionClick;
    
    this.name = "";
  }
  
  public boolean inBounds(float x, float y) {
    return(this.center.distance(x, y) < this.radius); 
  }  
  
  public void click(float x, float y) {
    this.needleGoal = atan2(y-this.center.y, x-this.center.x) + PI/2;             // Move the dial
    this.onClick.act(this.center.distance(x, y) / this.radius, this.needleGoal);  // Then run the custom callback (r, theta) scaled to the dial's dimensions
  }
  
  public String getName() {
    return this.name;
  }
  
  public void setName(String s) {
    this.name = s;
  }

  
  public void setHover(boolean hov) {
    this.hovering = hov;
  }  
  
  public void attach(Rotatable e) {
    this.attached.add(e);  
  }
  
  public void draw() {
    
    // Move the needle towards the goal, finding the shortest route
    if(needleGoal - needlePosition > PI) needlePosition += 2 * PI;
    if(needleGoal - needlePosition < -PI) needlePosition -= 2 * PI;
    needlePosition += (needleGoal - needlePosition) * .5f;
    
    if(needlePosition >= 2 * PI) needlePosition -= 2 * PI;
    if(needlePosition < 0) needlePosition += 2 * PI;
 
    // Update all attached elements to rotate with this
    for(int i=0; i<attached.size(); i++) {
      ((Rotatable)attached.get(i)).setRotation(this.needlePosition);  
    }
 
    pushMatrix();
      translate(this.center.x, this.center.y);
  
      // Darken background
      fill(0,0,0, 100);
      noStroke();
      ellipse(0,0, radius * 2, radius * 2);  
      
      // Draw tick marks around the perimeter
      stroke(0,0,255);
      strokeWeight(1);
      for(int i=0; i<360; i+=5) {
        float len;
        if(i%30 == 0) len = 15;
        else if(i%15 == 0) len = 10;
        else if(i%5 == 0) len = 5;
        else len = 3;
        line(radius * cos(radians(i)), radius * sin(radians(i)), (radius-len) * cos(radians(i)), (radius-len) * sin(radians(i)));
      }
      
      // Draw heading indicator needle
     pushMatrix();
        rotate(needlePosition);
        fill(0,180,255,200);
        strokeWeight(1);
        noStroke();
        beginShape();
          vertex(radius/10, 0);
          bezierVertex(radius/10, radius/7, -radius/10,radius/7, -radius/10,0);
          vertex(0,-radius*.75f);
          vertex(radius/10, 0);
        endShape();
        
        // Draw highlight circle
        //fill(0,0,255,100);   
        //ellipse(0,-radius*.77, 30,30);      
       
        // Circle at center
        //noFill();
        //stroke(0,0,120);
        //strokeWeight(1);
        //ellipse(0,0,radius/20, radius/20);
        //line(0,-gaugeSize/40, 0,-gaugeSize*.25);
        
      popMatrix();
      
      // Draw text labels every 30 degrees
      textFont(DialNumbers);
      textAlign(CENTER);
      fill(0,0,255,180);
      
      for(int i=0; i<360; i+=30) {
        pushMatrix();
          rotate(radians(i));
          text(PApplet.parseInt(i/360.f * (max-min) + min), 0, -radius * .75f);
          
        popMatrix();  
      }
      
    popMatrix();    
  }
  
}

class ArcBar implements Clickable, Rotatable
{
  private float start, stop;
  public float position, goal;
  public float min,max;
  public float radius, thickness;
 
  public String name;
  public String labelMin, labelMax;
  
  public float offset; // Rotation
  
  public XY center;
  public boolean hovering = false;
  
  public SliderAction onClick;
  
  ArcBar(float iradius, float ithickness, float istart, float istop, float imin, float imax, float icenterX, float icenterY, SliderAction ionClick) {
    this.radius = iradius;
    this.thickness = ithickness;
    this.start = istart;
    this.stop = istop;
    this.min = imin;
    this.max = imax;
    
    this.offset = 0;
    
    this.center = new XY(icenterX, icenterY);    

    this.onClick = ionClick;
    
    this.name = "";
    
    this.labelMin = "";
    this.labelMax = "";
  }
  
  public boolean inBounds(float x, float y) {
    return(this.center.distance(x, y) < this.radius + this.thickness/2 && this.center.distance(x, y) > this.radius - this.thickness/2); 
  }  
  
  public void click(float x, float y) {
    float angle = atan2(y-this.center.y, x-this.center.x) - this.offset;
    if(angle < -2*PI) angle+=2*PI;
    if(angle > this.start - .2f && angle < this.stop + .2f) {  // If we're within the range of the slider arc
      this.goal = (angle - this.start)/(this.stop-this.start) * (this.max - this.min) + this.min;  // Update the visual goal
      this.onClick.act(this.goal);                                                                        // Run the callback function with the new goal as the parameter
    }
  }
  
  public String getName() {
    return this.name;
  }
  
  public void setName(String s) {
    this.name = s;  
  }  
  
  public void setRotation(float theta) {
    this.offset = theta;  
  }
  
  public void setHover(boolean hov) {
    this.hovering = hov;
  }  
  
  public void draw() {
    position += (goal - position) * .5f;
    if(position > max) position = max;
    if(position < min) position = min;
    
    float angle = ((position - min) / (max-min)) * (stop-start) + start;    

    pushMatrix();    
      translate(this.center.x, this.center.y);
      rotate(offset);
      
      // Draw background arc
      strokeCap(ROUND);
      noFill();
      strokeWeight(thickness);
      stroke(0,0,255,80);
      arc(0,0, radius*2, radius*2, start, stop);           
      strokeWeight(thickness * .75f);
      arc(0,0, radius*2, radius*2, start, stop);     
      
      // Draw arc from center to value
      stroke(150,0,255); 
      strokeWeight(thickness*.5f);     
      strokeCap(SQUARE);
      if(angle > (stop - start)/2 + start) {
        arc(0,0, radius*2, radius*2, (stop - start)/2 + start, angle);
      }
      else {
        arc(0,0, radius*2, radius*2, angle, (stop - start)/2 + start);        
      }
      
      // Draw tick circles
      noStroke();
      fill(0,0,40);
      for(int i=PApplet.parseInt(degrees(start)); i<=PApplet.parseInt(degrees(stop)); i+=5) {
        float len;
        if(i%90 == 0) len = thickness/3;
        else if(i%15 == 0) len = thickness/8;
        else len = thickness/20;
        ellipse(radius * cos(radians(i)), radius * sin(radians(i)), len, len);
      }       
      
      // Draw labels at each end
      textFont(DialNumbers);
      textAlign(CENTER, CENTER); 
      noStroke();     
      pushMatrix();
        rotate(stop+PI/2);        
        fill(blue);
        ellipse(0,-radius, thickness*.75f, thickness*.75f);
        fill(white);
        text(labelMax, 0,-radius);            
      popMatrix();
      pushMatrix();
        rotate(start+PI/2);
        fill(blue);
        ellipse(0,-radius, thickness*.75f, thickness*.75f);
        fill(0,0,255);
        text(labelMin, 0,-radius);            
      popMatrix();
    popMatrix();  
  }
  
}

class VSlider implements Clickable
{
  private float width, height;
  public float position, goal;
  public float min,max;
  
  public float label_size;
 
  public String name;
  public String labelMin, labelMax;
  
  public XY center;
  public boolean hovering = false;
  
  public SliderAction onClick;
  
  VSlider(float iwidth, float iheight, float imin, float imax, float icenterX, float icenterY, SliderAction ionClick) {
    this.width = iwidth;
    this.height = iheight;
    this.min = imin;
    this.max = imax;
    
    this.label_size = this.height * .1f;
    
    this.center = new XY(icenterX, icenterY);    
    
    this.onClick = ionClick;
    
    this.name = "";
    
    this.labelMin = "";
    this.labelMax = "";
  }
  
  public boolean inBounds(float x, float y) {
    return (x < this.center.x + this.width/2  && x > this.center.x - this.width/2 &&
         y < this.center.y + this.height/2 && y > this.center.y - this.height/2);    
  }
  
  public void click(float x, float y) {
    float start = this.center.y + this.height/2 - this.width/2;
    float range = this.height - 2 * this.width/2;
    float value;
    if(y < start) value = this.max;
    if(y > start+range) value = this.min;
    else value = ((start - y) / range) * (this.max - this.min) + this.min;

    this.goal = value;
    println(value);
    this.onClick.act(value);
  }
  
  public String getName() {
    return this.name;
  }
  
  public void setName(String s) {
    this.name = s;  
  }  
  
  public void setHover(boolean hov) {
    this.hovering = hov;
  }  
  
  public void draw() {
    position += (goal - position) * .5f;
    if(position > max) position = max;
    if(position < min) position = min;

    pushMatrix();    
      translate(this.center.x, this.center.y);
      float start = this.height/2 - this.width/2;
      float range = this.height - 2 * this.width/2;

      // Draw background
      rectMode(CENTER);
      //noStroke();
      stroke(0,0,255,80);
      strokeCap(ROUND);
      strokeWeight(this.width);
      line(0, this.height/2 - this.width/2, 0, -this.height/2 + this.width/2);
      strokeWeight(this.width * .75f);
      line(0, this.height/2 - this.width/2, 0, -this.height/2 + this.width/2);
//      rect(0,0, this.width, this.height);;
//      rect(0,0, this.width * .75, this.height);
      
      // Draw bar from bottom to value
      noStroke();
      fill(150,0,255);
      float barHeight = ((position - this.min) / (this.max - this.min) * range);
      rect(0, start - barHeight/2, this.width*.5f, barHeight);
      
      // Draw tick marks
      stroke(0,0,0, 120);
      strokeWeight(PApplet.parseInt(this.height/200));
      for(float i=0; i<100; i += 5) {
        float w = .1f;
        if(i%10 == 0) w = .2f;
        if(i%25 == 0) w = .4f;
        if(i%50 == 0) w = .65f;
        line(-this.width/2 * w, start - i/100*range, this.width/2 * w, start - i/100*range);
      }
      
      // Draw labels
      textFont(DialNumbers);
      textAlign(CENTER, CENTER);
      fill(80,150,150);
      noStroke();
      ellipse(0, -this.height/2 + this.width/2, this.width*.75f, this.width * .75f);
      //rect(0, -this.height/2 + this.label_size/2, this.width, this.label_size);
      fill(0,0,255);
      text(this.labelMax, 0, -this.height/2 + this.label_size/2);
      
      fill(0,150,150);
      ellipse(0, this.height/2 - this.width/2, this.width*.75f, this.width * .75f);
      //rect(0, this.height/2 - this.label_size/2, this.width, this.label_size);
      fill(0,0,255);
      text(this.labelMin, 0, this.height/2 - this.label_size/2);
     
    popMatrix();  
  }
  
}


class Button implements Clickable {
  public XY center;
  public float width;
  public float height;
  public int bgColor, fgColor, hoverColor, borderColor;
  public int borderWidth;
  public boolean transparent;
  
  public PFont font;
  
  public Action onClick;
  
  public String label;
 
  public boolean hovering;
  public boolean clicking;
  
  public PShape icon;

  Button(XY icenter, String iconpath, Action ionClick) {
    this(icenter, 0, 0, iconpath, HelveticaBold, iconpath, ionClick);
  } 
  Button(XY icenter, int iwidth, int iheight, String ilabel, Action ionClick) {
    this(icenter, iwidth, iheight, ilabel, HelveticaBold, null, ionClick);
  }
  Button(XY icenter, int iwidth, int iheight, String ilabel, PFont ifont, String iconpath, Action ionClick) {
    this.center = icenter;
    this.width =  iwidth;
    this.height = iheight;
    this.label =  ilabel;
    this.font = ifont;
    this.onClick = ionClick;
 
    this.bgColor =     black;
    this.fgColor =     white;
    this.hoverColor =  blue;
    this.borderColor = white;
    this.borderWidth = 1;
    
    this.hovering = false;
    this.clicking = false;
    
    if(iconpath != null) {
      icon = loadShape(iconpath);
      this.width = icon.width;
      this.height = icon.height;
    }
    
  }   
  
  public boolean inBounds(float x, float y) {
    return (x < this.center.x + this.width/2  && x > this.center.x - this.width/2 &&
         y < this.center.y + this.height/2 && y > this.center.y - this.height/2);    
  }
  
  public void click(float x, float y) {
    this.onClick.act(x, y);  
  }
  
  public String getName() {
    return this.label;
  }
  
  public void setName(String s) {
    this.label = s;  
  }
  
  public void setHover(boolean hov) {
    this.hovering = hov;
  }
  
  public void draw() {
    rectMode(CENTER);
    stroke(this.borderColor);
    strokeWeight(this.borderWidth);
    if(!this.hovering) {
      fill(this.bgColor);
    }
    else {
      fill(this.hoverColor);
    }
    
    rect(this.center.x, this.center.y, this.width, this.height);
    
    if(icon == null) {
      textFont(this.font);
      textAlign(CENTER, CENTER);
      fill(this.fgColor);
      text(this.label, this.center.x, this.center.y); 
    }
    else {
      shapeMode(CENTER);
      shape(icon, center.x, center.y);
    }
  }
}


interface Action {
  public void act(float x, float y);
}
interface DialAction {
  public void act(float r, float theta); // On a dial, these values will be scaled relative to the range of the dial
}
interface SliderAction {
  public void act(float value);          // This should be pre-scaled
}


public interface Clickable extends GUIElement {
  public boolean inBounds(float x, float y);
  public void click(float x, float y);  
  public void setHover(boolean hov);
}

public interface GUIElement {
  public void draw();
  public String getName();
  public void setName(String s);
}

public interface Rotatable {
  public void setRotation(float theta);
}
class GUIManager {
  ArrayList buttons, dials, arcbars, sliders;
  
  ArrayList clickables;
  
  XY clickLocation;
  boolean mouseDown;
  boolean dragging;
  
  GUIManager() {
    buttons = new ArrayList();
    dials = new ArrayList();
    arcbars = new ArrayList();
    sliders = new ArrayList();
    
    mouseDown = false;
    dragging = false;
    clickLocation = new XY(0,0);
    
    clickables = new ArrayList();
  } 
  
  public void addClickable(Clickable e) {
    this.clickables.add(e);
  }
  
  public boolean removeElement(String searchName) {
    boolean found = false;
    for(int i=0; i<this.clickables.size(); i++) {
      if(((GUIElement)this.clickables.get(i)).getName() == searchName) {
        this.clickables.remove(i);
        found = true;
      }
    } 
    return found;    
  }
  
  public boolean removeButton(String searchLabel) {
    for(int i=0; i<this.buttons.size(); i++) {
      if(((Button)this.buttons.get(i)).label == searchLabel) {
        this.buttons.remove(i);
        return true;
      }
    } 
    return false;
  }
  
  public void clearButtons() {
    this.buttons.clear();  
  }

  
  public void clearElements() {
    this.clickables.clear();  
  }
  
  public int update(int imouseX, int imouseY, boolean clicked) {
    boolean buttonClicked = false;
    int numClicked = 0;
    Clickable currentElement;
    for(int i=0; i<this.clickables.size(); i++) {
      currentElement = (Clickable)this.clickables.get(i);
      if(currentElement.inBounds(imouseX, imouseY)) {
         currentElement.setHover(true);
         if(clicked) {
           currentElement.click(imouseX, imouseY);
           buttonClicked = true;
           numClicked++;
           break;
         }  
      }
      else {
        currentElement.setHover(false);
      }
    }
    
    if(clicked && !buttonClicked) {
      if(!dragging) {
        clickLocation = new XY(imouseX, imouseY);
      }
      dragging = true;
    }
    else {
       dragging = false;
    }      
    return numClicked;
  }
  
  public void draw() {
    for(int i=0; i<this.clickables.size(); i++) {
      ((Clickable)this.clickables.get(i)).draw(); 
    }
  }
}
class House
{
  // Constants
  static final int TOP = 0;
  static final int FRONT = 1;
  static final int SIDE = 2;

  static final float FOOT_DOWN_LEVEL = 55 * MODULE_LENGTH/124;    // Height to walk above ground.
  static final float FOOT_UP_LEVEL = 35 * MODULE_LENGTH/124;      // 55- 46 
  public float footDownLevel = 55;
  public float footUpLevel = 35;
   
  static final int MANUAL_NAV = 0;
  static final int WAYPOINT_NAV = 1;
  static final int RANDOM_NAV = 2;
  
  // Geometry
  public int length;
  public int width;
  public XYZ center;
  public float angle;
  public XYZ originalCenter;
  public float heading;
  
  // Movement input
  public XYZ translationVector;
  public float translationSpeed;
  public float rotation;
  public XYZ rotationCenter;
  public boolean holdHeading = false;
  public boolean trackSun = false;
  
  public WaypointList waypoints = new WaypointList();
  public int navMode = MANUAL_NAV;
  
  private XYZ stepVector;      // These stay static for an entire step
  private float stepRotation;
  
  // For drawing the change in position/angle
  public XYZ translated;
  public float rotated;
  public boolean move = true;
  
  public Module[] modules;
  
  public int gaitState;
  public int gaitPhase;
  public int stepCount;
  public float distanceWalked = 0;
  public ArrayList breadcrumbs;
  
  static final float VERTICAL_EPSILON = .1f;    // .024
  static final float HORIZONTAL_EPSILON = .25f; // .125
  static final float ANGULAR_EPSILON = .01f;
  
  
  public String status = "";
  
  boolean simulate;
  boolean calibrate;
  
  House(XYZ icenter, float iangle, int imodules, boolean simulate) {
    this.center = new XYZ(icenter.x, icenter.y, icenter.z);  
    this.simulate = simulate;
    this.angle = iangle;
    
    // Populate with modules
    this.modules = new Module[imodules];
    float o = (this.modules.length / 2.f) - .5f;
    for(int i=0; i<imodules; i++) {
      modules[i] = new Module(new XYZ((i-o) * MODULE_LENGTH, 0, 0));
    }     
    
    // Initialize the walking gait
    this.gaitState = 0;
    this.gaitPhase = -1;
    this.translationVector = new XYZ(0,0,0);
    this.stepVector = new XYZ(0,0,0);
    this.translationSpeed = 1;
    this.rotation = 0;
    this.rotationCenter = new XYZ(0,0,0);
    
    this.calibrate = false;
    
    this.heading = 0;
    
    this.stepCount = 0;
    
    this.translated = new XYZ(0,0,0);
    this.rotated = 0;
    
    this.breadcrumbs = new ArrayList();
  }  
  
  public void update() {
    if(navMode == WAYPOINT_NAV) {
      if(waypoints.size() > 0 && center.distance(waypoints.getGoal()) < 10) {
        if(!waypoints.advance()) {
          if(waypoints.size() > 0)
            waypoints.currentGoal = 0;
          else
            gaitState = 0;
        }        
      }
      translationVector = getTranslation();
      translationSpeed = 4;
      rotation = getRotation();
    }
    else if (navMode == MANUAL_NAV) {
      if(translationSpeed < 0) translationSpeed = 0;
      translationVector = new XYZ(cos(heading),sin(heading),0);
    }
    else if (navMode == RANDOM_NAV) {
      if(random(0,1000) < 1) {
        rotation = random(-.5f,.5f);
      }
      if(random(0,1000) < 1) {
        float head = random(PI/4,3*PI/4);
        translationVector = new XYZ(cos(head), sin(head), 0);
        translationSpeed = random(0,4);
      }
    }

    translationVector.normalize();
    translationVector.scale(translationSpeed);
    
    if(holdHeading || navMode == WAYPOINT_NAV) {
      translationVector.rotate(this.angle - (navMode == WAYPOINT_NAV ? PI : PI/2));
    }
    
    translated = new XYZ(0,0,0);
    rotated = 0;
    
    if(translationVector.length() == 0 && rotation == 0) gaitState = 0;  // If no movement is specified, don't try to move!
    
    stepVector = new XYZ(translationVector);  
    stepRotation = rotation * frameRateFactor();
    
    switch(gaitState) {
      case 0:  // Stop everything!
        this.status = "House at rest.";
        for(int i=0; i<this.modules.length; i++) {
          for(int j=0; j<this.modules[i].legs.length; j++) {
            //modules[i].legs[j].setTarget(modules[i].legs[j].target);
          }
        }      
        break;
      case 1:  // Move legs up/down. Repeat this state until all legs are up or down.
        this.status = "Switching legs up/down...";
        // Copy input commands to current step parameter
        boolean allUp = true;
        boolean allDown = true;
        if(debug) println("Moving legs up/down...");
        for(int i=0; i<this.modules.length; i++) {
          for(int j=0; j<this.modules[i].legs.length; j++) {
            if(isPushingLeg(i, j, gaitPhase)){              
              if(modules[i].legs[j].foot.z < footDownLevel) {  // Down (ground) is in the +z direction
                if(modules[i].legs[j].target.z <= footDownLevel+3) {
                  XYZ move = new XYZ(0,0,VERTICAL_EPSILON);
                  move.scale(frameRateFactor());  // Slow down or speed up movement per frame based on framerate to be framerate-independent.
                  if(!modules[i].legs[j].moveTarget(move)) {
                    modules[i].legs[j].setTarget(new XYZ(modules[i].legs[j].target.x,modules[i].legs[j].target.y,footDownLevel+1), true);
                  }
                  //allDown = false;
                }
                allDown = false;
              }
            }
            else {
              // Reset center of rotation
              modules[i].legs[j].toCenter = new XYZ(modules[i].legs[j].offset);              
              if(modules[i].legs[j].foot.z > footUpLevel) {  // Up is in the -z direction
                if(modules[i].legs[j].target.z >= footUpLevel-3) {
                  XYZ move = new XYZ(0,0,-VERTICAL_EPSILON);
                  move.scale(frameRateFactor());
                  if(!modules[i].legs[j].moveTarget(move)) {
                    modules[i].legs[j].setTarget(new XYZ(modules[i].legs[j].target.x,modules[i].legs[j].target.y,footUpLevel-3), true);
                  }
                  //allUp = false;
                }
                allUp = false;
              }              
            }          
          }
        }
        if(allUp && allDown) {
          // Set new targets for legs that are up
          for(int i=0; i<this.modules.length; i++) {
            for(int j=0; j<this.modules[i].legs.length; j++) {
              int sign = j==1 ? 1 : -1;          
              if(!isPushingLeg(i, j, gaitPhase)){
                // Begin with target in the center of the leg's range of motion
                modules[i].legs[j].setTarget(new XYZ(modules[i].legs[j].middlePosition.x, modules[i].legs[j].middlePosition.y, footUpLevel-3));
              }          
            }
          }
          // Pass on to the next state
          gaitState = 2;
        }
        break;
      case 2:  // Move legs forward/backwards
        this.status = "Moving house...";
        if(debug) println("Moving legs forward/backward...");
        
        boolean stop = false;
        boolean stopFloating = false;
        boolean moveOn = true;
        XYZ delta;
        XYZ angular, orig;

        for(int i=0; i<this.modules.length; i++) {
          for(int j=0; j<this.modules[i].legs.length; j++) {
            int sign = j==1 ? 1 : -1;
            
            if(isPushingLeg(i, j, gaitPhase) || true){
              //delta = new XYZ(this.stepVector.x * -1 *sign, this.stepVector.y * -1 * sign, this.stepVector.z);
              delta = new XYZ(this.stepVector.x, this.stepVector.y, this.stepVector.z);
              
              orig = new XYZ(modules[i].legs[j].target);
              orig.rotate(modules[i].legs[j].rot);
              orig.translate(modules[i].legs[j].toCenter); // Vector from center of house to the test point
              angular = new XYZ(orig);
              angular.rotate(stepRotation * ANGULAR_EPSILON);    // Rotate that vector
              angular.subtract(orig);      // Then subtract it to find the difference and direction of the rotational component              
              
              delta.translate(angular);              
              float factor = delta.length();
              //delta.normalize();
              delta.scale(isPushingLeg(i, j, gaitPhase) ? HORIZONTAL_EPSILON : -HORIZONTAL_EPSILON);
              delta.scale(frameRateFactor());  // Slow down or speed up movement per frame based on framerate to be framerate-independent.
              
              if(stop && isPushingLeg(i, j, gaitPhase))
                delta.scale(0);  // If this leg is on the ground and one can't move, don't move this one either
              
              if(!(stopFloating && !isPushingLeg(i,j, gaitPhase)) && modules[i].legs[j].moveTarget(delta)) {
                if(!isPushingLeg(i, j, gaitPhase) || !stop)  // If this leg isn't on the ground and can still move or the legs on the ground are not stopped, don't go to the next state yet!
                  moveOn = false;
                 
                 // Move the rotational center by the linear vector
                 factor = delta.length()/factor;  // Figure out how much the linear and rotational vectors were reduced by
                 XYZ linChange = new XYZ(factor*this.stepVector.x, factor*this.stepVector.y, factor*this.stepVector.z);
                 //linChange.rotate(modules[i].legs[j].rot);
                 linChange.scale(isPushingLeg(i,j,gaitPhase) ? -1 : 1);                 
                 modules[i].legs[j].toCenter.translate(linChange);
                 
                 if(isPushingLeg(i,j, gaitPhase)) {
                   linChange.rotate(-this.angle);
                   linChange.scale(1.f/this.modules.length);
                   
                   this.translated.translate(linChange);
                   this.rotated += factor * stepRotation * ANGULAR_EPSILON / this.modules.length;
                 }
              }
              else {
                if(isPushingLeg(i, j, gaitPhase))  // If this leg is on the ground and can't move, stop all the legs that are on the ground
                  stop = true;
                else
                  stopFloating = true;
                  
                if(stopFloating && stop) moveOn = true;
              }
            }
          }
        }
        if(moveOn) {

          gaitState = 3;
        }
        break;
      case 3:
        if(debug) println("Switching phase to start again...");
        gaitPhase *= -1; // Invert phase to switch legs
        gaitState = 1;  
        stepCount++;
        break;
    }
        
    for(int i=0; i<this.modules.length; i++) {
      for(int j=0; j<this.modules[i].legs.length; j++) {
        modules[i].legs[j].update();    
      }
    }
    
    if(this.move) {
      // Update the house's position
      this.center.translate(this.translated);
      this.angle += this.rotated;
      if(this.angle > 2*PI) this.angle -= 2 * PI;
      if(this.angle < -2*PI) this.angle += 2 * PI;
    }
    //println(this.stepVector.text());
    distanceWalked += this.translated.length();
    
    if(gaitState == 3) breadcrumbs.add(new XYZ(this.center.x, this.center.y, this.center.z));
  }
  
  public void updateLegsOnly() {
    for(int i=0; i<this.modules.length; i++) {
      for(int j=0; j<this.modules[i].legs.length; j++) {
        boolean sim = true;
        if(i == 0 && j == 0) sim = false;
        modules[i].legs[j].update();    
      }
    }  
  }
  
  public XYZ getTranslation() {
    return getTranslation(new XYZ(center));
  }
  
  public XYZ getTranslation(XYZ initial) {
    if(waypoints.size() > 0) {
      XYZ goal = new XYZ(waypoints.getGoal().x, waypoints.getGoal().y, 0);
      goal.subtract(initial);
      return goal;
    }
    else return new XYZ(0,0,0);
  }
  
  public float getRotation() {
    return getRotation(angle);
  }
  
  public float getRotation(float initial) {
    XYZ toGoal = getTranslation();
    float error = (atan2(toGoal.y, toGoal.x)-PI) - initial;
    while(error <= -PI) error += 2 * PI;
    while(error >= PI) error -= 2 * PI;  
    float out = map(error, PI, -PI, 3, -3);
    if(out > .75f) out = .75f;
    if(out < -.75f) out = -.75f;
    return out;
  }
  
  public void draw(int view, float zoom) {  
    pushMatrix();
      translate(this.center.x, this.center.y);
      rotate(this.angle);
      imageMode(CENTER);
      
      scale(zoom);
      
      // Draw house outline
      rectMode(CENTER);
      fill(0,0,0);
      stroke(0,0,255);
      strokeWeight(3);
      rect(0,0,MODULE_LENGTH * modules.length, MODULE_WIDTH + 2* MODULE_WIDTH * sin(radians(30)));
      strokeWeight(1);
      noFill();
      stroke(0,0,80);
      rect(0,0,MODULE_LENGTH * modules.length, MODULE_WIDTH);
      float o = (this.modules.length / 2.f) - .5f;
      for(int i=0; i<modules.length; i++) {
        rect(MODULE_LENGTH * (i-o),0,MODULE_LENGTH, MODULE_WIDTH + 2* MODULE_WIDTH * sin(radians(30)));
      }
      stroke(0,0,255);
      strokeWeight(3);
      noFill();
      rect(0,0,MODULE_LENGTH * modules.length, MODULE_WIDTH + 2* MODULE_WIDTH * sin(radians(30)));
  
      
          // Blit images of each leg onto the house image
      for(int i=0; i<modules.length; i++) {
        for(int j=0; j<modules[i].legs.length; j++) {
          pushMatrix();
          translate(modules[i].legs[j].offset.x, modules[i].legs[j].offset.y);
          //modules[i].legs[j].draw(view, 1, isPushingLeg(i, j, gaitPhase));
          modules[i].legs[j].draw(view, 1, true);
          popMatrix();
        }
      } 
    popMatrix();
  }
  
  public PGraphics drawDebug() {
    PGraphics img = createGraphics(350, 60, P2D);
    img.beginDraw();
    img.smooth();
    img.colorMode(HSB);        
    img.fill(0,0,255);
    
    img.textAlign(LEFT, BASELINE);
    img.textFont(Courier);
     
    NumberFormat f = new DecimalFormat("+000.00;-000.00");
    NumberFormat g = new DecimalFormat("000.00");
    
    for(int i=0; i<this.modules.length; i++) {
      for(int j=0; j<2; j++) {
        if(!debugTargets) {
          img.text("(" + f.format(modules[i].legs[j].foot.x) + "," +
                     f.format(modules[i].legs[j].foot.y) + "," +
                     f.format(modules[i].legs[j].foot.z) + ")",
                     170*j, 15*(1+i));
        }
        else { 
          img.text("(" + f.format(modules[i].legs[j].target.x) + "," +
                     f.format(modules[i].legs[j].target.y) + "," +
                     f.format(modules[i].legs[j].target.z) + ")",
                     170*j, 15*(1+i));
        }
      }
    }
    
    img.textFont(HelveticaBold);
    //img.text("Step: " + this.stepCount + "\nState: " + this.gaitState  , 0, 20);
    
    img.endDraw();
    return img;
  }         

  class Module
  {
    public Leg[] legs;
    
    static final float LEG_Y_OFFSET = 7;
    public XYZ center;

    Module(XYZ icenter) {
      this.legs = new Leg[2];
      this.center = icenter;
  
      // Add one leg rotated 0, one rotated PI radians for each module, half a module width from the center    
      legs[0] = new Leg(new XYZ(icenter.x, icenter.y + MODULE_WIDTH/2 + LEG_Y_OFFSET, icenter.z), 0);
      legs[1] = new Leg(new XYZ(icenter.x, icenter.y - (MODULE_WIDTH/2 + LEG_Y_OFFSET), icenter.z), PI); 
    }
  }

public class Leg {    
      // Default actuator properties
      final float H_ACTUATOR_MIN = 70 * MODULE_LENGTH/124;      // Min length from joint at frame to center of vertical tube
      final float H_ACTUATOR_MAX = 100 * MODULE_LENGTH/124;    //100
      final float V_ACTUATOR_MIN = 5 * MODULE_LENGTH/124;      // Min length along v tube past the point where h actuators meet
      final float V_ACTUATOR_MAX = 45 * MODULE_LENGTH/124;
      final float H_ACTUATOR_SPEED = 1.5f;
      final float V_ACTUATOR_SPEED = H_ACTUATOR_SPEED / 5.f;
      
      // 20 seconds to lift
      // 6 seconds to translate forward
      
      // Define leg frame properties
      static final float FRAME_BASE = 88 * MODULE_LENGTH/124;    // Front-back distance between horizontal actuators
      static final float FRAME_HEIGHT = 88 * MODULE_LENGTH/124;  // Top-bottom distance between base and connection of vertical actuator
      static final float FRAME_SLANT = 100 * MODULE_LENGTH/124;  // Distance along vertical actuator where horizontal actuators attach
      final float FRAME_ANGLE = radians(30);   // Angle in radians frame makes with vertical
      XYZ FRAME_TOP = new XYZ(0, FRAME_HEIGHT * sin(FRAME_ANGLE), -FRAME_HEIGHT * cos(FRAME_ANGLE));
      
      // Visual constants
      static final int ACTUATOR_SPINDLE_THICKNESS = 2;
      static final int ACTUATOR_BODY_THICKNESS = 5;
      int SPINDLE_COLOR = color(0,0,255);
      int BODY_COLOR = color(0,0,150);   
      
      final float EPSILON = .1f; // Used for goal finding, NOT motion
      
      // Three actuators per leg
      Actuator frontAct, backAct, vertAct;
      
      XYZ offset;
      XYZ toCenter;
      XYZ vertex;
      XYZ foot;
      
      XYZ middlePosition;
      
      XYZ target;
      
      float rot;
      
      
      Leg(XYZ iCenter, float irot) {
        this.frontAct = new Actuator(H_ACTUATOR_MAX, H_ACTUATOR_MIN, H_ACTUATOR_SPEED, .0433f, simulate);
        this.backAct = new Actuator(H_ACTUATOR_MAX, H_ACTUATOR_MIN, H_ACTUATOR_SPEED, .0433f, simulate);
        this.vertAct = new Actuator(V_ACTUATOR_MAX, V_ACTUATOR_MIN, V_ACTUATOR_SPEED, .0111f, simulate);
        
        this.rot = irot;
        this.offset = new XYZ(iCenter);
        this.toCenter = new XYZ(offset);
        //this.toCenter.rotate(this.rot);
        
        this.vertex = this.findVertex(this.frontAct.length, this.backAct.length);
        this.foot = this.findFoot(this.frontAct.length, this.backAct.length, this.vertAct.length);
        this.target = new XYZ(this.foot);
        this.middlePosition = this.findFoot(this.frontAct.midlength, this.backAct.midlength, this.vertAct.midlength);
        
        SPINDLE_COLOR = color(0,0,255);
        BODY_COLOR = color(0,0,150);    
      }
      
      public Actuator getAct(int i) {
        switch(i) {
          case 0: return this.frontAct;
          case 1: return this.backAct;
          case 2: return this.vertAct;
          default: return null;
        }
      }
      
      public void update() {
        float[] newPos = this.IKsolve(this.target);
        if(this.possible(this.target) || true) {
          this.frontAct.setPos(newPos[0]);
          this.backAct.setPos(newPos[1]);
          this.vertAct.setPos(newPos[2]);
        }
       
        if(simulate) {
          // Invoke methods to simulate leg movement only if simulation is true
          this.frontAct.updatePos();  
          this.backAct.updatePos();
          this.vertAct.updatePos();
        }
        this.vertex = this.findVertex(this.frontAct.length, this.backAct.length);
        this.foot = this.findFoot(this.frontAct.length, this.backAct.length, this.vertAct.length);    
      }
        
      public boolean possible(XYZ t) {
        float[] newPos = this.IKsolve(new XYZ(t));
        return this.frontAct.possible(newPos[0]) && this.backAct.possible(newPos[1]) && this.vertAct.possible(newPos[2]);   
      }
      
      public boolean setTarget(XYZ t) {
        return this.setTarget(t, false);
      }
      
      public boolean setTarget(XYZ t, boolean force) {
        if(this.possible(t) || force) {
          this.target = new XYZ(t);  
          return true;
        }
        else return false;
      }
      
      public void moveTargetToFoot() {
        this.setTarget(this.findFoot(this.frontAct.length, this.backAct.length, this.vertAct.length), true);  
      }
      
      public void targetCenterUp() {
        this.setTarget(new XYZ(middlePosition.x, middlePosition.y, footUpLevel), true); 
      }
      public void targetCenterDown() {
        this.setTarget(new XYZ(middlePosition.x, middlePosition.y, footDownLevel), true);
      }
      
      public void jumpTarget(XYZ vector, float rotation) {
        this.jumpTarget(vector, 0, this.foot);  
      }
      
      public float jumpTarget(XYZ vector, float rotation, XYZ start) {
        // Finds maximum target from start position along vector
        XYZ test = new XYZ(start);
        
        XYZ linear = new XYZ(vector);
        //linear.normalize();
        // Linear vector magnitude and rotation amount should be scaled -1 to 1 coming in, so scale both by this.EPSILON to stay proportional but become a small step
        linear.scale(this.EPSILON);
        rotation *= this.EPSILON * .01f;
        println(rotation);
        linear.rotate(rot);          // Rotate linear vector to be in local coordinate system
        
        XYZ angular = new XYZ(0,0,0);
        XYZ orig;
    
        
        float moved = 0; // Count how far the target is being moved.
        
        while(possible(test) && possible(new XYZ(test.x, test.y, footUpLevel-1)) && possible(new XYZ(test.x, test.y, footDownLevel+1))) {  // As long as test is a valid target
          // Re-calculate angular component every time
          orig = new XYZ(test);
          orig.rotate(this.rot);
          orig.translate(this.toCenter); // Vector from center of house to the test point
          angular = new XYZ(orig);
          angular.rotate(rotation);    // Rotate that vector
          angular.subtract(orig);      // Then subtract it to find the difference and direction of the rotational component
          angular.rotate(this.rot);    // Rotate to be in local coordinate system
          
          test.translate(linear);    // Add a little bit in the desired direction
          test.translate(angular);
               
          moved += this.EPSILON;
        }
        test.subtract(linear); // Back up one step
        test.subtract(angular); // Back up one step    
    
        this.setTarget(test);             // And set this as the new target
        
        return moved;
      }
      
      public boolean moveTarget(XYZ e) { return this.moveTarget(e, false); }
      
      public boolean moveTarget(XYZ e, boolean force) {
        // Transform to local coordinate system
        e.rotate(this.rot);
    
        XYZ t = new XYZ(this.target.x + e.x, this.target.y + e.y, this.target.z + e.z);
        
        if(force || (possible(new XYZ(t.x, t.y, t.z)) && 
           possible(new XYZ(t.x, t.y, footUpLevel-1)) &&
           possible(new XYZ(t.x, t.y, footDownLevel+1)))) { // Make sure we can move up or down from the new position
          return setTarget(t, force);
        }
        else return false;
      }
      
      public XYZ findFoot(float front, float back, float vert) {
        XYZ vertex = this.findVertex(front, back); 
        // Calculate the coordinate of the top of the frame, use it to find the vector to the vertex, then extend by act3's length to find fo
        XYZ footVector = new XYZ(vertex);
        footVector.subtract(this.FRAME_TOP);
        footVector.scale(1 + vert / FRAME_SLANT);
        footVector.translate(FRAME_TOP);
    
        return footVector;   
      }   
    
      public XYZ findVertex(float front, float back) {
        // CORRECT FORMULA AS OF 18 OCT 2009
        XYZ vertex = new XYZ(0,0,0);
        vertex.x = -(sq(back) - sq(front) - sq(FRAME_BASE)) / (2 * FRAME_BASE);
        vertex.z = (sq(FRAME_BASE)/4 - (vertex.x*FRAME_BASE) + sq(FRAME_HEIGHT) - sq(FRAME_SLANT) + sq(front))
          / (2*FRAME_HEIGHT);
        vertex.y = sqrt(sq(front) - sq(vertex.x) - sq(vertex.z));
      
        // Now do the rotation about the x-axis by frameAngle + pi/2 radians and translate along x-axis to center on leg
        vertex.set(-(vertex.x - FRAME_BASE/2),
        (vertex.y * cos(-FRAME_ANGLE) - vertex.z * sin(-FRAME_ANGLE)),
        -(vertex.y * sin(-FRAME_ANGLE) + vertex.z * cos(-FRAME_ANGLE)));
        
        //vertex.set(vertex.x, vertex.z, vertex.y);
        return vertex;
        
      } 
      
      public float[] IKsolve(XYZ goal) {
        goal = new XYZ(goal);
        float[] lengths = new float[3];
        lengths[2] = goal.distance(this.FRAME_TOP) - this.FRAME_SLANT;
        
        goal.subtract(this.FRAME_TOP);
        goal.normalize();
        goal.scale(this.FRAME_SLANT);
        goal.translate(this.FRAME_TOP);
    
        lengths[0] = goal.distance(new XYZ(this.FRAME_BASE/2, 0, 0));
        lengths[1] = goal.distance(new XYZ(-this.FRAME_BASE/2, 0, 0));
         
        return lengths;
      }
      
      public void draw(int view, boolean pushing) {
        this.draw(view,1, pushing);  
      }
      
      public void moveActuators(float dfront, float dback, float dvert) {
        setTarget(findFoot(frontAct.length + dfront, backAct.length + dback, vertAct.length+dvert), true);
      }
      
      public void draw(int view, float zoom, boolean pushing) {
        switch (view) {
          case House.TOP:      
            pushMatrix();
              scale(zoom);  // Scale based on zoom factor   
              rotate(-this.rot);
            
              // Circles at frame vertices
              noFill();
              stroke(150,70,80);
              strokeWeight(5);
              triangle(this.FRAME_TOP.x, this.FRAME_TOP.y, -this.FRAME_BASE / 2, 0, this.FRAME_BASE / 2, 0);
              fill(150, 150, 255);
              noStroke();
              ellipse(this.FRAME_TOP.x, this.FRAME_TOP.y, 10, 10);
              ellipse(-this.FRAME_BASE / 2, 0, 10, 10);
              ellipse(this.FRAME_BASE / 2, 0, 10, 10);
              ellipse(this.vertex.x, this.vertex.y, 10, 10);    
            
              // Foot
              float zFactor = (55 - this.foot.z)/35.f + 1.5f;  // Fake Z axis scaling        
              fill(40, pushing ? 250 : 50, pushing ? 255 : 150);
              noStroke();
              ellipse(this.foot.x, this.foot.y, FOOT_DIAMETER * zFactor, FOOT_DIAMETER * zFactor);  
              fill(0,pushing ? 150 : 50,255);
              ellipse(this.foot.x, this.foot.y, 10, 10);    
              
              // Vertical Actuator spindle
              noFill();
              stroke(SPINDLE_COLOR);  
              strokeWeight(ACTUATOR_SPINDLE_THICKNESS);
              line(this.FRAME_TOP.x, this.FRAME_TOP.y, this.foot.x, this.foot.y);
            
              // Vertical actuator body
              stroke(BODY_COLOR);
              strokeWeight(ACTUATOR_BODY_THICKNESS);
              line(this.FRAME_TOP.x, this.FRAME_TOP.y, this.vertex.x, this.vertex.y);
            
              // Horizontal Actuator spindles
              stroke(SPINDLE_COLOR);   
              strokeWeight(ACTUATOR_SPINDLE_THICKNESS);
              XYZ corner1 = new XYZ(-this.FRAME_BASE / 2, 0, 0);
              XYZ corner2 = new XYZ(this.FRAME_BASE / 2, 0, 0);
              line(corner1.x, corner1.y, this.vertex.x, this.vertex.y);
              line(corner2.x, corner2.y, this.vertex.x, this.vertex.y);
            
              // Horizontal actuator bodies
              stroke(BODY_COLOR);   
              strokeWeight(ACTUATOR_BODY_THICKNESS);
              XYZ temp = new XYZ(this.vertex);
              temp.subtract(corner1);
              temp.normalize();
              temp.scale(this.H_ACTUATOR_MIN);
              temp.translate(corner1);
              line(corner1.x, corner1.y, temp.x, temp.y);
            
              temp = new XYZ(this.vertex);
              temp.subtract(corner2);
              temp.normalize();
              temp.scale(this.H_ACTUATOR_MIN);
              temp.translate(corner2);
              line(corner2.x, corner2.y, temp.x, temp.y);  
            
              // Target position
              pushMatrix();
                translate(this.target.x, this.target.y);
                stroke(0,0,255);
                strokeWeight(1);
                noFill();
                line(-4, 0, 4, 0);
                line(0, -4, 0, 4);
                ellipse(0,0, 4, 4);
                
                if(debug) {
                  // DRAWING FROM TARGET = (0,0)
                  XYZ t = new XYZ(target);
                  t.rotate(this.rot);
                  t.translate(this.toCenter);
                  t.rotate(-this.rot);
                  line(0, 0, -t.x, -t.y);
                }
              popMatrix();
            popMatrix();
            break;
          case House.FRONT:
            
            break;
            
          case House.SIDE:
            
            break;  
        }
      }
    }  

}
/*
public class Leg {    
  // Default actuator properties
  final float H_ACTUATOR_MIN = 70 * MODULE_LENGTH/124;      // Min length from joint at frame to center of vertical tube
  final float H_ACTUATOR_MAX = 100 * MODULE_LENGTH/124;    //100
  final float V_ACTUATOR_MIN = 5 * MODULE_LENGTH/124;      // Min length along v tube past the point where h actuators meet
  final float V_ACTUATOR_MAX = 45 * MODULE_LENGTH/124;
  final float H_ACTUATOR_SPEED = 1.5;
  final float V_ACTUATOR_SPEED = H_ACTUATOR_SPEED / 5.;
  
  // 20 seconds to lift
  // 6 seconds to translate forward
  
  // Define leg frame properties
  static final float FRAME_BASE = 88 * MODULE_LENGTH/124;    // Front-back distance between horizontal actuators
  static final float FRAME_HEIGHT = 88 * MODULE_LENGTH/124;  // Top-bottom distance between base and connection of vertical actuator
  static final float FRAME_SLANT = 100 * MODULE_LENGTH/124;  // Distance along vertical actuator where horizontal actuators attach
  final float FRAME_ANGLE = radians(30);   // Angle in radians frame makes with vertical
  XYZ FRAME_TOP = new XYZ(0, FRAME_HEIGHT * sin(FRAME_ANGLE), -FRAME_HEIGHT * cos(FRAME_ANGLE));
  
  // Visual constants
  static final int ACTUATOR_SPINDLE_THICKNESS = 2;
  static final int ACTUATOR_BODY_THICKNESS = 5;
  color SPINDLE_COLOR = color(0,0,255);
  color BODY_COLOR = color(0,0,150);   
  
  final float EPSILON = .1; // Used for goal finding, NOT motion
  
  // Three actuators per leg
  Actuator frontAct, backAct, vertAct;
  
  XYZ offset;
  XYZ toCenter;
  XYZ vertex;
  XYZ foot;
  
  XYZ middlePosition;
  
  XYZ target;
  
  float rot;
  
  boolean simulate;
  
  
  Leg(XYZ iCenter, float irot, boolean simulate) {
    this.simulate = simulate;
    
    this.frontAct = new Actuator(H_ACTUATOR_MAX, H_ACTUATOR_MIN, H_ACTUATOR_SPEED, .0433, simulate);
    this.backAct = new Actuator(H_ACTUATOR_MAX, H_ACTUATOR_MIN, H_ACTUATOR_SPEED, .0433, simulate);
    this.vertAct = new Actuator(V_ACTUATOR_MAX, V_ACTUATOR_MIN, V_ACTUATOR_SPEED, .0111, simulate);
    
    this.rot = irot;
    this.offset = new XYZ(iCenter);
    this.toCenter = new XYZ(offset);
    //this.toCenter.rotate(this.rot);
    
    this.vertex = this.findVertex(this.frontAct.length, this.backAct.length);
    this.foot = this.findFoot(this.frontAct.length, this.backAct.length, this.vertAct.length);
    this.target = new XYZ(this.foot);
    this.middlePosition = new XYZ(this.foot);
    
    SPINDLE_COLOR = color(0,0,255);
    BODY_COLOR = color(0,0,150);    
  }
  
  void update() {
    float[] newPos = this.IKsolve(this.target);
    if(this.possible(this.target) || true) {
      this.frontAct.setPos(newPos[0]);
      this.backAct.setPos(newPos[1]);
      this.vertAct.setPos(newPos[2]);
    }
   
    if(simulate) {
      // Invoke methods to simulate leg movement only if simulation is true
      this.frontAct.updatePos();  
      this.backAct.updatePos();
      this.vertAct.updatePos();
    }
    this.vertex = this.findVertex(this.frontAct.length, this.backAct.length);
    this.foot = this.findFoot(this.frontAct.length, this.backAct.length, this.vertAct.length);    
  }
    
  boolean possible(XYZ t) {
    float[] newPos = this.IKsolve(new XYZ(t));
    return this.frontAct.possible(newPos[0]) && this.backAct.possible(newPos[1]) && this.vertAct.possible(newPos[2]);   
  }
  
  boolean setTarget(XYZ t) {
    return this.setTarget(t, false);
  }
  
  boolean setTarget(XYZ t, boolean force) {
    if(this.possible(t) || force) {
      this.target = new XYZ(t);  
      return true;
    }
    else return false;
  }
  
  void targetCenterUp() {
    this.setTarget(new XYZ(middlePosition.x, middlePosition.y, House.FOOT_UP_LEVEL), true); 
  }
  void targetCenterDown() {
    this.setTarget(new XYZ(middlePosition.x, middlePosition.y, House.FOOT_DOWN_LEVEL), true);
  }
  
  void jumpTarget(XYZ vector, float rotation) {
    this.jumpTarget(vector, 0, this.foot);  
  }
  
  float jumpTarget(XYZ vector, float rotation, XYZ start) {
    // Finds maximum target from start position along vector
    XYZ test = new XYZ(start);
    
    XYZ linear = new XYZ(vector);
    //linear.normalize();
    // Linear vector magnitude and rotation amount should be scaled -1 to 1 coming in, so scale both by this.EPSILON to stay proportional but become a small step
    linear.scale(this.EPSILON);
    rotation *= this.EPSILON * .01;
    println(rotation);
    linear.rotate(rot);          // Rotate linear vector to be in local coordinate system
    
    XYZ angular = new XYZ(0,0,0);
    XYZ orig;

    
    float moved = 0; // Count how far the target is being moved.
    
    while(possible(test) && possible(new XYZ(test.x, test.y, House.FOOT_UP_LEVEL-1)) && possible(new XYZ(test.x, test.y, House.FOOT_DOWN_LEVEL+1))) {  // As long as test is a valid target
      // Re-calculate angular component every time
      orig = new XYZ(test);
      orig.rotate(this.rot);
      orig.translate(this.toCenter); // Vector from center of house to the test point
      angular = new XYZ(orig);
      angular.rotate(rotation);    // Rotate that vector
      angular.subtract(orig);      // Then subtract it to find the difference and direction of the rotational component
      angular.rotate(this.rot);    // Rotate to be in local coordinate system
      
      test.translate(linear);    // Add a little bit in the desired direction
      test.translate(angular);
           
      moved += this.EPSILON;
    }
    test.subtract(linear); // Back up one step
    test.subtract(angular); // Back up one step    

    this.setTarget(test);             // And set this as the new target
    
    return moved;
  }
  
  boolean moveTarget(XYZ e) {
    // Transform to local coordinate system
    e.rotate(this.rot);

    XYZ t = new XYZ(this.target.x + e.x, this.target.y + e.y, this.target.z + e.z);
    
    if(possible(new XYZ(t.x, t.y, t.z)) && 
       possible(new XYZ(t.x, t.y, House.FOOT_UP_LEVEL-1)) &&
       possible(new XYZ(t.x, t.y, House.FOOT_DOWN_LEVEL+1))) { // Make sure we can move up or down from the new position
      return setTarget(t);
    }
    else return false;
  }
  
  XYZ findFoot(float front, float back, float vert) {
    XYZ vertex = this.findVertex(front, back); 
    // Calculate the coordinate of the top of the frame, use it to find the vector to the vertex, then extend by act3's length to find fo
    XYZ footVector = new XYZ(vertex);
    footVector.subtract(this.FRAME_TOP);
    footVector.scale(1 + vert / FRAME_SLANT);
    footVector.translate(FRAME_TOP);

    return footVector;   
  }   

  XYZ findVertex(float front, float back) {
    // CORRECT FORMULA AS OF 18 OCT 2009
    XYZ vertex = new XYZ(0,0,0);
    vertex.x = -(sq(back) - sq(front) - sq(FRAME_BASE)) / (2 * FRAME_BASE);
    vertex.z = (sq(FRAME_BASE)/4 - (vertex.x*FRAME_BASE) + sq(FRAME_HEIGHT) - sq(FRAME_SLANT) + sq(front))
      / (2*FRAME_HEIGHT);
    vertex.y = sqrt(sq(front) - sq(vertex.x) - sq(vertex.z));
  
    // Now do the rotation about the x-axis by frameAngle + pi/2 radians and translate along x-axis to center on leg
    vertex.set(-(vertex.x - FRAME_BASE/2),
    (vertex.y * cos(-FRAME_ANGLE) - vertex.z * sin(-FRAME_ANGLE)),
    -(vertex.y * sin(-FRAME_ANGLE) + vertex.z * cos(-FRAME_ANGLE)));
    
    //vertex.set(vertex.x, vertex.z, vertex.y);
    return vertex;
    
  } 
  
  float[] IKsolve(XYZ goal) {
    goal = new XYZ(goal);
    float[] lengths = new float[3];
    lengths[2] = goal.distance(this.FRAME_TOP) - this.FRAME_SLANT;
    
    goal.subtract(this.FRAME_TOP);
    goal.normalize();
    goal.scale(this.FRAME_SLANT);
    goal.translate(this.FRAME_TOP);

    lengths[0] = goal.distance(new XYZ(this.FRAME_BASE/2, 0, 0));
    lengths[1] = goal.distance(new XYZ(-this.FRAME_BASE/2, 0, 0));
     
    return lengths;
  }
  
  void draw(int view, boolean pushing) {
    this.draw(view,1, pushing);  
  }
  
  void moveActuators(float dfront, float dback, float dvert) {
    setTarget(findFoot(frontAct.length + dfront, backAct.length + dback, vertAct.length+dvert), true);
  }
  
  void draw(int view, float zoom, boolean pushing) {
    switch (view) {
      case House.TOP:      
        pushMatrix();
          scale(zoom);  // Scale based on zoom factor   
          rotate(-this.rot);
        
          // Circles at frame vertices
          noFill();
          stroke(150,70,80);
          strokeWeight(5);
          triangle(this.FRAME_TOP.x, this.FRAME_TOP.y, -this.FRAME_BASE / 2, 0, this.FRAME_BASE / 2, 0);
          fill(150, 150, 255);
          noStroke();
          ellipse(this.FRAME_TOP.x, this.FRAME_TOP.y, 10, 10);
          ellipse(-this.FRAME_BASE / 2, 0, 10, 10);
          ellipse(this.FRAME_BASE / 2, 0, 10, 10);
          ellipse(this.vertex.x, this.vertex.y, 10, 10);    
        
          // Foot
          float zFactor = (House.FOOT_DOWN_LEVEL - this.foot.z)/(House.FOOT_UP_LEVEL) + 1.5;  // Fake Z axis scaling        
          fill(40, pushing ? 250 : 50, pushing ? 255 : 150);
          noStroke();
          ellipse(this.foot.x, this.foot.y, FOOT_DIAMETER * zFactor, FOOT_DIAMETER * zFactor);  
          fill(0,pushing ? 150 : 50,255);
          ellipse(this.foot.x, this.foot.y, 10, 10);    
          
          // Vertical Actuator spindle
          noFill();
          stroke(SPINDLE_COLOR);  
          strokeWeight(ACTUATOR_SPINDLE_THICKNESS);
          line(this.FRAME_TOP.x, this.FRAME_TOP.y, this.foot.x, this.foot.y);
        
          // Vertical actuator body
          stroke(BODY_COLOR);
          strokeWeight(ACTUATOR_BODY_THICKNESS);
          line(this.FRAME_TOP.x, this.FRAME_TOP.y, this.vertex.x, this.vertex.y);
        
          // Horizontal Actuator spindles
          stroke(SPINDLE_COLOR);   
          strokeWeight(ACTUATOR_SPINDLE_THICKNESS);
          XYZ corner1 = new XYZ(-this.FRAME_BASE / 2, 0, 0);
          XYZ corner2 = new XYZ(this.FRAME_BASE / 2, 0, 0);
          line(corner1.x, corner1.y, this.vertex.x, this.vertex.y);
          line(corner2.x, corner2.y, this.vertex.x, this.vertex.y);
        
          // Horizontal actuator bodies
          stroke(BODY_COLOR);   
          strokeWeight(ACTUATOR_BODY_THICKNESS);
          XYZ temp = new XYZ(this.vertex);
          temp.subtract(corner1);
          temp.normalize();
          temp.scale(this.H_ACTUATOR_MIN);
          temp.translate(corner1);
          line(corner1.x, corner1.y, temp.x, temp.y);
        
          temp = new XYZ(this.vertex);
          temp.subtract(corner2);
          temp.normalize();
          temp.scale(this.H_ACTUATOR_MIN);
          temp.translate(corner2);
          line(corner2.x, corner2.y, temp.x, temp.y);  
        
          // Target position
          pushMatrix();
            translate(this.target.x, this.target.y);
            stroke(0,0,255);
            strokeWeight(1);
            noFill();
            line(-4, 0, 4, 0);
            line(0, -4, 0, 4);
            ellipse(0,0, 4, 4);
            
            if(debug) {
              // DRAWING FROM TARGET = (0,0)
              XYZ t = new XYZ(target);
              t.rotate(this.rot);
              t.translate(this.toCenter);
              t.rotate(-this.rot);
              line(0, 0, -t.x, -t.y);
            }
          popMatrix();
        popMatrix();
        break;
      case House.FRONT:
        
        break;
        
      case House.SIDE:
        
        break;  
    }
  }
}*/
/*
class Module
{
  public Leg[] legs;
  public Leg portLeg;
  public Leg starLeg;
  
  static final float LEG_Y_OFFSET = 7;
  
  public float length;
  public float legBaseLength;
  public XYZ center;
  
  public boolean simulate;
  
  Module(XYZ icenter, boolean simulate) {
    this.legs = new Leg[2];
    this.center = icenter;
    this.simulate = simulate;

    // Add one leg rotated 0, one rotated PI radians for each module, half a module width from the center    
    legs[0] = new Leg(new XYZ(icenter.x, icenter.y + MODULE_WIDTH/2 + LEG_Y_OFFSET, icenter.z), 0);
    legs[1] = new Leg(new XYZ(icenter.x, icenter.y - (MODULE_WIDTH/2 + LEG_Y_OFFSET), icenter.z), PI); 
  }
  
  public class Leg {    
    // Default actuator properties
    final float H_ACTUATOR_MIN = 70 * MODULE_LENGTH/124;      // Min length from joint at frame to center of vertical tube
    final float H_ACTUATOR_MAX = 100 * MODULE_LENGTH/124;    //100
    final float V_ACTUATOR_MIN = 5 * MODULE_LENGTH/124;      // Min length along v tube past the point where h actuators meet
    final float V_ACTUATOR_MAX = 45 * MODULE_LENGTH/124;
    final float H_ACTUATOR_SPEED = 1.5;
    final float V_ACTUATOR_SPEED = H_ACTUATOR_SPEED / 5.;
    
    // 20 seconds to lift
    // 6 seconds to translate forward
    
    // Define leg frame properties
    static final float FRAME_BASE = 88 * MODULE_LENGTH/124;    // Front-back distance between horizontal actuators
    static final float FRAME_HEIGHT = 88 * MODULE_LENGTH/124;  // Top-bottom distance between base and connection of vertical actuator
    static final float FRAME_SLANT = 100 * MODULE_LENGTH/124;  // Distance along vertical actuator where horizontal actuators attach
    final float FRAME_ANGLE = radians(30);   // Angle in radians frame makes with vertical
    XYZ FRAME_TOP = new XYZ(0, FRAME_HEIGHT * sin(FRAME_ANGLE), -FRAME_HEIGHT * cos(FRAME_ANGLE));
    
    // Visual constants
    static final int ACTUATOR_SPINDLE_THICKNESS = 2;
    static final int ACTUATOR_BODY_THICKNESS = 5;
    color SPINDLE_COLOR = color(0,0,255);
    color BODY_COLOR = color(0,0,150);   
    
    final float EPSILON = .1; // Used for goal finding, NOT motion
    
    // Three actuators per leg
    Actuator frontAct, backAct, vertAct;
    
    XYZ offset;
    XYZ toCenter;
    XYZ vertex;
    XYZ foot;
    
    XYZ middlePosition;
    
    XYZ target;
    
    float rot;
    
    
    Leg(XYZ iCenter, float irot) {
      this.frontAct = new Actuator(H_ACTUATOR_MAX, H_ACTUATOR_MIN, H_ACTUATOR_SPEED, .0433, simulate);
      this.backAct = new Actuator(H_ACTUATOR_MAX, H_ACTUATOR_MIN, H_ACTUATOR_SPEED, .0433, simulate);
      this.vertAct = new Actuator(V_ACTUATOR_MAX, V_ACTUATOR_MIN, V_ACTUATOR_SPEED, .0111, simulate);
      
      this.rot = irot;
      this.offset = new XYZ(iCenter);
      this.toCenter = new XYZ(offset);
      //this.toCenter.rotate(this.rot);
      
      this.vertex = this.findVertex(this.frontAct.length, this.backAct.length);
      this.foot = this.findFoot(this.frontAct.length, this.backAct.length, this.vertAct.length);
      this.target = new XYZ(this.foot);
      this.middlePosition = new XYZ(this.foot);
      
      SPINDLE_COLOR = color(0,0,255);
      BODY_COLOR = color(0,0,150);    
    }
    
    void update() {
      float[] newPos = this.IKsolve(this.target);
      if(this.possible(this.target) || true) {
        this.frontAct.setPos(newPos[0]);
        this.backAct.setPos(newPos[1]);
        this.vertAct.setPos(newPos[2]);
      }
     
      if(simulate) {
        // Invoke methods to simulate leg movement only if simulation is true
        this.frontAct.updatePos();  
        this.backAct.updatePos();
        this.vertAct.updatePos();
      }
      this.vertex = this.findVertex(this.frontAct.length, this.backAct.length);
      this.foot = this.findFoot(this.frontAct.length, this.backAct.length, this.vertAct.length);    
    }
      
    boolean possible(XYZ t) {
      float[] newPos = this.IKsolve(new XYZ(t));
      return this.frontAct.possible(newPos[0]) && this.backAct.possible(newPos[1]) && this.vertAct.possible(newPos[2]);   
    }
    
    boolean setTarget(XYZ t) {
      return this.setTarget(t, false);
    }
    
    boolean setTarget(XYZ t, boolean force) {
      if(this.possible(t) || force) {
        this.target = new XYZ(t);  
        return true;
      }
      else return false;
    }
    
    void targetCenterUp() {
      this.setTarget(new XYZ(middlePosition.x, middlePosition.y, House.FOOT_UP_LEVEL), true); 
    }
    void targetCenterDown() {
      this.setTarget(new XYZ(middlePosition.x, middlePosition.y, House.FOOT_DOWN_LEVEL), true);
    }
    
    void jumpTarget(XYZ vector, float rotation) {
      this.jumpTarget(vector, 0, this.foot);  
    }
    
    float jumpTarget(XYZ vector, float rotation, XYZ start) {
      // Finds maximum target from start position along vector
      XYZ test = new XYZ(start);
      
      XYZ linear = new XYZ(vector);
      //linear.normalize();
      // Linear vector magnitude and rotation amount should be scaled -1 to 1 coming in, so scale both by this.EPSILON to stay proportional but become a small step
      linear.scale(this.EPSILON);
      rotation *= this.EPSILON * .01;
      println(rotation);
      linear.rotate(rot);          // Rotate linear vector to be in local coordinate system
      
      XYZ angular = new XYZ(0,0,0);
      XYZ orig;
  
      
      float moved = 0; // Count how far the target is being moved.
      
      while(possible(test) && possible(new XYZ(test.x, test.y, House.FOOT_UP_LEVEL-1)) && possible(new XYZ(test.x, test.y, House.FOOT_DOWN_LEVEL+1))) {  // As long as test is a valid target
        // Re-calculate angular component every time
        orig = new XYZ(test);
        orig.rotate(this.rot);
        orig.translate(this.toCenter); // Vector from center of house to the test point
        angular = new XYZ(orig);
        angular.rotate(rotation);    // Rotate that vector
        angular.subtract(orig);      // Then subtract it to find the difference and direction of the rotational component
        angular.rotate(this.rot);    // Rotate to be in local coordinate system
        
        test.translate(linear);    // Add a little bit in the desired direction
        test.translate(angular);
             
        moved += this.EPSILON;
      }
      test.subtract(linear); // Back up one step
      test.subtract(angular); // Back up one step    
  
      this.setTarget(test);             // And set this as the new target
      
      return moved;
    }
    
    boolean moveTarget(XYZ e) {
      // Transform to local coordinate system
      e.rotate(this.rot);
  
      XYZ t = new XYZ(this.target.x + e.x, this.target.y + e.y, this.target.z + e.z);
      
      if(possible(new XYZ(t.x, t.y, t.z)) && 
         possible(new XYZ(t.x, t.y, House.FOOT_UP_LEVEL-1)) &&
         possible(new XYZ(t.x, t.y, House.FOOT_DOWN_LEVEL+1))) { // Make sure we can move up or down from the new position
        return setTarget(t);
      }
      else return false;
    }
    
    XYZ findFoot(float front, float back, float vert) {
      XYZ vertex = this.findVertex(front, back); 
      // Calculate the coordinate of the top of the frame, use it to find the vector to the vertex, then extend by act3's length to find fo
      XYZ footVector = new XYZ(vertex);
      footVector.subtract(this.FRAME_TOP);
      footVector.scale(1 + vert / FRAME_SLANT);
      footVector.translate(FRAME_TOP);
  
      return footVector;   
    }   
  
    XYZ findVertex(float front, float back) {
      // CORRECT FORMULA AS OF 18 OCT 2009
      XYZ vertex = new XYZ(0,0,0);
      vertex.x = -(sq(back) - sq(front) - sq(FRAME_BASE)) / (2 * FRAME_BASE);
      vertex.z = (sq(FRAME_BASE)/4 - (vertex.x*FRAME_BASE) + sq(FRAME_HEIGHT) - sq(FRAME_SLANT) + sq(front))
        / (2*FRAME_HEIGHT);
      vertex.y = sqrt(sq(front) - sq(vertex.x) - sq(vertex.z));
    
      // Now do the rotation about the x-axis by frameAngle + pi/2 radians and translate along x-axis to center on leg
      vertex.set(-(vertex.x - FRAME_BASE/2),
      (vertex.y * cos(-FRAME_ANGLE) - vertex.z * sin(-FRAME_ANGLE)),
      -(vertex.y * sin(-FRAME_ANGLE) + vertex.z * cos(-FRAME_ANGLE)));
      
      //vertex.set(vertex.x, vertex.z, vertex.y);
      return vertex;
      
    } 
    
    float[] IKsolve(XYZ goal) {
      goal = new XYZ(goal);
      float[] lengths = new float[3];
      lengths[2] = goal.distance(this.FRAME_TOP) - this.FRAME_SLANT;
      
      goal.subtract(this.FRAME_TOP);
      goal.normalize();
      goal.scale(this.FRAME_SLANT);
      goal.translate(this.FRAME_TOP);
  
      lengths[0] = goal.distance(new XYZ(this.FRAME_BASE/2, 0, 0));
      lengths[1] = goal.distance(new XYZ(-this.FRAME_BASE/2, 0, 0));
       
      return lengths;
    }
    
    void draw(int view, boolean pushing) {
      this.draw(view,1, pushing);  
    }
    
    void moveActuators(float dfront, float dback, float dvert) {
      setTarget(findFoot(frontAct.length + dfront, backAct.length + dback, vertAct.length+dvert), true);
    }
    
    void draw(int view, float zoom, boolean pushing) {
      switch (view) {
        case House.TOP:      
          pushMatrix();
            scale(zoom);  // Scale based on zoom factor   
            rotate(-this.rot);
          
            // Circles at frame vertices
            noFill();
            stroke(150,70,80);
            strokeWeight(5);
            triangle(this.FRAME_TOP.x, this.FRAME_TOP.y, -this.FRAME_BASE / 2, 0, this.FRAME_BASE / 2, 0);
            fill(150, 150, 255);
            noStroke();
            ellipse(this.FRAME_TOP.x, this.FRAME_TOP.y, 10, 10);
            ellipse(-this.FRAME_BASE / 2, 0, 10, 10);
            ellipse(this.FRAME_BASE / 2, 0, 10, 10);
            ellipse(this.vertex.x, this.vertex.y, 10, 10);    
          
            // Foot
            float zFactor = (House.FOOT_DOWN_LEVEL - this.foot.z)/(House.FOOT_UP_LEVEL) + 1.5;  // Fake Z axis scaling        
            fill(40, pushing ? 250 : 50, pushing ? 255 : 150);
            noStroke();
            ellipse(this.foot.x, this.foot.y, FOOT_DIAMETER * zFactor, FOOT_DIAMETER * zFactor);  
            fill(0,pushing ? 150 : 50,255);
            ellipse(this.foot.x, this.foot.y, 10, 10);    
            
            // Vertical Actuator spindle
            noFill();
            stroke(SPINDLE_COLOR);  
            strokeWeight(ACTUATOR_SPINDLE_THICKNESS);
            line(this.FRAME_TOP.x, this.FRAME_TOP.y, this.foot.x, this.foot.y);
          
            // Vertical actuator body
            stroke(BODY_COLOR);
            strokeWeight(ACTUATOR_BODY_THICKNESS);
            line(this.FRAME_TOP.x, this.FRAME_TOP.y, this.vertex.x, this.vertex.y);
          
            // Horizontal Actuator spindles
            stroke(SPINDLE_COLOR);   
            strokeWeight(ACTUATOR_SPINDLE_THICKNESS);
            XYZ corner1 = new XYZ(-this.FRAME_BASE / 2, 0, 0);
            XYZ corner2 = new XYZ(this.FRAME_BASE / 2, 0, 0);
            line(corner1.x, corner1.y, this.vertex.x, this.vertex.y);
            line(corner2.x, corner2.y, this.vertex.x, this.vertex.y);
          
            // Horizontal actuator bodies
            stroke(BODY_COLOR);   
            strokeWeight(ACTUATOR_BODY_THICKNESS);
            XYZ temp = new XYZ(this.vertex);
            temp.subtract(corner1);
            temp.normalize();
            temp.scale(this.H_ACTUATOR_MIN);
            temp.translate(corner1);
            line(corner1.x, corner1.y, temp.x, temp.y);
          
            temp = new XYZ(this.vertex);
            temp.subtract(corner2);
            temp.normalize();
            temp.scale(this.H_ACTUATOR_MIN);
            temp.translate(corner2);
            line(corner2.x, corner2.y, temp.x, temp.y);  
          
            // Target position
            pushMatrix();
              translate(this.target.x, this.target.y);
              stroke(0,0,255);
              strokeWeight(1);
              noFill();
              line(-4, 0, 4, 0);
              line(0, -4, 0, 4);
              ellipse(0,0, 4, 4);
              
              if(debug) {
                // DRAWING FROM TARGET = (0,0)
                XYZ t = new XYZ(target);
                t.rotate(this.rot);
                t.translate(this.toCenter);
                t.rotate(-this.rot);
                line(0, 0, -t.x, -t.y);
              }
            popMatrix();
          popMatrix();
          break;
        case House.FRONT:
          
          break;
          
        case House.SIDE:
          
          break;  
      }
    }
  }  
}*/
/*
TODO:
# Look into weird z-axis behavior --> freeze targets on stopping (but not z-target)
# Enable "forcing" a moveTarget

# Move PID control to arduino board
# USB auto-detection
# USB communication
# Draw house/module bodies
# Side and front view

# TURNING - circular motion
    --> Move target normal to center (with compensation)?

# CONVERT TO PVECTORs!!!

--> Rotation is messed up for one side only, depending on turn direction.
--> Freezing feet can result in an invalid target position

*/

class PID {
  public float pK, iK, dK; // Gains
  public float pTerm, iTerm, dTerm; // Terms
  public float iMax;
  public float PIDsum; // pTerm + iTerm + kTerm
  public float error;
  
  PID(float p, float i, float d, float iMax) {
    this.pK = p;
    this.iK = i;
    this.dK = d;  
    this.iMax = iMax;
    this.error = 0;
  }
  
  public float update(float current, float goal) {
    float err = goal - current;
    this.pTerm = err * this.pK;                 // error * gain
    this.iTerm += err * this.iK;                // add error * gain
    if(abs(iTerm) > this.iMax)
      iTerm = (iTerm < 0 ? -1 : 1) * this.iMax;
    this.dTerm = (err - this.error) * this.dK;  // changeInError * gain
    this.PIDsum = this.pTerm + this.iTerm + this.dTerm;
    return this.PIDsum;
  }  
}

class XYZ
{
  NumberFormat f = new DecimalFormat("+000.00;-000.00");  
  
  public float x;
  public float y;
  public float z;
  XYZ(float ix, float iy, float iz) {
    this.x = ix;
    this.y = iy;
    this.z = iz; 
  }
  XYZ(XYZ p) {
    this.x = p.x;
    this.y = p.y;
    this.z = p.z;
  }
  
  public void set(float ix, float iy, float iz) {
    this.x = ix;
    this.y = iy;
    this.z = iz;
  }
  
  public void translate(float dx, float dy, float dz) {
    this.x += dx;
    this.y += dy;
    this.z += dz;
  }
  
  public void translate(XYZ d) {
    this.x += d.x;
    this.y += d.y;
    this.z += d.z;
  }

  public void subtract(XYZ d) {
    this.x -= d.x;
    this.y -= d.y;
    this.z -= d.z;
  }
  public void subtract(float dx, float dy, float dz) {
    this.x -= dx;
    this.y -= dy;
    this.z -= dz;
  }  
  
  public float distance(XYZ a) {
    return this.distance(this, a);  
  }
  public float distance(XYZ a, XYZ b) {
    a = new XYZ(a);
    a.subtract(b);
    return a.length();
  }
  
  public void scale(float k) {
    this.x *= k;
    this.y *= k;
    this.z *= k; 
  }
  
  public void rotate(float phi) {
    // Rotates a vector in the x-y plane about its tail (or a point about the z-axis [0,0])
    float ox = this.x;
    float oy = this.y;
    float oz = this.z;
    this.x = ox * cos(phi) + oy * sin(phi);
    this.y = oy * cos(phi) - ox * sin(phi);
    this.z = oz;
  }
  
  
  public String text() {
    return "(" + f.format(this.x) + ", " + f.format(this.y) + ", " + f.format(this.z) + ")"; 
  }
  
  public float length() {
    return sqrt(this.x*this.x + this.y*this.y + this.z*this.z);
  }
  
  public void normalize() {
    if(this.length() > 0) {
      this.scale(1/this.length());
    }
  }
  
}

class XY
{
  public float x;
  public float y;
  XY(float ix, float iy) {
    this.x = ix;
    this.y = iy; 
  }
  
  public void set(float ix, float iy) {
    this.x = ix;
    this.y = iy;
  }
  
  public float distance(float ix, float iy) {
    return sqrt(sq(ix-this.x) + sq(iy-this.y));
  }
  
  public float distance(XY p) {
    return this.distance(p.x, p.y);  
  }
}

class WaypointList extends ArrayList
{ 
  public int currentGoal = 0;
  WaypointList() {
    super();
  }
  public boolean add(XYZ o) {
    return super.add(o);  
  }
  public boolean add(float x, float y) {
    return super.add(new XYZ(x,y,0));  
  }  
  public XYZ get(int i) {
    return (XYZ)super.get(i);  
  }
  
  public boolean advance() {
    if(currentGoal < this.size()-1) {
      this.currentGoal++;
      return true;
    }
    else return false;
  }
  
  public XYZ getGoal() {
    return this.get(currentGoal);  
  }
  
  public float segmentLength(int i) {
    try {
      return this.get(i).distance(this.get(i+1));  
    }
    catch (Exception e) {
      return 0;  
    }    
  }
  
  public float segmentLength() {
    return this.segmentLength(currentGoal-1);
  }
}

public class ScrollEvent implements MouseWheelListener {
 public ScrollEvent() {
   addMouseWheelListener(this);
 }
 public void mouseWheelMoved(MouseWheelEvent e) {
   zoom *= (e.getWheelRotation() > 0) ? .9f : 1.1f;
 }
}

public class SunAngle {
  // Based on formulae from http://www.providence.edu/mcs/rbg/java/sungraph.htm
  
  public Calendar datetime;
  public float latitude, longitude;
  
  SunAngle(float latitude, float longitude) {
    this.datetime = Calendar.getInstance();
    
    this.latitude = latitude;
    this.longitude = longitude;
  }  
  
  SunAngle(float latitude, float longitude, int month, int date, int year, int hour, int minute, int second) {
    this.datetime = Calendar.getInstance();
    this.datetime.set(year, month-1, date, hour, minute, second);
    
    this.latitude = latitude;
    this.longitude = longitude;
  }
  
  public float getSolarHour(Calendar cal, float longitude) {
    // First, get the corresponding time in the GMT timezone
    Calendar gmt = (Calendar)cal.clone();
    gmt.add(Calendar.MILLISECOND, -cal.get(Calendar.ZONE_OFFSET));  // By subtracting the timezone offset
    gmt.add(Calendar.MILLISECOND, -cal.get(Calendar.DST_OFFSET));  // and subtracting any daylight savings offset
    
    float gmtSolarHour = gmt.get(Calendar.HOUR_OF_DAY) + gmt.get(Calendar.MINUTE)/60.f + gmt.get(Calendar.SECOND)/3600.f - 12;
    float longitudeOffset = longitude / 180 * 12;  // 180 degrees would be the other side of the world and therefore 12 hours off
    float solarHour = gmtSolarHour + longitudeOffset;
    
    while(solarHour < -12) solarHour += 24;
    
    return solarHour;
  }
  
  public float solarDeclination(int dayNumber) {
    // Returns the solar declination on the given day of the year
    return radians(23.45f) * sin(PI * (dayNumber - 81)/182.5f);  // 81 is the day of the spring equinox
  }

  public float getAltitude() {
    float t = PI/12 * getSolarHour(datetime, longitude);
    float declination = solarDeclination(datetime.get(Calendar.DAY_OF_YEAR));
    
    // Now the big equation...
    return asin(sin(radians(latitude))*sin(declination) + cos(radians(latitude))*cos(declination)*cos(t));
  }
  
  public float getAzimuth() {    
    float t = PI/12 * getSolarHour(datetime, longitude);
    float declination = solarDeclination(datetime.get(Calendar.DAY_OF_YEAR));
    
    // Now the big equation...
    float offset = (cos(radians(latitude))*sin(declination) - sin(radians(latitude))*cos(declination)*cos(t)) > 0 ? PI : 0;
    return offset +  atan(cos(declination) * sin(t) / (cos(radians(latitude))*sin(declination) - sin(radians(latitude))*cos(declination)*cos(t)));
  }  
}

public float frameRateFactor() {
  return BASE_FRAMERATE / frameRate;  
}


public boolean isPushingLeg(int i, int j, int phase) {
  if(((i+j) % 2 == 0 && phase == -1) || ((i+j) % 2 != 0 && phase == 1)) {
    return true;
  }
  else {
    return false;
  }
}

public XYZ screenToWorldCoords(float x, float y) {
  XYZ temp = new XYZ(x, y, 0);
  temp.x = (x-width/2)/zoom;
  temp.y = (y-height/2)/zoom;
  
  temp.rotate(viewRotation);
  
  temp.x -= (viewCenter.x - width/2);
  temp.y -= (viewCenter.y - height/2);
  
  return temp;
 
  /*
    The forward transform:
    ----------------------
    translate(width/2, height/2);
    rotate(viewRotation);
    translate(-width/2, -height/2);
    translate((viewCenter.x-width/2)*zoom, (viewCenter.y-height/2)*zoom);     
    scale(zoom);
    translate(width/2/zoom, height/2/zoom);
    */
}

public void moveViewDown() {
  viewCenter.x -= 5/zoom * sin(viewRotation);
  viewCenter.y -= 5/zoom * cos(viewRotation);  
  follow = false;
}
public void moveViewUp() {
  viewCenter.x += 5/zoom * sin(viewRotation);
  viewCenter.y += 5/zoom * cos(viewRotation);  
  follow = false;
}
public void moveViewRight() {
  viewCenter.x -= 5/zoom * cos(viewRotation);
  viewCenter.y += 5/zoom * sin(viewRotation);  
  follow = false;
}
public void moveViewLeft() {
  viewCenter.x += 5/zoom * cos(viewRotation);
  viewCenter.y -= 5/zoom * sin(viewRotation);  
  follow = false;
}
static final int SINGLE_ACT  = 1;
static final int SINGLE_LEG  = 2;
static final int WHOLE_HOUSE = 3;
static final int ALL_ACTS = 4;

int configLegi = -1;
int configLegj = -1;
int calibrateMode = 1;

public void homeMenu() {
  viewMode = DRIVE_VIEW;
  house.navMode = House.MANUAL_NAV;
  house.gaitState = 0;              // Stop the house moving when you go to this mode
  follow = true;
  zoom = 1;
  GUI.clearElements();
  
  Button walkButton = new Button(new XY(100, 50), 200, 50, "WALK", new Action() { public void act(float x, float y) { house.gaitState = 1; } });
  Button stopButton = new Button(new XY(100, 100), 200, 50, "STOP", new Action() { public void act(float x, float y) { house.gaitState = 0; } });

  Dial  headingDial = new Dial(120, 0, 360, width/2, height/2, new DialAction() {
                                public void act(float r, float theta) {
                                  house.heading = theta;
                                  //house.translationSpeed  = r;
                                } });
  ArcBar turnRateBar = new ArcBar(140, 40, -5*PI/6, -PI/6, -1, 1, headingDial.center.x, headingDial.center.y, new SliderAction() {
                                  public void act(float value) {
                                    house.rotation = value;
                                  }
                                });
  turnRateBar.labelMin = "L";
  turnRateBar.labelMax = "R";
  turnRateBar.goal = house.rotation;
  headingDial.needleGoal = house.heading;
  
  VSlider speedSlider = new VSlider(40, 350, 0, 4, headingDial.center.x + headingDial.radius + 65, headingDial.center.y, new SliderAction() { public void act(float value) { house.translationSpeed = value;} });
  speedSlider.name = "SPEED";
  speedSlider.goal = house.translationSpeed;
 
  headingDial.attach(turnRateBar); // Make the heading dial and turn rate bar move together
  GUI.clickables.add(walkButton);  
  GUI.clickables.add(stopButton);
  
  GUI.clickables.add(headingDial);
  if(!house.trackSun) {
    GUI.clickables.add(turnRateBar);
  }
  GUI.clickables.add(speedSlider);
  
  addMapNavIcons();
  addModeIcons();
}

public void hiddenMenu() {
  GUI.clearElements();
  Button showButton = new Button(new XY(10, height/2), 20, height, ">", new Action() { public void act(float x, float y) { homeMenu(); } });
  GUI.clickables.add(showButton);
}

public void waypointMenu() {
  viewMode = ROUTE_VIEW;
  zoom = .5f;
  
  GUI.clearElements();
  
  Button walkButton = new Button(new XY(100, 50), 200, 50, "WALK", new Action() { public void act(float x, float y) { house.navMode = House.WAYPOINT_NAV; house.gaitState = 1; } });
  Button stopButton = new Button(new XY(100, 100), 200, 50, "STOP", new Action() { public void act(float x, float y) { house.gaitState = 0; } });
  
  Button mapButton = new Button(new XY(width/2, height/2), width, height, " ", new Action() { public void act(float x, float y) {
    house.waypoints.add(screenToWorldCoords(x,y));
  } });
  
  mapButton.bgColor = color(0,0,255,0);
  mapButton.fgColor = color(0,0,0,0);
  mapButton.hoverColor = color(0,0,255,0);
  mapButton.borderWidth = 0;
  mapButton.borderColor = color(0,0,255,0);
  
  GUI.clickables.add(walkButton);  
  GUI.clickables.add(stopButton);
  
  addModeIcons();
  addMapNavIcons();
  
  GUI.clickables.add(mapButton);  
}

public void sunMenu() {
  viewMode = SUN_VIEW;
  GUI.clearElements();

  addModeIcons();  
}

public void configMenu() {
  GUI.clearElements();
  Button calibrateButton = new Button(new XY(width/2, 150), 300, 50, "CALIBRATE", new Action() { public void act(float x, float y) { house.calibrate = true; calibrateMenu(ALL_ACTS); } } ); 
  Button moveLegButton = new Button(new XY(width/2, 200), 300, 50, "MOVE LEG", new Action() { public void act(float x, float y) { house.calibrate = true; calibrateMenu(SINGLE_LEG); } } ); 
  Button stepheightButton = new Button(new XY(width/2, 250), 300, 50, "STEP HEIGHT", new Action() { public void act(float x, float y) { stepHeightMenu(); } } );
 
  Button exitButton = new Button(new XY(width/2, 350), 300, 50, "EXIT", new Action() { public void act(float x, float y) { exit(); } } ); 
  
  GUI.clickables.add(calibrateButton);
  GUI.clickables.add(moveLegButton);
  GUI.clickables.add(stepheightButton);
  
  GUI.clickables.add(exitButton);
  
  addModeIcons();
}

public void stepHeightMenu() {
    GUI.clearElements();
    Button bigButton = new Button(new XY(width/2 , 80), 230, 40, "BIGGER", new Action() { public void act(float x, float y) { house.footUpLevel -= 1; } }); 
    Button smallButton = new Button(new XY(width/2, 120), 230, 40, "SMALLER", new Action() { public void act(float x, float y) { house.footUpLevel += 1; } });  
     
    Button highButton = new Button(new XY(width/2 , 180), 230, 40, "HIGHER", new Action() { public void act(float x, float y) { house.footUpLevel += .5f; house.footDownLevel += .5f;} }); 
    Button lowButton = new Button(new XY(width/2, 220), 230, 40, "LOWER", new Action() { public void act(float x, float y) { house.footUpLevel -= .5f; house.footDownLevel -= .5f; } });  
    
    Button resetButton = new Button(new XY(width/2, 280), 230, 40, "RESET", new Action() { public void act(float x, float y) { house.footUpLevel = 35; house.footDownLevel = 55; } });  
     
    GUI.clickables.add(bigButton);
    GUI.clickables.add(smallButton);
    GUI.clickables.add(highButton);
    GUI.clickables.add(lowButton);
    GUI.clickables.add(resetButton);
  
    addModeIcons();
}

public void setConfigLeg(int i, int j) {
  configLegi = i;
  configLegj = j;  
}

public void calibrateMenu() { calibrateMenu(calibrateMode); }

public void calibrateMenu(int mode) {
  calibrateMode = mode;
  GUI.clearElements();
  
  viewMode = DRIVE_VIEW;
  house.navMode = House.MANUAL_NAV;
  house.gaitState = 0;       
  
  if(calibrateMode == SINGLE_ACT || calibrateMode == SINGLE_LEG) {
     Button oneButton  = new Button(new XY(width/2-125, height-25), 50, 50, "1", new Action() { public void act(float x, float y) { setConfigLeg(0,0); calibrateMenu(); } } ); 
     Button twoButton   = new Button(new XY(width/2-75, height-25), 50, 50, "2", new Action() { public void act(float x, float y) { setConfigLeg(0,1); calibrateMenu(); } } ); 
     Button threeButton   = new Button(new XY(width/2-25, height-25), 50, 50, "3", new Action() { public void act(float x, float y) { setConfigLeg(1,0); calibrateMenu(); } } ); 
     Button fourButton = new Button(new XY(width/2+25, height-25), 50, 50, "4", new Action() { public void act(float x, float y) { setConfigLeg(1,1); calibrateMenu(); } } ); 
     Button fiveButton  = new Button(new XY(width/2+75, height-25), 50, 50, "5", new Action() { public void act(float x, float y) { setConfigLeg(2,0); calibrateMenu(); } } ); 
     Button sixButton  = new Button(new XY(width/2+125, height-25), 50, 50, "6", new Action() { public void act(float x, float y) { setConfigLeg(2,1); calibrateMenu(); } } ); 
     
  
     GUI.clickables.add(oneButton);
     GUI.clickables.add(twoButton);
     GUI.clickables.add(threeButton);
     GUI.clickables.add(fourButton);
     GUI.clickables.add(fiveButton);
     GUI.clickables.add(sixButton);
     
     if(configLegi > -1) {
       if(mode == SINGLE_ACT) {
         Button frontOutButton = new Button(new XY(width/2 - 40, 200), "icons/up.svg", new Action() { public void act(float x, float y) { house.modules[configLegi].legs[configLegj].moveActuators(2,0,0); } });  
         Button frontInButton =  new Button(new XY(width/2 + 0, 200), "icons/down.svg", new Action() { public void act(float x, float y) { house.modules[configLegi].legs[configLegj].moveActuators(-2,0,0); } }); 
         Button frontZeroButton =  new Button(new XY(width/2 + 40, 200), "icons/crosshair.svg", new Action() { public void act(float x, float y) { calibrate(configLegi, configLegj * 3 + 0); } });      
         Button backOutButton =  new Button(new XY(width/2 - 40, 140), "icons/up.svg", new Action() { public void act(float x, float y) { house.modules[configLegi].legs[configLegj].moveActuators(0,2,0); } });  
         Button backInButton =   new Button(new XY(width/2 + 0, 140), "icons/down.svg", new Action() { public void act(float x, float y) { house.modules[configLegi].legs[configLegj].moveActuators(0,-2,0); } });      
         Button backZeroButton =  new Button(new XY(width/2 + 40, 140), "icons/crosshair.svg", new Action() { public void act(float x, float y) { calibrate(configLegi, configLegj * 3 + 1); } });      
         Button topOutButton =   new Button(new XY(width/2 - 40, 80), "icons/up.svg", new Action() { public void act(float x, float y) { house.modules[configLegi].legs[configLegj].moveActuators(0,0,2); } });  
         Button topInButton =    new Button(new XY(width/2 + 0, 80), "icons/down.svg", new Action() { public void act(float x, float y) { house.modules[configLegi].legs[configLegj].moveActuators(0,0,-2); } });      
         Button topZeroButton =  new Button(new XY(width/2 + 40, 80), "icons/crosshair.svg", new Action() { public void act(float x, float y) { calibrate(configLegi, configLegj * 3 + 2); } });      
         
         GUI.clickables.add(frontOutButton);
         GUI.clickables.add(frontInButton);
         GUI.clickables.add(frontZeroButton);
         GUI.clickables.add(backOutButton);
         GUI.clickables.add(backInButton);
         GUI.clickables.add(backZeroButton);
         GUI.clickables.add(topOutButton);
         GUI.clickables.add(topInButton);
         GUI.clickables.add(topZeroButton);
       }
       if(mode == SINGLE_LEG) {

         Button upButton = new Button(new XY(width/2 , 80), 130, 40, "UP", new Action() { public void act(float x, float y) { house.modules[configLegi].legs[configLegj].moveTarget(new XYZ(0, 0, -2), true); } }); 
         Button downButton = new Button(new XY(width/2, 120), 130, 40, "DWN", new Action() { public void act(float x, float y) { house.modules[configLegi].legs[configLegj].moveTarget(new XYZ(0, 0, 2), true); } }); 
         Button fwdButton = new Button(new XY(width/2, 160), 130, 40, "FWD", new Action() { public void act(float x, float y) { house.modules[configLegi].legs[configLegj].moveTarget(new XYZ(-2, 0, 0), true); } }); 
         Button bkwdButton = new Button(new XY(width/2, 200), 130, 40, "BKWD", new Action() { public void act(float x, float y) { house.modules[configLegi].legs[configLegj].moveTarget(new XYZ(2, 0, 0), true); } }); 
         Button leftButton = new Button(new XY(width/2, 240), 130, 40, "LEFT", new Action() { public void act(float x, float y) { house.modules[configLegi].legs[configLegj].moveTarget(new XYZ(0, 2, 0), true); } }); 
         Button rightButton = new Button(new XY(width/2, 280), 130, 40, "RIGHT", new Action() { public void act(float x, float y) { house.modules[configLegi].legs[configLegj].moveTarget(new XYZ(0, -2, 0), true); } }); 
         Button centerUpButton = new Button(new XY(width/2, 320), 250, 40, "REST UP", new Action() { public void act(float x, float y) { house.modules[configLegi].legs[configLegj].targetCenterUp(); } }); 
         Button centerDwnButton = new Button(new XY(width/2, 360), 250, 40, "REST DWN", new Action() { public void act(float x, float y) { house.modules[configLegi].legs[configLegj].targetCenterDown(); } }); 
         GUI.clickables.add(upButton); 
         GUI.clickables.add(downButton); 
         GUI.clickables.add(fwdButton); 
         GUI.clickables.add(bkwdButton); 
         GUI.clickables.add(leftButton); 
         GUI.clickables.add(rightButton); 
         GUI.clickables.add(centerUpButton); 
         GUI.clickables.add(centerDwnButton); 
         
       }
     }
    Button backButton = new Button(new XY(100, 50), 200, 50, "BACK", new Action() { public void act(float x, float y) { configMenu(); } } ); 
    
    GUI.clickables.add(backButton);     
  }
  else if(mode == ALL_ACTS) { 
      viewMode = ACTUATOR_VIEW;
      VSlider[] sliders = new VSlider[18];
      Button[] buttons = new Button[18];
      float groupWidth = width/controllers.length;
      sliders[00] = new VSlider(30, height*.65f, -1000, 1000, 20 + 00*(width-80)/18.f, height/2, new SliderAction() { public void act(float value) { setPosition(0,0, PApplet.parseInt(value)); } });
      sliders[01] = new VSlider(30, height*.65f, -1000, 1000, 20 + 01*(width-80)/18.f, height/2, new SliderAction() { public void act(float value) { setPosition(0,1, PApplet.parseInt(value)); } });
      sliders[02] = new VSlider(30, height*.65f, -2000, 2000, 20 + 02*(width-80)/18.f, height/2, new SliderAction() { public void act(float value) { setPosition(0,2, PApplet.parseInt(value)); } });
      sliders[03] = new VSlider(30, height*.65f, -1000, 1000, 20 + 03*(width-80)/18.f, height/2, new SliderAction() { public void act(float value) { setPosition(0,3, PApplet.parseInt(value)); } });
      sliders[04] = new VSlider(30, height*.65f, -1000, 1000, 20 + 04*(width-80)/18.f, height/2, new SliderAction() { public void act(float value) { setPosition(0,4, PApplet.parseInt(value)); } });
      sliders[05] = new VSlider(30, height*.65f, -2000, 2000, 20 + 05*(width-80)/18.f, height/2, new SliderAction() { public void act(float value) { setPosition(0,5, PApplet.parseInt(value)); } });
      sliders[06] = new VSlider(30, height*.65f, -1000, 1000, 20 + 06*(width-80)/18.f, height/2, new SliderAction() { public void act(float value) { setPosition(1,0, PApplet.parseInt(value)); } });
      sliders[07] = new VSlider(30, height*.65f, -1000, 1000, 20 + 07*(width-80)/18.f, height/2, new SliderAction() { public void act(float value) { setPosition(1,1, PApplet.parseInt(value)); } });
      sliders[8]  = new VSlider(30, height*.65f, -2000, 2000, 20 +  8*(width-80)/18.f, height/2, new SliderAction() { public void act(float value) { setPosition(1,2, PApplet.parseInt(value)); } });
      sliders[9]  = new VSlider(30, height*.65f, -1000, 1000, 20 +  9*(width-80)/18.f, height/2, new SliderAction() { public void act(float value) { setPosition(1,3, PApplet.parseInt(value)); } });
      sliders[10] = new VSlider(30, height*.65f, -1000, 1000, 20 + 10*(width-80)/18.f, height/2, new SliderAction() { public void act(float value) { setPosition(1,4, PApplet.parseInt(value)); } });
      sliders[11] = new VSlider(30, height*.65f, -2000, 2000, 20 + 11*(width-80)/18.f, height/2, new SliderAction() { public void act(float value) { setPosition(1,5, PApplet.parseInt(value)); } });
      sliders[12] = new VSlider(30, height*.65f, -1000, 1000, 20 + 12*(width-80)/18.f, height/2, new SliderAction() { public void act(float value) { setPosition(2,0, PApplet.parseInt(value)); } });
      sliders[13] = new VSlider(30, height*.65f, -1000, 1000, 20 + 13*(width-80)/18.f, height/2, new SliderAction() { public void act(float value) { setPosition(2,1, PApplet.parseInt(value)); } });
      sliders[14] = new VSlider(30, height*.65f, -2000, 2000, 20 + 14*(width-80)/18.f, height/2, new SliderAction() { public void act(float value) { setPosition(2,2, PApplet.parseInt(value)); } });
      sliders[15] = new VSlider(30, height*.65f, -1000, 1000, 20 + 15*(width-80)/18.f, height/2, new SliderAction() { public void act(float value) { setPosition(2,3, PApplet.parseInt(value)); } });
      sliders[16] = new VSlider(30, height*.65f, -1000, 1000, 20 + 16*(width-80)/18.f, height/2, new SliderAction() { public void act(float value) { setPosition(2,4, PApplet.parseInt(value)); } });
      sliders[17] = new VSlider(30, height*.65f, -2000, 2000, 20 + 17*(width-80)/18.f, height/2, new SliderAction() { public void act(float value) { setPosition(2,5, PApplet.parseInt(value)); } });  
      
      buttons[00] = new Button(new XY(20 + 00*(width-80)/18.f, 30), 40, 40, "C", new Action() { public void act(float x, float y) { calibrate(0,0); } });
      buttons[01] = new Button(new XY(20 + 01*(width-80)/18.f, 30), 40, 40, "C", new Action() { public void act(float x, float y) { calibrate(0,1); } });
      buttons[02] = new Button(new XY(20 + 02*(width-80)/18.f, 30), 40, 40, "C", new Action() { public void act(float x, float y) { calibrate(0,2); } });
      buttons[03] = new Button(new XY(20 + 03*(width-80)/18.f, 30), 40, 40, "C", new Action() { public void act(float x, float y) { calibrate(0,3); } });
      buttons[04] = new Button(new XY(20 + 04*(width-80)/18.f, 30), 40, 40, "C", new Action() { public void act(float x, float y) { calibrate(0,4); } });
      buttons[05] = new Button(new XY(20 + 05*(width-80)/18.f, 30), 40, 40, "C", new Action() { public void act(float x, float y) { calibrate(0,5); } });
      buttons[06] = new Button(new XY(20 + 06*(width-80)/18.f, 30), 40, 40, "C", new Action() { public void act(float x, float y) { calibrate(1,0); } });
      buttons[07] = new Button(new XY(20 + 07*(width-80)/18.f, 30), 40, 40, "C", new Action() { public void act(float x, float y) { calibrate(1,1); } });
      buttons[8]  = new Button(new XY(20 + 8*(width-80)/18.f, 30), 40, 40, "C", new Action() { public void act(float x, float y) { calibrate(1,2); } });
      buttons[9]  = new Button(new XY(20 + 9*(width-80)/18.f, 30), 40, 40, "C", new Action() { public void act(float x, float y) { calibrate(1,3); } });
      buttons[10] = new Button(new XY(20 + 10*(width-80)/18.f, 30), 40, 40, "C", new Action() { public void act(float x, float y) { calibrate(1,4); } });
      buttons[11] = new Button(new XY(20 + 11*(width-80)/18.f, 30), 40, 40, "C", new Action() { public void act(float x, float y) { calibrate(1,5); } });
      buttons[12] = new Button(new XY(20 + 12*(width-80)/18.f, 30), 40, 40, "C", new Action() { public void act(float x, float y) { calibrate(2,0); } });
      buttons[13] = new Button(new XY(20 + 13*(width-80)/18.f, 30), 40, 40, "C", new Action() { public void act(float x, float y) { calibrate(2,1); } });
      buttons[14] = new Button(new XY(20 + 14*(width-80)/18.f, 30), 40, 40, "C", new Action() { public void act(float x, float y) { calibrate(2,2); } });
      buttons[15] = new Button(new XY(20 + 15*(width-80)/18.f, 30), 40, 40, "C", new Action() { public void act(float x, float y) { calibrate(2,3); } });
      buttons[16] = new Button(new XY(20 + 16*(width-80)/18.f, 30), 40, 40, "C", new Action() { public void act(float x, float y) { calibrate(2,4); } });
      buttons[17] = new Button(new XY(20 + 17*(width-80)/18.f, 30), 40, 40, "C", new Action() { public void act(float x, float y) { calibrate(2,5); } });  
      
      for(int i=0; i<sliders.length; i++) {
        GUI.clickables.add(sliders[i]);
      }
      
      for(int i=0; i<buttons.length; i++) {
        GUI.clickables.add(buttons[i]);
      }       
  }
  
  switch(calibrateMode) {
    case SINGLE_ACT:
      break;
    case SINGLE_LEG:
      // Calibrate
      // +x -x +y -y +z -z
      // Center
      // TODO: Draw top/side/front/iso view of leg
      break;
    case WHOLE_HOUSE:
      break;
    default:
      break;
  }
  
  addModeIcons();
}

public void statsMenu() {
  viewMode = STATS_VIEW;
  GUI.clearElements();
  addModeIcons();
}

public void addModeIcons() {
  Button driveButton = new Button(new XY(width-40, 40), "icons/drive.svg", new Action() { public void act(float x, float y) { house.calibrate = false; homeMenu(); } });
  Button waypointsButton = new Button(new XY(width-40, 120), "icons/waypoints.svg", new Action() { public void act(float x, float y) { house.calibrate = false; waypointMenu(); } });
  Button sunButton = new Button(new XY(width-40, 200), "icons/sun.svg", new Action() { public void act(float x, float y) { house.calibrate = false; sunMenu(); } });
  Button viewsButton = new Button(new XY(width-40, 280), "icons/views.svg", new Action() { public void act(float x, float y) { } });  
  Button statsButton = new Button(new XY(width-40, 360), "icons/stats.svg", new Action() { public void act(float x, float y) { statsMenu(); } });
  Button configButton = new Button(new XY(width-40, 440), "icons/config.svg", new Action() { public void act(float x, float y) { house.calibrate = false; configMenu(); } });
  
  GUI.clickables.add(driveButton);
  GUI.clickables.add(waypointsButton);
  GUI.clickables.add(sunButton);
  GUI.clickables.add(viewsButton);
  GUI.clickables.add(statsButton);
  GUI.clickables.add(configButton);
}

public void addMapNavIcons() {
  Button leftButton = new Button(new XY(50, 390), "icons/left.svg", new Action() { public void act(float x, float y) { moveViewLeft(); } });  
  Button rightButton = new Button(new XY(130, 390), "icons/right.svg", new Action() { public void act(float x, float y) { moveViewRight(); } });
  Button centerButton = new Button(new XY(90, 390), "icons/crosshair.svg", new Action() { public void act(float x, float y) { follow = !follow; } });  
  Button upButton = new Button(new XY(90, 350), "icons/up.svg", new Action() { public void act(float x, float y) { moveViewUp(); } });  
  Button downButton = new Button(new XY(90, 430), "icons/down.svg", new Action() { public void act(float x, float y) { moveViewDown(); } }); 
  Button zoominButton = new Button(new XY(50, 350), "icons/zoomin.svg", new Action() { public void act(float x, float y) { zoom *= 1.1f; } });
  Button zoomoutButton = new Button(new XY(130, 350), "icons/zoomout.svg", new Action() { public void act(float x, float y) { zoom *= .9f; } });     
  
  Button rotateCWButton = new Button(new XY(50, 430), "icons/CW.svg", new Action() { public void act(float x, float y) { follow = false; viewRotation += PI/24;; } });
  Button rotateCCWButton = new Button(new XY(130, 430), "icons/CCW.svg", new Action() { public void act(float x, float y) { follow = false; viewRotation -= PI/24; } });     
  
  GUI.clickables.add(zoominButton);
  GUI.clickables.add(zoomoutButton);
  GUI.clickables.add(leftButton);
  GUI.clickables.add(rightButton);
  GUI.clickables.add(centerButton);
  GUI.clickables.add(upButton);
  GUI.clickables.add(downButton);
  GUI.clickables.add(rotateCWButton);
  GUI.clickables.add(rotateCCWButton);

}
public void updatePositions() {
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

public void serialEvent(Serial p) {
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
    arrayCopy(powerHistory, 1, powerHistory, 0, powerHistory.length - 1);
    String inString = auxBoard.readString();
    powerHistory[powerHistory.length-1] = Float.parseFloat(inString.substring(0, inString.length()-1));  
  }
}

public boolean calibrate(int controller, int actuator) {
  try {
    controllers[controller].write("C" + actuator + "*");
  }
  catch (Exception e) {
    println("Can't calibrate! Unable to communicate with serial port.");
  }
  return true;
}

public boolean setPosition(int controller, int actuator, int value) {
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

  static public void main(String args[]) {
    PApplet.main(new String[] { "--bgcolor=#ece9d8", "WALKINGHOUSE" });
  }
}
