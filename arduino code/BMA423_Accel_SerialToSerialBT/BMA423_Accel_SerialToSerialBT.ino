/*
    DigiAsia
    (c) Ossama, 2023
    All rights reserved.

    Functionality: 
    
    Version log:
    
    2023-04-13:
        v1.0.0  - Initial Public Beta
        
*/
// ==== DEFINES ===================================================================================

// ==== Debug and Test options ==================
#define _DEBUG_
//#define _TEST_

//===== Debugging macros ========================
#ifdef _DEBUG_
#define SerialD Serial
#define _PM(a) SerialD.print(millis()); SerialD.print(": "); SerialD.println(a)
#define _PP(a) SerialD.print(a)
#define _PL(a) SerialD.println(a)
#define _PX(a) SerialD.println(a, HEX)
#else
#define _PM(a)
#define _PP(a)
#define _PL(a)
#define _PX(a)
#endif




// ==== INCLUDES ==================================================================================
#include <Wire.h>
#include "MAX30105.h"
#include "config.h"
#include "heartRate.h"
#include "BluetoothSerial.h"


// edge cloud stuff
#include <WiFi.h>
#include <ArduinoJson.h>
#include "time.h"
#include <HTTPClient.h>
#include <WiFiMulti.h>
WiFiMulti wifiMulti;


//for watch to Pi via wifi change this flag to 0, for watch to android/ios via bluetooth change this flag to 1
int direction_flag = 1;

// Insert your network credentials
#define WIFI_SSID "Heker"
#define WIFI_PASSWORD "meawmeawpsps123"
// #define RASPBERRY_PI_SERVER_IP_PORT "http://192.168.43.51:8000"

// // Variable to save USER UID, always update the number with the watch Serial Number before flashing tools>get board info 
String uuid = "5479028817@watch.esp";

//Intialise BT
BluetoothSerial SerialBT;

//t watch classes
TTGOClass * watch;
TFT_eSPI * tft;


//acc sensor
BMA *accSensor;
float xacc = 0;
float yacc = 0;
float zacc = 0;

//battery
int batSOC = 0;

// heart rate data
MAX30105 particleSensor;

const byte RATE_SIZE = 20; //Increase this for more averaging. 4 is good.
byte rates[RATE_SIZE]; //Array of heart rates
byte rateSpot = 0;
long lastBeat = 0; //Time at which the last beat occurred

float beatsPerMinute;
int beatAvg;

// ==== Uncomment desired compile options =================================
// ----------------------------------------
// The following "defines" control library functionality at compile time,
// and should be used in the main sketch depending on the functionality required
// Should be defined BEFORE #include <TaskScheduler.h>  !!!
//
// #define _TASK_TIMECRITICAL       // Enable monitoring scheduling overruns
// #define _TASK_SLEEP_ON_IDLE_RUN  // Enable 1 ms SLEEP_IDLE powerdowns between runs if no callback methods were invoked during the pass
// #define _TASK_STATUS_REQUEST     // Compile with support for StatusRequest functionality - triggering tasks on status change events in addition to time only
// #define _TASK_WDT_IDS            // Compile with support for wdt control points and task ids
// #define _TASK_LTS_POINTER        // Compile with support for local task storage pointer
// #define _TASK_PRIORITY           // Support for layered scheduling priority
// #define _TASK_MICRO_RES          // Support for microsecond resolution
// #define _TASK_STD_FUNCTION       // Support for std::function (ESP8266 ONLY)
// #define _TASK_DEBUG              // Make all methods and variables public for debug purposes
// #define _TASK_INLINE             // Make all methods "inline" - needed to support some multi-tab, multi-file implementations
// #define _TASK_TIMEOUT            // Support for overall task timeout
// #define _TASK_OO_CALLBACKS       // Support for callbacks via inheritance
// #define _TASK_EXPOSE_CHAIN       // Methods to access tasks in the task chain
// #define _TASK_SCHEDULING_OPTIONS // Support for multiple scheduling options
// #define _TASK_DEFINE_MILLIS      // Force forward declaration of millis() and micros() "C" style
// #define _TASK_EXTERNAL_TIME      // Custom millis() and micros() methods
// #define _TASK_THREAD_SAFE        // Enable additional checking for thread safety
// #define _TASK_SELF_DESTRUCT      // Enable tasks to "self-destruct" after disable

#include <TaskScheduler.h>



// ==== GLOBALS ===================================================================================
// ==== Scheduler ==============================
Scheduler ts;

void task1Callback();
void task2Callback();

// ==== Scheduling defines (cheat sheet) =====================
/*
  TASK_MILLISECOND  - one millisecond in millisecond/microseconds
  TASK_SECOND       - one second in millisecond/microseconds
  TASK_MINUTE       - one minute in millisecond/microseconds
  TASK_HOUR         - one hour in millisecond/microseconds
  TASK_IMMEDIATE    - schedule task to runn as soon as possible
  TASK_FOREVER      - run task indefinitely
  TASK_ONCE         - run task once
  TASK_NOTIMEOUT    - set timeout interval to No Timeout
  
  TASK_SCHEDULE     - schedule is a priority, with "catch up" (default)
  TASK_SCHEDULE_NC  - schedule is a priority, without "catch up"
  TASK_INTERVAL     - interval is a priority, without "catch up"
  
  TASK_SR_OK        - status request triggered with an OK code (all good)
  TASK_SR_ERROR     - status request triggered with an ERROR code
  TASK_SR_CANCEL    - status request was cancelled
  TASK_SR_ABORT     - status request was aborted
  TASK_SR_TIMEOUT   - status request timed out
*/

// ==== Task definitions ========================
Task t1 (TASK_IMMEDIATE, TASK_FOREVER, &task1Callback, &ts, true);
Task t2 (TASK_IMMEDIATE, TASK_FOREVER, &task2Callback, &ts, true);



// ==== CODE ======================================================================================

/**************************************************************************/
/*!
    @brief    Standard Arduino SETUP method - initialize sketch
    @param    none
    @returns  none
*/
/**************************************************************************/
void setup() {
if(direction_flag == 1){
    SerialBT.begin("OssWatch"); //Bluetooth device name
  }

  // Initialize heart rate sensor
  if (!particleSensor.begin(Wire, I2C_SPEED_FAST)) //Use default I2C port, 400kHz speed
  {
    Serial.println("MAX30105 was not found. Please check wiring/power. ");
    while (1);
  }
  Serial.println("Place your index finger on the sensor with steady pressure.");

  particleSensor.setup(); //Configure sensor with default settings
  particleSensor.setPulseAmplitudeRed(0x0A); //Turn Red LED to low to indicate sensor is running
  particleSensor.setPulseAmplitudeGreen(0); //Turn off Green LED


  //intialise watch components
   // Get TTGOClass instance
  watch = TTGOClass::getWatch();

  // Initialize the hardware
  watch -> begin();

  // Turn on the backlight
  watch -> openBL();

  //Receive objects for easy writing
  tft = watch -> tft;
  // end watch components


  if(direction_flag == 0){
    // intialise wifi
    initWiFi();
  }


  // initalise acc
  setupAcc();

  // intialise batery percentage reading sensor
  watch -> power -> adc1Enable(AXP202_VBUS_VOL_ADC1 | AXP202_VBUS_CUR_ADC1 | AXP202_BATT_CUR_ADC1 | AXP202_BATT_VOL_ADC1, true);


  if(direction_flag == 0){
    // register the edge to the Pi if it's not registered
    registerEdge();
  }
  #if defined(_DEBUG_) || defined(_TEST_)
  Serial.begin(115200);
  delay(2000);
  _PL("Scheduler Template: setup()");
#endif
}


/**************************************************************************/
/*!
    @brief    Standard Arduino LOOP method - using with TaskScheduler there 
              should be nothing here but ts.execute()
    @param    none
    @returns  none
*/
/**************************************************************************/
void loop() {
  ts.execute();
}

// ==== Helper Functions ===================================================

// Initialize WiFi
void initWiFi() {
  wifiMulti.addAP(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connecting to WiFi ..");
}

// setup the accelerometer sensor
void setupAcc(){
  accSensor = watch->bma;

  // Accel parameter structure
  Acfg cfg;
  /*!
      Output data rate in Hz, Optional parameters:
          - BMA4_OUTPUT_DATA_RATE_0_78HZ
          - BMA4_OUTPUT_DATA_RATE_1_56HZ
          - BMA4_OUTPUT_DATA_RATE_3_12HZ
          - BMA4_OUTPUT_DATA_RATE_6_25HZ
          - BMA4_OUTPUT_DATA_RATE_12_5HZ
          - BMA4_OUTPUT_DATA_RATE_25HZ
          - BMA4_OUTPUT_DATA_RATE_50HZ
          - BMA4_OUTPUT_DATA_RATE_100HZ
          - BMA4_OUTPUT_DATA_RATE_200HZ
          - BMA4_OUTPUT_DATA_RATE_400HZ
          - BMA4_OUTPUT_DATA_RATE_800HZ
          - BMA4_OUTPUT_DATA_RATE_1600HZ
  */
  cfg.odr = BMA4_OUTPUT_DATA_RATE_100HZ;
  /*!
      G-range, Optional parameters:
          - BMA4_ACCEL_RANGE_2G
          - BMA4_ACCEL_RANGE_4G
          - BMA4_ACCEL_RANGE_8G
          - BMA4_ACCEL_RANGE_16G
  */
  cfg.range = BMA4_ACCEL_RANGE_2G;
  /*!
      Bandwidth parameter, determines filter configuration, Optional parameters:
          - BMA4_ACCEL_OSR4_AVG1
          - BMA4_ACCEL_OSR2_AVG2
          - BMA4_ACCEL_NORMAL_AVG4
          - BMA4_ACCEL_CIC_AVG8
          - BMA4_ACCEL_RES_AVG16
          - BMA4_ACCEL_RES_AVG32
          - BMA4_ACCEL_RES_AVG64
          - BMA4_ACCEL_RES_AVG128
  */
  cfg.bandwidth = BMA4_ACCEL_NORMAL_AVG4;

  /*! Filter performance mode , Optional parameters:
      - BMA4_CIC_AVG_MODE
      - BMA4_CONTINUOUS_MODE
  */
  cfg.perf_mode = BMA4_CONTINUOUS_MODE;

  // Configure the BMA423 accelerometer
  accSensor->accelConfig(cfg);

  // Enable BMA423 accelerometer
  accSensor->enableAccel();

  // You can also turn it off
  // accSensor->disableAccel();
}

// register the watch with the edge
void registerEdge() {
 
  Serial.println("registering with the server...");
  // Block until we are able to connect to the WiFi access point
  if (wifiMulti.run() == WL_CONNECTED) {
     
    HTTPClient http;   
     
    http.begin("http://192.168.43.51:8000/api/register");  
    http.addHeader("Content-Type", "application/json");         
     
    StaticJsonDocument<200> doc;
    // Add values in the document
    //
    doc["email"] = uuid;
    doc["password"] = 12345678;
    doc["password_confirmation"] = 12345678;
    doc["name"] = "Watch SN 5479028817";

    String requestBody;
    serializeJson(doc, requestBody);
     
    int httpResponseCode = http.POST(requestBody);
 
    if(httpResponseCode>0){
       
      String response = http.getString();                       
       
      Serial.println(httpResponseCode);   
      Serial.println(response);
     
    }
    else {
     
      Serial.print("Error occurred while sending HTTP POST: \n"+String(httpResponseCode));
       
    }
     
  }
}


// update the edge
void updateEdge() {
  Serial.println("Posting JSON data to server...");
  // Block until we are able to connect to the WiFi access point
  if (wifiMulti.run() == WL_CONNECTED) {
     
    HTTPClient http;   
     
    http.begin("http://192.168.43.51:8000/api/hrs");  
    http.addHeader("Content-Type", "application/json");         
     
    StaticJsonDocument<200> doc;
    // Add values in the document
    //

    doc["curr_hr"] = beatsPerMinute;
    doc["avg_hr"] = beatAvg;
    doc["xacc"] = xacc;
    doc["yacc"] = yacc;
    doc["zacc"] = zacc;
    doc["user_id"] = uuid;
   
     
    String requestBody;
    serializeJson(doc, requestBody);
     
    int httpResponseCode = http.POST(requestBody);
 
    if(httpResponseCode>0){
       
      String response = http.getString();                       
       
      Serial.println(httpResponseCode);   
      Serial.println(response);
     
    }
    else {
      Serial.print("Error occurred while sending HTTP POST: \n"+String(httpResponseCode));  
    }
  }
}


// update the texts displayed on the watch
void updateText() {
  watch -> tft -> setTextSize(2);
  watch -> tft -> setCursor(0, 0);
  watch -> tft -> setTextColor(TFT_ORANGE, TFT_BLACK);
  watch -> tft -> print("Battery:");
  watch -> tft -> print(batSOC);
  watch -> tft -> println("%");
  

  if(beatAvg > 55){
    watch -> tft -> print("BPM: ");

    watch -> tft -> println(beatAvg+"        ");  
  }
  else{
    watch -> tft -> print("Calibrating");

  }


  int chargeOffset = map(batSOC, 0, 100, 0, 17);

  //  Draw Battery Charged Icon
  watch -> tft -> fillRect(150, 0, 20, 10, TFT_GREEN);
  watch -> tft -> fillRect(146, 3, 4, 4, TFT_GREEN);
  watch -> tft -> fillRect(152, 2, 16 - chargeOffset, 6, TFT_BLACK);
}


// accelerometer sensor readings
void updateAcc(){
  Accel acc;

  // Get acceleration data
  bool res = accSensor->getAccel(acc);

  if (res == false) {
    Serial.println("getAccel FAIL");
  } 
  else {
    xacc = acc.x;
    yacc = acc.y;
    zacc = acc.z;
  }
}


// send the reading to the connected bluetooth/WiFi device
void updateWatch(){
  int temp = 0;
  int uva = 0;
  int uvb = 0;
  int uvindx = 0;

  if(direction_flag == 1){
    SerialBT.println(String(beatAvg) + " " + String(beatsPerMinute) + " " + String(batSOC) + " " + String(temp) + " " + String(watch -> power -> isChargeing())+ " "+ String(xacc)+ " "+ String(yacc)+ " "+ String(zacc) + " "+ String(uva)+ " "+ String(uvb)+ " "+ String(uvindx));
    Serial.println(String(beatAvg) + " " + String(beatsPerMinute) + " " + String(batSOC) + " " + String(temp) + " " + String(watch -> power -> isChargeing())+ " "+ String(xacc)+ " "+ String(yacc)+ " "+ String(zacc) + " "+ String(uva)+ " "+ String(uvb)+ " "+ String(uvindx));
  }
  else{
    updateEdge();
  }
  
}





/**************************************************************************/
/*!
    @brief    Callback method of task1 - main heart rate loop, need to be on seperate task
    @param    none
    @returns  none
*/
/**************************************************************************/
void task1Callback() {


  long irValue = particleSensor.getIR();

  if (checkForBeat(irValue) == true)
  {
    //We sensed a beat!
    long delta = millis() - lastBeat;
    lastBeat = millis();

    beatsPerMinute = 60 / (delta / 1000.0);

    if (beatsPerMinute < 255 && beatsPerMinute > 50)
    {
      rates[rateSpot++] = (byte)beatsPerMinute; //Store this reading in the array
      rateSpot %= RATE_SIZE; //Wrap variable

      //Take average of readings
      beatAvg = 0;
      for (byte x = 0 ; x < RATE_SIZE ; x++)
        beatAvg += rates[x];
      beatAvg /= RATE_SIZE;
    }
  }

  Serial.print("IR=");
  Serial.print(irValue);
  Serial.print(", BPM=");
  Serial.print(beatsPerMinute);
  Serial.print(", Avg BPM=");
  Serial.print(beatAvg);

  if (irValue < 50000)
    Serial.print(" No finger?");

  Serial.println();

}


/**************************************************************************/
/*!
    @brief    Callback method of task2 - send the data to the cloud, update accelerometer and battery status
    @param    none
    @returns  none
*/
/**************************************************************************/
void task2Callback() {
  batSOC = watch -> power -> getBattPercentage();
  updateText();

  updateAcc();
 if(beatAvg > 50){
      updateWatch();
    }

  
}



