#include <Servo.h> 
#include <Charlieplex.h>
#include <EEPROM.h>

#define SAVE_EVERY 1000  // Save to EEPROM ever n cycles

byte charliePins[] = {8, 12, 13};
Charlieplex charlieplex = Charlieplex(charliePins,3);
//individual 'pins' , adress charlieplex pins as you would adress an array
charliePin led5 = { 1 , 2 }; //led1 is indicated by current flow from 12 to 13
charliePin led2 = { 2 , 1 };
charliePin led6 = { 2 , 0 };
charliePin led3 = { 0 , 2 };
charliePin led1 = { 0 , 1 };
charliePin led4 = { 1 , 0 };
charliePin pins[] = {led1, led2, led3, led4, led5, led6};

int pos = 0;    // variable to store the servo position 
int cylon = 0;
int indicatorDecay = 0;
int chip = 0;
boolean rev = false;

int cycle = 0;

// Serial communication
// ====================
// Command constants
#define NONCOM -1  // No command
#define MOVCOM 1   // Move actuator to position
#define SETCOM 2   // Set actuator position
#define GETCOM 3   // Get actuator position
#define CALCOM 4   // Calibrate
#define LEGCALOCM 5 // Calibrate leg

char incoming = 0;    // Place to temporarily store incoming serial byte
int c_type = -1;      // Stores current command type to process
int c_actuator = -1;  // Stores actuator which command is operating on, -1 when not used (unset)
int c_value = 0;     // Tallies up the value of the commmand coming in  
boolean c_neg = false; // Negative number flag

char buffer[32];  // For building strings

// Example commands
// ----------------
// Move to (absolute) position:
//   M6300* = Move actuator #6 to position 300
// Set counter value
//   S11*  = Set actuator #1's current count to 1
// Get actuator position:
//   G3* = Print actuator #3's count to the serial line
// Calibration routine:
//   C* = Retract all actuators inwards, set zero point

// Control board replies to host with '*!' to acknowledge receipt of a command,
// or something like '*P3200!' if a position was requested (Actuator 3 is at position 200)


//SPI Setup
//=========
// Communication pins 
// I'm bitbanging rather than  doing hardware spi to keep all my PWM ports free (or because I designed the board wrong)
// so these pins could be anything that's wired to the slave chips.
#define DATAOUT 7//MOSI 
#define DATAIN  4//MISO  
#define SPICLOCK  2//sck 

// Slave Selects
//byte SS[6] = {14, 15, 16, 17, 18, 19};
byte SS[6] = {18, 19, 17, 16, 15, 14};
           // LF  LB  LV  RF  RB  RV
           
byte outputPins[6] = {10, 11, 6, 9, 3, 5};
           
//LS7366R Quadrature counter OP-Codes 
#define CLEAR_COUNTER 8 // Set CNTR to 0
#define CLEAR_STATUS 48 // Set STR to 0
#define READ_COUNTER B01100000 // Read register CNTR (96)
#define READ_STATUS 112 // Read register STR
#define WRITE_MODE0 B10001000 // Write to register MDR0 (136) 
#define WRITE_MODE1 B10010000 // Write to register MDR1 (144)
#define WRITE_DTR B10011000   // Write to DTR register (for holding a value to transfer to CNTR)
#define LOAD_COUNT B11100000   // Transfer DTR to CNTR

// PWM outputs
Servo PWMout[6];

// Counters
int counter[6];
int target[6];
int maybenoise[6];


#define DEADTIME 10 // Must detect no movement for this many cycles for actuator to be considered stopped

void setup() 
{ 
  for(int i=0; i<6; i++) {
    PWMout[i].attach(outputPins[i]);
    set_PWM(i,0);  
  }
  /*
  PWMout[0].attach(3);
  PWMout[1].attach(5);
  PWMout[2].attach(6);
  PWMout[3].attach(9);
  PWMout[4].attach(10);
  PWMout[5].attach(11);
  */
 
  
  Serial.begin(9600);

  // Set up SPI
  pinMode(DATAOUT, OUTPUT);
  pinMode(DATAIN, INPUT);
  pinMode(SPICLOCK,OUTPUT);
  
  Serial.println("Setting up counters...");
  
  for(int i=0; i<6; i++) {
    pinMode(SS[i],OUTPUT);
    digitalWrite(SS[i],HIGH); //disable device
    
    // Initialize parameters for each actuator
    counter[i] = 0; target[i] = 0;
  }  
  
  // Set each slave select pin to be an output and bring them high to disable
  for(int i=0; i<6; i++) {
    pinMode(SS[i],OUTPUT);
    digitalWrite(SS[i],HIGH); //disable device     
    
    digitalWrite(SS[i],LOW); // Enable
    spi_transfer(WRITE_MODE0);
    //spi_transfer(B00000000);  // Non-quadrature
    //spi_transfer(B00000001);  // 1x quadrature
    spi_transfer(B00000011);  // 4x quadrature
    digitalWrite(SS[i], HIGH);
    delay(10);
    
    digitalWrite(SS[i],LOW);
    spi_transfer(WRITE_MODE1);
    //spi_transfer(B00000000);  // Four-byte counter mode    
    //spi_transfer(B00000001);  // Three-byte counter mode
    spi_transfer(B00000010);  // Two-byte counter mode
    //spi_transfer(B00000011);  // One-byte counter mode    
    digitalWrite(SS[i], HIGH);
    delay(10);    
    
    digitalWrite(SS[i],LOW);
    spi_transfer(CLEAR_STATUS);  // Set status to zero
    digitalWrite(SS[i], HIGH);
    delay(10);            
    
    // Read stored value from EEPROM and set counter
    int stored = int(EEPROM.read(2*i+1)) | (int(EEPROM.read(2*i)) << 8);
    if(stored == 65535) // This is the default value and obviously invalid, set to 0
      stored = 0;
    set_count(i, stored);
      
    delay(10);             
    
    
    //digitalWrite(SS[i], LOW);
    //Serial.println((int)spi_transfer(READ_STATUS));
    //digitalWrite(SS[i],HIGH);
  }
  
  for(int i=0; i<10; i++) {
    charlieplex.charlieWrite(pins[0], HIGH);
    delay(100);
    charlieplex.clear();
    delay(100);
  }
 
  
  Serial.print("Encoders configured.");
  delay(10);
} 


byte spi_transfer(volatile byte towrite)
{
  // Manual SPI transfer function
  // Hardcoded to Most Significant Bit (MSB), sample on rising edge
  // For each bit:
  //   Bring SPI clock low
  //   Write bit of towrite to DATAOUT/MOSI
  //   Bring SPI clock high
  //   Read bit on DATAIN/MISO, shift into read
  byte read = 0;
  
  for(byte i=0; i<8; i++){

    if((towrite & (1<<(7-i))) > 0)
      digitalWrite(DATAOUT, HIGH);
    else
      digitalWrite(DATAOUT, LOW);
  
    digitalWrite(SPICLOCK, LOW);
    
    read |= (digitalRead(DATAIN) << (7-i));    // Must come AFTER clock goes low
   
    digitalWrite(SPICLOCK,HIGH);
    //delay(1);      
  }  

  // Finish with clock low
  digitalWrite(SPICLOCK,LOW);
  
  return read;  
}

int get_count(int counter) {
  // 1. Bring SS[counter] low to enable the chip
  // 2. Send READ_COUNTER byte using spi_transfer
  // 3. Send two arbitrary bytes using spi_transfer to read two bytes into the counter
  // 4. Bring SS[counter] high to disable
  digitalWrite(SS[counter], LOW);
  spi_transfer(READ_COUNTER);
  byte a = spi_transfer(0);
  byte b = spi_transfer(0);
  //byte c = spi_transfer(0);  
  //byte d = spi_transfer(0);  
  digitalWrite(SS[counter], HIGH);
  return (int(b) | (int(a) << 8));
  //return (long(d) | (long(c) << 8) | (long(b) << 16) | (long(a) << 24));
}


void set_count(int counter, int value) {
  // Write to DTR register, then load DTR into CNTR
  digitalWrite(SS[counter], LOW);
  spi_transfer(WRITE_DTR);
  spi_transfer(value);
  digitalWrite(SS[counter], HIGH); 
  digitalWrite(SS[counter], LOW);
  spi_transfer(LOAD_COUNT);
  digitalWrite(SS[counter], HIGH);   
}


int write_DTR(int counter) {
  digitalWrite(SS[counter], LOW);
  spi_transfer(WRITE_DTR);
  byte a = spi_transfer(0);
  digitalWrite(SS[counter], HIGH);
  return int(a);
} 

int read_MDR0(int counter) {
  digitalWrite(SS[counter], LOW);
  spi_transfer(B01001000);
  byte a = spi_transfer(0);
  digitalWrite(SS[counter], HIGH);
  return int(a);
} 
int read_MDR1(int counter) {
  //digitalWrite(SS[counter], HIGH);
  digitalWrite(SS[counter], LOW);
  spi_transfer(B01010000);
  byte a = spi_transfer(0);
  digitalWrite(SS[counter], HIGH);
  return int(a);
} 
int read_STR(int counter) {
  digitalWrite(SS[counter], HIGH);
  digitalWrite(SS[counter], LOW);
  spi_transfer(B01110000);
  byte a = spi_transfer(0);
  digitalWrite(SS[counter], HIGH);
  return int(a);
} 

void set_PWM(int actuator, int value) {
  // Value ranges from -500 to 500
  if(value > 500) value = 500;
  if(value < -500) value = -500;
  if(actuator % 2 > 0) value *= -1;  // Flip every other channel
  PWMout[actuator].writeMicroseconds(1500 + value);
}

void loop() 
{  
  // See if data is coming in
  if(Serial.available() > 0) {
    incoming = Serial.read();
    if(c_type == NONCOM) {  // If the command type has not yet been set
      switch(incoming) {
        case 'M':
          c_type = MOVCOM;
          break;
        case 'S':
          c_type = SETCOM;
          break;
        case 'G':
          c_type = GETCOM;
          break;
        case 'C':
          c_type = CALCOM;
          break;
        case 'L':
          c_type = LEGCALCOM;
          break;          
        default:  // If the command is anything else, essentially ignore it
          c_type = NONCOM;
          while(Serial.available() > 0) { Serial.read(); }
      }
    }
    // If no actuator has been specified yet AND next char is an ASCII number 0-5
    else if((c_actuator < 0 || c_actuator > 5) && (incoming <= 53 || incoming >= 48)) { 
      c_actuator = incoming - 48;  // 48 is ASCII 0
    }
    // If not a stop character and this is a number, tally it on to the value
    else if(incoming != '*' && (incoming <= 57 || incoming >= 48 || incoming == 45)) {   
      c_value *= 10;  // Move old digits over one place
      if(incoming == 45) c_neg = true;  // ASCII 45 is a '-' sign
      else c_value += incoming - 48;   // Add this number to the ones' place
    }
    // Anything else (including a stop char) will cause the command to try to run and then reset
    else if(incoming == '*') {
      // Run the command
      if(c_neg) c_value *= -1;  // Make value negative if the flag is set
      switch(c_type) {
        case MOVCOM: 
          if(abs(c_value - target[c_actuator]) > 00) {
            // If this is a big change, wait for a second signal to ensure it's not just noise
            if(maybenoise[c_actuator] == c_value) {
              // This value was already stored and can be assumed to NOT be noise so update target
              target[c_actuator] = c_value;
            }
            // Don't do anything if this value doesn't match the noisy check value
          }
          else {
            target[c_actuator] = c_value;  // Set a new target
            Serial.print("*M");            // Acknowledge receipt         
            Serial.print(c_actuator);
            Serial.print(c_value);
            Serial.print("!");
          }
          
          maybenoise[c_actuator] = c_value;

          break;
        case SETCOM:
          set_count(c_actuator, c_value);
          target[c_actuator] = c_value;  // Don't move from this new position
          Serial.print("*S!");
          break;
        case GETCOM:
          sprintf(buffer, "*P%u%d!", c_actuator, counter[c_actuator]);
          Serial.print(buffer);
          break;
        case CALCOM:
          // NOTE: Calibration halts the control loop
          int last = get_count(c_actuator);
          int n = DEADTIME;
          int timeout = 2000;
          while(n > 0 && timeout > 0) {
            set_PWM(c_actuator, -500);  // Move inward
            if(get_count(c_actuator) == last)
              n--;           // Count down if no movement
            else {
              n = DEADTIME;  // Reset if actuator moved
              timeout--;
            }
            
            last = get_count(c_actuator);
            
            // Now twiddle the cylon pins
            charlieplex.charlieWrite(pins[cylon], HIGH);  
            delay(50);
            charlieplex.clear();    
            if(rev) cylon--; else cylon++;
            if(cylon == 5) rev = true;
            if(cylon == 0) rev = false;            
          }

          
          set_count(c_actuator, 0);  // Set this point to be 0
          target[c_actuator] = 0;    // Set target to 0, too
          Serial.print("*C!");  // Acknowledge this is complete
          break;
        case LEGCALCOM:
          // NOTE: Calibration halts the control loop
          // This routine calibrates all three actuators of one leg in sequence
          int leg = (c_actuator%2) * 3;
          for(int l=2; l>=0; l--) {
            int last = get_count(leg + l);
            int n = DEADTIME;
            int timeout = 2000;
            while(n > 0 && timeout > 0) {
              set_PWM(leg + l, -500);  // Move inward
              if(get_count(leg + l) == last)
                n--;           // Count down if no movement
              else {
                n = DEADTIME;  // Reset if actuator moved
                timeout--;
              }
              
              last = get_count(leg + l);
              
              // Now twiddle the cylon pins
              charlieplex.charlieWrite(pins[cylon], HIGH);  
              delay(50);
              charlieplex.clear();    
              if(rev) cylon--; else cylon++;
              if(cylon == 5) rev = true;
              if(cylon == 0) rev = false;            
            }
  
            
            set_count(leg + l, 0);  // Set this point to be 0
            target[leg + l] = 0;    // Set target to 0, too
          }
          Serial.print("*C!");  // Acknowledge this is complete
          break;          
      }

      // Blink the indicator pin
      if(c_actuator >= 0 && c_actuator <= 5 && c_type == MOVCOM) {
        charlieplex.charlieWrite(pins[c_actuator], HIGH);
        indicatorDecay = 50; 
      }
     
      // Reset
      c_type = NONCOM;
      c_actuator = -1;  
      c_value = 0;
      c_neg = false;
    }
    else {
      Serial.print("*MBULLSHIT!");
    }
  }
  
  if(indicatorDecay > 0) indicatorDecay--;
  else charlieplex.clear();
  
  cycle++;
  
  for(int i=0; i<6; i++) {
    counter[i] = get_count(i);
  
    // Calculate offset and set PWM accordingly
    int error = target[i] - counter[i];
    error = map(error, -100, 100, -500, 500);
    set_PWM(i, error);
    
    
    // Write position to EEPROM every n cycles if it's different
    // MSB first
    if(cycle % SAVE_EVERY == 0) {
      if(EEPROM.read(2*i) != counter[i] >> 8)
        EEPROM.write(2*i, counter[i] >> 8);
      if(EEPROM.read(2*i+1) != counter[i] & B11111111)
        EEPROM.write(2*i+1, counter[i] & B11111111);
    }
  }
  
  /*
  //Print debug info about actuator 0
  if(cycle % 1000 == 0) {
    Serial.println("\n");
    sprintf(buffer, "%8d", target[0]);
    Serial.print(buffer);
    sprintf(buffer, "%8d", counter[0]);
    Serial.print(buffer);  
    sprintf(buffer, "%8d", target[0] - counter[0]);
    Serial.print(buffer);  
  }
  */
  
} 


// Don't leave pins floating -- this leaves them susceptible to noise. Make sure they are connected OR pulled to ground!
// If running board and actuator on different power supplies, make sure the grounds are tied together!

// 2600N actuator: 0.417mm/count
