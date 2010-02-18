class House
{
  // Constants
  static final int TOP = 0;
  static final int FRONT = 1;
  static final int SIDE = 2;
  static final float FOOT_DOWN_LEVEL = 50 * MODULE_LENGTH/124;    // Height to walk above ground.
  static final float FOOT_UP_LEVEL = 46 * MODULE_LENGTH/124;      // 55- 46  
  
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
  
  static final float VERTICAL_EPSILON = .125 * PROCESSOR_SPEED_SCALE;    // .024
  static final float HORIZONTAL_EPSILON = .125 * PROCESSOR_SPEED_SCALE; // .125
  
  public String status = "";
  
  boolean simulate;
  
  House(XYZ icenter, float iangle, int imodules, boolean simulate) {
    this.center = new XYZ(icenter.x, icenter.y, icenter.z);  
    
    // Populate with modules
    this.modules = new Module[imodules];
    float o = (this.modules.length / 2.) - .5;
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
    
    this.simulate = simulate;
    
    this.heading = 0;
    
    this.stepCount = 0;
    
    this.angle = iangle;
    
    this.translated = new XYZ(0,0,0);
    this.rotated = 0;
    
    this.breadcrumbs = new ArrayList();
  }  
  
  void update() {
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
        rotation = random(-.5,.5);
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
    stepRotation = rotation;
    
    switch(gaitState) {
      case 0:  // Stop everything!
        this.status = "House at rest.";
        for(int i=0; i<this.modules.length; i++) {
          for(int j=0; j<this.modules[i].legs.length; j++) {
            modules[i].legs[j].setTarget(modules[i].legs[j].target);
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
              if(modules[i].legs[j].foot.z < FOOT_DOWN_LEVEL) {  // Down (ground) is in the +z direction
                if(modules[i].legs[j].target.z <= FOOT_DOWN_LEVEL+1) {
                  if(!modules[i].legs[j].moveTarget(new XYZ(0,0,VERTICAL_EPSILON))) {
                    modules[i].legs[j].setTarget(new XYZ(modules[i].legs[j].target.x,modules[i].legs[j].target.y,FOOT_DOWN_LEVEL+1), false);
                  }
                }
                allDown = false;
              }
            }
            else {
              // Reset center of rotation
              modules[i].legs[j].toCenter = new XYZ(modules[i].legs[j].offset);              
              if(modules[i].legs[j].foot.z > FOOT_UP_LEVEL) {  // Up is in the -z direction
                if(modules[i].legs[j].target.z >= FOOT_UP_LEVEL-1) {
                  if(!modules[i].legs[j].moveTarget(new XYZ(0,0,-VERTICAL_EPSILON))) {
                    modules[i].legs[j].setTarget(new XYZ(modules[i].legs[j].target.x,modules[i].legs[j].target.y,FOOT_UP_LEVEL-1), false);
                  }
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
                modules[i].legs[j].setTarget(new XYZ(modules[i].legs[j].middlePosition.x, modules[i].legs[j].middlePosition.y, FOOT_UP_LEVEL));
                //modules[i].legs[j].jumpTarget(new XYZ(-this.stepVector.x, -this.stepVector.y, this.stepVector.z),
                //                              stepRotation * -1,
                //                              new XYZ(modules[i].legs[j].middlePosition.x, modules[i].legs[j].middlePosition.y, FOOT_UP_LEVEL));
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
              angular.rotate(stepRotation * .015);    // Rotate that vector
              angular.subtract(orig);      // Then subtract it to find the difference and direction of the rotational component              
              
              delta.translate(angular);              
              float factor = delta.length();
              //delta.normalize();
              delta.scale(isPushingLeg(i, j, gaitPhase) ? HORIZONTAL_EPSILON : -HORIZONTAL_EPSILON);
              
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
                   linChange.scale(1./this.modules.length);
                   
                   this.translated.translate(linChange);
                   this.rotated += factor * stepRotation * .015 / this.modules.length;
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
        modules[i].legs[j].update(this.simulate);    
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
  
  XYZ getTranslation() {
    return getTranslation(new XYZ(center));
  }
  
  XYZ getTranslation(XYZ initial) {
    if(waypoints.size() > 0) {
      XYZ goal = new XYZ(waypoints.getGoal().x, waypoints.getGoal().y, 0);
      goal.subtract(initial);
      return goal;
    }
    else return new XYZ(0,0,0);
  }
  
  float getRotation() {
    return getRotation(angle);
  }
  
  float getRotation(float initial) {
    XYZ toGoal = getTranslation();
    float error = (atan2(toGoal.y, toGoal.x)-PI) - initial;
    while(error <= -PI) error += 2 * PI;
    while(error >= PI) error -= 2 * PI;  
    float out = map(error, PI, -PI, 3, -3);
    if(out > .75) out = .75;
    if(out < -.75) out = -.75;
    return out;
  }
  
  void draw(int view, float zoom) {  
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
      float o = (this.modules.length / 2.) - .5;
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
  
  PGraphics drawDebug() {
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

}
