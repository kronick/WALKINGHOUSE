class House
{
  // Constants
  static final int TOP = 0;
  static final int FRONT = 1;
  static final int SIDE = 2;

  static final float FOOT_DOWN_LEVEL = 55 * MODULE_LENGTH/124;    // Height to walk above ground.
  static final float FOOT_UP_LEVEL = 35 * MODULE_LENGTH/124;      // 55- 46 
  public float footDownLevel = 57;
  public float footUpLevel = 45;
  // Optimal walking:  57-45
  // Big steps:        57-37
  // High clearance:   62-42
  // Low clearance:    40-26
  
  
   
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
  private boolean legLimit; // Flag when a leg on the ground can't move any more
  
  public int stepCount;
  public float distanceWalked = 0;
  public ArrayList breadcrumbs;
  
  static final float VERTICAL_EPSILON = .12;    // .024
  static final float HORIZONTAL_EPSILON = .25; // .125
  static final float ANGULAR_EPSILON = .01;

  
  
  public String status = "";
  
  boolean simulate;
  boolean calibrate;
  
  House(XYZ icenter, float iangle, int imodules, boolean simulate) {
    this.center = new XYZ(icenter.x, icenter.y, icenter.z);  
    this.simulate = simulate;
    this.angle = iangle;
    
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
    this.translationSpeed = 4;
    this.rotation = 0;
    this.rotationCenter = new XYZ(0,0,0);
    
    this.calibrate = false;
    
    this.heading = 0;
    
    this.stepCount = 0;
    
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
        legLimit = false; // Reset this flag once per step
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
        
        //boolean stop = false;
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
              
              if(legLimit && isPushingLeg(i, j, gaitPhase))
                delta.scale(0);  // If this leg is on the ground and one can't move, don't move this one either
              
              if(!(stopFloating && !isPushingLeg(i,j, gaitPhase)) && modules[i].legs[j].moveTarget(delta)) {
                if(!isPushingLeg(i, j, gaitPhase) || !legLimit)  // If this leg isn't on the ground and can still move or the legs on the ground are not stopped, don't go to the next state yet!
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
                   this.rotated += factor * stepRotation * ANGULAR_EPSILON / this.modules.length;
                 }
              }
              else {
                if(isPushingLeg(i, j, gaitPhase))  // If this leg is on the ground and can't move, stop all the legs that are on the ground
                  legLimit = true;
                else
                  stopFloating = true;
                  
                if(stopFloating && legLimit) moveOn = true;
              }
              if(debug) println(legLimit);
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
  
  void updateLegsOnly() {
    for(int i=0; i<this.modules.length; i++) {
      for(int j=0; j<this.modules[i].legs.length; j++) {
        boolean sim = true;
        if(i == 0 && j == 0) sim = false;
        modules[i].legs[j].update();    
      }
    }  
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

  
  void highlightLeg(int i, int j) {
    pushMatrix();
      translate(this.center.x, this.center.y);
      rotate(this.angle);
      translate(modules[i].legs[j].offset.x, modules[i].legs[j].offset.y);
      //scale(zoom);  // Scale based on zoom factor 
      rotate(-modules[i].legs[j].rot);
      
      float _s = abs((frameCount)%60 - 30)+80;
      noStroke();
      fill(0,250,255,80);
      ellipse(modules[i].legs[j].foot.x, modules[i].legs[j].foot.y, _s, _s);
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
        this.middlePosition = this.findFoot(this.frontAct.midlength, this.backAct.midlength, this.vertAct.midlength);
        
        SPINDLE_COLOR = color(0,0,255);
        BODY_COLOR = color(0,0,150);    
      }
      
      Actuator getAct(int i) {
        switch(i) {
          case 0: return this.frontAct;
          case 1: return this.backAct;
          case 2: return this.vertAct;
          default: return null;
        }
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
      
      void moveTargetToFoot() {
        this.setTarget(this.findFoot(this.frontAct.length, this.backAct.length, this.vertAct.length), true);  
      }
      
      void targetCenterUp() {
        this.setTarget(new XYZ(middlePosition.x, middlePosition.y, footUpLevel), true); 
      }
      void targetCenterDown() {
        this.setTarget(new XYZ(middlePosition.x, middlePosition.y, footDownLevel), true);
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
      
      boolean moveTarget(XYZ e) { return this.moveTarget(e, false); }
      
      boolean moveTarget(XYZ e, boolean force) {
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
              float zFactor = (55 - this.foot.z)/35. + 1.5;  // Fake Z axis scaling        
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
