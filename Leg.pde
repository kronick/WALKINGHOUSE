public class Leg {    
  // Default actuator properties
  final float H_ACTUATOR_MIN = 70 * MODULE_LENGTH/124;      // Min length from joint at frame to center of vertical tube
  final float H_ACTUATOR_MAX = 100 * MODULE_LENGTH/124;    //100
  final float V_ACTUATOR_MIN = 5 * MODULE_LENGTH/124;      // Min length along v tube past the point where h actuators meet
  final float V_ACTUATOR_MAX = 45 * MODULE_LENGTH/124;
  final float H_ACTUATOR_SPEED = .3                    * PROCESSOR_SPEED_SCALE;
  final float V_ACTUATOR_SPEED = H_ACTUATOR_SPEED / 5 * PROCESSOR_SPEED_SCALE;
  
  // 20 seconds to lift
  // 10 seconds to translate forward
  
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
    this.frontAct = new Actuator(H_ACTUATOR_MAX, H_ACTUATOR_MIN, H_ACTUATOR_SPEED, .04);
    this.backAct = new Actuator(H_ACTUATOR_MAX, H_ACTUATOR_MIN, H_ACTUATOR_SPEED, .04);
    this.vertAct = new Actuator(V_ACTUATOR_MAX, V_ACTUATOR_MIN, V_ACTUATOR_SPEED, .01);
    
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
  
  void update(boolean simulate) {
    /*if(oscillate) {
      this.frontAct.setPos((cos(radians(frameCount%360))+1)/2 * (this.frontAct.maxLength - this.frontAct.minLength) + this.frontAct.minLength);
      this.backAct.setPos((sin(radians(frameCount%360))+1)/2 * (this.backAct.maxLength - this.backAct.minLength) + this.backAct.minLength);
      this.vertAct.setPos((sin(radians(frameCount/2%360))+1)/2 * (this.vertAct.maxLength - this.vertAct.minLength) + this.vertAct.minLength);
    }
    */
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
      
      /*
      angular = new XYZ(-(toCenter.y - test.y), 
                       toCenter.x - test.x, 0);
      angular.normalize();
      angular.scale(rotation);    
      angular.scale(this.EPSILON); 
      */
      
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
          float zFactor = (House.FOOT_DOWN_LEVEL - this.foot.z)/(.5*House.FOOT_UP_LEVEL) + 1;  // Fake Z axis scaling        
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
