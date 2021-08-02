public class Voice {
  // controller values
  float eq = 0.5;
  float drywet_echo = 0;
  float feedback_echo = 0;
  float drywet_reverb = 0;
  float duration = 1;
  float pan = 0.5;
  float speed = 0.5;
  float stutter = 0;
  float chopper = 0;
  float reverse = 0;
  float volume = 0.75;

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
  int interval = 5000;
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

  void setControlP5 () {
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
    cp5.addSlider("interval_" + index)
      .setPosition(ui_pos_x, ui_pos_y + y)
      .setSize(140,10)
      .setRange(0, 60000)
      .setValue(interval);
    y += 15;
    cp5.addSlider("volume_" + index)
      .setPosition(ui_pos_x, ui_pos_y + y)
      .setSize(140,10)
      .setRange(0, 1)
      .setValue(volume);
    y += 15;
    cp5.addSlider("eq_" + index)
      .setPosition(ui_pos_x, ui_pos_y + y)
      .setSize(140,10)
      .setRange(0, 1)
      .setValue(eq);
    y += 15;
    cp5.addSlider("drywet_echo_" + index)
      .setPosition(ui_pos_x, ui_pos_y + y)
      .setSize(140,10)
      .setRange(0, 1)
      .setValue(drywet_echo);
    y += 15;
    cp5.addSlider("drywet_reverb_" + index)
      .setPosition(ui_pos_x, ui_pos_y + y)
      .setSize(140,10)
      .setRange(0, 1)
      .setValue(drywet_reverb);
    y += 15;
    cp5.addSlider("pan_" + index)
      .setPosition(ui_pos_x, ui_pos_y + y)
      .setSize(140,10)
      .setRange(0, 1)
      .setValue(pan);
    y += 15;
    cp5.addSlider("speed_" + index)
      .setPosition(ui_pos_x, ui_pos_y + y)
      .setSize(140,10)
      .setRange(0, 1)
      .setValue(speed);
    y += 15;
    cp5.addToggle("stutter_" + index)
      .setPosition(ui_pos_x, ui_pos_y + y)
      .setSize(40,10)
      .setValue(stutter);
      ;
    cp5.addToggle("chopper_" + index)
      .setPosition(ui_pos_x + 50, ui_pos_y + y)
      .setSize(40,10)
      .setValue(chopper);
      ;
    cp5.addToggle("reverse_" + index)
      .setPosition(ui_pos_x + 100, ui_pos_y + y)
      .setSize(40,10)
      .setValue(reverse);
      ;
  }

  void play (JSONObject audio) {
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

  void end () {
    orchestration.sendOscEnd(currentSpeakerId, curAudioId);
    tl.setValue(" ");
    reset();
  }

  void reset () {
    curAudioDuration = 0;
    isPlaying = false;
    curAudioId = 0;
    currentSpeakerId = 0;
    currentSpeakerName = "";
    curAudioText = "";
  }

  void setActive(boolean val) {
    isActive = val;
    if (val == false) {
      if (isPlaying) {
        end();
      } else {
        reset();
      }
    }
  }

  void setInterval (int val) {
    interval = val;
  }

  void setReverb (float val) {
    drywet_reverb = val; 
  }

  void update () {
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

  boolean getIsPlaying () {
    return isPlaying;
  }

  long getSpeakerId () {
    return currentSpeakerId;
  }
}