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

private typedef AOMCodec = hl.Abstract<"aom_codec_ctx_t">;
private typedef AOMImage = hl.Abstract<"aom_image_t">;
private typedef AOMIter = hl.Abstract<"aom_codec_iter_t">;

typedef Image = {
	var buffer : haxe.io.Bytes;
	var width : Int;
	var height : Int;
}

interface Codec {
	public function decode(frame : haxe.io.Bytes) : Void;
	public function getNextFrame(buffer : haxe.io.Bytes) : Bool;
	public function close() : Void;
}

@:hlNative("?video")
class AV1 implements Codec {
	var codec : AOMCodec;
	var iter : AOMIter = null;

	public function new() {
		codec = aom_codec_get_av1();
		if(codec == null)
			throw "Can't create AV1 codec";
	}

	public function decode(frame : haxe.io.Bytes) : Void {
		if(codec == null)
			return;
		if(frame != null) {
			aom_codec_decode(codec, hl.Bytes.fromBytes(frame), frame.length);
			iter = aom_codec_init_iter();
			if(iter == null)
				throw "Failed to alloc iterator";
		}
		else
			iter = null;
	}

	public function getNextFrame(buffer : haxe.io.Bytes) : Bool {
		if(codec == null || iter == null)
			return false;
		var image = aom_codec_get_frame(codec, iter);
		if(iter == null)
			throw "Iterator didn't allocated properly";
		if(image == null)
			return false;
		if(buffer == null)
			return false;
		aom_image_get_buffer(image, hl.Bytes.fromBytes(buffer));
		return true;
	}

	public function close() : Void {
		aom_codec_destroy(codec);
		codec = null;
	}

	static function aom_codec_get_av1() : AOMCodec {
		return null;
	}

	static function aom_codec_decode(codec : AOMCodec, frame : hl.Bytes, frameSize : Int) : Void {}

	static function aom_codec_init_iter() : AOMIter {
		return null;
	}

	static function aom_codec_get_frame(codec : AOMCodec, iter : AOMIter) : AOMImage {
		return null;
	}

	static function aom_codec_destroy(codec : AOMCodec) : Void {}

	static function aom_image_get_buffer(image : AOMImage, buffer : hl.Bytes) : Void {}
}
