extends RefCounted
## Original, nonverbal synthesized greeting. No recorded or imitated voices.
static func sample(profile: Dictionary) -> AudioStreamWAV:
	var rate := 22050; var length := 1.2
	var data := PackedByteArray(); data.resize(int(rate*length)*2)
	var fundamental := lerpf(115.0,280.0,float(profile.pitch)/100.0)
	var voice := int(profile.voice)
	for index in range(int(rate*length)):
		var t := float(index)/rate
		var syllable := int(t/0.24)
		var local := fmod(t,0.24)/0.24
		var envelope := pow(sin(local*PI),1.8)*minf(1.0,(length-t)*8)
		var frequency: float = fundamental*[1.0,1.16,1.10,0.95,1.05][mini(syllable,4)]
		var value := 0.0
		for harmonic in range(1,9):
			var weight := 1.0/pow(float(harmonic),1.0+voice*0.22)
			var formant: float = [650.0,1050.0,450.0,1400.0][voice]+syllable*65
			weight*=0.4+0.6*exp(-pow((frequency*harmonic-formant)/500.0,2))
			value+=sin(TAU*frequency*t*harmonic+0.03*sin(t*34))*weight
		data.encode_s16(index*2,int(clampf(value*envelope*0.24,-1,1)*32767))
	var stream := AudioStreamWAV.new(); stream.format=AudioStreamWAV.FORMAT_16_BITS; stream.mix_rate=rate; stream.data=data
	return stream
