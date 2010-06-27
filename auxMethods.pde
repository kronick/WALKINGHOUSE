float frameRateFactor() {
  return BASE_FRAMERATE / frameRate;  
}


boolean isPushingLeg(int i, int j, int phase) {
  if(((i+j) % 2 == 0 && phase == -1) || ((i+j) % 2 != 0 && phase == 1)) {
    return true;
  }
  else {
    return false;
  }
}

int[] nextWaveLeg(int n) {
  int[] o = new int[2];
  switch(n) {
    case 1: o[0] = 1; o[1] = 1; break;
    case 4: o[0] = 1; o[1] = 0; break;
    case 3: o[0] = 2; o[1] = 1; break;
    case 6: o[0] = 0; o[1] = 1; break;
    case 2: o[0] = 2; o[1] = 0; break;
    case 5: o[0] = 0; o[1] = 0; break;
  }   
  return o;
}

int[] getLegij(int n) {
  int[] o = new int[2];
  o[0] = (int)((n-1)/2);
  o[1] = n%2 == 1 ? 0 : 1;
  return o;  
}

XYZ screenToWorldCoords(float x, float y) {
  XYZ temp = new XYZ(x, y, 0);
  temp.x = (x-width/2)/zoom;
  temp.y = (y-height/2)/zoom;
  
  temp.rotate(viewRotation);
  
  temp.x -= (viewCenter.x - width/2);
  temp.y -= (viewCenter.y - height/2);
  
  return temp;
 
  /*
    The forward transform:
    ----------------------
    translate(width/2, height/2);
    rotate(viewRotation);
    translate(-width/2, -height/2);
    translate((viewCenter.x-width/2)*zoom, (viewCenter.y-height/2)*zoom);     
    scale(zoom);
    translate(width/2/zoom, height/2/zoom);
    */
}

void moveViewDown() {
  viewCenter.x -= 5/zoom * sin(viewRotation);
  viewCenter.y -= 5/zoom * cos(viewRotation);  
  follow = false;
}
void moveViewUp() {
  viewCenter.x += 5/zoom * sin(viewRotation);
  viewCenter.y += 5/zoom * cos(viewRotation);  
  follow = false;
}
void moveViewRight() {
  viewCenter.x -= 5/zoom * cos(viewRotation);
  viewCenter.y += 5/zoom * sin(viewRotation);  
  follow = false;
}
void moveViewLeft() {
  viewCenter.x += 5/zoom * cos(viewRotation);
  viewCenter.y -= 5/zoom * sin(viewRotation);  
  follow = false;
}
