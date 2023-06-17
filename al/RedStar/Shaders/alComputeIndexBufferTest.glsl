/**
 * @file	alComputeIndexBufferTest.glsl
 * @author	Matsuda Hirokazu  (C)Nintendo
 *
 * @brief	インデックスバッファを作り出すコンピュートシェーダのテストコード
 */

#extension GL_NV_gpu_shader5 : enable
#extension GL_NV_desktop_lowp_mediump : enable
#extension GL_ARB_shading_language_packing : enable

#define IS_ENABLE_CULL_BACK_FACE	(0)

#define IS_MESH_FP16				(0)
#define IS_INDEX_16BIT				(0)
#define IS_WRITE_INDEX_16BIT		(0)

#if IS_WRITE_INDEX_16BIT
	#define WRITE_INDEX_TYPE	uint16_t
	#define INVALID_INDEX		(uint16_t)0xFFFFu
#else
	#define WRITE_INDEX_TYPE	uint
	#define INVALID_INDEX		0xFFFFFFFF
#endif

#if defined( AGL_COMPUTE_SHADER )

layout(std140, binding = 1) uniform CullPrepassUbo // @@ id="cCullPrepassUbo"
{
	int		uOriginalTriangleNum;
	vec2	uPosCullTestValue;
	int		uPosOffset;
	int		uVertexStrideByte;
};

layout(std430, binding = 3) readonly buffer uSSBO_IndexArrayRead
{
#if IS_INDEX_16BIT
	uint16_t sbIndexArrayRead[];
#else
	uint sbIndexArrayRead[];
#endif
};

/**
 *	インデックスバッファの読み込み
 */
uvec3 getIndexRead(uint tri_index)
{
	uint index_base = tri_index*3;
	return uvec3((uint)sbIndexArrayRead[index_base], (uint)sbIndexArrayRead[index_base+1], (uint)sbIndexArrayRead[index_base+2]);
}

#define USE_FLOAT16_T	(0)

/**
 *	VertexBuffer の SSBO 経由でのRead
 */
layout(std430, binding = 4) readonly buffer uSSBO_VertexArray
{
#if IS_MESH_FP16
	#if USE_FLOAT16_T
		float16_t	sbVertexArray[];
	#else
		uint		sbVertexArray[]; // 組み込み関数 unpackHalf2x16() で float にする。
	#endif // USE_FLOAT16_T
#else
	float	sbVertexArray[];
#endif
};

vec2 getPos2f(uint index)
{
#if IS_MESH_FP16
	#if USE_FLOAT16_T
	 return vec2((float)sbVertexArray[index*uVertexStrideByte/2 + uPosOffset]
	 		   , (float)sbVertexArray[index*uVertexStrideByte/2 + uPosOffset + 1]);
	#else
	// u32 に二つの float が入っている
	return unpackHalf2x16(sbVertexArray[index*uVertexStrideByte/4 + uPosOffset]).xy;
	#endif // USE_FLOAT16_T
#else
	 return vec2(sbVertexArray[index*uVertexStrideByte/4 + uPosOffset]
	 		   , sbVertexArray[index*uVertexStrideByte/4 + uPosOffset + 1]);
#endif // IS_MESH_FP16
}

layout(std430, binding = 5) writeonly buffer uSSBO_IndexArrayWrite
{
#if IS_WRITE_INDEX_16BIT
	uint16_t sbIndexArrayWrite[];
#else
	uint sbIndexArrayWrite[];
#endif // IS_WRITE_INDEX_16BIT
};

// Switch は合計 1536。xの最大値は 1536, y の最大値は 1024, z の最大値は 64 参考ソース： nvn_DeviceConstantsNX.h
// dispatch の最大数は十分あるようだ。
layout (local_size_x = 1536, local_size_y = 1, local_size_z = 1) in;
void main()
{
	// global_invocation_index を三角形のインデックスとする
	uint tri_index = gl_WorkGroupID.x * gl_WorkGroupSize.x + gl_LocalInvocationID.x;
	uint write_index = tri_index*3;//atomicAdd(sbIndexCount, 3); // triangles  atomicAdd はオリジナルの値を返す

	// 頂点数だけ処理（それ以外は範囲外アクセスになる）
	if (uOriginalTriangleNum <= tri_index)
	{
		sbIndexArrayWrite[write_index]		= INVALID_INDEX;
		sbIndexArrayWrite[write_index + 1]	= INVALID_INDEX;
		sbIndexArrayWrite[write_index + 2]	= INVALID_INDEX;
		return;
	}
	#if 0
	if ((tri_index & 0x01) == 0)
	{
		sbIndexArrayWrite[write_index]		= INVALID_INDEX;
		sbIndexArrayWrite[write_index + 1]	= INVALID_INDEX;
		sbIndexArrayWrite[write_index + 2]	= INVALID_INDEX;
		return;
	}
	#endif
	
	// インデックスバッファを読む
	uvec3 ind = getIndexRead(tri_index);

	// 裏面カリング
	#if (IS_ENABLE_CULL_BACK_FACE == 1)
	{
		#if 1
		vec2 pos0 = getPos2f(ind.x);
		vec2 pos1 = getPos2f(ind.y);
		vec2 pos2 = getPos2f(ind.z);
		vec2 p1_p0 = pos1 - pos0;
		vec2 p2_p0 = pos2 - pos0;
		// ２次元ベクトルで外積計算
		float cross = p1_p0.x * p2_p0.y - p1_p0.y * p2_p0.x;
	//	vec3 c = cross(pos1.xyz - pos0.xyz, pos2.xyz - pos0.xyz);
		if (cross < 0.0)
		{
			sbIndexArrayWrite[write_index]		= INVALID_INDEX;
			sbIndexArrayWrite[write_index + 1]	= INVALID_INDEX;
			sbIndexArrayWrite[write_index + 2]	= INVALID_INDEX;
			return;
		}
		#elif 0
		// 偶数ポリゴンだけ通してみる
		if ((tri_index % 2) == 1)
		{
			sbIndexArrayWrite[write_index]		= INVALID_INDEX;
			sbIndexArrayWrite[write_index + 1]	= INVALID_INDEX;
			sbIndexArrayWrite[write_index + 2]	= INVALID_INDEX;
			return;
		}
		#else
		{
			// 座標で判定してみる
			vec2 pos0 = getPos2f(ind.x);
		//	vec4 pos0 = sbVertexArray[ind0].pos;
		//	float pos0_y = sbVertexArray[ind0].pos_y;
			if (pos0.y < uPosCullTestValue.y && pos0.x < uPosCullTestValue.x)
			{
				sbIndexArrayWrite[write_index]		= INVALID_INDEX;
				sbIndexArrayWrite[write_index + 1]	= INVALID_INDEX;
				sbIndexArrayWrite[write_index + 2]	= INVALID_INDEX;
				return;
			}
		}
		#endif
	}
	#endif // IS_ENABLE_CULL_BACK_FACE

	// ひとまず単純なコピー
	sbIndexArrayWrite[write_index]		= (WRITE_INDEX_TYPE)ind.x;
	sbIndexArrayWrite[write_index + 1]	= (WRITE_INDEX_TYPE)ind.y;
	sbIndexArrayWrite[write_index + 2]	= (WRITE_INDEX_TYPE)ind.z;
}

#endif // defined( AGL_COMPUTE_SHADER )
