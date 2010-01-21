class Module
{
  public Leg[] legs;
  public Leg portLeg;
  public Leg starLeg;
  
  static final float LEG_Y_OFFSET = 7;
  
  public float length;
  public float legBaseLength;
  public XYZ center;
  
  Module(XYZ icenter) {
    this.legs = new Leg[2];
    this.center = icenter;

    // Add one leg rotated 0, one rotated PI radians for each module, half a module width from the center    
    legs[0] = new Leg(new XYZ(icenter.x, icenter.y + MODULE_WIDTH/2 + LEG_Y_OFFSET, icenter.z), 0);
    legs[1] = new Leg(new XYZ(icenter.x, icenter.y - (MODULE_WIDTH/2 + LEG_Y_OFFSET), icenter.z), PI); 
  }
}
