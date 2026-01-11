
/*
 * Smart Parking System - ESP32 Code
 *
 * Features:
 * - 3 Ultrasonic sensors for parking slot detection
 * - LCD 16x2 display for local status
 * - Firebase Realtime Database integration
 * - WiFi connectivity
 *
 * Hardware:
 * - ESP32 Dev Board
 * - 3x HC-SR04 Ultrasonic Sensors
 * - LCD 16x2 with I2C
 * - 2x 18650 batteries + 5V step-down
 */

#include <WiFi.h>
#include <FirebaseESP32.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>

// ===== WiFi Credentials =====
#define WIFI_SSID "ITIDA"
#define WIFI_PASSWORD "12345678"

// ===== Firebase Configuration =====
#define FIREBASE_HOST "https://stem-53cdc-default-rtdb.firebaseio.com/"
#define FIREBASE_AUTH "UlqdAaYSCRjTcqFBRVW0df1Y513SLgoJ2vuZ2lZO"

// ===== Ultrasonic Sensor Pins =====
// Slot A
#define TRIG_A 5
#define ECHO_A 18

// Slot B
#define TRIG_B 19
#define ECHO_B 21

// Slot C
#define TRIG_C 22
#define ECHO_C 23

// ===== LCD Configuration =====
#define LCD_ADDRESS 0x27  // Change to 0x3F if 0x27 doesn't work
#define LCD_COLUMNS 16
#define LCD_ROWS 2

// ===== Detection Settings =====
#define DISTANCE_THRESHOLD 15  // Distance in cm to consider slot occupied
#define UPDATE_INTERVAL 1000   // Update every 1 second

// ===== Global Objects =====
FirebaseData firebaseData;
FirebaseConfig firebaseConfig;
FirebaseAuth firebaseAuth;
LiquidCrystal_I2C lcd(LCD_ADDRESS, LCD_COLUMNS, LCD_ROWS);

// ===== Global Variables =====
bool slotA_occupied = false;
bool slotB_occupied = false;
bool slotC_occupied = false;
int availableSlots = 3;
unsigned long lastUpdate = 0;

// ===== Function Declarations =====
float getDistance(int trigPin, int echoPin);
void updateLCD();
void sendToFirebase();
void connectWiFi();
void initFirebase();

void setup() {
  Serial.begin(115200);
  Serial.println("Smart Parking System Starting...");

  // Initialize ultrasonic sensors
  pinMode(TRIG_A, OUTPUT);
  pinMode(ECHO_A, INPUT);
  pinMode(TRIG_B, OUTPUT);
  pinMode(ECHO_B, INPUT);
  pinMode(TRIG_C, OUTPUT);
  pinMode(ECHO_C, INPUT);

  // Initialize LCD
  lcd.init();
  lcd.backlight();
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Smart Parking");
  lcd.setCursor(0, 1);
  lcd.print("Initializing...");

  delay(2000);

  // Connect to WiFi
  connectWiFi();

  // Initialize Firebase
  initFirebase();

  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("System Ready!");
  delay(1000);
}

void loop() {
  unsigned long currentMillis = millis();

  // Update every second
  if (currentMillis - lastUpdate >= UPDATE_INTERVAL) {
    lastUpdate = currentMillis;

    // Read distances from sensors
    float distA = getDistance(TRIG_A, ECHO_A);
    float distB = getDistance(TRIG_B, ECHO_B);
    float distC = getDistance(TRIG_C, ECHO_C);

    // Determine slot occupancy
    slotA_occupied = (distA > 0 && distA < DISTANCE_THRESHOLD);
    slotB_occupied = (distB > 0 && distB < DISTANCE_THRESHOLD);
    slotC_occupied = (distC > 0 && distC < DISTANCE_THRESHOLD);

    // Calculate available slots
    availableSlots = 0;
    if (!slotA_occupied) availableSlots++;
    if (!slotB_occupied) availableSlots++;
    if (!slotC_occupied) availableSlots++;

    // Debug output
    Serial.println("=== Parking Status ===");
    Serial.printf("Slot A: %.1fcm - %s\n", distA, slotA_occupied ? "OCCUPIED" : "AVAILABLE");
    Serial.printf("Slot B: %.1fcm - %s\n", distB, slotB_occupied ? "OCCUPIED" : "AVAILABLE");
    Serial.printf("Slot C: %.1fcm - %s\n", distC, slotC_occupied ? "OCCUPIED" : "AVAILABLE");
    Serial.printf("Available: %d/3\n\n", availableSlots);

    // Update LCD display
    updateLCD();

    // Send data to Firebase
    if (WiFi.status() == WL_CONNECTED) {
      sendToFirebase();
    } else {
      Serial.println("WiFi disconnected! Reconnecting...");
      connectWiFi();
    }
  }
}

// ===== Get Distance from Ultrasonic Sensor =====
float getDistance(int trigPin, int echoPin) {
  digitalWrite(trigPin, LOW);
  delayMicroseconds(2);
  digitalWrite(trigPin, HIGH);
  delayMicroseconds(10);
  digitalWrite(trigPin, LOW);

  long duration = pulseIn(echoPin, HIGH, 30000); // 30ms timeout

  if (duration == 0) {
    return -1; // No echo received
  }

  float distance = duration * 0.034 / 2; // Speed of sound: 340m/s
  return distance;
}

// ===== Update LCD Display =====
void updateLCD() {
  lcd.clear();

  // Line 1: Show individual slot status
  lcd.setCursor(0, 0);
  lcd.print("A:");
  lcd.print(slotA_occupied ? "X" : "O");
  lcd.print(" B:");
  lcd.print(slotB_occupied ? "X" : "O");
  lcd.print(" C:");
  lcd.print(slotC_occupied ? "X" : "O");

  // Line 2: Show available count
  lcd.setCursor(0, 1);
  lcd.print("Free: ");
  lcd.print(availableSlots);
  lcd.print("/3");

  if (availableSlots == 0) {
    lcd.print(" FULL");
  }
}

// ===== Send Data to Firebase =====
void sendToFirebase() {
  // Update individual slot status
  Firebase.setBool(firebaseData, "/parking/slots/slotA/occupied", slotA_occupied);
  Firebase.setBool(firebaseData, "/parking/slots/slotB/occupied", slotB_occupied);
  Firebase.setBool(firebaseData, "/parking/slots/slotC/occupied", slotC_occupied);

  // Update slot names (for display)
  Firebase.setString(firebaseData, "/parking/slots/slotA/name", "Slot A");
  Firebase.setString(firebaseData, "/parking/slots/slotB/name", "Slot B");
  Firebase.setString(firebaseData, "/parking/slots/slotC/name", "Slot C");

  // Update summary
  Firebase.setInt(firebaseData, "/parking/summary/totalSlots", 3);
  Firebase.setInt(firebaseData, "/parking/summary/availableSlots", availableSlots);
  Firebase.setInt(firebaseData, "/parking/summary/occupiedSlots", 3 - availableSlots);

  // Update timestamp
  Firebase.setInt(firebaseData, "/parking/summary/lastUpdate", millis() / 1000);

  // Set system status
  Firebase.setString(firebaseData, "/parking/system/status", "online");

  Serial.println("Data sent to Firebase successfully!");
}

// ===== Connect to WiFi =====
void connectWiFi() {
  Serial.print("Connecting to WiFi: ");
  Serial.println(WIFI_SSID);

  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Connecting WiFi");

  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    lcd.setCursor(attempts % 16, 1);
    lcd.print(".");
    attempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWiFi Connected!");
    Serial.print("IP Address: ");
    Serial.println(WiFi.localIP());

    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("WiFi Connected!");
    lcd.setCursor(0, 1);
    lcd.print(WiFi.localIP());
    delay(2000);
  } else {
    Serial.println("\nWiFi Connection Failed!");
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("WiFi Failed!");
    lcd.setCursor(0, 1);
    lcd.print("Check Settings");
    delay(3000);
  }
}

// ===== Initialize Firebase =====
void initFirebase() {
  Serial.println("Initializing Firebase...");

  firebaseConfig.host = FIREBASE_HOST;
  firebaseConfig.signer.tokens.legacy_token = FIREBASE_AUTH;

  Firebase.begin(&firebaseConfig, &firebaseAuth);
  Firebase.reconnectWiFi(true);

  // Set initial system status
  Firebase.setString(firebaseData, "/parking/system/name", "Smart Parking System");
  Firebase.setString(firebaseData, "/parking/system/location", "Main Parking Area");

  Serial.println("Firebase initialized!");
}
