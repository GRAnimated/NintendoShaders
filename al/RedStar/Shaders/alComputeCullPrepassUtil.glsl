/**
 * @file	alComputeCullPrepassUtil.glsl
 * @author	Matsuda Hirokazu  (C)Nintendo
 *
 * @brief	ComputeShader による事前カリングユーティリティ
 */

// 各種データのフォーマット
#define IS_MESH_FP16				(0)
#define IS_INDEX_16BIT				(0)
#define IS_WRITE_INDEX_16BIT		(0)

#include "alPrepassCullingUtil.glsl"

/**
 *	Compute Shader において Uniform Block へのアクセスで速いのは 0 ～ 4 まで。
 */
layout(std140, binding = 1) uniform CullPrepassUbo // @@ id="cCullPrepassUbo"
{
	vec2	uPosCullTestValue;
	int		uPosOffset;
	int		uVertexStrideByte;
	// 各シェイプの SubMesh 数と各マテリアル分確保したい
	// x : tri num, y : base vertex, z : Index Buffer Memory Pool Offset, w : base write index
	SMR_TYPE	uSubMeshRange[128];
};


/**
 *	VertexBuffer, IndexBuffer の SSBO 経由でのRead, Write
 */
layout(std430, binding = 3) readonly  buffer uSSBO_IndexArrayRead	{ READ_INDEX_TYPE	sbIndexArrayRead[];	};
layout(std430, binding = 4) readonly  buffer uSSBO_VertexArrayRead	{ READ_VERTEX_TYPE	sbVertexArrayRead[];};

/**
 *	トライアングル指定のインデックスバッファの読み込み
 */
uvec3 getIndexReadTriangle(uint tri_index, in SMR_TYPE sub_mesh_range)
{
	uint index_base = tri_index*3 + SMR_MEMORY_POOL_OFFSET(sub_mesh_range);
	return uvec3( (uint)sbIndexArrayRead[index_base]   + SMR_BASE_VERTEX(sub_mesh_range)
				, (uint)sbIndexArrayRead[index_base+1] + SMR_BASE_VERTEX(sub_mesh_range)
				, (uint)sbIndexArrayRead[index_base+2] + SMR_BASE_VERTEX(sub_mesh_range));
}

/**
 *	インデックスバッファの読み込み
 */
uint getIndexRead(uint index, in SMR_TYPE sub_mesh_range)
{
	uint index_base = index + SMR_MEMORY_POOL_OFFSET(sub_mesh_range);
	return (uint)sbIndexArrayRead[index_base] + SMR_BASE_VERTEX(sub_mesh_range);
}

/**
 *	Vertex の Read
 */
vec3 getPos3f(uint index)
{
#if IS_MESH_FP16
	#if USE_FLOAT16_T
	 return vec3((float)sbVertexArrayRead[index*uVertexStrideByte/2 + uPosOffset]
	 		   , (float)sbVertexArrayRead[index*uVertexStrideByte/2 + uPosOffset + 1]
	 		   , (float)sbVertexArrayRead[index*uVertexStrideByte/2 + uPosOffset + 2]);
	#else
	// u32 に二つの float が入っている
	return vec3(unpackHalf2x16(sbVertexArrayRead[index*uVertexStrideByte/4 + uPosOffset]).xy
			  , unpackHalf2x16(sbVertexArrayRead[index*uVertexStrideByte/4 + uPosOffset + 1]).x);
	#endif // USE_FLOAT16_T
#else
	 return vec3(sbVertexArrayRead[index*uVertexStrideByte/4 + uPosOffset]
	 		   , sbVertexArrayRead[index*uVertexStrideByte/4 + uPosOffset + 1]
	 		   , sbVertexArrayRead[index*uVertexStrideByte/4 + uPosOffset + 2]);
#endif // IS_MESH_FP16
}

#if 0
// チアゴさんから頂いた HLSL の実装コード
// back face culling
// P0, P1, P2 は clip space
bool trianglePassesBackFaceTest(float4 P0, float4 P1, float4 P2){
	//Triangle Scan Conversion using 2D Homogeneous Coordinates (http://www.cs.unc.edu/~olano/papers/2dh-tri/2dh-tri.pdf)
	// "for vertices defined by the righthand rule, the determinant is positive if the triangle is frontfacing and negative if the triangle is back-facing"
	return dot(P0.xyw, cross(P1.xyw, P2.xyw)) > 0; // return determinant(float3x3(P0.xyw, P1.xyw, P2.xyw)) > 0;
}

// frustm culling
bool isTriangleAtLeastPartiallyVisible(float4 P0, float4 P1, float4 P2){
	// http://www.wihlidal.ca/Presentations/GDC_2016_Compute.pdf
    // frustum culling on normalized device coordinates
    const float2 tp0 = clipSpaceToTexSpace(P0);
    const float2 tp1 = clipSpaceToTexSpace(P1);
    const float2 tp2 = clipSpaceToTexSpace(P2);
	
    const float minX = min (min (tp0.x, tp1.x), tp2.x);
    const float minY = min (min (tp0.y, tp1.y), tp2.y);
    const float maxX = max (max (tp0.x, tp1.x), tp2.x);
    const float maxY = max (max (tp0.y, tp1.y), tp2.y);

    return (maxX >= 0) && (maxY >= 0) && (minX <= 1) && (minY <= 1);
}

#endif
