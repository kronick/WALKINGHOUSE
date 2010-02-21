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
