classdef pitcher < handle
    %   Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        Fs = 44100;     % sampling frequency
        frequencies     % table of frequencies entered in xx.m
        duration   = 0; 		% length of sound in s
        audiobuffer = []; % buffer
		vibratoRange = 2; %vibrato radius in semitones
		vibratoFrequency = 7; %cycles per second
		vibratoDelay = 0;
		vibratoAttack = 1;
		semitone = (2^(1/12)) - 1;
		timeSegment = 1;
		fadeIn = 0.20;
		fadeOut = 0.5;
		currentInstrument = 'pureTone';
		instruments = struct();
		reverbDepth = 7;
		reverbDelay = 0.05;
		
    end
    
    methods

	function self = pitcher()
	
		self.instruments.('pureTone') = [1,1];
		
		self.instruments.('flute') = [
		1*2,0.8;
		2*2,1;
		3*2,0.9;
		4*2,0.85;
		5*2,0.6;
		]
		
		self.instruments.('flute2') = [
		1,1;
		2,29/60;
		3,30/60;
		4,18/60;
		5,19/60;
		6,11/60;
		7,10/60;
		8,5/60;
		9,5/60;
		10,4/60;
		11,4/60;
		12,3/60;
		13,3/60;
		14,2/60;
		15,2/60;
		]
		
		
		self.instruments.('cello') = [
		1,1;
		2,0.72;
		3,0.80;
		4,0.65;
		5,0.65;
		6,0.67;
		7,0.49;
		8,0.55;
		9,0.49;
		10,0.23;
		11,0.40;
		12,0.43;
		13,0.42;
		14,0.28;
		15,0.28;
		16,0.27;
		17,0.27;
		18,0.28;
		19,0.19;
		20,0.24;
		21,0.12;
		22,0.20;
		23,0.11;
		];
	end
	
	
		function pitch=addVibrato(this,freq,time)
		if time < this.vibratoDelay
		pitch = freq;
		return;
		end
		sineVal = sin(2*pi*this.vibratoFrequency*time);
		freqVal = sineVal * this.vibratoRange * this.semitone *freq;
		if time > this.vibratoDelay && time < (this.vibratoAttack + this.vibratoDelay)
		volume = sin(pi/2 * ((time-this.vibratoDelay)/(this.vibratoAttack)));
		freqVal = freqVal * volume;
		end
		pitch = freq + freqVal;
		
		end
		function pitch=getPitchAtTime(this,time)
			listSize = length(this.frequencies);
			if listSize == 2
				pitch = this.frequencies(1,2);
				return;
			end
			for i = this.timeSegment:length(this.frequencies)+1
				if i > length(this.frequencies)
					pitch = this.frequencies(i-1,2);
					return;
				elseif time == this.frequencies(i,1)
					pitch = this.frequencies(i,2);
					return;
				elseif time < this.frequencies(i,1)
					if i == 1
						pitch = this.frequencies(i,2);
						return;
					else
						
						nextFrequency = i;
						lastFrequency = i-1;
					end
					this.timeSegment = i;
					break;
				end
			end
			pitchRange = this.frequencies(nextFrequency,2) - this.frequencies(lastFrequency,2);
			timeRange = this.frequencies(nextFrequency,1) - this.frequencies(lastFrequency,1);
			timeRatio = (time - this.frequencies(lastFrequency,1))/timeRange;
			pitch = (timeRatio * pitchRange) + this.frequencies(lastFrequency,2); % currently linear function
		
		end
    
   
    
		function makesound(this)
		
			lastPoint = size(this.frequencies);
			lastPointTime = this.frequencies(lastPoint(1),1);
			if lastPointTime >= this.duration || this.duration == 0;
				this.duration = lastPointTime + 0.0001;
			end
			
			formants = this.instruments.(this.currentInstrument);
			formantsSize = size(formants);
			formantsLength = formantsSize(1);
			timeFrames = floor(this.duration * this.Fs);
			this.audiobuffer = zeros(1,timeFrames);
			for formant = 1:formantsLength
			
				phase = 0;
				formantFactor = formants(formant,1);
				formantAmplitude = formants(formant,2);
				lastPitch = this.getPitchAtTime(0)*formantFactor;
				tempBuffer = zeros(1,timeFrames);
				this.timeSegment = 1;

				for i = 1:timeFrames
					timeFrame = i/this.Fs;
					freq = this.getPitchAtTime(timeFrame);
					freq = this.addVibrato(freq,timeFrame);
					freq = freq*formantFactor;
					phase = phase + 2*pi*timeFrame*(lastPitch-freq);
					bufferValue = sin(2*pi*freq*timeFrame + phase);
					lastPitch = freq;
					tempBuffer(1,i) = bufferValue;
				end
				
				tempBuffer = tempBuffer * formantAmplitude;
				this.audiobuffer = this.audiobuffer + tempBuffer;
			end
			
			intensity = max(abs(this.audiobuffer));
			this.audiobuffer = this.audiobuffer/intensity;
			
			this.applyFadeIn();
			this.applyFadeOut();
			this.addReverb();
		end
	
		function applyFadeIn(this)
			fadeInLength = floor(this.fadeIn*this.Fs);
			for i = 1:fadeInLength
				volume = sin((pi/2)*((i-1)/fadeInLength));
				this.audiobuffer(1,i) = this.audiobuffer(1,i) * volume;
			end
		end
	
		function applyFadeOut(this)
			fadeOutLength = floor(this.fadeOut*this.Fs);
			bufferLength = size(this.audiobuffer);
			for i = 1:fadeOutLength
				volume = sin((pi/2)*((fadeOutLength-i)/fadeOutLength));
				this.audiobuffer(1,(bufferLength(2) - fadeOutLength)+i) = this.audiobuffer(1,(bufferLength(2) - fadeOutLength)+i) * volume;
			end
		end

		function addReverb(this)
			
			delayInFrames = floor(this.reverbDelay * this.Fs);
			
			bufferFragment = cat(2,this.audiobuffer,zeros(1,delayInFrames*this.reverbDepth));
			for i = 1:this.reverbDepth
				reverb = cat(2,cat(2,zeros(1,(delayInFrames*i)),this.audiobuffer),zeros(1,delayInFrames*(this.reverbDepth-i)));
				reverb = reverb * ((this.reverbDepth-i+1)/(this.reverbDepth+1))^2;
				bufferFragment = bufferFragment + reverb;
			end
						intensity = max(abs(bufferFragment));
			this.audiobuffer = bufferFragment/intensity;
		
		end
		
		
		function play (this)
			sound (this.audiobuffer, this.Fs);
		end
		
		function save (this, fileout)
			audiowrite(fileout, this.audiobuffer, this.Fs);
		end
		
		function loadFrequencies (this, filename)
			fileID = fopen(filename, 'r');
			this.frequencies = fscanf(fileID, '%f %f', [2 Inf])';
		end
		
	end
end


