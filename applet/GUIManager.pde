class GUIManager {
  ArrayList buttons, dials, arcbars, sliders;
  
  ArrayList clickables;
  
  XY clickLocation;
  boolean mouseDown;
  boolean dragging;
  
  GUIManager() {
    buttons = new ArrayList();
    dials = new ArrayList();
    arcbars = new ArrayList();
    sliders = new ArrayList();
    
    mouseDown = false;
    dragging = false;
    clickLocation = new XY(0,0);
    
    clickables = new ArrayList();
  } 
  
  void addClickable(Clickable e) {
    this.clickables.add(e);
  }
  
  boolean removeElement(String searchName) {
    boolean found = false;
    for(int i=0; i<this.clickables.size(); i++) {
      if(((GUIElement)this.clickables.get(i)).getName() == searchName) {
        this.clickables.remove(i);
        found = true;
      }
    } 
    return found;    
  }
  
  boolean removeButton(String searchLabel) {
    for(int i=0; i<this.buttons.size(); i++) {
      if(((Button)this.buttons.get(i)).label == searchLabel) {
        this.buttons.remove(i);
        return true;
      }
    } 
    return false;
  }
  
  void clearButtons() {
    this.buttons.clear();  
  }

  
  void clearElements() {
    this.clickables.clear();  
  }
  
  int update(int imouseX, int imouseY, boolean clicked) {
    boolean buttonClicked = false;
    int numClicked = 0;
    Clickable currentElement;
    for(int i=0; i<this.clickables.size(); i++) {
      currentElement = (Clickable)this.clickables.get(i);
      if(currentElement.inBounds(imouseX, imouseY)) {
         currentElement.setHover(true);
         if(clicked) {
           currentElement.click(imouseX, imouseY);
           buttonClicked = true;
           numClicked++;
           break;
         }  
      }
      else {
        currentElement.setHover(false);
      }
    }
    
    if(clicked && !buttonClicked) {
      if(!dragging) {
        clickLocation = new XY(imouseX, imouseY);
      }
      dragging = true;
    }
    else {
       dragging = false;
    }      
    return numClicked;
  }
  
  void draw() {
    for(int i=0; i<this.clickables.size(); i++) {
      ((Clickable)this.clickables.get(i)).draw(); 
    }
  }
}
