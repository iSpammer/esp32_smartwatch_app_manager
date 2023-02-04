#pragma mark - Depend SparkFun_MAX3010x_Sensor_Library
#pragma mark - Depend MAX30208_Library
#pragma mark - Depend SparkFun_VEML6075_Arduino_Library

#include "config.h"

#include "BluetoothSerial.h"


#include "config.h"

#include <Wire.h>

#include "MAX30105.h"
#include "MAX30208.h"
#include <SparkFun_VEML6075_Arduino_Library.h>


#include "heartRate.h"

#include "spo2_algorithm.h"


TTGOClass * watch;
TFT_eSPI * tft;
MAX30105 particleSensor;
MAX30208_Class tempSensor;
VEML6075 uv;
BMA *accSensor;


#define MAX30208_INT_PIN            4
#define MAX30208_SLAVE_ADDRESS      0x50


const uint8_t RATE_SIZE = 20; //Increase this for more averaging.
uint8_t rates[RATE_SIZE]; //Array of heart rates
uint8_t rateSpot = 0;
long lastBeat = 0; //Time at which the last beat occurred

float beatsPerMinute = 0;
int beatAvg = 0;
int prevBPM = 0;
int reading_flag = 0;

int countdown = 0; // 10 minutes in milliseconds
unsigned long previousMillis = 0;

int temp = 0;
float temp_error = 0;
int uv_error = 0;

float uva = 0;
float uvb = 0;
float uvindx = 0;

float xacc = 0;
float yacc = 0;
float zacc = 0;

int batSOC = 0;

#if!defined(CONFIG_BT_ENABLED) || !defined(CONFIG_BLUEDROID_ENABLED)
#error Bluetooth is not enabled!Please run `make menuconfig`
to and enable it
#endif

BluetoothSerial SerialBT;

// drawing battery icon
void drawRect(uint16_t x0, uint16_t y0, uint16_t w, uint16_t h, uint16_t color);
void fillRect(uint16_t x0, uint16_t y0, uint16_t w, uint16_t h, uint16_t color);

bool rtcIrq = false;

char
const * WEEKDAYS[] = {
  "SUN",
  "MON",
  "TUE",
  "WED",
  "THU",
  "FRU",
  "SAT"
};

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


// setup the heart rate sensor
void setupHR(){
  if (!particleSensor.begin(Wire, I2C_SPEED_FAST)) { //Use default I2C port, 400kHz speed
    Serial.println("Sensor was not found. Please check wiring/power. ");
    while (1);
  }
  watch -> tft -> drawCentreString("OssWatch", 120, 60, 2);
  particleSensor.setup();
  particleSensor.setPulseAmplitudeRed(0xFF);
  particleSensor.setPulseAmplitudeGreen(0);
  Serial.println("Place your index finger on the sensor with steady pressure.");

}


// setup the watch clock
void setupTemp(){
    /*
  * The default address is 0x51, which conflicts with the TWATCH RTC chip.
  * Set MAX30208 INT to LOW and change the address to 0x50.
  * * */
  pinMode(MAX30208_INT_PIN, OUTPUT);
  digitalWrite(MAX30208_INT_PIN, LOW);

  if (tempSensor.begin(Wire, MAX30208_SLAVE_ADDRESS) == false) {
    Serial.println("Unable to communicate with MAX30208.");
    // tft->println("Unable to communicate with Sensor.");
    temp_error = 1;
  }

  if (temp_error == 0){
    // Turn on temperature conversion complete interrupt
    tempSensor.enableDATARDY();

    // Start the conversion
    tempSensor.startConvert();
  }
}


// setup the UV sensor
void setupUV(){
  Wire1.begin(25, 26);
  if (uv.begin(Wire1) == false) {
    Serial.println("Unable to communicate with VEML6075.");
    uv_error = 1;
  }
}


// call the setup methods
void setup() {

  Serial.begin(115200);
  SerialBT.begin("OssWatch"); //Bluetooth device name
  Serial.println("The device started, now you can pair it with bluetooth!");

  // Get TTGOClass instance
  watch = TTGOClass::getWatch();

  // Initialize the hardware
  watch -> begin();

  // Turn on the backlight
  watch -> openBL();

  //Receive objects for easy writing
  tft = watch -> tft;

  // Initialize sensor
  setupHR();
  //accl 
  setupAcc();

  // batery
  watch -> power -> adc1Enable(AXP202_VBUS_VOL_ADC1 | AXP202_VBUS_CUR_ADC1 | AXP202_BATT_CUR_ADC1 | AXP202_BATT_VOL_ADC1, true);
  // pink floyed time

  pinMode(RTC_INT_PIN, INPUT_PULLUP);
  attachInterrupt(RTC_INT_PIN, [] {
    rtcIrq = 1;
  }, FALLING);
  watch -> rtc -> disableAlarm();
  watch -> rtc -> setDateTime(2020, 8, 12, 15, 0, 53);
  watch -> rtc -> setAlarmByMinutes(1);
  watch -> rtc -> enableAlarm();



  // temp sensor
  setupTemp();
  // UVSensor
  setupUV();

  

}


// update the texts displayed on the watch
void updateText() {
  watch -> tft -> setTextSize(2);
  watch -> tft -> setCursor(0, 0);
  watch -> tft -> setTextColor(TFT_ORANGE, TFT_BLACK);
  watch -> tft -> print("Battery:");
  watch -> tft -> print(batSOC);
  watch -> tft -> println("%");
  watch -> tft -> print("Temp: ");
  watch -> tft -> print(temp);
  watch -> tft -> print((char) 247);
  watch -> tft -> print("C");

  int chargeOffset = map(batSOC, 0, 100, 0, 17);

  //  Draw Battery Charged Icon
  watch -> tft -> fillRect(150, 0, 20, 10, TFT_GREEN);
  watch -> tft -> fillRect(146, 3, 4, 4, TFT_GREEN);
  watch -> tft -> fillRect(152, 2, 16 - chargeOffset, 6, TFT_BLACK);

  if (rtcIrq && countdown <= 0) {
    rtcIrq = 0;
    detachInterrupt(RTC_INT_PIN);
    watch -> rtc -> resetAlarm();
    watch -> tft -> setTextColor(TFT_WHITE, TFT_RED);
    RTC_Date tnow = watch -> rtc -> getDateTime();

    watch -> tft -> setCursor(0, 220);

    watch -> tft -> print(tnow.hour);
    watch -> tft -> print(":");
    watch -> tft -> print(tnow.minute);
    watch -> tft -> print(" ");
    watch -> tft -> print(tnow.day);
    watch -> tft -> print("/");
    watch -> tft -> print(tnow.month);
    watch -> tft -> print("/");
    watch -> tft -> print(tnow.year % 100);
    watch -> tft -> print("  ");

    watch -> tft -> print(WEEKDAYS[watch -> rtc -> getDayOfWeek(tnow.day, tnow.month, tnow.year)]);

    // countdown = 600;
  }
}


// unused method
String* split(String name){
  String array[50];
  int r=0,t=0;
  for(int i=0;i<name.length();i++)
  {
    if(name[i] == ' ' || name[i] == ',')
    {
      if (i-r > 1)
      {
        array[t] = name.substring(r,i);
        t++;
      }
      r = (i+1);
    }
  }

  for(int k=0 ;k<=t ;k++)
  {
    Serial.println(array[k]);
  }
  return array;

}


// update the time, unused
void updateTime(){
  String message = "";
  if (SerialBT.available()){
    char incomingChar = SerialBT.read();
    if (incomingChar != '\n'){
      message += String(incomingChar);
    }
    else{
      message = "";
    }
    Serial.write(incomingChar);
    if (message != ""){
      String arraysplit(message);
      watch -> rtc -> setDateTime(2020, 8, 12, 15, 0, 53);
    }  
  }
}



// update the heart rate readings
void updateBPM() {
  // Serial.println("meaw1");
  particleSensor.check(); //Check the sensor, read up to 3 samples
  while (particleSensor.available()) { //do we have new data?
    Serial.println("meaw2");

    long irValue = particleSensor.getFIFOIR();
    Serial.println("meaw is "+String(irValue));
    if (irValue < 50000) {
      return;
    }
    Serial.println("asd "+String(checkForBeat(irValue)));
    if (checkForBeat(irValue) == true) {

      //We sensed a beat!
      long delta = millis() - lastBeat;
      lastBeat = millis();
      Serial.println("meawwwwwwww");
      beatsPerMinute = 60 / (delta / 1000.0);

      if (beatsPerMinute < 255 && beatsPerMinute > 30) {
        rates[rateSpot++] = (uint8_t) beatsPerMinute; //Store this reading in the array
        rateSpot %= RATE_SIZE; //Wrap variable

        //Take average of readings
        beatAvg = 0;
        for (uint8_t x = 0; x < RATE_SIZE; x++)
          beatAvg += rates[x];
        beatAvg /= RATE_SIZE;
      }

    }
   

    if (prevBPM != beatAvg) {
      reading_flag = 1;
      prevBPM = beatAvg;
              
     // if (countdown <= 0) {
        watch -> tft -> setTextColor(TFT_GREEN);
        static char buffer[256];
        watch -> tft -> fillRect(0, 120, 240, 30, TFT_RED);
        snprintf(buffer, sizeof(buffer), "Avg BPM:%d", beatAvg);
        watch -> tft -> drawCentreString(buffer, 240 / 2, 120, 2);

        // SerialBT.print("********Heart Rate: ");
        SerialBT.println(String(beatAvg) + " " + String(beatsPerMinute) + " " + String(batSOC) + " " + String(temp) + " " + String(watch -> power -> isChargeing())+ " "+ String(xacc)+ " "+ String(yacc)+ " "+ String(zacc) + " "+ String(uva)+ " "+ String(uvb)+ " "+ String(uvindx));
        Serial.println(String(beatAvg) + " " + String(beatsPerMinute) + " " + String(batSOC) + " " + String(temp) + " " + String(watch -> power -> isChargeing())+ " "+ String(xacc)+ " "+ String(yacc)+ " "+ String(zacc) + " "+ String(uva)+ " "+ String(uvb)+ " "+ String(uvindx));
        // countdown = 1000; // reset countdown
      }
     else {
      reading_flag = 0;
    }
    // }
    particleSensor.nextSample(); //We're finished with this sample so move to next sample 
  }
}

// update the temperature readings
void updateTemp(){
      uint8_t mask = tempSensor.getINT();
    if (mask & MAX30208_INT_STATUS_TEMP_RDY) {
        tempSensor.check();
        temp = tempSensor.readTemperature();
        
        Serial.printf("Temp:%.2f\n", temp);

        //Start the next conversion
        tempSensor.startConvert();
    }
}

// update the UV readings
void updateUV(){
    uva = uv.uva();
    uvb = uv.uvb();
    uvindx = uv.index();
}


// update the accelerometer readings
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

// send the reading to the connected bluetooth device
void updateWatch(){

  if(reading_flag == 0){
    SerialBT.println(String(beatAvg) + " " + String(beatsPerMinute) + " " + String(batSOC) + " " + String(temp) + " " + String(watch -> power -> isChargeing())+ " "+ String(xacc)+ " "+ String(yacc)+ " "+ String(zacc) + " "+ String(uva)+ " "+ String(uvb)+ " "+ String(uvindx));
    Serial.println(String(beatAvg) + " " + String(beatsPerMinute) + " " + String(batSOC) + " " + String(temp) + " " + String(watch -> power -> isChargeing())+ " "+ String(xacc)+ " "+ String(yacc)+ " "+ String(zacc) + " "+ String(uva)+ " "+ String(uvb)+ " "+ String(uvindx));
  }
}


// main loop method
void loop() {

  // countdown = countdown - (millis() - previousMillis);
  // previousMillis = millis();
  batSOC = watch -> power -> getBattPercentage();
  // if (temp_error == 1){
    //     temp = watch -> power -> getTemp();

  // }
  // else{
  //   updateTemp();
  // }

  temp = watch -> power -> getTemp();

  updateBPM();

  updateText();

    if (uv_error == 0){
    updateUV();
  }
  updateAcc();

  updateWatch();
  
}