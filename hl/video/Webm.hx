/*
 * The MIT License (MIT)
 *
 * Copyright (c) 2022-2023 Nicolas Cannasse
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy of
 * this software and associated documentation files (the "Software"), to deal in
 * the Software without restriction, including without limitation the rights to
 * use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
 * the Software, and to permit persons to whom the Software is furnished to do so,
 * subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
 * FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
 * COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
 * IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

package hl.video;

private typedef MkvReader = hl.Abstract<"IMkvReader">;
private typedef Segment = hl.Abstract<"Segment">;
private typedef Cluster = hl.Abstract<"Cluster">;
private typedef BlockEntry = hl.Abstract<"BlockEntry">;
private typedef Block = hl.Abstract<"Block">;
private typedef Tracks = hl.Abstract<"Tracks">;
private typedef Track = hl.Abstract<"Track">;

enum abstract TrackType(Int) {
	var Video = 0x01;
	var Audio = 0x02;
	var Subtitle = 0x11;
	var Metadata = 0x21;
}

enum abstract CodecId(String) {
	var VP8 = "V_VP8";
	var VP9 = "V_VP9";
	var AV1 = "V_AV1";
}

typedef Frame = {
	var image : Aom.Image;
};

@:hlNative("?video")
class Webm {
	var reader : MkvReader;

	var segment : Segment;
	var cluster : Cluster;
	var blockEntry : BlockEntry;
	var block : Block;

	var blockFrameIndex : Int = 0;

	var videoTrack : Track;
	public var videoCodec(default,null) : CodecId;
	public var availableSize(never,set) : Int;

	public var width : Int;
	public var height : Int;

	var reachedEos = false;
	var isInit = false;

	function new() {
	}

	public static function fromFile(file:String) : Webm {
		var webm = new Webm();

		webm.reader = webm_open_file(@:privateAccess file.toUtf8());
		if(webm.reader == null)
			throw "File " + file + " doesn't exists";
		webm.init();
		return webm;
	}

	public static function fromReader(onRead : (Int, Int) -> haxe.io.Bytes, fullSize : Int) : Webm {
		var webm = new Webm();
		webm.reader = webm_open_buffer(function(offset : Int, length : Int, data : hl.Bytes):Int {
			var bytes = onRead(offset, length);
			if(bytes == null)
				return -1;
			var src = hl.Bytes.fromBytes(bytes);
			data.blit(0, src, 0, length);
			return 0;
		}, fullSize);
		if(webm.reader == null)
			throw "Failed to open webm buffer";
		return webm;
	}

	public function init() {
		segment = webm_segment_create(reader);
		if(segment == null)
			throw "Can't open mkv segment : bad format ?";

		for(t in webm_segment_get_tracks(segment)) {
			if(webm_track_get_type(t) == cast Video) {
				videoTrack = t;
				var w = 0;
				var h = 0;
				webm_track_get_size(t, w, h);
				width = w;
				height = h;
			}
		}
		if(videoTrack == null)
			throw "No video track found";
		videoCodec = cast @:privateAccess String.fromUTF8(webm_track_get_codec_id(videoTrack));
		if(videoCodec == null)
			throw "Invalid codec";
		cluster = webm_segment_get_first(segment);
		if(cluster == null)
			throw "Video track cluster can't be found";
		isInit = true;
	}

	function set_availableSize(size : Int) : Int {
		webm_buffer_set_available_size(reader, size);
		return size;
	}

	public function readFrame(codec : hl.video.Aom.Codec, buffer : haxe.io.Bytes) : Null<Float> {
		var frame = readMkvFrame();
		if(frame == null)
			return null;
		codec.decode(frame.data);
		codec.getNextFrame(buffer);
		return frame.time;
	}

	public function rewind() {
		blockEntry = null;
		block = null;
		blockFrameIndex = 0;
		reachedEos = false;
		cluster = webm_segment_get_first(segment);
		if(cluster == null)
			throw "Video track cluster can't be found";
	}

	function readMkvFrame() : {data: haxe.io.Bytes, time: Float} {
		if(reader == null || reachedEos)
			return null;
		var blockEntryEos = false;
		do {
			var getNewBlock = false;
			if(blockEntry == null && !blockEntryEos) {
				blockEntry = webm_cluster_get_first(cluster);
				if(blockEntry == null) throw "got null block";
				getNewBlock = true;
			}
			else if(blockEntryEos || webm_blockentry_eos(blockEntry)) {
				cluster = webm_segment_get_next(segment, cluster);
				if(cluster == null || webm_cluster_eos(cluster)) {
					reachedEos = true;
					return null;
				}
				blockEntry = webm_cluster_get_first(cluster);
				blockEntryEos = false;
				getNewBlock = true;
			}
			else if(block == null || blockFrameIndex == webm_block_get_frame_count(block) || webm_block_get_track_number(block) != webm_track_get_number(videoTrack)) {
				blockEntry = webm_cluster_get_next(cluster, blockEntry);
				if(blockEntry == null || webm_blockentry_eos(blockEntry)) {
					blockEntryEos = true;
					continue;
				}
				getNewBlock = true;
			}
			if(getNewBlock) {
				block = webm_blockentry_get_block(blockEntry);
				if(block == null)
					return null;
				blockFrameIndex = 0;
			}
		} while(blockEntryEos || webm_block_get_track_number(block) != webm_track_get_number(videoTrack));

		var len = webm_block_get_frame_length(block, blockFrameIndex);
		var buf = webm_block_get_frame(block, reader, blockFrameIndex++);
		return {
			data: buf.toBytes(len),
			time: webm_block_get_time(block, cluster) / 1000000000
		};
	}

	public function createCodec() {
		return switch(videoCodec) {
			case AV1:
				return new Aom.AV1();
			default:
				throw videoCodec + " not implemented";
		}
	}

	public function close() {
		if(reader == null)
			return;
		webm_close(reader);
		reader = null;
	}

	static function webm_open_file(filename : hl.Bytes) : MkvReader {
		return null;
	}

	static function webm_open_buffer(onRead : (Int, Int, hl.Bytes) -> Int, size : Int) : MkvReader {
		return null;
	}

	static function webm_buffer_set_available_size(reader : MkvReader, size : Int) : Bool {
		return false;
	}

	static function webm_close(reader : MkvReader) : Void {}

	static function webm_segment_create(reader : MkvReader) : Segment {
		return null;
	}

	static function webm_segment_get_tracks(segment : Segment) : hl.NativeArray<Track> {
		return null;
	}

	static function webm_segment_get_first(segment : Segment) : Cluster {
		return null;
	}

	static function webm_segment_get_next(segment : Segment, cur : Cluster) : Cluster {
		return null;
	}

	static function webm_cluster_get_first(cluster : Cluster) : BlockEntry {
		return null;
	}

	static function webm_cluster_get_next(cluster : Cluster, cur : BlockEntry) : BlockEntry {
		return null;
	}

	static function webm_cluster_eos(cluster : Cluster) : Bool {
		return false;
	}

	static function webm_blockentry_eos(block : BlockEntry) : Bool {
		return false;
	}

	static function webm_blockentry_get_block(block : BlockEntry) : Block {
		return null;
	}

	static function webm_block_get_frame_count(block : Block) : Int {
		return 0;
	}

	static function webm_block_get_track_number(block : Block) : Int {
		return 0;
	}

	static function webm_block_get_frame(block : Block, reader : MkvReader, idx : Int) : hl.Bytes {
		return null;
	}

	static function webm_block_get_frame_length(block: Block, idx : Int) : Int {
		return 0;
	}

	static function webm_block_get_time(block : Block, cluster : Cluster) : Float {
		return 0;
	}

	static function webm_block_is_key(block : Block) : Bool {
		return false;
	}

	static function webm_track_get_number(track : Track) : Int {
		return 0;
	}

	static function webm_track_get_type(track : Track) : Int {
		return 0;
	}

	static function webm_track_get_codec_id(track : Track) : hl.Bytes {
		return null;
	}

	static function webm_track_get_size(track : Track, width : hl.Ref<Int>, height : hl.Ref<Int>) : Bool {
		return false;
	}

	static function webm_track_get_framerate(track : Track) : Float {
		return 0.;
	}

	static function webm_segment_get_tracks_count(tracks : Tracks) : Int {
		return 0;
	}
}
