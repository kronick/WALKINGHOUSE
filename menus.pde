static final int SINGLE_ACT  = 1;
static final int SINGLE_LEG  = 2;
static final int WHOLE_HOUSE = 3;
static final int ALL_ACTS = 4;

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
  Button calibrateButton = new Button(new XY(width/2, 150), 300, 50, "CALIBRATE", new Action() { void act(float x, float y) { house.calibrate = true; calibrateMenu(ALL_ACTS); } } ); 
  Button moveLegButton = new Button(new XY(width/2, 200), 300, 50, "MOVE LEG", new Action() { void act(float x, float y) { house.calibrate = true; calibrateMenu(SINGLE_LEG); } } ); 
  Button stepheightButton = new Button(new XY(width/2, 250), 300, 50, "STEP HEIGHT", new Action() { void act(float x, float y) { stepHeightMenu(); } } );
 
  Button exitButton = new Button(new XY(width/2, 350), 300, 50, "EXIT", new Action() { void act(float x, float y) { exit(); } } ); 
  
  GUI.clickables.add(calibrateButton);
  GUI.clickables.add(moveLegButton);
  GUI.clickables.add(stepheightButton);
  GUI.clickables.add(exitButton);
  
  addModeIcons();
}

void stepHeightMenu() {
    GUI.clearElements();
    Button bigButton = new Button(new XY(width/2 , 80), 230, 40, "BIGGER", new Action() { void act(float x, float y) { house.footUpLevel -= 1; } }); 
    Button smallButton = new Button(new XY(width/2, 120), 230, 40, "SMALLER", new Action() { void act(float x, float y) { house.footUpLevel += 1; } });  
     
    Button highButton = new Button(new XY(width/2 , 180), 230, 40, "HIGHER", new Action() { void act(float x, float y) { house.footUpLevel += .5; house.footDownLevel += .5;} }); 
    Button lowButton = new Button(new XY(width/2, 220), 230, 40, "LOWER", new Action() { void act(float x, float y) { house.footUpLevel -= .5; house.footDownLevel -= .5; } });  
    
    Button resetButton = new Button(new XY(width/2, 280), 230, 40, "RESET", new Action() { void act(float x, float y) { house.footUpLevel = 35; house.footDownLevel = 55; } });  
     
    GUI.clickables.add(bigButton);
    GUI.clickables.add(smallButton);
    GUI.clickables.add(highButton);
    GUI.clickables.add(lowButton);
    GUI.clickables.add(resetButton);
  
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
     Button oneButton  = new Button(new XY(width/2-125, height-25), 50, 50, "1", new Action() { void act(float x, float y) { setConfigLeg(0,0); calibrateMenu(); } } ); 
     Button twoButton   = new Button(new XY(width/2-75, height-25), 50, 50, "2", new Action() { void act(float x, float y) { setConfigLeg(0,1); calibrateMenu(); } } ); 
     Button threeButton   = new Button(new XY(width/2-25, height-25), 50, 50, "3", new Action() { void act(float x, float y) { setConfigLeg(1,0); calibrateMenu(); } } ); 
     Button fourButton = new Button(new XY(width/2+25, height-25), 50, 50, "4", new Action() { void act(float x, float y) { setConfigLeg(1,1); calibrateMenu(); } } ); 
     Button fiveButton  = new Button(new XY(width/2+75, height-25), 50, 50, "5", new Action() { void act(float x, float y) { setConfigLeg(2,0); calibrateMenu(); } } ); 
     Button sixButton  = new Button(new XY(width/2+125, height-25), 50, 50, "6", new Action() { void act(float x, float y) { setConfigLeg(2,1); calibrateMenu(); } } ); 
     
  
     GUI.clickables.add(oneButton);
     GUI.clickables.add(twoButton);
     GUI.clickables.add(threeButton);
     GUI.clickables.add(fourButton);
     GUI.clickables.add(fiveButton);
     GUI.clickables.add(sixButton);
     
     if(configLegi > -1) {
       if(mode == SINGLE_ACT) {
         Button frontOutButton = new Button(new XY(width/2 - 40, 200), "icons/up.svg", new Action() { void act(float x, float y) { house.modules[configLegi].legs[configLegj].moveActuators(2,0,0); } });  
         Button frontInButton =  new Button(new XY(width/2 + 0, 200), "icons/down.svg", new Action() { void act(float x, float y) { house.modules[configLegi].legs[configLegj].moveActuators(-2,0,0); } }); 
         Button frontZeroButton =  new Button(new XY(width/2 + 40, 200), "icons/crosshair.svg", new Action() { void act(float x, float y) { calibrate(configLegi, configLegj * 3 + 0); } });      
         Button backOutButton =  new Button(new XY(width/2 - 40, 140), "icons/up.svg", new Action() { void act(float x, float y) { house.modules[configLegi].legs[configLegj].moveActuators(0,2,0); } });  
         Button backInButton =   new Button(new XY(width/2 + 0, 140), "icons/down.svg", new Action() { void act(float x, float y) { house.modules[configLegi].legs[configLegj].moveActuators(0,-2,0); } });      
         Button backZeroButton =  new Button(new XY(width/2 + 40, 140), "icons/crosshair.svg", new Action() { void act(float x, float y) { calibrate(configLegi, configLegj * 3 + 1); } });      
         Button topOutButton =   new Button(new XY(width/2 - 40, 80), "icons/up.svg", new Action() { void act(float x, float y) { house.modules[configLegi].legs[configLegj].moveActuators(0,0,2); } });  
         Button topInButton =    new Button(new XY(width/2 + 0, 80), "icons/down.svg", new Action() { void act(float x, float y) { house.modules[configLegi].legs[configLegj].moveActuators(0,0,-2); } });      
         Button topZeroButton =  new Button(new XY(width/2 + 40, 80), "icons/crosshair.svg", new Action() { void act(float x, float y) { calibrate(configLegi, configLegj * 3 + 2); } });      
         
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
         Button upButton = new Button(new XY(width/2 , 80), 130, 40, "UP", new Action() { void act(float x, float y) { house.modules[configLegi].legs[configLegj].moveTarget(new XYZ(0, 0, -2)); } }); 
         Button downButton = new Button(new XY(width/2, 120), 130, 40, "DWN", new Action() { void act(float x, float y) { house.modules[configLegi].legs[configLegj].moveTarget(new XYZ(0, 0, 2)); } }); 
         Button fwdButton = new Button(new XY(width/2, 160), 130, 40, "FWD", new Action() { void act(float x, float y) { house.modules[configLegi].legs[configLegj].moveTarget(new XYZ(-2, 0, 0)); } }); 
         Button bkwdButton = new Button(new XY(width/2, 200), 130, 40, "BKWD", new Action() { void act(float x, float y) { house.modules[configLegi].legs[configLegj].moveTarget(new XYZ(2, 0, 0)); } }); 
         Button leftButton = new Button(new XY(width/2, 240), 130, 40, "LEFT", new Action() { void act(float x, float y) { house.modules[configLegi].legs[configLegj].moveTarget(new XYZ(0, 2, 0)); } }); 
         Button rightButton = new Button(new XY(width/2, 280), 130, 40, "RIGHT", new Action() { void act(float x, float y) { house.modules[configLegi].legs[configLegj].moveTarget(new XYZ(0, -2, 0)); } }); 
         Button centerUpButton = new Button(new XY(width/2, 320), 250, 40, "REST UP", new Action() { void act(float x, float y) { house.modules[configLegi].legs[configLegj].targetCenterUp(); } }); 
         Button centerDwnButton = new Button(new XY(width/2, 360), 250, 40, "REST DWN", new Action() { void act(float x, float y) { house.modules[configLegi].legs[configLegj].targetCenterDown(); } }); 
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
    Button backButton = new Button(new XY(100, 50), 200, 50, "BACK", new Action() { void act(float x, float y) { configMenu(); } } ); 
    
    GUI.clickables.add(backButton);     
  }
  else if(mode == ALL_ACTS) { 
      viewMode = ACTUATOR_VIEW;
      VSlider[] sliders = new VSlider[18];
      Button[] buttons = new Button[18];
      float groupWidth = width/controllers.length;
      sliders[00] = new VSlider(30, height*.65, -1000, 1000, 20 + 00*(width-80)/18., height/2, new SliderAction() { void act(float value) { setPosition(0,0, int(value)); } });
      sliders[01] = new VSlider(30, height*.65, -1000, 1000, 20 + 01*(width-80)/18., height/2, new SliderAction() { void act(float value) { setPosition(0,1, int(value)); } });
      sliders[02] = new VSlider(30, height*.65, -2000, 2000, 20 + 02*(width-80)/18., height/2, new SliderAction() { void act(float value) { setPosition(0,2, int(value)); } });
      sliders[03] = new VSlider(30, height*.65, -1000, 1000, 20 + 03*(width-80)/18., height/2, new SliderAction() { void act(float value) { setPosition(0,3, int(value)); } });
      sliders[04] = new VSlider(30, height*.65, -1000, 1000, 20 + 04*(width-80)/18., height/2, new SliderAction() { void act(float value) { setPosition(0,4, int(value)); } });
      sliders[05] = new VSlider(30, height*.65, -2000, 2000, 20 + 05*(width-80)/18., height/2, new SliderAction() { void act(float value) { setPosition(0,5, int(value)); } });
      sliders[06] = new VSlider(30, height*.65, -1000, 1000, 20 + 06*(width-80)/18., height/2, new SliderAction() { void act(float value) { setPosition(1,0, int(value)); } });
      sliders[07] = new VSlider(30, height*.65, -1000, 1000, 20 + 07*(width-80)/18., height/2, new SliderAction() { void act(float value) { setPosition(1,1, int(value)); } });
      sliders[8]  = new VSlider(30, height*.65, -2000, 2000, 20 +  8*(width-80)/18., height/2, new SliderAction() { void act(float value) { setPosition(1,2, int(value)); } });
      sliders[9]  = new VSlider(30, height*.65, -1000, 1000, 20 +  9*(width-80)/18., height/2, new SliderAction() { void act(float value) { setPosition(1,3, int(value)); } });
      sliders[10] = new VSlider(30, height*.65, -1000, 1000, 20 + 10*(width-80)/18., height/2, new SliderAction() { void act(float value) { setPosition(1,4, int(value)); } });
      sliders[11] = new VSlider(30, height*.65, -2000, 2000, 20 + 11*(width-80)/18., height/2, new SliderAction() { void act(float value) { setPosition(1,5, int(value)); } });
      sliders[12] = new VSlider(30, height*.65, -1000, 1000, 20 + 12*(width-80)/18., height/2, new SliderAction() { void act(float value) { setPosition(2,0, int(value)); } });
      sliders[13] = new VSlider(30, height*.65, -1000, 1000, 20 + 13*(width-80)/18., height/2, new SliderAction() { void act(float value) { setPosition(2,1, int(value)); } });
      sliders[14] = new VSlider(30, height*.65, -2000, 2000, 20 + 14*(width-80)/18., height/2, new SliderAction() { void act(float value) { setPosition(2,2, int(value)); } });
      sliders[15] = new VSlider(30, height*.65, -1000, 1000, 20 + 15*(width-80)/18., height/2, new SliderAction() { void act(float value) { setPosition(2,3, int(value)); } });
      sliders[16] = new VSlider(30, height*.65, -1000, 1000, 20 + 16*(width-80)/18., height/2, new SliderAction() { void act(float value) { setPosition(2,4, int(value)); } });
      sliders[17] = new VSlider(30, height*.65, -2000, 2000, 20 + 17*(width-80)/18., height/2, new SliderAction() { void act(float value) { setPosition(2,5, int(value)); } });  
      
      buttons[00] = new Button(new XY(20 + 00*(width-80)/18., 30), 40, 40, "C", new Action() { void act(float x, float y) { calibrate(0,0); } });
      buttons[01] = new Button(new XY(20 + 01*(width-80)/18., 30), 40, 40, "C", new Action() { void act(float x, float y) { calibrate(0,1); } });
      buttons[02] = new Button(new XY(20 + 02*(width-80)/18., 30), 40, 40, "C", new Action() { void act(float x, float y) { calibrate(0,2); } });
      buttons[03] = new Button(new XY(20 + 03*(width-80)/18., 30), 40, 40, "C", new Action() { void act(float x, float y) { calibrate(0,3); } });
      buttons[04] = new Button(new XY(20 + 04*(width-80)/18., 30), 40, 40, "C", new Action() { void act(float x, float y) { calibrate(0,4); } });
      buttons[05] = new Button(new XY(20 + 05*(width-80)/18., 30), 40, 40, "C", new Action() { void act(float x, float y) { calibrate(0,5); } });
      buttons[06] = new Button(new XY(20 + 06*(width-80)/18., 30), 40, 40, "C", new Action() { void act(float x, float y) { calibrate(1,0); } });
      buttons[07] = new Button(new XY(20 + 07*(width-80)/18., 30), 40, 40, "C", new Action() { void act(float x, float y) { calibrate(1,1); } });
      buttons[8]  = new Button(new XY(20 + 8*(width-80)/18., 30), 40, 40, "C", new Action() { void act(float x, float y) { calibrate(1,2); } });
      buttons[9]  = new Button(new XY(20 + 9*(width-80)/18., 30), 40, 40, "C", new Action() { void act(float x, float y) { calibrate(1,3); } });
      buttons[10] = new Button(new XY(20 + 10*(width-80)/18., 30), 40, 40, "C", new Action() { void act(float x, float y) { calibrate(1,4); } });
      buttons[11] = new Button(new XY(20 + 11*(width-80)/18., 30), 40, 40, "C", new Action() { void act(float x, float y) { calibrate(1,5); } });
      buttons[12] = new Button(new XY(20 + 12*(width-80)/18., 30), 40, 40, "C", new Action() { void act(float x, float y) { calibrate(2,0); } });
      buttons[13] = new Button(new XY(20 + 13*(width-80)/18., 30), 40, 40, "C", new Action() { void act(float x, float y) { calibrate(2,1); } });
      buttons[14] = new Button(new XY(20 + 14*(width-80)/18., 30), 40, 40, "C", new Action() { void act(float x, float y) { calibrate(2,2); } });
      buttons[15] = new Button(new XY(20 + 15*(width-80)/18., 30), 40, 40, "C", new Action() { void act(float x, float y) { calibrate(2,3); } });
      buttons[16] = new Button(new XY(20 + 16*(width-80)/18., 30), 40, 40, "C", new Action() { void act(float x, float y) { calibrate(2,4); } });
      buttons[17] = new Button(new XY(20 + 17*(width-80)/18., 30), 40, 40, "C", new Action() { void act(float x, float y) { calibrate(2,5); } });  
      
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

void addModeIcons() {
  Button driveButton = new Button(new XY(width-40, 40), "icons/drive.svg", new Action() { void act(float x, float y) { house.calibrate = false; homeMenu(); } });
  Button waypointsButton = new Button(new XY(width-40, 120), "icons/waypoints.svg", new Action() { void act(float x, float y) { house.calibrate = false; waypointMenu(); } });
  Button sunButton = new Button(new XY(width-40, 200), "icons/sun.svg", new Action() { void act(float x, float y) { house.calibrate = false; sunMenu(); } });
  Button viewsButton = new Button(new XY(width-40, 280), "icons/views.svg", new Action() { void act(float x, float y) { } });  
  Button statsButton = new Button(new XY(width-40, 360), "icons/stats.svg", new Action() { void act(float x, float y) { } });
  Button configButton = new Button(new XY(width-40, 440), "icons/config.svg", new Action() { void act(float x, float y) { house.calibrate = false; configMenu(); } });
  
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
