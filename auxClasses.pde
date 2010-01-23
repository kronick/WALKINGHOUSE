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
  
  float update(float current, float goal) {
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
  
  void set(float ix, float iy, float iz) {
    this.x = ix;
    this.y = iy;
    this.z = iz;
  }
  
  void translate(float dx, float dy, float dz) {
    this.x += dx;
    this.y += dy;
    this.z += dz;
  }
  
  void translate(XYZ d) {
    this.x += d.x;
    this.y += d.y;
    this.z += d.z;
  }

  void subtract(XYZ d) {
    this.x -= d.x;
    this.y -= d.y;
    this.z -= d.z;
  }
  void subtract(float dx, float dy, float dz) {
    this.x -= dx;
    this.y -= dy;
    this.z -= dz;
  }  
  
  float distance(XYZ a) {
    return this.distance(this, a);  
  }
  float distance(XYZ a, XYZ b) {
    a = new XYZ(a);
    a.subtract(b);
    return a.length();
  }
  
  void scale(float k) {
    this.x *= k;
    this.y *= k;
    this.z *= k; 
  }
  
  void rotate(float phi) {
    // Rotates a vector in the x-y plane about its tail (or a point about the z-axis [0,0])
    float ox = this.x;
    float oy = this.y;
    float oz = this.z;
    this.x = ox * cos(phi) + oy * sin(phi);
    this.y = oy * cos(phi) - ox * sin(phi);
    this.z = oz;
  }
  
  
  String text() {
    return "(" + f.format(this.x) + ", " + f.format(this.y) + ", " + f.format(this.z) + ")"; 
  }
  
  float length() {
    return sqrt(this.x*this.x + this.y*this.y + this.z*this.z);
  }
  
  void normalize() {
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
  
  void set(float ix, float iy) {
    this.x = ix;
    this.y = iy;
  }
  
  float distance(float ix, float iy) {
    return sqrt(sq(ix-this.x) + sq(iy-this.y));
  }
  
  float distance(XY p) {
    return this.distance(p.x, p.y);  
  }
}

class WaypointList extends ArrayList
{ 
  public int currentGoal = 0;
  WaypointList() {
    super();
  }
  boolean add(XYZ o) {
    return super.add(o);  
  }
  boolean add(float x, float y) {
    return super.add(new XYZ(x,y,0));  
  }  
  XYZ get(int i) {
    return (XYZ)super.get(i);  
  }
  
  boolean advance() {
    if(currentGoal < this.size()-1) {
      this.currentGoal++;
      return true;
    }
    else return false;
  }
  
  XYZ getGoal() {
    return this.get(currentGoal);  
  }
  
  float segmentLength(int i) {
    try {
      return this.get(i).distance(this.get(i+1));  
    }
    catch (Exception e) {
      return 0;  
    }    
  }
  
  float segmentLength() {
    return this.segmentLength(currentGoal-1);
  }
}

public class ScrollEvent implements MouseWheelListener {
 public ScrollEvent() {
   addMouseWheelListener(this);
 }
 public void mouseWheelMoved(MouseWheelEvent e) {
   zoom *= (e.getWheelRotation() > 0) ? .9 : 1.1;
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
  
  float getSolarHour(Calendar cal, float longitude) {
    // First, get the corresponding time in the GMT timezone
    Calendar gmt = (Calendar)cal.clone();
    gmt.add(Calendar.MILLISECOND, -cal.get(Calendar.ZONE_OFFSET));  // By subtracting the timezone offset
    
    float gmtSolarHour = gmt.get(Calendar.HOUR_OF_DAY) + gmt.get(Calendar.MINUTE)/60. + gmt.get(Calendar.SECOND)/3600. - 12;
    float longitudeOffset = longitude / 180 * 12;  // 180 degrees would be the other side of the world and therefore 12 hours off
    float solarHour = gmtSolarHour + longitudeOffset;
    
    while(solarHour < -12) solarHour += 24;
    
    return solarHour;
  }
  
  float solarDeclination(int dayNumber) {
    // Returns the solar declination on the given day of the year
    return radians(23.45) * sin(PI * (dayNumber - 81)/182.5);  // 81 is the day of the spring equinox
  }

  float getAltitude() {
    float t = PI/12 * getSolarHour(datetime, longitude);
    float declination = solarDeclination(datetime.get(Calendar.DAY_OF_YEAR));
    
    // Now the big equation...
    return asin(sin(radians(latitude))*sin(declination) + cos(radians(latitude))*cos(declination)*cos(t));
  }
  
  float getAzimuth() {    
    float t = PI/12 * getSolarHour(datetime, longitude);
    float declination = solarDeclination(datetime.get(Calendar.DAY_OF_YEAR));
    
    // Now the big equation...
    float offset = (cos(radians(latitude))*sin(declination) - sin(radians(latitude))*cos(declination)*cos(t)) > 0 ? PI : 0;
    return offset +  atan(cos(declination) * sin(t) / (cos(radians(latitude))*sin(declination) - sin(radians(latitude))*cos(declination)*cos(t)));
  }  
}

