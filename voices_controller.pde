
import netP5.*;
import oscP5.*;
import AULib.*;

import java.net.URLDecoder;
import java.net.URLEncoder;
import java.io.UnsupportedEncodingException;

import themidibus.*; //Import the library

MidiBus bus; //The first MidiBus

OscP5 oscP5;
NetAddress remoteBroadcast; 
NetAddress localBroadcast; 

import controlP5.*;
ControlP5 cp5;

JSONArray speakers;
JSONObject json;

int maxNumVoices = 8;
int numActiveVoices = 1;
int initialInterval = 3000;
int numSpeakers = 25;

int maxInterval = 10000;

boolean [] activeVoices = {false,false,false,false,false,false,false,false}; 

String[] effects = {"volume", "eq","drywet_echo","drywet_reverb","pan", "speed", "stutter", "chopper", "reverse"};
String[] globalEffects = {"echo", "reverb", "echo_fdbk"};

ArrayList<Voice> voices = new ArrayList<Voice>();

Orchestration orchestration;

ArrayList<String> availableVoices = new ArrayList<String>();

// cp5 position
int margin = 10;
PFont inputFont; 
void setup () {
  size(900, 800);

  PFont font = createFont("Courier New",12,true);
  inputFont = createFont("Courier New",9,true);

  // load audios
  json = loadJSONObject("data.json");
  JSONArray audios = json.getJSONArray("audios");

  // connectOSC
  connectOSC();

  // start orchestration
  cp5 = new ControlP5(this);
  orchestration = new Orchestration(audios);
  setController();

  connectMIDIController();
}

void connectMIDIController () {
  MidiBus.list(); //List all available Midi devices. This will show each device's index and name.

  System.out.println("----------Input (from availableInputs())----------");
  String[] available_inputs = MidiBus.availableInputs(); //Returns an array of available input devices
  for (int i = 0;i < available_inputs.length;i++) System.out.println("["+i+"] \""+available_inputs[i]+"\"");

  bus = new MidiBus(this, "FAD"); //Create a first new MidiBus attached to the IncommingA Midi input device and the OutgoingA Midi output device. We will name it busA.

  bus.addInput("FAD.9"); //Add a new input device to busB called IncommingC
}

void setController () {
  int y = 0;
  /*
  cp5.addSlider("num_speakers")
     .setPosition(margin, margin + y)
     .setSize(200,15)
     .setNumberOfTickMarks(9)
     .setRange(0, 8)
     .setValue(numActiveVoices)
     ;
  y += 30;
  */
  cp5.addSlider("reverb")
    .setPosition(margin, margin + y)
    .setSize(140,15)
    .setRange(0, 1)
    .setValue(0);
  y += 30;
  cp5.addSlider("echo")
    .setPosition(margin, margin + y)
    .setSize(140,15)
    .setRange(0, 1)
    .setValue(5);
  y += 30;
  cp5.addSlider("echo_fdbk")
    .setPosition(margin, margin + y)
    .setSize(140,15)
    .setRange(0, 1)
    .setValue(5);
  y += 30;
  
}

void connectOSC () {
  oscP5 = new OscP5(this,12000);
  localBroadcast = new NetAddress("127.0.0.1",32000);
  remoteBroadcast = new NetAddress("192.168.0.103",8083);
}

void draw() {
  background(0);
  orchestration.update();
}

/*
void num_speakers (float val) {
  println("val", val);
  orchestration.setActiveVoices(int(val));
}
*/

void controlEvent(ControlEvent theControlEvent) {
  // -------------------------------------------------
  // voices individual effects
  for (int i = 0; i < maxNumVoices; i++) {
    // interval controller
    if(theControlEvent.isFrom("interval_" + i)) {
      float interval_value = theControlEvent.getController().getValue();
      orchestration.setVoiceInterval(i, int(interval_value));
    }
    for (int j = 0; j < effects.length; j++) {
      String effect = effects[j];
      if(theControlEvent.isFrom(effect + "_" + i)) {
        if (effect == "speed" || effect == "reverse") {
          OscMessage effectMessage = new OscMessage("/speed");
          float speed_val = cp5.getController("speed_" + i).getValue();
          float reverse_val = cp5.getController("reverse_" + i).getValue();
          effectMessage.add(i);
          effectMessage.add(int(map(speed_val, 0, 1, 0, 100)));
          effectMessage.add(int(map(reverse_val, 0, 1, 0, 100)));
          println("speed change!", i);
          // send 
          oscP5.send(effectMessage, remoteBroadcast);
          oscP5.send(effectMessage, localBroadcast);  
          return;
        }
        // effect message
        OscMessage effectMessage = new OscMessage("/" + effect);
        // get value from cp5
        float cp5value = theControlEvent.getController().getValue();

        println("Effect change!", cp5value);

        // map value to 7bit
        int value = int(map(cp5value, 0, 1, 0, 100));
   
        // normal just currently changed needs to be sent 
        effectMessage.add(i);
        effectMessage.add(value);
   
        // send 
        oscP5.send(effectMessage, remoteBroadcast);
        oscP5.send(effectMessage, localBroadcast);
      }
    }

    // text filter
    if (theControlEvent.isFrom("textfilter_" + i)) {
      String text = theControlEvent.getStringValue();
      orchestration.setVoiceTextFilter(i, text);
    }

    // -------------------------------------------------
    // individual voices toggle
    if (theControlEvent.isFrom("activate_" + i)) {
      float value = theControlEvent.getController().getValue();
      println("boolean value", value, i);
      activeVoices[i] = value == 1.0;
      orchestration.setActiveVoices();
      // orchestration.setVoiceTextFilter(i, text);
    }
  }
  // -------------------------------------------------

  // -------------------------------------------------
  // global effects
  for (int i = 0; i < globalEffects.length; i++) {
    String effect = globalEffects[i];
    if(theControlEvent.isFrom(effect)) {
      OscMessage effectMessage = new OscMessage("/" + effect);
      float cp5value = theControlEvent.getController().getValue();
      int value = int(map(cp5value, 0, 1, 0, 100));
      println(effect + " " + value);
      effectMessage.add(value);
      oscP5.send(effectMessage, remoteBroadcast);
      oscP5.send(effectMessage, localBroadcast);
    }
  }
}


void sendInitialValues () {
  for (int i = 0; i < maxNumVoices; i++) {
    for (int j = 0; j < effects.length; j++) {
      String effect = effects[j];
      if (effect == "speed" || effect == "reverse") {
        
        OscMessage effectMessage = new OscMessage("/speed");
        
        float speed_val = cp5.getController("speed_" + i).getValue();
        float reverse_val = cp5.getController("reverse_" + i).getValue();

        effectMessage.add(i);
        effectMessage.add(int(map(speed_val, 0, 1, 0, 100)));
        effectMessage.add(int(map(reverse_val, 0, 1, 0, 100)));

        println("start speed!", i);

        // send 
        oscP5.send(effectMessage, remoteBroadcast);
        oscP5.send(effectMessage, localBroadcast);
      }
      // effect message
      OscMessage effectMessage = new OscMessage("/" + effect);
      // get value from cp5
      float cp5value = cp5.getController(effect + "_" + i).getValue();

      println("Effect start!", cp5value);

      // map value to 7bit
      int value = int(map(cp5value, 0, 1, 0, 100));

      // normal just currently changed needs to be sent 
      effectMessage.add(i);
      effectMessage.add(value);

      // send 
      oscP5.send(effectMessage, remoteBroadcast);
      oscP5.send(effectMessage, localBroadcast);
    }
  }
  for (int i = 0; i < globalEffects.length; i++) {
    String effect = globalEffects[i];

      OscMessage effectMessage = new OscMessage("/" + effect);
      float cp5value = cp5.getController(effect).getValue();
      int value = int(map(cp5value, 0, 1, 0, 100));
      println(effect + " " + value);
      effectMessage.add(value);
      oscP5.send(effectMessage, remoteBroadcast);
      oscP5.send(effectMessage, localBroadcast);
  }
}

void controllerChange(int channel, int number, int value, long timestamp, String bus_name) {  
  int sliders0 = 18;
  int knob0 = 27;
  int io0 = 36;

  int generalSlider  = 26;
  int generalKnob  = 35;
  int generalIo  = 44;

  float fValue = map(value, 0, 127, 0, 1);
  
  float intervalValue = fValue * maxInterval;

  if (number == generalSlider) {
    for (int i =0; i < 8; i++) {
      cp5.getController("interval_" + i).setValue(intervalValue);
    }
  }
  if (number == generalKnob) {
    for (int i =0; i < 8; i++) {
      cp5.getController("volume_" + i).setValue(fValue);
    }
  }
  if (number == generalIo) {
    for (int i =0; i < 8; i++) {
      cp5.getController("activate_" + i).setValue(fValue);
    }
  }

  for (int i =0; i < 8; i++) {
    // interval
    if (number == sliders0 + i) {
      println("voice " + i);
      println("slider " + value);

      cp5.getController("interval_" + i).setValue(intervalValue);
    }
    // volume
    if (number == knob0 + i) {
      println("voice " + i);
      println("knob " + value);
      cp5.getController("volume_" + i).setValue(fValue);
    }
    // toggle
    if (number == io0 + i) {
      println("voice " + i);
      println("io " + value);
      cp5.getController("activate_" + i).setValue(fValue);
    }
  }
}

void keyPressed () {
 if (key == 'S') {
   cp5.saveProperties();
 }
 if (key == 'L') {
   cp5.loadProperties();
 }
 if (key == 'I') {
   sendInitialValues();
 }
}