#define HL_NAME(n) video_##n

#include "hl.h"
#include "aom/aom.h"
#include "aom/aom_decoder.h"
#include "aom/aomdx.h"
#include "mkvparser/mkvparser.h"
#include "mkvparser/mkvreader.h"
#include "libyuv/convert_argb.h"
#include "libyuv/row.h"

using namespace mkvparser;

// Reader

class MkvHlBuffer : public IMkvReader {
private:
	vclosure* m_onRead;

	long long m_totalSize;
	long long m_availableSize;

public:
	MkvHlBuffer(vclosure* onRead, long long totalSize) {
		m_onRead = onRead;
		hl_add_root(&m_onRead);

		m_totalSize = totalSize;
		m_availableSize = 0;
	}

	~MkvHlBuffer() {
		hl_remove_root(&m_onRead);
	}

	virtual int Read(long long offset, long len, unsigned char* buffer) {
		vdynamic hl_offset;
		hl_offset.t = &hlt_i32;
		hl_offset.v.i = (int) offset;

		vdynamic hl_len;
		hl_len.t = &hlt_i32;
		hl_len.v.i = len;

		vdynamic hl_buffer;
		hl_buffer.t = &hlt_bytes;
		hl_buffer.v.ptr = buffer;

		vdynamic* dArgs[3];
		dArgs[0] = &hl_offset;
		dArgs[1] = &hl_len;
		dArgs[2] = &hl_buffer;
		vdynamic* ret = hl_dyn_call(m_onRead, dArgs, 3);
		int r = ret->v.i;

		return 0;
	}

	void setAvailableSize(long long size) {
		m_availableSize = size;
	}

	virtual int Length(long long* total, long long* available) {
		*total = m_totalSize;
		*available = m_availableSize;

		return 0;
	}
};

HL_PRIM IMkvReader* HL_NAME(webm_open_file)(char* filename) {
	FILE* file = fopen(filename, "rb");
	if (file == NULL)
		return NULL;
	return new MkvReader(file);
}

HL_PRIM IMkvReader* HL_NAME(webm_open_buffer)(vclosure* onRead, long long size) {
	return new MkvHlBuffer(onRead, size);
}

HL_PRIM bool HL_NAME(webm_buffer_set_available_size)(IMkvReader* reader, long long available_size) {
	MkvHlBuffer* buffer = dynamic_cast<MkvHlBuffer*>(reader);
	if (!buffer)
		return false;
	buffer->setAvailableSize(available_size);
	return true;
}

HL_PRIM void HL_NAME(webm_close)(IMkvReader* reader) {
	MkvHlBuffer* buffer = dynamic_cast<MkvHlBuffer*>(reader);
	if (buffer) {
		delete buffer;
		return;
	}
	MkvReader* r = dynamic_cast<MkvReader*>(reader);
	if (r) {
		r->Close();
		return;
	}
}

HL_PRIM Segment* HL_NAME(webm_segment_create)(IMkvReader* reader) {
	EBMLHeader header;
	long long pos = 0;
	if (header.Parse(reader, pos) < 0) {
		return NULL;
	}
	Segment* segment = (Segment*) hl_alloc_bytes(sizeof(Segment));
	Segment::CreateInstance(reader, pos, segment);
	if (segment->Load() < 0)
		return NULL;
	return segment;
}

#define _MKV_READER _ABSTRACT(IMkvReader)
#define _SEGMENT _ABSTRACT(Segment)

DEFINE_PRIM(_MKV_READER, webm_open_file, _BYTES);
DEFINE_PRIM(_MKV_READER, webm_open_buffer, _FUN(_I32, _I32 _I32 _BYTES) _I32);
DEFINE_PRIM(_BOOL, webm_buffer_set_available_size, _MKV_READER _I32);
DEFINE_PRIM(_SEGMENT, webm_segment_create, _MKV_READER);
DEFINE_PRIM(_VOID, webm_close, _MKV_READER);

// Segment

HL_PRIM varray* HL_NAME(webm_segment_get_tracks)(Segment* segment) {
	long count = segment->GetTracks()->GetTracksCount();
	varray* arr = hl_alloc_array(&hlt_bytes, count);
	for (int i = 0; i < count; i++) {
		hl_aptr(arr, vbyte*)[i] = (vbyte*) segment->GetTracks()->GetTrackByIndex(i);
	}
	return arr;
}

HL_PRIM const Cluster* HL_NAME(webm_segment_get_first)(Segment* segment) {
	return segment->GetFirst();
}

HL_PRIM const Cluster* HL_NAME(webm_segment_get_next)(Segment* segment, Cluster* cur) {
	return segment->GetNext(cur);
}

#define _CLUSTER _ABSTRACT(Cluster)

DEFINE_PRIM(_ARR, webm_segment_get_tracks, _SEGMENT);
DEFINE_PRIM(_CLUSTER, webm_segment_get_first, _SEGMENT);
DEFINE_PRIM(_CLUSTER, webm_segment_get_next, _SEGMENT _CLUSTER);

// Cluster

HL_PRIM const BlockEntry* HL_NAME(webm_cluster_get_first)(const Cluster* cluster) {
	const BlockEntry* block = NULL;
	cluster->GetFirst(block);
	return block;
}

HL_PRIM const BlockEntry* HL_NAME(webm_cluster_get_next)(Cluster* cluster, BlockEntry* cur) {
	const BlockEntry* block = NULL;
	cluster->GetNext(cur, block);
	return block;
}

HL_PRIM bool HL_NAME(webm_cluster_eos)(Cluster* cluster) {
	return cluster->EOS();
}

#define _BLOCK_ENTRY _ABSTRACT(BlockEntry)

DEFINE_PRIM(_BLOCK_ENTRY, webm_cluster_get_first, _CLUSTER);
DEFINE_PRIM(_BLOCK_ENTRY, webm_cluster_get_next, _CLUSTER _BLOCK_ENTRY);
DEFINE_PRIM(_BOOL, webm_cluster_eos, _CLUSTER);

// Block entry

HL_PRIM bool HL_NAME(webm_blockentry_eos)(BlockEntry* block_entry) {
	return block_entry->EOS();
}

HL_PRIM const Block* HL_NAME(webm_blockentry_get_block)(BlockEntry* block_entry) {
	return block_entry->GetBlock();
}

#define _BLOCK _ABSTRACT(Block)

DEFINE_PRIM(_BOOL, webm_blockentry_eos, _BLOCK_ENTRY);
DEFINE_PRIM(_BLOCK, webm_blockentry_get_block, _BLOCK_ENTRY);

// Block

HL_PRIM int HL_NAME(webm_block_get_frame_count)(Block* block) {
	return block->GetFrameCount();
}

HL_PRIM long long HL_NAME(webm_block_get_track_number)(Block* block) {
	return block->GetTrackNumber();
}

HL_PRIM uint8_t* HL_NAME(webm_block_get_frame)(Block* block, MkvReader* reader, int idx) {
	Block::Frame frame = block->GetFrame(idx);
	vbyte* bytes = hl_alloc_bytes(frame.len);
	frame.Read(reader, bytes);
	return bytes;
}

HL_PRIM long HL_NAME(webm_block_get_frame_length)(Block* block, int idx) {
	Block::Frame frame = block->GetFrame(idx);
	return frame.len;
}

HL_PRIM double HL_NAME(webm_block_get_time)(Block* block, Cluster* cluster) {
	return (double) block->GetTime(cluster);
}

HL_PRIM bool HL_NAME(webm_block_is_key)(Block* block) {
	return block->IsKey();
}

#define _BLOCK _ABSTRACT(Block)

DEFINE_PRIM(_I32, webm_block_get_frame_count, _BLOCK);
DEFINE_PRIM(_I32, webm_block_get_track_number, _BLOCK);
DEFINE_PRIM(_BYTES, webm_block_get_frame, _BLOCK _MKV_READER _I32);
DEFINE_PRIM(_I32, webm_block_get_frame_length, _BLOCK _I32);
DEFINE_PRIM(_F64, webm_block_get_time, _BLOCK _CLUSTER);
DEFINE_PRIM(_BOOL, webm_block_is_key, _BLOCK);

// Tracks

HL_PRIM int HL_NAME(webm_segment_get_tracks_count)(Tracks* tracks) {
	return tracks->GetTracksCount();
}

#define _TRACKS _ABSTRACT(Tracks)

DEFINE_PRIM(_I32, webm_segment_get_tracks_count, _TRACKS);

// Track

HL_PRIM long HL_NAME(webm_track_get_number)(Track* track) {
	return track->GetNumber();
}

HL_PRIM long HL_NAME(webm_track_get_type)(Track* track) {
	return track->GetType();
}

HL_PRIM char* HL_NAME(webm_track_get_codec_id)(Track* track) {
	return (char*) hl_copy_bytes((vbyte*) track->GetCodecId(), (int)strlen(track->GetCodecId()) + 1);
}

HL_PRIM bool HL_NAME(webm_track_get_size)(Track* track, int* width, int* height) {
	if (track->GetType() != Track::kVideo)
		return false;
	const VideoTrack* vtrack = static_cast<const VideoTrack*>(track);
	*width = (int)vtrack->GetWidth();
	*height = (int)vtrack->GetHeight();
	return true;
}

HL_PRIM double HL_NAME(webm_track_get_framerate)(Track* track) {
	if (track->GetType() != Track::kVideo)
		return 0;
	const VideoTrack* vtrack = static_cast<const VideoTrack*>(track);
	return vtrack->GetFrameRate();
}

#define _TRACK _ABSTRACT(Track)

DEFINE_PRIM(_I32, webm_track_get_number, _TRACK);
DEFINE_PRIM(_I32, webm_track_get_type, _TRACK);
DEFINE_PRIM(_BYTES, webm_track_get_codec_id, _TRACK);
DEFINE_PRIM(_BOOL, webm_track_get_size, _TRACK _REF(_I32) _REF(_I32));
DEFINE_PRIM(_F64, webm_track_get_framerate, _TRACK);

// AOM

HL_PRIM aom_codec_ctx_t* HL_NAME(aom_codec_get_av1)() {
	aom_codec_ctx_t* codec = (aom_codec_ctx_t*) hl_alloc_bytes(sizeof(aom_codec_ctx_t));
	aom_codec_dec_init(codec, aom_codec_av1_dx(), NULL, 0);
	return codec;
}

HL_PRIM void HL_NAME(aom_codec_decode)(aom_codec_ctx_t *codec, uint8_t *frame, size_t frame_size) {
	aom_codec_decode(codec, frame, frame_size, NULL);
}

varray* realloc_array(varray* arr, hl_type* t, int new_size) {
	if (new_size <= arr->size)
		return arr;
	int buflen = arr->size * 3;
	varray* narr = hl_alloc_array(t, buflen);
	memcpy((void*) (narr+1), (void*) (arr+1), buflen);
	return narr;
}

HL_PRIM aom_codec_iter_t* HL_NAME(aom_codec_init_iter)() {
	aom_codec_iter_t *it = (aom_codec_iter_t*) hl_alloc_bytes(sizeof(aom_codec_iter_t));
	memset(it, 0, sizeof(aom_codec_iter_t));
	return it;
}

HL_PRIM aom_image_t* HL_NAME(aom_codec_get_frame)(aom_codec_ctx_t* codec, aom_codec_iter_t* iter) {
	return aom_codec_get_frame(codec, iter);
}

HL_PRIM void HL_NAME(aom_codec_destroy)(aom_codec_ctx_t* codec) {
	aom_codec_destroy(codec);
}

#define _CODEC _ABSTRACT(aom_codec_ctx_t)
#define _IMAGE _ABSTRACT(aom_image_t)
#define _ITER _ABSTRACT(aom_codec_iter_t)

DEFINE_PRIM(_CODEC, aom_codec_get_av1, _NO_ARG);
DEFINE_PRIM(_VOID, aom_codec_decode, _CODEC _BYTES _I32);
DEFINE_PRIM(_ITER, aom_codec_init_iter, _NO_ARG);
DEFINE_PRIM(_IMAGE, aom_codec_get_frame, _CODEC _ITER); 
DEFINE_PRIM(_VOID, aom_codec_destroy, _CODEC);

// AOM image

HL_PRIM void HL_NAME(aom_image_get_buffer)(aom_image_t* img, unsigned char* buffer) {
	int width = aom_img_plane_width(img, 0) * ((img->fmt & AOM_IMG_FMT_HIGHBITDEPTH) ? 2 : 1);
	int height = aom_img_plane_height(img, 0);
	libyuv::I420ToABGR(
		img->planes[0], img->stride[0],
		img->planes[1], img->stride[1],
		img->planes[2], img->stride[2],
		buffer, width*4,
		width, height);
}

DEFINE_PRIM(_VOID, aom_image_get_buffer, _IMAGE _BYTES);