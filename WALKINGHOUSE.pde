// Viewmode constants
static final int MAP_VIEW = 1;
static final int ROUTE_VIEW = 2;
static final int HOUSE_VIEW = 3;

static final float PROCESSOR_SPEED_SCALE = 5;  //.5

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

void setup() {
  size(1280,800, JAVA2D); //800x480
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
  house = new House(new XYZ(0, 0,0), PI/2, 3);
  
  colony = new ArrayList();

  GUI = new GUIManager();
  
  viewCenter = new XYZ(width/2, height/2, 0);
  bgMap = loadImage("map.png");
  
  mWheel = new ScrollEvent();
  
  //deviance = new ArcBar(60, 20, -PI, 0, -10, 10, width/4, height/2);
  
  zeroDist = 0;
  
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
    House n = new House(new XYZ(random(-1500,1500), random(-1500,1500), 0), random(0,PI/2), (int)random(3,7));
    n.update();
    n.navMode = House.RANDOM_NAV;
    n.gaitState = 1;
    colony.add(n);
  }
  
  if(key == '1') debugTargets = false;
  if(key == '2') debugTargets = true;
  if(key == 'z') {
    XYZ a = new XYZ(house.modules[0].legs[0].offset);
    XYZ b = new XYZ(house.modules[1].legs[1].offset);
    a.translate(cos(house.modules[0].legs[0].rot) * house.modules[0].legs[0].foot.x +
                  sin(house.modules[0].legs[0].rot) * house.modules[0].legs[0].foot.y,
              cos(house.modules[0].legs[0].rot) * house.modules[0].legs[0].foot.y -
                  sin(house.modules[0].legs[0].rot) * house.modules[0].legs[0].foot.x, 0);
    b.translate(cos(house.modules[1].legs[1].rot) * house.modules[1].legs[1].foot.x +
                  sin(house.modules[1].legs[1].rot) * house.modules[1].legs[1].foot.y,
              cos(house.modules[1].legs[1].rot) * house.modules[1].legs[1].foot.y -
                  sin(house.modules[1].legs[1].rot) * house.modules[1].legs[1].foot.x, 0);  
    zeroDist = a.distance(b);  
  }
  
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
  //println(frameRate);
  // Update things and check input
  for(int i=0; i<(turbo ? 10 : 1); i++) {
    house.update();
    for(int j=0; j<colony.size(); j++) {
      ((House)colony.get(j)).update();  
    }
  }
  
  if(follow) {
    viewCenter.x -= (viewCenter.x - (width/2 - house.center.x)) * .1;
    viewCenter.y -= (viewCenter.y - (height/2-house.center.y)) * .1;
    
    float compAngle = -house.angle + PI/2;
    float viewDiff = (viewRotation - compAngle);
    if(viewDiff > PI) viewDiff -= 2*PI;
    if(viewDiff < -PI) viewDiff += 2*PI;
    println(degrees(viewDiff));
    viewRotation -= viewDiff * .05;
    while(viewRotation+PI/2 < 0) viewRotation += 2*PI;
    while(viewRotation+PI/2 > 2*PI) viewRotation -= 2*PI;
  }
  
  // Draw the house
  background(80,20,100); 
  imageMode(CENTER);
  rectMode(CENTER);
  
  pushMatrix();
    // Move view closer to view target
    //zoom -= (zoom - zoomGoal) * .1;
    //if(abs(zoom-zoomGoal) < .001) zoom = zoomGoal;
    
    // Transform to local view
    translate(width/2, height/2);
    rotate(viewRotation);
    translate(-width/2, -height/2);
    translate((viewCenter.x-width/2)*zoom, (viewCenter.y-height/2)*zoom);     
    scale(zoom);
    translate(width/2/zoom, height/2/zoom);
    
    pushMatrix();
      scale(10);
      //image(bgMap, 0,0);
    popMatrix();    
    
    noFill(); stroke(red); strokeWeight(5);
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
    if(debug) { image(house.drawDebug(), 0, 0); }  
  popMatrix();
  
  pushMatrix();
    translate(width/2, height-20);
    textAlign(CENTER, CENTER);
    textFont(Courier);
    fill(0,0,255);
    //text(house.status, 0,0);
  popMatrix();
  
  textAlign(LEFT, CENTER);
  text("Distance Walked: " + (house.distanceWalked/100) + " m", 10, 460);
  text("Steps Taken: " + house.stepCount, 10, 470);
  
  // Draw framerate counter
  textAlign(RIGHT,CENTER);
  text((new DecimalFormat("00.0")).format(frameRate) + "fps", width-10, height-10);
  
  // Draw the GUI
  GUI.draw();
}
