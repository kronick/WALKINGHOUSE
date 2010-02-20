// TODO: Move PID loop to the microcontroller once hardware is set up

public class Actuator {
  public float length;
  public float goalLength;
  public float speed;
  
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
    
    if(simulate)
      this.length = (this.maxLength - this.minLength) / 2 + this.minLength;  // Default to half-extended
    else
      this.length = -1;
      
    //this.length = this.minLength;
    this.goalLength = this.length;
    
    this.noise = 0;
    this.drift = 0;
    
    //this.control = new PID(.1,.00001,0,10);
    this.control = new PID(1*this.maxSpeed, .0005*this.maxSpeed, 0.0, 100000*this.maxSpeed);
    this.power = 0;
  }
  
  boolean setPos(float goal) {
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
  
  void updateLength(int count) {
    // This method gets called upon receipt of serial data with a position update
    this.length = this.minLength + count * this.counterFactor;
    // Initialize goal if this is the first data received
    if(this.goalLength == -1) this.goalLength = this.length;
  }
  int getTargetCount() {
    return int((this.goalLength-this.minLength) / this.counterFactor);  
  }
  
  boolean possible(float goal) {
    if(goal > this.minLength && goal < this.maxLength)
      return true;
    else 
      return false;
  }      
  
  void setDrift(float d) {
    this.drift = d;  
  }
  void setNoise(float n) {
    this.noise = n;
  }
  
  void updatePos() {
    // This should be done asynchronously when new serial data is received
    // What's below just provides simulated data and is run only if the parent leg/house is being simulated
    if(!simulate) {
      this.length += this.drift;
      this.power = control.update(this.length, this.goalLength);
      if(abs(this.power) > this.maxSpeed * frameRateFactor())
        this.power = (this.power < 0 ? -1 : 1) * this.maxSpeed * frameRateFactor();
      this.power *= (1-random(0,this.noise));
      this.length += this.power;
    }
    
  }
  
  PGraphics draw(float xscale, float yscale) {
      PGraphics i = createGraphics(int(this.maxLength * xscale * 1.2), int(yscale * 3 * 1.2), JAVA2D);
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
      i.translate(1.5*yscale, 1.5*yscale);
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
