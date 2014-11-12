classdef pitcher < handle
    %   Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        Fs = 44100;     % sampling frequency
        frequencies     % table of frequencies entered in xx.m
		freqMap
		amplitudes
		ampMap
        duration   = 0; 		% length of sound in s
        audiobuffer = []; % buffer
		vibratoRange = 2; %vibrato radius in semitones
		vibratoFrequency = 7; %cycles per second
		vibratoDelay = 0;
		vibratoAttack = 1;
		semitone = (2^(1/12)) - 1;
		timeSegment = 1;
		fadeIn = 0.10;
		fadeOut = 0.1;
		currentInstrument = 'pureTone';
		instruments = struct();
		reverbDepth = 0;
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
	
		function fillFreqMap(this, timeSamples)
			freqSegment = 1;
			[lastSegment,dud] = size(this.frequencies);
			lastFrequency = this.frequencies(1,2);
			lastFreqTime = 0;
			nextFrequency = this.frequencies(1,2);
			nextFreqTime = this.frequencies(1,1);
			for i = 1:timeSamples
				time = i / this.Fs;
				if time >= nextFreqTime
					if freqSegment < lastSegment
						freqSegment = freqSegment + 1;
						lastFreqTime = nextFreqTime;
					end
					lastFrequency = nextFrequency;			
					nextFrequency = this.frequencies(freqSegment,2);
					nextFreqTime = this.frequencies(freqSegment,1);
				end
				deltaTime = time - lastFreqTime;
				totalTime = nextFreqTime - lastFreqTime;
				timeRatio = deltaTime/totalTime;
				freqRange = nextFrequency - lastFrequency;
				freqRatio = freqRange * timeRatio;
				finalFreq = freqRatio + lastFrequency;
				finalFreq = this.addVibrato(finalFreq,time);
				this.freqMap(1,i) = finalFreq;
			end
			
		end
		
		function fillAmpMap(this, timeSamples)
			ampSegment = 1;
			[lastSegment,dud] = size(this.amplitudes)
			lastAmplitude = 0;
			lastAmpTime = 0;
			nextAmplitude = this.amplitudes(1,2);
			nextAmpTime = this.amplitudes(1,1);
			for i = 1:timeSamples
				time = i / this.Fs;
				if time >= nextAmpTime
					if ampSegment < lastSegment
						ampSegment = ampSegment + 1;
						lastAmpTime = nextAmpTime;
						lastAmplitude = nextAmplitude;			
						nextAmplitude = this.amplitudes(ampSegment,2);
						nextAmpTime = this.amplitudes(ampSegment,1);
					else
						lastAmpTime = nextAmpTime;
						lastAmplitude = nextAmplitude;			
						nextAmplitude = 0;
						nextAmpTime = timeSamples/this.Fs;
					end
				end
				deltaTime = time - lastAmpTime;
				totalTime = nextAmpTime - lastAmpTime;
				timeRatio = deltaTime/totalTime;
				ampRange = nextAmplitude - lastAmplitude;
				ampRatio = ampRange * timeRatio;
				finalAmp = ampRatio + lastAmplitude;
				this.ampMap(1,i) = finalAmp;
			end
			
			this.ampMap = this.ampMap.^(14)
			
			this.ampMap = normalise(this.ampMap);
			
			
		end
		
		function pitch=addVibrato(this,freq,time)
			%disp('Adding vibrato to frequency tier.')
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
			this.fillFreqMap(timeFrames);
			for formant = 1:formantsLength
			
				phase = 0;
				formantFactor = formants(formant,1);
				formantAmplitude = formants(formant,2);
				lastPitch = this.freqMap(1,1)*formantFactor;
				tempBuffer = zeros(1,timeFrames);
				this.timeSegment = 1;

				for i = 1:timeFrames
					timeFrame = i/this.Fs;
					freq = this.freqMap(1,i) * formantFactor;
					%freq = this.addVibrato(freq,timeFrame);
					%freq = freq*formantFactor;
					phase = phase + 2*pi*timeFrame*(lastPitch-freq);
					bufferValue = sin(2*pi*freq*timeFrame + phase);
					lastPitch = freq;
					tempBuffer(1,i) = bufferValue;
				end
				
				tempBuffer = tempBuffer * formantAmplitude;
				this.audiobuffer = this.audiobuffer + tempBuffer;
			end
			
			this.fillAmpMap(timeFrames);
			this.audiobuffer = this.audiobuffer.* this.ampMap;
			
			
			%intensity = max(abs(this.audiobuffer));
			%this.audiobuffer = this.audiobuffer/intensity;
			this.audiobuffer = normalise(this.audiobuffer);
			
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
		
		function loadAmplitudes (this, filename)
			fileID = fopen(filename, 'r');
			this.amplitudes = fscanf(fileID, '%f', [2 Inf])';
		end
		
	end
end

function obj = normalise(buffer)
						intensity = max(abs(buffer));
			obj = buffer/intensity;
end

