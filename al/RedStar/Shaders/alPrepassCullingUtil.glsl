/**
 *	@file	alPrepassCullingUtil.glsl
 *	@author	Matsuda Hirokazu  (C)Nintendo
 *
 *	@brief	事前カリングユーティリティ
 */
#ifndef AL_PREPASS_CULLING_UTIL_GLSL
#define AL_PREPASS_CULLING_UTIL_GLSL

/**
 *	入力インデックスバッファのフォーマットからタイプを選択
 */
#if IS_INDEX_16BIT
	#define READ_INDEX_TYPE		uint16_t
	#define WRITE_INDEX_TYPE	uint16_t
	#define INVALID_INDEX		(uint16_t)0xFFFFu
#else
	#define READ_INDEX_TYPE		uint
	#define WRITE_INDEX_TYPE	uint
	#define INVALID_INDEX		0xFFFFFFFF
#endif

#define USE_FLOAT16_T	(0)
/**
 *	入力バーテックスバッファのフォーマットからタイプを選択
 */
#if IS_MESH_FP16
	#if USE_FLOAT16_T
		#define READ_VERTEX_TYPE 	float16_t
	#else
		#define READ_VERTEX_TYPE	uint // 組み込み関数 unpackHalf2x16() で float にする。
	#endif // USE_FLOAT16_T
#else
	#define READ_VERTEX_TYPE	float
#endif

#if 1
/**
 *	Compute, Geometry 両方で必要な SSBO 
 */
layout(std430, binding = 1) buffer uSSBO_IndexArrayWrite
{
	WRITE_INDEX_TYPE sbIndexArrayWrite[];
};

layout(std430, binding = 2) buffer uSSBO_DrawElementsIndirectData
{
    int count;
    int instance_count;
    int first_index;
    int base_vertex;
    int base_instance;
};
#endif

/**
 *	Model
 *	  └ Shape (Material)
 *	      └ Mesh (LOD)
 *	         └ SubMesh
 *	SubMeshRange は同一 LOD での連続した SubMesh 描画の１単位
 *	LOD はつまり Mesh 指定なのでインデックスバッファの指定が必要
 *	uIndexBufferMemoryPoolOffset と uBaseReadIndex は一つにまとめられる
 
struct SubMeshRange
{
	uint 	uTriangleNum;
	uint 	uBaseVertex;
	uint	uIndexBufferMemoryPoolOffset; // 32bit で足りて欲しい
	uint 	uBaseWriteIndex; // SubMesh 対応
	// ここまででぴっちりパディングなし
};
 */

// SubMeshRange
#define SMR_TYPE						uvec4
#define SMR_TRI_NUM(range)				range.x
#define SMR_BASE_VERTEX(range)			range.y
#define SMR_MEMORY_POOL_OFFSET(range)	range.z
#define SMR_BASE_WRITE_INDEX(range)		range.w


#if 0
// back face culling
// P0, P1, P2 は clip space
bool trianglePassesBackFaceTest(in vec4 P0, in vec4 P1, in vec4 P2)
{
	//Triangle Scan Conversion using 2D Homogeneous Coordinates (http://www.cs.unc.edu/~olano/papers/2dh-tri/2dh-tri.pdf)
	// "for vertices defined by the righthand rule, the determinant is positive if the triangle is frontfacing and negative if the triangle is back-facing"
	return dot(P0.xyw, cross(P1.xyw, P2.xyw)) > 0; // return determinant(float3x3(P0.xyw, P1.xyw, P2.xyw)) > 0;
}
#endif

// xyw で判定するのが正しい。面の向きとゼロエリアカリングを行える
#if 0
#define CULL_SWIZZLE(p)	p.xyz
#else
#define CULL_SWIZZLE(p)	p.xyw
#endif

#define trianglePassesCullFaceTestBack(ret, p0, p1, p2)	{ ret = (dot(CULL_SWIZZLE(p0), cross(CULL_SWIZZLE(p1), CULL_SWIZZLE(p2))) > 0.0); }
#define trianglePassesCullFaceTestFront(ret, p0, p1, p2){ ret = (dot(CULL_SWIZZLE(p0), cross(CULL_SWIZZLE(p1), CULL_SWIZZLE(p2))) < 0.0); }
#define trianglePassesCullFaceTestAll(ret, p0, p1, p2)	{ ret = true; }
#define trianglePassesCullFaceTestNone(ret, p0, p1, p2)	{ ret = false; }

/**
 *	フラスタムカリング
 *	sc_pX は w で割った後の vec2
 */
void isTriangleFrustumAndSubPixelCulling(out bool is_pass, in vec4 p0, in vec4 p1, in vec4 p2, in vec2 sc_size)
{
	// スクリーンスペースへ
	vec2 sc_p0, sc_p1, sc_p2;
	sc_p0 = p0.xy / p0.w;
	sc_p1 = p1.xy / p1.w;
	sc_p2 = p2.xy / p2.w;
	// スクリーンスペースのバウンディングボックスを算出
	vec2 bb_min, bb_max;
	bb_min.x = min (min (sc_p0.x, sc_p1.x), sc_p2.x);
	bb_min.y = min (min (sc_p0.y, sc_p1.y), sc_p2.y);
	bb_max.x = max (max (sc_p0.x, sc_p1.x), sc_p2.x);
	bb_max.y = max (max (sc_p0.y, sc_p1.y), sc_p2.y);

	// サブピクセルカリングはバウンディングボックスをピクセル座標系に移す
	vec2 half_sc_size = 0.5 * sc_size;
	vec2 sc_min = round(bb_min * half_sc_size + half_sc_size);
	vec2 sc_max = round(bb_max * half_sc_size + half_sc_size);

	bool is_frustum_pass = (bb_max.x >= -1) && (bb_max.y >= -1) && (bb_min.x <= 1) && (bb_min.y <= 1);
	bool is_subpixel_pass = (sc_min.x != sc_max.x) && (sc_min.y != sc_max.y);
	is_pass = is_frustum_pass && is_subpixel_pass;
}

#if 0
// frustm culling
bool isTriangleAtLeastPartiallyVisible(in vec4 P0, in vec4 P1, in vec4 P2)
{
	// http://www.wihlidal.ca/Presentations/GDC_2016_Compute.pdf
    // frustum culling on normalized device coordinates
    const vec2 tp0 = clipSpaceToTexSpace(P0);
    const vec2 tp1 = clipSpaceToTexSpace(P1);
    const vec2 tp2 = clipSpaceToTexSpace(P2);
	
    const float minX = min (min (tp0.x, tp1.x), tp2.x);
    const float minY = min (min (tp0.y, tp1.y), tp2.y);
    const float maxX = max (max (tp0.x, tp1.x), tp2.x);
    const float maxY = max (max (tp0.y, tp1.y), tp2.y);

    return (maxX >= 0) && (maxY >= 0) && (minX <= 1) && (minY <= 1);
}
#endif // 0

#endif // AL_PREPASS_CULLING_UTIL_GLSL
