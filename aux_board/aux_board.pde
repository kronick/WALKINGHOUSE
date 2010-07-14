#include <Wire.h>

// Compass/tilt sensor
// ============================
const static int COMPASS_ADDRESS = 0x32 >> 1;
#define DECLINATION 152  // Based on location, use: http://www.ngdc.noaa.gov/geomagmodels/IGRFWMM.jsp?defaultModel=WMM (opposite of the value given there), in tenths of a degree

// Register addresses
#define DECLINATION_MSB 0x0D
#define DECLINATION_LSB 0x0C
#define SLAVE_ADDRESS   0x00
#define OPMODE_1        0x04
#define OPMODE_2        0x05

// Opcodes
#define READ_BYTE   0x33
#define GET_ACCEL   0x40 // Returns 6 bytes (AxMSB, AxLSB, AyMSB, AyLSB, AzMSB, AzLSB)
#define GET_MAG     0x45 // Returns 6 bytes (MxMSB, MxLSB, MyMSB, MyLSB, MzMSB, MzLSB)
#define GET_HEADING 0x50 // Returns 6 bytes (HeadMSB, HeadLSB, PitchMSB, PitchLSB, RollMSB, RollLSB)
#define GET_TILT    0x55 // Returns 6 bytes (PitchMSB, PitchLSB, RollMSB, RollLSB, TempMSB, TempLSB)
#define GET_OP1     0x65 // Returns 1 byte
#define ORIENT1     0x72 // Level, x=forawrd, +z=up (default)
#define ORIENT2     0x73 // Upright sideways, x=forward, y=up
#define ORIENT3     0x74 // Upright flat front, z=forward, -x=up
#define RUNMODE     0x75
#define STANDBY     0x76
#define RESET       0x82
#define GOSLEEP     0x83 // From run mode
#define ENDSLEEP    0x84 // To standby mode
#define READEEPROM  0xE1 // Argument 1 is EEPROM adress, returns 1 byte
#define WRITEEEPROM 0xF1 // Argument 1 is address, 2 is data
#define STARTCALIB  0x71
#define STOPCALIB  0x7E

// Current sensor
// ============================
static int CURRENT_IN = 1;
static float ZERO_CURRENT = 7.3;
static float NOMINAL_CURRENT = 50;
static float CURRENT_COEFFICIENT = .625;

void setup()
{
  Serial.begin(9600);
  Wire.begin();
  
  delay(500); // Wait for compass to be ready
  /*
  Wire.beginTransmission(COMPASS_ADDRESS);
    Wire.send(STARTCALIB);
  Wire.endTransmission();    
  for(int i=0; i<80; i++) {
    digitalWrite(13, HIGH);
    delay(500);
    digitalWrite(13, LOW);
    delay(500);
  }
  
  Wire.beginTransmission(COMPASS_ADDRESS);
    Wire.send(STOPCALIB);
  Wire.endTransmission();
  */
  
  // Configure compass, if needed
  Wire.beginTransmission(COMPASS_ADDRESS);
    Wire.send(WRITEEEPROM);
    delay(1);
    Wire.send(OPMODE_2);
    delay(1);
    Wire.send(B00000010);
  Wire.endTransmission();
  
  Serial.println("Configured.");
}

void loop() {
  Wire.beginTransmission(COMPASS_ADDRESS);
    Wire.send(GET_HEADING);
  Wire.endTransmission();
  
  Wire.beginTransmission(COMPASS_ADDRESS);
    Wire.send(READ_BYTE);  
  Wire.endTransmission();
  delay(1);
  Wire.requestFrom(COMPASS_ADDRESS, 6);
  delay(1);
  int i=0;
  int heading = 0;
  int pitch = 0;
  int roll = 0;
  while(Wire.available()) {
    if(i==0) heading = Wire.receive() << 8;
    if(i==1) heading += Wire.receive();
    if(i==2) pitch = Wire.receive() << 8;
    if(i==3) pitch += Wire.receive();
    if(i==4) roll = Wire.receive() << 8;
    if(i==5) roll += Wire.receive();
    i++;
  }
  
  Serial.print("*H");
  Serial.print(heading, DEC);
  Serial.print("!*X");
  Serial.print(pitch, DEC);
  Serial.print("!*Y");
  Serial.print(roll, DEC);
  Serial.print("!");
  
  // Now calculate current by averaging over 100 readings
  float i_avg = 0;
  for(int j = 0; j < 50; j++) {
    i_avg += analogToCurrent(analogRead(CURRENT_IN));
    delay(1);
  }
  i_avg /= 50;
  Serial.print("*C");
  Serial.print(i_avg);
  Serial.print("!");
  //sdelay(100);
  
}

float analogToCurrent(int a) {
  // First convert reading to voltage, subtracting out zeroCurrent offset
  float v = (a-ZERO_CURRENT) * 5 / 1024.;
  float i = (v-2.5) * NOMINAL_CURRENT / CURRENT_COEFFICIENT;
  return i;
  //v = VREF ±(0.625·I_P/I_PN)  
}
