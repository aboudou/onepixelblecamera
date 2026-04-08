#include <Arduino.h>
#include <ArduinoBLE.h>
#include <Servo.h>
#include <WiFiNINA.h>

enum status {
  READY_TO_CAPTURE = 0,
  CAPTURING = 1,
  DISCONNECTED = 2
};

const int width = 160;
const int height = 100;

byte currentStatus = DISCONNECTED;
char currentPixel[11] = "0#0"; // Index and value as a string (e.g., "585#1012" for index 585 and value 1012)
constexpr bool debugEnabled = false;
constexpr bool verboseLogEnabled = false;
constexpr bool rawDebugEnabled = false;

BLEService cameraService("688c6011-fa63-429b-bea4-18517d46c9ee"); // Camera service
BLEByteCharacteristic statusChar("cbedefb3-b8ec-4656-b7db-96271f7f33d2", BLEWrite | BLENotify); // Status characteristic
BLEStringCharacteristic currentPixelChar("081458cb-264d-4b7f-8007-4e0cfbbe2300", BLENotify, 11); // Current pixel value characteristic

Servo servoPan;
Servo servoTilt;

void updateStatusLed();
void setWifiLEDs(uint8_t red, uint8_t green, uint8_t blue);
int readSensorAverage();
template <typename T>
void debug(T c);
template <typename T>
void debugln(T c);

void setup() {
  if (debugEnabled) {
    Serial.begin(9600);
    while (!Serial);

  } else if (rawDebugEnabled) {
    // Bypass the main program logic and just print raw sensor values for debugging purposes
    Serial.begin(9600);
    while (!Serial);

    while(true) {
      delay(100);
      int sensorValue = readSensorAverage();
      Serial.print("Raw sensor value: ");
      Serial.println(sensorValue);
    }
  }

  if (!BLE.begin()) {
    debugln("starting Bluetooth® Low Energy failed!");
    while (1);
  }

  WiFiDrv::pinMode(25, OUTPUT);
  WiFiDrv::pinMode(26, OUTPUT);
  WiFiDrv::pinMode(27, OUTPUT);

  servoPan.attach(4);
  servoTilt.attach(5);

  BLE.setLocalName("1Pixel Camera");
  BLE.setDeviceName("1Pixel Camera");
  BLE.setAdvertisedService(cameraService);

  cameraService.addCharacteristic(statusChar);
  cameraService.addCharacteristic(currentPixelChar);
  BLE.addService(cameraService);

  statusChar.writeValue(currentStatus);
  currentPixelChar.writeValue(currentPixel);

  BLE.advertise();
  updateStatusLed();
  debugln(" Bluetooth® device active, waiting for connections...");
}

void loop() {

  BLEDevice central = BLE.central();
  if (central) {
    debug("Connected to central: ");
    debugln(central.address());

    currentStatus = READY_TO_CAPTURE;
    statusChar.writeValue(currentStatus);

    while (central.connected()) {
      currentStatus = statusChar.value();
      updateStatusLed();

      if (currentStatus == CAPTURING) {
        updateStatusLed();
        debugln("Capturing and transmitting pixel data...");    
        int i = 0;
        for (int y = 1000; y < 2000; y=y+(1000/height)) {
          if (!central.connected()) {
            debugln("Central disconnected during capture.");
            break;
          }

          servoTilt.writeMicroseconds(y);
          delay(10);
          servoPan.writeMicroseconds(2080);
          delay(800);
    
          for (int x = 2080; x > 800; x=x-(1280/width)) { 
            servoPan.writeMicroseconds(x);
            delay(20);
            
            int sensorValue = readSensorAverage();
            snprintf(currentPixel, sizeof(currentPixel), "%d#%d", i, sensorValue);
            currentPixelChar.writeValue(currentPixel);

            if (verboseLogEnabled) {
              debug("Transmitted pixel index: ");
              debug(i);
              debug(", value: ");
              debugln(sensorValue);
            }
                
            i++;
          }
          delay(300);
  
        }
        currentPixelChar.writeValue("EOT"); // End of transmission indicator

        debugln("Capture done.");

        currentStatus = READY_TO_CAPTURE;
        statusChar.writeValue(currentStatus);
      }
    }

    debug("Disconnected from central: ");
    debugln(central.address());
    currentStatus = DISCONNECTED;
    statusChar.writeValue(currentStatus);
    updateStatusLed();
  }
    
}

void updateStatusLed() {
  switch (currentStatus) {
    case DISCONNECTED:
    setWifiLEDs(255, 0, 0);
    break;

    case READY_TO_CAPTURE:
    setWifiLEDs(0, 0, 255);
    break;

    case CAPTURING:
    setWifiLEDs(0, 255, 0);
    break;

  }
}

void setWifiLEDs(uint8_t red, uint8_t green, uint8_t blue) {
  WiFiDrv::analogWrite(25, green);
  WiFiDrv::analogWrite(26, red);
  WiFiDrv::analogWrite(27, blue);
}

int readSensorAverage() {
  analogRead(A1); // Dummy read to stabilize the sensor
  delay(1);
  return (analogRead(A1) + analogRead(A1) + analogRead(A1) + analogRead(A1)) / 4;
}

template<typename T>
void debug(T c) {
  if (debugEnabled) Serial.print(c);
}

template<typename T>
void debugln(T c) {
  if (debugEnabled) Serial.println(c);
}