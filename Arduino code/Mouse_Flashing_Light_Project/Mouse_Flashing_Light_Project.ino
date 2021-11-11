const int intensityIn = A0;
int intensityVal = 0;

const int light1 = 5;
const int light2 = 6;
int lightVal = 0;

int lightActive = 2000; //This sets the length of time that the light is active. 
//12.5SEC mimics the optogenetics we are currently using. 1ms is what Guo et al. used.
//7/23: changed to two seconds according to Many's request.

//The below is for the button and the camera.
//7/23: unnecessary
//const int button = 2;
//int switchState = 0;

int delayVal = 0;


void setup() {
  // put your setup code here, to run once:
  Serial.begin(9600);
  pinMode(light1, OUTPUT);
  pinMode(light2, OUTPUT);
//  pinMode(button, INPUT);
 // pinMode(camera, INPUT);
}

void loop() {
  
  //Measure the value corresponding to the first dial (A1) so that we can assign an intensity
  //to the light based on where the dial is positioned.
  //switchState = digitalRead(button);
  //cameraActive = digitalRead(camera);
  //while(switchState == HIGH) {
    intensityVal = analogRead(intensityIn);
    Serial.print("The intensity value is: ");
    Serial.println(intensityVal);
    lightVal = map(intensityVal,0,1023,0,255);
    Serial.print("The light value is: ");
    Serial.println(lightVal);
    analogWrite(light1, lightVal);
    analogWrite(light2, lightVal);
    delay(lightActive); 
  
    analogWrite(light1,0); 
    analogWrite(light2,0); //Turns off the light.
    
    //Sets the value of the length of time the light remains off depending on the input dial (A0). 
    //delayVal = analogRead(delayIn);
    //Serial.print("The delay value is: ");
    //Serial.println(delayVal);
    //delayVal = map(delayVal,0,1023,10,200);
    //Serial.print("The new delay value is: ");
    //Serial.println(delayVal);
    //delay(delayVal);

    //7/23: Sets the value of the length of time inbetween light flashes to be a random value between 5 and 10 seconds.
    delayVal = random(5,10);
    Serial.println(delayVal);
    delay(delayVal * 1000);
 //   switchState = digitalRead(button);
// }
 delay(5);
}
