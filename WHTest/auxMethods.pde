
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
