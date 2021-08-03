public class Orchestration { 
  
  // "soft", "melodic", "rhythm", "loud", "plain"
  
  String categories[] = {"soft", "melodic", "rhythm", "", "plain"};
  
  JSONArray audios;
  Voice[] voices = new Voice[maxNumVoices];
  
  Orchestration (JSONArray _audios) {
    audios = _audios;
    // initiate all voices
    for (int i = 0; i < maxNumVoices; i++) {
     voices[i] = new Voice(i, activeVoices[i]); 
    }
  }
  
  void setActiveVoices () {
    // numActiveVoices = amount;
    for(int i = 0; i < maxNumVoices; i++) {
        voices[i].setActive(activeVoices[i]);
    }
  }
  
  void update () {
    for(int i = 0; i < maxNumVoices; i++) {
       voices[i].update();
    }
  }

  JSONObject getNextAudio (int voiceIndex, String textFilter) {
    ArrayList<JSONObject> filtered = new ArrayList<JSONObject>();
    ArrayList<JSONObject> unfiltered = new ArrayList<JSONObject>();
    for (int i = 0; i < audios.size(); i++) {
      JSONObject obj = audios.getJSONObject(i);
      String cur_name = obj.getString("from").toLowerCase();
      if (cur_name.contains(textFilter)) {
        filtered.add(obj);
      }
      unfiltered.add(obj);
    }
    if (filtered.size() > 0) {
      int index = floor(random(0, filtered.size())); 
      return filtered.get(index);
    } else {
      int index = floor(random(0, unfiltered.size())); 
      return unfiltered.get(index);
    }
  }
  
  void sendOscplay (long speakerId, int audioID, String audioText, int index) {
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
  
  void sendOscEnd (long speakerId, int audioID) {
    OscMessage myOscMessage = new OscMessage("/end");
    myOscMessage.add(Long.toString(speakerId));
    myOscMessage.add(audioID);
    oscP5.send(myOscMessage, localBroadcast);
  }
  
  long [] getCurrentSpeakerId () {
    long [] ids = new long[maxNumVoices];
    for(int i = 0; i < maxNumVoices; i++) {
      if (activeVoices[i]) {
       ids[i] = voices[i].getSpeakerId();
      }
    }
    return ids;
  }
  
  void setVoiceTextFilter (int index, String value) {
    voices[index].setTextfilter(value);
  }

  void setVoiceInterval (int index, int value) {
    voices[index].setInterval(value);
  }
  
  void setVoiceReverb (int index, float value) {
    voices[index].setReverb(value);
  }
}