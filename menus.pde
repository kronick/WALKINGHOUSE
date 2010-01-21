void homeMenu() {
  viewMode = MAP_VIEW;
  GUI.clearElements();
  Button walkButton = new Button(new XY(100, 50), 200, 50, "WALK", new Action() { void act(float x, float y) { house.gaitState = 1; } });
  Button stopButton = new Button(new XY(100, 100), 200, 50, "STOP", new Action() { void act(float x, float y) { house.gaitState = 0; } });
  Button absButton = new Button(new XY(50, 175), 100, 50, "ABS", new Action() { void act(float x, float y) { house.holdHeading = true; } });
  Button relButton = new Button(new XY(150, 175), 100, 50, "REL", new Action() { void act(float x, float y) { house.holdHeading = false; } });
  Button hideButton = new Button(new XY(100, 250), 200, 50, "HIDE", new Action() { void act(float x, float y) { hiddenMenu(); } });

  Button leftButton = new Button(new XY(50, 375), 50, 50, "<", new Action() { void act(float x, float y) { moveViewLeft(); } });  
  Button rightButton = new Button(new XY(150, 375), 50, 50, ">", new Action() { void act(float x, float y) { moveViewRight(); } });
  Button centerButton = new Button(new XY(100, 375), 50, 50, "O", new Action() { void act(float x, float y) { follow = !follow; } });  
  Button upButton = new Button(new XY(100, 325), 50, 50, "^", new Action() { void act(float x, float y) { moveViewUp(); } });  
  Button downButton = new Button(new XY(100, 425), 50, 50, "v", new Action() { void act(float x, float y) { moveViewDown(); } });  
  Button zoominButton = new Button(new XY(50, 325), 50, 50, "+", new Action() { void act(float x, float y) { zoom *= 1.1; } });
  Button zoomoutButton = new Button(new XY(150, 425), 50, 50, "-", new Action() { void act(float x, float y) { zoom *= .9; } });  
  
  
  Dial  headingDial = new Dial(120, 0, 360, width - 220, height/2, new DialAction() {
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
  
  VSlider speedSlider = new VSlider(40, 350, 0, 4, headingDial.center.x + headingDial.radius + 65, headingDial.center.y, new SliderAction() { void act(float value) { house.translationSpeed = value;} });
  speedSlider.name = "SPEED";
  speedSlider.goal = house.translationSpeed;
 
  headingDial.attach(turnRateBar); // Make the heading dial and turn rate bar move together
  GUI.clickables.add(walkButton);  
  GUI.clickables.add(stopButton);
  
  GUI.clickables.add(absButton);
  GUI.clickables.add(relButton);
  
  GUI.clickables.add(hideButton);
  
  GUI.clickables.add(zoominButton);
  GUI.clickables.add(zoomoutButton);
  GUI.clickables.add(leftButton);
  GUI.clickables.add(rightButton);
  GUI.clickables.add(centerButton);
  GUI.clickables.add(upButton);
  GUI.clickables.add(downButton);
  
  GUI.clickables.add(headingDial);
  GUI.clickables.add(turnRateBar);
  GUI.clickables.add(speedSlider);
}

void hiddenMenu() {
  GUI.clearElements();
  Button showButton = new Button(new XY(10, height/2), 20, height, ">", new Action() { void act(float x, float y) { homeMenu(); } });
  GUI.clickables.add(showButton);
}

void waypointMenu() {
  viewMode = ROUTE_VIEW;
  house.navMode = House.WAYPOINT_NAV;
  
  GUI.clearElements();
  Button walkButton = new Button(new XY(100, 50), 200, 50, "WALK", new Action() { void act(float x, float y) { house.gaitState = 1; } });
  Button stopButton = new Button(new XY(100, 100), 200, 50, "STOP", new Action() { void act(float x, float y) { house.gaitState = 0; } });

  Button leftButton = new Button(new XY(50, 375), 50, 50, "<", new Action() { void act(float x, float y) { moveViewLeft(); } });  
  Button rightButton = new Button(new XY(150, 375), 50, 50, ">", new Action() { void act(float x, float y) { moveViewRight(); } });
  Button centerButton = new Button(new XY(100, 375), 50, 50, "O", new Action() { void act(float x, float y) { follow = !follow; } });  
  Button upButton = new Button(new XY(100, 325), 50, 50, "^", new Action() { void act(float x, float y) { moveViewUp(); } });  
  Button downButton = new Button(new XY(100, 425), 50, 50, "v", new Action() { void act(float x, float y) { moveViewDown(); } }); 
  Button zoominButton = new Button(new XY(50, 325), 50, 50, "+", new Action() { void act(float x, float y) { zoom *= 1.1; } });
  Button zoomoutButton = new Button(new XY(150, 425), 50, 50, "-", new Action() { void act(float x, float y) { zoom *= .9; } });   
  
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
  
  GUI.clickables.add(zoominButton);
  GUI.clickables.add(zoomoutButton);
  GUI.clickables.add(leftButton);
  GUI.clickables.add(rightButton);
  GUI.clickables.add(centerButton);
  GUI.clickables.add(upButton);
  GUI.clickables.add(downButton);

  GUI.clickables.add(mapButton);  
}
