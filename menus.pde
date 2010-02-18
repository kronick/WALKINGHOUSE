static final int SINGLE_ACT  = 1;
static final int SINGLE_LEG  = 2;
static final int WHOLE_HOUSE = 3;

int configLegi = -1;
int configLegj = -1;
int calibrateMode = 1;

void homeMenu() {
  viewMode = DRIVE_VIEW;
  house.navMode = House.MANUAL_NAV;
  house.gaitState = 0;              // Stop the house moving when you go to this mode
  follow = true;
  zoom = 1;
  GUI.clearElements();
  
  Button walkButton = new Button(new XY(100, 50), 200, 50, "WALK", new Action() { void act(float x, float y) { house.gaitState = 1; } });
  Button stopButton = new Button(new XY(100, 100), 200, 50, "STOP", new Action() { void act(float x, float y) { house.gaitState = 0; } });

  Dial  headingDial = new Dial(120, 0, 360, width/2, height/2, new DialAction() {
                                void act(float r, float theta) {
                                  house.heading = theta;
                                  //house.translationSpeed  = r;
                                } });
  ArcBar turnRateBar = new ArcBar(140, 40, -5*PI/6, -PI/6, -1, 1, headingDial.center.x, headingDial.center.y, new SliderAction() {
                                  void act(float value) {
                                    house.rotation = value;
                                  }
                                });
  turnRateBar.labelMin = "L";
  turnRateBar.labelMax = "R";
  turnRateBar.goal = house.rotation;
  headingDial.needleGoal = house.heading;
  
  VSlider speedSlider = new VSlider(40, 350, 0, 4, headingDial.center.x + headingDial.radius + 65, headingDial.center.y, new SliderAction() { void act(float value) { house.translationSpeed = value;} });
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

void hiddenMenu() {
  GUI.clearElements();
  Button showButton = new Button(new XY(10, height/2), 20, height, ">", new Action() { void act(float x, float y) { homeMenu(); } });
  GUI.clickables.add(showButton);
}

void waypointMenu() {
  viewMode = ROUTE_VIEW;
  zoom = .5;
  
  GUI.clearElements();
  
  Button walkButton = new Button(new XY(100, 50), 200, 50, "WALK", new Action() { void act(float x, float y) { house.navMode = House.WAYPOINT_NAV; house.gaitState = 1; } });
  Button stopButton = new Button(new XY(100, 100), 200, 50, "STOP", new Action() { void act(float x, float y) { house.gaitState = 0; } });
  
  Button mapButton = new Button(new XY(width/2, height/2), width, height, " ", new Action() { void act(float x, float y) {
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

void sunMenu() {
  viewMode = SUN_VIEW;
  GUI.clearElements();

  addModeIcons();  
}

void configMenu() {
  GUI.clearElements();
  Button calibrateButton = new Button(new XY(width/2, 50), 300, 50, "CALIBRATE", new Action() { void act(float x, float y) { calibrateMenu(1); } } ); 
  
  GUI.clickables.add(calibrateButton);
  
  addModeIcons();
}

void setConfigLeg(int i, int j) {
  configLegi = i;
  configLegj = j;  
}

void calibrateMenu() { calibrateMenu(calibrateMode); }

void calibrateMenu(int mode) {
  calibrateMode = mode;
  GUI.clearElements();
  
  viewMode = DRIVE_VIEW;
  house.navMode = House.MANUAL_NAV;
  house.gaitState = 0;       
  
  if(calibrateMode == SINGLE_ACT || calibrateMode == SINGLE_LEG) {
     Button oneButton  = new Button(new XY(width/2-125, height-25), 50, 50, "0", new Action() { void act(float x, float y) { setConfigLeg(0,0); calibrateMenu(); } } ); 
     Button twoButton   = new Button(new XY(width/2-75, height-25), 50, 50, "1", new Action() { void act(float x, float y) { setConfigLeg(0,1); calibrateMenu(); } } ); 
     Button threeButton   = new Button(new XY(width/2-25, height-25), 50, 50, "2", new Action() { void act(float x, float y) { setConfigLeg(1,0); calibrateMenu(); } } ); 
     Button fourButton = new Button(new XY(width/2+25, height-25), 50, 50, "3", new Action() { void act(float x, float y) { setConfigLeg(1,1); calibrateMenu(); } } ); 
     Button fiveButton  = new Button(new XY(width/2+75, height-25), 50, 50, "4", new Action() { void act(float x, float y) { setConfigLeg(2,0); calibrateMenu(); } } ); 
     Button sixButton  = new Button(new XY(width/2+125, height-25), 50, 50, "5", new Action() { void act(float x, float y) { setConfigLeg(2,1); calibrateMenu(); } } ); 
     
     GUI.clickables.add(oneButton);
     GUI.clickables.add(twoButton);
     GUI.clickables.add(threeButton);
     GUI.clickables.add(fourButton);
     GUI.clickables.add(fiveButton);
     GUI.clickables.add(sixButton);
     
     if(configLegi > -1) {
       if(mode == SINGLE_ACT) {
         Button frontOutButton = new Button(new XY(width/2 - 20, 80), "icons/up.svg", new Action() { void act(float x, float y) { house.modules[configLegi].legs[configLegj].frontAct.setPos(house.modules[configLegi].legs[configLegj].frontAct.length + 5); } });  
         Button frontInButton =  new Button(new XY(width/2 + 20, 80), "icons/down.svg", new Action() { void act(float x, float y) { house.modules[configLegi].legs[configLegj].frontAct.setPos(house.modules[configLegi].legs[configLegj].frontAct.length - 5); } });      
         Button backOutButton =  new Button(new XY(width/2 - 20, 140), "icons/up.svg", new Action() { void act(float x, float y) { house.modules[configLegi].legs[configLegj].backAct.setPos(house.modules[configLegi].legs[configLegj].backAct.length + 5); } });  
         Button backInButton =   new Button(new XY(width/2 + 20, 140), "icons/down.svg", new Action() { void act(float x, float y) { house.modules[configLegi].legs[configLegj].backAct.setPos(house.modules[configLegi].legs[configLegj].backAct.length - 5); } });      
         Button topOutButton =   new Button(new XY(width/2 - 20, 200), "icons/up.svg", new Action() { void act(float x, float y) { house.modules[configLegi].legs[configLegj].vertAct.setPos(house.modules[configLegi].legs[configLegj].vertAct.length + 5); } });  
         Button topInButton =    new Button(new XY(width/2 + 20, 200), "icons/down.svg", new Action() { void act(float x, float y) { house.modules[configLegi].legs[configLegj].vertAct.setPos(house.modules[configLegi].legs[configLegj].vertAct.length - 5); } });      
         
         GUI.clickables.add(frontOutButton);
         GUI.clickables.add(frontInButton);
         GUI.clickables.add(backOutButton);
         GUI.clickables.add(backInButton);
         GUI.clickables.add(topOutButton);
         GUI.clickables.add(topInButton);
       }
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
  
  Button backButton = new Button(new XY(100, 50), 200, 50, "BACK", new Action() { void act(float x, float y) { configMenu(); } } ); 
  
  GUI.clickables.add(backButton);
  
  addModeIcons();
}

void addModeIcons() {
  Button driveButton = new Button(new XY(width-40, 40), "icons/drive.svg", new Action() { void act(float x, float y) { homeMenu(); } });
  Button waypointsButton = new Button(new XY(width-40, 120), "icons/waypoints.svg", new Action() { void act(float x, float y) { waypointMenu(); } });
  Button sunButton = new Button(new XY(width-40, 200), "icons/sun.svg", new Action() { void act(float x, float y) { sunMenu(); } });
  Button viewsButton = new Button(new XY(width-40, 280), "icons/views.svg", new Action() { void act(float x, float y) { } });  
  Button statsButton = new Button(new XY(width-40, 360), "icons/stats.svg", new Action() { void act(float x, float y) { } });
  Button configButton = new Button(new XY(width-40, 440), "icons/config.svg", new Action() { void act(float x, float y) { configMenu(); } });
  
  GUI.clickables.add(driveButton);
  GUI.clickables.add(waypointsButton);
  GUI.clickables.add(sunButton);
  GUI.clickables.add(viewsButton);
  GUI.clickables.add(statsButton);
  GUI.clickables.add(configButton);
}

void addMapNavIcons() {
  Button leftButton = new Button(new XY(50, 390), "icons/left.svg", new Action() { void act(float x, float y) { moveViewLeft(); } });  
  Button rightButton = new Button(new XY(130, 390), "icons/right.svg", new Action() { void act(float x, float y) { moveViewRight(); } });
  Button centerButton = new Button(new XY(90, 390), "icons/crosshair.svg", new Action() { void act(float x, float y) { follow = !follow; } });  
  Button upButton = new Button(new XY(90, 350), "icons/up.svg", new Action() { void act(float x, float y) { moveViewUp(); } });  
  Button downButton = new Button(new XY(90, 430), "icons/down.svg", new Action() { void act(float x, float y) { moveViewDown(); } }); 
  Button zoominButton = new Button(new XY(50, 350), "icons/zoomin.svg", new Action() { void act(float x, float y) { zoom *= 1.1; } });
  Button zoomoutButton = new Button(new XY(130, 350), "icons/zoomout.svg", new Action() { void act(float x, float y) { zoom *= .9; } });     
  
  Button rotateCWButton = new Button(new XY(50, 430), "icons/CW.svg", new Action() { void act(float x, float y) { follow = false; viewRotation += PI/24;; } });
  Button rotateCCWButton = new Button(new XY(130, 430), "icons/CCW.svg", new Action() { void act(float x, float y) { follow = false; viewRotation -= PI/24; } });     
  
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
