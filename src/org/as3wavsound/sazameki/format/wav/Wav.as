package org.as3wavsound.sazameki.format.wav {
	import org.as3wavsound.sazameki.core.AudioSamples;
	import org.as3wavsound.sazameki.core.AudioSetting;
	import org.as3wavsound.sazameki.format.riff.Chunk;
	import org.as3wavsound.sazameki.format.riff.RIFF;
	import org.as3wavsound.sazameki.format.wav.chunk.WavdataChunk;
	import org.as3wavsound.sazameki.format.wav.chunk.WavfmtChunk;
	
	import flash.utils.ByteArray;
	
	/**
	 * The WAVE decoder used for playing back wav files.
	 *
	 * @author Takaaki Yamazaki(zk design),
	 * @author Benny Bottema (modified, optimized and cleaned up code)
	 */
	public class Wav extends RIFF {

		public function Wav() {
			super('WAVE');
		}
		
		public function encode(samples:AudioSamples):ByteArray {
			var fmt:WavfmtChunk = new WavfmtChunk();
			var data:WavdataChunk = new WavdataChunk();

			_chunks = new Vector.<Chunk>;
			_chunks.push(fmt);
			_chunks.push(data);

			data.setAudioData(samples);
			fmt.setSetting(samples.setting);
			
			return toByteArray();
		}
		
		public function decode(wavData:ByteArray, setting:AudioSetting):AudioSamples {
			var obj:Object = splitList(wavData);
			var data:AudioSamples;
			
			var relevantSetting:AudioSetting = setting;
			if (relevantSetting == null && obj['fmt ']) {
				relevantSetting = new WavfmtChunk().decodeData(obj['fmt '] as ByteArray);
			}
			
			if (obj['fmt '] && obj['data']) {
				data = new WavdataChunk().decodeData(obj['data'] as ByteArray, relevantSetting);
			} else {
				data = new WavdataChunk().decodeData(wavData, relevantSetting);
			}
			
			var needsResampling:Boolean = relevantSetting != null && relevantSetting.sampleRate != 44100;
			return (needsResampling) ? resampleAudioSamples(data, relevantSetting.sampleRate) : data;
		}
		
		/**
		 * Resamples the given audio samples from a given sample rate to a target sample rate (or default 44100).
		 * 
		 * @author "Slow Burnaz" (slowburnaz@gmail.com), Simion Medvedi (medvedisimion@gmail.com)
		 * @author Benny Bottema (sanitized code and added support for stereo resampling)
		 */
		private function resampleAudioSamples(data:AudioSamples, sourceRate:int, targetRate:int = 44100):AudioSamples {
			var newSize:int = data.length * targetRate / sourceRate;
			var newData:AudioSamples = new AudioSamples(new AudioSetting(data.setting.channels, targetRate, 16), newSize);
			
			resampleSamples(data.left, newData.left, newSize, sourceRate, targetRate);
			// playback buffering in WavSoundChannel will take care of a possibly missing right channel
			if (data.setting.channels == 2) {
				resampleSamples(data.right, newData.right, newSize, sourceRate, targetRate);
			}
			
			return newData;
		}
		
		/**
		 * Resamples the given audio samples from a given sample rate to a target sample rate (or default 44100).
		 * 
		 * @author "Slow Burnaz" (slowburnaz@gmail.com), Simion Medvedi (medvedisimion@gmail.com)
		 * @author Benny Bottema (sanitized code)
		 */
		private function resampleSamples(sourceSamples:Vector.<Number>, targetSamples:Vector.<Number>, newSize:int, sourceRate:int, targetRate:int = 44100):void {
			var quality:int = 4;
			var srcLength:uint = sourceSamples.length;
			var destLength:uint = sourceSamples.length*targetRate/sourceRate;
			var dx:Number = srcLength/destLength;
			
			// fmax : nyqist half of destination sampleRate
			// fmax / fsr = 0.5;
			var fmaxDivSR:Number = 0.5;
			var r_g:Number = 2 * fmaxDivSR;
			
			// Quality is half the window width
			var wndWidth2:int = quality;
			var wndWidth:int = quality*2;
			
			var x:Number = 0;
			var i:uint, j:uint;
			var r_y:Number;
			var tau:int;
			var r_w:Number;
			var r_a:Number;
			var r_snc:Number;
			for (i=0;i<destLength;++i)
			{
				r_y = 0.0;
				for (tau=-wndWidth2;tau < wndWidth2;++tau)
				{
					// input sample index
					j = (int)(x+tau);
					
					// Hann Window. Scale and calculate sinc
					r_w = 0.5 - 0.5 * Math.cos(2*Math.PI*(0.5 + (j-x)/wndWidth));
					r_a = 2*Math.PI*(j-x)*fmaxDivSR;
					r_snc = 1.0;
					if (r_a != 0)
						r_snc = Math.sin(r_a)/r_a;
					
					if ((j >= 0) && (j < srcLength))
					{
						r_y += r_g * r_w * r_snc * sourceSamples[j];
					}
				}
				targetSamples[i] = r_y;
				x += dx;
			}
		}
	}
}