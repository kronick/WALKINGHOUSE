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
  
  boolean inBounds(float x, float y) {
    return(this.center.distance(x, y) < this.radius); 
  }  
  
  void click(float x, float y) {
    this.needleGoal = atan2(y-this.center.y, x-this.center.x) + PI/2;             // Move the dial
    this.onClick.act(this.center.distance(x, y) / this.radius, this.needleGoal);  // Then run the custom callback (r, theta) scaled to the dial's dimensions
  }
  
  String getName() {
    return this.name;
  }
  
  void setName(String s) {
    this.name = s;
  }

  
  void setHover(boolean hov) {
    this.hovering = hov;
  }  
  
  void attach(Rotatable e) {
    this.attached.add(e);  
  }
  
  void draw() {
    
    // Move the needle towards the goal, finding the shortest route
    if(needleGoal - needlePosition > PI) needlePosition += 2 * PI;
    if(needleGoal - needlePosition < -PI) needlePosition -= 2 * PI;
    needlePosition += (needleGoal - needlePosition) * .5;
    
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
          vertex(0,-radius*.75);
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
          text(int(i/360. * (max-min) + min), 0, -radius * .75);
          
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
  
  boolean inBounds(float x, float y) {
    return(this.center.distance(x, y) < this.radius + this.thickness/2 && this.center.distance(x, y) > this.radius - this.thickness/2); 
  }  
  
  void click(float x, float y) {
    float angle = atan2(y-this.center.y, x-this.center.x) - this.offset;
    if(angle < -2*PI) angle+=2*PI;
    if(angle > this.start - .2 && angle < this.stop + .2) {  // If we're within the range of the slider arc
      this.goal = (angle - this.start)/(this.stop-this.start) * (this.max - this.min) + this.min;  // Update the visual goal
      this.onClick.act(this.goal);                                                                        // Run the callback function with the new goal as the parameter
    }
  }
  
  String getName() {
    return this.name;
  }
  
  void setName(String s) {
    this.name = s;  
  }  
  
  void setRotation(float theta) {
    this.offset = theta;  
  }
  
  void setHover(boolean hov) {
    this.hovering = hov;
  }  
  
  void draw() {
    position += (goal - position) * .5;
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
      strokeWeight(thickness * .75);
      arc(0,0, radius*2, radius*2, start, stop);     
      
      // Draw arc from center to value
      stroke(150,0,255); 
      strokeWeight(thickness*.5);     
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
      for(int i=int(degrees(start)); i<=int(degrees(stop)); i+=5) {
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
        ellipse(0,-radius, thickness*.75, thickness*.75);
        fill(white);
        text(labelMax, 0,-radius);            
      popMatrix();
      pushMatrix();
        rotate(start+PI/2);
        fill(blue);
        ellipse(0,-radius, thickness*.75, thickness*.75);
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
    
    this.label_size = this.height * .1;
    
    this.center = new XY(icenterX, icenterY);    
    
    this.onClick = ionClick;
    
    this.name = "";
    
    this.labelMin = "";
    this.labelMax = "";
  }
  
  boolean inBounds(float x, float y) {
    return (x < this.center.x + this.width/2  && x > this.center.x - this.width/2 &&
         y < this.center.y + this.height/2 && y > this.center.y - this.height/2);    
  }
  
  void click(float x, float y) {
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
  
  String getName() {
    return this.name;
  }
  
  void setName(String s) {
    this.name = s;  
  }  
  
  void setHover(boolean hov) {
    this.hovering = hov;
  }  
  
  void draw() {
    position += (goal - position) * .5;
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
      strokeWeight(this.width * .75);
      line(0, this.height/2 - this.width/2, 0, -this.height/2 + this.width/2);
//      rect(0,0, this.width, this.height);;
//      rect(0,0, this.width * .75, this.height);
      
      // Draw bar from bottom to value
      noStroke();
      fill(150,0,255);
      float barHeight = ((position - this.min) / (this.max - this.min) * range);
      rect(0, start - barHeight/2, this.width*.5, barHeight);
      
      // Draw tick marks
      stroke(0,0,0, 120);
      strokeWeight(int(this.height/200));
      for(float i=0; i<100; i += 5) {
        float w = .1;
        if(i%10 == 0) w = .2;
        if(i%25 == 0) w = .4;
        if(i%50 == 0) w = .65;
        line(-this.width/2 * w, start - i/100*range, this.width/2 * w, start - i/100*range);
      }
      
      // Draw labels
      textFont(DialNumbers);
      textAlign(CENTER, CENTER);
      fill(80,150,150);
      noStroke();
      ellipse(0, -this.height/2 + this.width/2, this.width*.75, this.width * .75);
      //rect(0, -this.height/2 + this.label_size/2, this.width, this.label_size);
      fill(0,0,255);
      text(this.labelMax, 0, -this.height/2 + this.label_size/2);
      
      fill(0,150,150);
      ellipse(0, this.height/2 - this.width/2, this.width*.75, this.width * .75);
      //rect(0, this.height/2 - this.label_size/2, this.width, this.label_size);
      fill(0,0,255);
      text(this.labelMin, 0, this.height/2 - this.label_size/2);
     
    popMatrix();  
  }
  
}


class Button implements Clickable {
  public XY center;
  public int width;
  public int height;
  public color bgColor, fgColor, hoverColor, borderColor;
  public int borderWidth;
  public boolean transparent;
  
  public PFont font;
  
  public Action onClick;
  
  public String label;
 
  public boolean hovering;
  public boolean clicking;
 
  Button(XY icenter, int iwidth, int iheight, String ilabel, Action ionClick) {
    this(icenter, iwidth, iheight, ilabel, HelveticaBold, ionClick);
  }
  Button(XY icenter, int iwidth, int iheight, String ilabel, PFont ifont, Action ionClick) {
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
  }   
  
  boolean inBounds(float x, float y) {
    return (x < this.center.x + this.width/2  && x > this.center.x - this.width/2 &&
         y < this.center.y + this.height/2 && y > this.center.y - this.height/2);    
  }
  
  void click(float x, float y) {
    this.onClick.act(x, y);  
  }
  
  String getName() {
    return this.label;
  }
  
  void setName(String s) {
    this.label = s;  
  }
  
  void setHover(boolean hov) {
    this.hovering = hov;
  }
  
  void draw() {
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
    textFont(this.font);
    textAlign(CENTER, CENTER);
    fill(this.fgColor);
    text(this.label, this.center.x, this.center.y); 
  }
}


interface Action {
  void act(float x, float y);
}
interface DialAction {
  void act(float r, float theta); // On a dial, these values will be scaled relative to the range of the dial
}
interface SliderAction {
  void act(float value);          // This should be pre-scaled
}


public interface Clickable extends GUIElement {
  boolean inBounds(float x, float y);
  void click(float x, float y);  
  void setHover(boolean hov);
}

public interface GUIElement {
  void draw();
  String getName();
  void setName(String s);
}

public interface Rotatable {
  void setRotation(float theta);
}
