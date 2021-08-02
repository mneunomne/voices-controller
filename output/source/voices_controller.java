import processing.core.*; 
import processing.data.*; 
import processing.event.*; 
import processing.opengl.*; 

import netP5.*; 
import oscP5.*; 
import AULib.*; 
import java.net.URLDecoder; 
import java.net.URLEncoder; 
import java.io.UnsupportedEncodingException; 
import controlP5.*; 

import java.util.HashMap; 
import java.util.ArrayList; 
import java.io.File; 
import java.io.BufferedReader; 
import java.io.PrintWriter; 
import java.io.InputStream; 
import java.io.OutputStream; 
import java.io.IOException; 

public class voices_controller extends PApplet {










OscP5 oscP5;
NetAddress remoteBroadcast; 
NetAddress localBroadcast; 


ControlP5 cp5;

JSONArray speakers;
JSONObject json;

int maxNumVoices = 8;
int numActiveVoices = 1;
int initialInterval = 3000;
int numSpeakers = 25;

String[] effects = {"eq","drywet_echo","drywet_reverb","stutter", "chopper"};
String[] globalEffects = {"echo_duration", "reverb"};

ArrayList<Voice> voices = new ArrayList<Voice>();

Orchestration orchestration;

ArrayList<String> availableVoices = new ArrayList<String>();

// cp5 position
int margin = 10;

public void setup () {
  
  PFont font = createFont("Courier New",12,true);

  // load audios
  json = loadJSONObject("data.json");
  JSONArray audios = json.getJSONArray("audios");

  // connectOSC
  connectOSC();

  // start orchestration
  cp5 = new ControlP5(this);

  orchestration = new Orchestration(audios);

  setController();
  
}

public void setController () {
  int y = 0;
  cp5.addSlider("num_speakers")
     .setPosition(margin, margin + y)
     .setSize(200,15)
     .setNumberOfTickMarks(9)
     .setRange(0, 8)
     .setValue(numActiveVoices)
     ;
  y += 30;
  cp5.addSlider("room")
    .setPosition(margin, margin + y)
    .setSize(140,15)
    .setRange(0, 1)
    .setValue(0);
  y += 30;
  cp5.addSlider("echo_duration")
    .setPosition(margin, margin + y)
    .setSize(140,15)
    .setRange(0, 1)
    .setValue(5);
  y += 30;
}

public void connectOSC () {
  oscP5 = new OscP5(this,12000);
  localBroadcast = new NetAddress("127.0.0.1",32000);
  remoteBroadcast = new NetAddress("192.168.178.66",32000);
}

public void draw() {
  background(0);
  orchestration.update();
}

public void num_speakers (float val) {
  println("val", val);
  orchestration.setActiveVoices(PApplet.parseInt(val));
}

public void controlEvent(ControlEvent theControlEvent) {
  
  for (int i = 0; i < maxNumVoices; i++) {
    for (int j = 0; j < effects.length; j++) {
      String effect = effects[j];
      if(theControlEvent.isFrom(effect + "_" + i)) {
        // effect message
        OscMessage effectMessage = new OscMessage("/" + effect);
        // get value from cp5
        float cp5value = theControlEvent.getController().getValue();

        println("Effect change!", cp5value);

        // map value to 7bit
        int value = PApplet.parseInt(map(cp5value, 0, 1, 0, 127));
        effectMessage.add(i);
        effectMessage.add(value);
        // send 
        oscP5.send(effectMessage, remoteBroadcast);
        oscP5.send(effectMessage, localBroadcast);
      }
    }
  }

  for (int i = 0; i < globalEffects.length; i++) {
    String effect = globalEffects[i];
    if(theControlEvent.isFrom(effect)) {
      OscMessage effectMessage = new OscMessage("/" + effect);
      float cp5value = theControlEvent.getController().getValue();
      int value = PApplet.parseInt(map(cp5value, 0, 1, 0, 127));
      println(effect + " " + value);
      effectMessage.add(value);
      oscP5.send(effectMessage, remoteBroadcast);
      oscP5.send(effectMessage, localBroadcast);
    }
  }
}

public void keyPressed () {
 if (key == 's' || key == 'S') {
   cp5.saveProperties();
 }
 if (key == 'l' || key == 'L') {
   cp5.loadProperties();
 }
}
public class Orchestration { 
  
  // "soft", "melodic", "rhythm", "loud", "plain"
  
  String categories[] = {"soft", "melodic", "rhythm", "", "plain"};
  
  JSONArray audios;
  Voice[] voices = new Voice[maxNumVoices];
  
  Orchestration (JSONArray _audios) {
    audios = _audios;
    // initiate all voices
    for (int i = 0; i < maxNumVoices; i++) {
     voices[i] = new Voice(i, i < numActiveVoices); 
    }
  }
  
  public void setActiveVoices (int amount) {
    numActiveVoices = amount;
    for(int i = 0; i < maxNumVoices; i++) {
      if (i < numActiveVoices) {
        voices[i].setActive(true); 
      } else {
        voices[i].setActive(false);
      }
    }
  }
  
  public void update () {
    for(int i = 0; i < maxNumVoices; i++) {
       voices[i].update();
    }
  }

  public JSONObject getNextAudio (int voiceIndex) {
    ArrayList<JSONObject> filtered = new ArrayList<JSONObject>();
    for (int i = 0; i < audios.size(); i++) {
      JSONObject obj = audios.getJSONObject(i);
      long cur_id = obj.getLong("from_id");
      boolean hasFound = false; 
      boolean hasCategory = false; 
      
      /*
      for (int j = 0; j < speakers.size(); j++) {
        JSONObject item = speakers.getJSONObject(j); 
        String category = item.getString("category");
        String name = item.getString("speaker");
        long _id = item.getLong("id");
        if (_id != cur_id) continue;
        if (category.contains(categories[floor(voiceIndex/2)])) {
          println("added", category, categories[floor(voiceIndex/2)], name);
          hasCategory = true;
        }
      }
      */
      hasCategory = true;
      for (long id : getCurrentSpeakerId()) {
         if (cur_id == id) {
            hasFound = true;
         }
      }
      if (!hasFound && hasCategory) {
         filtered.add(obj);
      }
    }
    int index = floor(random(0, filtered.size())); 
    return filtered.get(index);
  }
  
  public void sendOscplay (long speakerId, int audioID, String audioText, int index) {
    // VISUAL
    OscMessage visMessage = new OscMessage("/play");
    visMessage.add(Long.toString(speakerId));
    visMessage.add(audioID);
    visMessage.add(audioText);
    oscP5.send(visMessage, localBroadcast);
    
    println("PLAY!", audioText);
        
    // AUDIO
    OscMessage audioMessage = new OscMessage("/play");
    audioMessage.add(Long.toString(speakerId));
    audioMessage.add(audioID);
    audioMessage.add(index);
   
    oscP5.send(audioMessage, remoteBroadcast);
  }
  
  public void sendOscEnd (long speakerId, int audioID) {
    OscMessage myOscMessage = new OscMessage("/end");
    myOscMessage.add(Long.toString(speakerId));
    myOscMessage.add(audioID);
    oscP5.send(myOscMessage, localBroadcast);
  }
  
  public long [] getCurrentSpeakerId () {
    long [] ids = new long[numActiveVoices];
    for(int i = 0; i < numActiveVoices; i++) {
       ids[i] = voices[i].getSpeakerId();
    }
    return ids;
  }
  
  public void setVoiceInterval (int index, int value) {
    voices[index].setInterval(value);
  }
  
  public void setVoiceReverb (int index, float value) {
    voices[index].setReverb(value);
  }
}
public class Voice {
  // controller values
  float eq = 0.5f;
  float echo_amount = 0;
  float duration = 1;
  float reverb = 0;
  float pan = 0;
  // id
  int id;
  int index;
  long currentSpeakerId;
  boolean isActive = false;
  // states
  int curAudioDuration; 
  int curAudioId;
  String curAudioText = "";
  String currentSpeakerName = "";
  boolean isPlaying = false;
  int interval;
  int lastTimeCheck = 0;

  int ui_pos_x;
  int ui_pos_y;

  int startX = 300;

  Textlabel tl;

  Voice(int _index, boolean _isActive) {
    index = _index;
    isActive = _isActive;
    ui_pos_x = startX + floor(index / 4) * 300;
    ui_pos_y = margin + (index % 4) * (height / 4);

    setControlP5();
  }

  public void setControlP5 () {
    cp5.addTextlabel("label_" + index)
      .setText("Voice " + index)
      .setPosition(ui_pos_x,ui_pos_y)
      .setColorValue(0xffffff00)
      .setFont(createFont("Georgia",14));
    int y = 15;
    tl = cp5.addTextlabel("current_text_" + index)
      .setText("")
      .setPosition(ui_pos_x,ui_pos_y + y)
      .setFont(createFont("Arial Unicode MS",14));
    y += 20;
    // values
    cp5.addSlider("eq_" + index)
      .setPosition(ui_pos_x, ui_pos_y + y)
      .setSize(140,10)
      .setRange(0, 1)
      .setValue(0.5f);
    y += 15;
    cp5.addSlider("drywet_echo_" + index)
      .setPosition(ui_pos_x, ui_pos_y + y)
      .setSize(140,10)
      .setRange(0, 1)
      .setValue(0);
    y += 15;
    cp5.addSlider("drywet_reverb_" + index)
      .setPosition(ui_pos_x, ui_pos_y + y)
      .setSize(140,10)
      .setRange(0, 1)
      .setValue(0);
    y += 15;
    cp5.addSlider("pan_" + index)
      .setPosition(ui_pos_x, ui_pos_y + y)
      .setSize(140,10)
      .setRange(0, 1)
      .setValue(0);
    y += 15;
    cp5.addToggle("stutter_" + index)
      .setPosition(ui_pos_x, ui_pos_y + y)
      .setSize(50,10)
      ;
    cp5.addToggle("chopper_" + index)
      .setPosition(ui_pos_x + 70, ui_pos_y + y)
      .setSize(50,10)
      ;
  }

  public void play (JSONObject audio) {
    curAudioDuration = audio.getInt("duration_seconds") * 1000 + 500;
    lastTimeCheck = millis();
    isPlaying = true;
    currentSpeakerId = audio.getLong("from_id");
    curAudioId = audio.getInt("id");
    currentSpeakerName = audio.getString("from");
    curAudioText = audio.getString("text");

    // float[] values = {filter, echo_amount, duration, reverb, pan};
    
    orchestration.sendOscplay(currentSpeakerId, curAudioId, curAudioText, index);

    tl.setValue(currentSpeakerName);
  }

  public void end () {
    orchestration.sendOscEnd(currentSpeakerId, curAudioId);
    tl.setValue(" ");
    reset();
  }

  public void reset () {
    curAudioDuration = 0;
    isPlaying = false;
    curAudioId = 0;
    currentSpeakerId = 0;
    currentSpeakerName = "";
    curAudioText = "";
  }

  public void setActive(boolean val) {
    isActive = val;
    if (val == false) {
      if (isPlaying) {
        end();
      } else {
        reset();
      }
    }
  }

  public void setInterval (int val) {
    interval = val;
  }

  public void setReverb (float val) {
    reverb = val; 
  }

  public void update () {
    if (isActive) {
      if (!isPlaying) {
        if (millis() > lastTimeCheck + interval ) {
          // here pick on audio 
          JSONObject audio = orchestration.getNextAudio(index);
          play(audio);
        }
      } else {
        // check if audio has finnished playing
        if (millis() > lastTimeCheck + curAudioDuration) {
          end();
        }
      }
    } 
  }

  public boolean getIsPlaying () {
    return isPlaying;
  }

  public long getSpeakerId () {
    return currentSpeakerId;
  }
}
  public void settings() {  size(900, 600); }
  static public void main(String[] passedArgs) {
    String[] appletArgs = new String[] { "voices_controller" };
    if (passedArgs != null) {
      PApplet.main(concat(appletArgs, passedArgs));
    } else {
      PApplet.main(appletArgs);
    }
  }
}
