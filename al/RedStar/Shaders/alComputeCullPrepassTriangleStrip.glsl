/**
 * @file	alComputeCullPrepassTriangleStrip.glsl
 * @author	Matsuda Hirokazu  (C)Nintendo
 *
 * @brief	ComputeShader による事前カリング（Triangle Strip 版）
 */
#extension GL_NV_gpu_shader5 : enable
#extension GL_NV_desktop_lowp_mediump : enable
#extension GL_ARB_shading_language_packing : enable
#extension GL_NV_shader_thread_shuffle : require

#include "alComputeCullPrepassUtil.glsl"

#define IS_USING_SHUFFLE			(0)
#define IS_ENABLE_CULL_BACK_FACE	(0)
#define WORK_GROUP_SIZE				(1536)

#if defined( AGL_COMPUTE_SHADER )

#define	IF_NOT_VALID_RETURN()									\
	if (!is_thread_id_valid && 0 <= write_index)				\
	{															\
		sbIndexArrayWrite[write_index]		= INVALID_INDEX;	\
		sbIndexArrayWrite[write_index + 1]	= INVALID_INDEX;	\
		sbIndexArrayWrite[write_index + 2]	= INVALID_INDEX;	\
		return;													\
	}

layout (local_size_x = WORK_GROUP_SIZE, local_size_y = 1, local_size_z = 1) in;
void main()
{
	// global_invocation_index を頂点のインデックスとする
	// 0, 1 は shuffle するためだけのスレッドで三角形のインデックスは書き込まない
	uint global_invocation_index = gl_WorkGroupID.x * gl_WorkGroupSize.x + gl_LocalInvocationID.x;

	// 32 で分ける
	uint local_32_index = global_invocation_index & (32u - 1u); // 0x1Fu;
	uint warp_index = global_invocation_index >> 5; // 1/32
	uint vtx_index = warp_index * 32 + local_32_index - warp_index * 2; // 2 頂点ずつずれていく
	// 二番目以降のワークでは最初の 2 頂点は前の頂点にオーバーラップさせる。
	int tri_index = (int)vtx_index - 2;
	uint write_index = tri_index*3 + uBaseWriteIndex;

	// 頂点数だけ処理（それ以外は範囲外アクセスになる）
	if (0 <= tri_index && uOriginalTriangleNum <= tri_index)
	{
		sbIndexArrayWrite[write_index]		= INVALID_INDEX;
		sbIndexArrayWrite[write_index + 1]	= INVALID_INDEX;
		sbIndexArrayWrite[write_index + 2]	= INVALID_INDEX;
		return;
	}

	// 自分のデータだけ引く
	uint index_value = sbIndexArrayRead[vtx_index];
	vec3 vtx_pos = getPos3f(index_value);

	// 最初の２頂点は index = 0, 1 であっても 32 単位の最初の２頂点であっても良いが
	// どちらもデータをシャッフルするためだけのスレッド
	bool is_edge_discard = (2 > local_32_index);

#if (IS_USING_SHUFFLE == 0)
	if (is_edge_discard)	return;
	// TriangleStrip は表面裏面が交互に来る
	int prev1_offset, prev2_offset;
	if ((local_32_index & 0x01) == 0)	{ prev1_offset = 1; prev2_offset = 2; }
	else								{ prev1_offset = 2; prev2_offset = 1; }
	uint prev1_index = sbIndexArrayRead[vtx_index - prev1_offset];
	uint prev2_index = sbIndexArrayRead[vtx_index - prev2_offset];
	vec3 prev1_pos = getPos3f(prev1_index);
	vec3 prev2_pos = getPos3f(prev2_index);
#else
	// シャッフルして隣のデータを教えてもらう
	bool is_thread_id_valid = true;
	uint prev1_index, prev2_index;
	vec3 prev1_pos;
	vec3 prev2_pos;
	if ((local_32_index & 0x01) == 0)
	{
		#if 0
		prev1_index = shuffleDownNV(index_value, 1, 32, is_thread_id_valid);	IF_NOT_VALID_RETURN();
		prev2_index = shuffleDownNV(index_value, 2, 32, is_thread_id_valid);	IF_NOT_VALID_RETURN();
		// 頂点も教えてもらう
		prev1_pos = shuffleDownNV(vtx_pos, 1, 32, is_thread_id_valid);	IF_NOT_VALID_RETURN();
		prev2_pos = shuffleDownNV(vtx_pos, 2, 32, is_thread_id_valid);	IF_NOT_VALID_RETURN();
		#else
		// vec4 にまとめてシャッフルするこっちの方が速かった。
		vec4 shuffle_data = vec4(vtx_pos, index_value);
		vec4 prev1_data = shuffleDownNV(shuffle_data, 1, 32, is_thread_id_valid);	IF_NOT_VALID_RETURN();
		vec4 prev2_data = shuffleDownNV(shuffle_data, 2, 32, is_thread_id_valid);	IF_NOT_VALID_RETURN();
		prev1_pos = prev1_data.xyz;
		prev2_pos = prev2_data.xyz;
		prev1_index = (uint)prev1_data.w;
		prev2_index = (uint)prev2_data.w;
		#endif
	}
	else
	{
		#if 0
		prev1_index = shuffleDownNV(index_value, 2, 32, is_thread_id_valid);	IF_NOT_VALID_RETURN();
		prev2_index = shuffleDownNV(index_value, 1, 32, is_thread_id_valid);	IF_NOT_VALID_RETURN();
		// 頂点も教えてもらう
		prev1_pos = shuffleDownNV(vtx_pos, 2, 32, is_thread_id_valid);	IF_NOT_VALID_RETURN();
		prev2_pos = shuffleDownNV(vtx_pos, 1, 32, is_thread_id_valid);	IF_NOT_VALID_RETURN();
		#else
		// vec4 にまとめてシャッフルするこっちの方が速かった。
		vec4 shuffle_data = vec4(vtx_pos, index_value);
		vec4 prev1_data = shuffleDownNV(shuffle_data, 2, 32, is_thread_id_valid);	IF_NOT_VALID_RETURN();
		vec4 prev2_data = shuffleDownNV(shuffle_data, 1, 32, is_thread_id_valid);	IF_NOT_VALID_RETURN();
		prev1_pos = prev1_data.xyz;
		prev2_pos = prev2_data.xyz;
		prev1_index = (uint)prev1_data.w;
		prev2_index = (uint)prev2_data.w;
		#endif // 0
	}

	if (is_edge_discard)	return;
#endif // IS_USING_SHUFFLE

	// 裏面カリング
	#if (IS_ENABLE_CULL_BACK_FACE == 1)
	{
		#if 1
		vec3 pos0 = prev2_pos;
		vec3 pos1 = prev1_pos;
		vec3 pos2 = vtx_pos;
		vec3 p1_p0 = pos1 - pos0;
		vec3 p2_p0 = pos2 - pos0;
		// ２次元ベクトルで外積計算
	//	float cross = p1_p0.x * p2_p0.y - p1_p0.y * p2_p0.x;
		vec3 c = cross(p1_p0, p2_p0);
		if (c.z < 0.0)
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

	sbIndexArrayWrite[write_index]		= (WRITE_INDEX_TYPE)prev2_index;
	sbIndexArrayWrite[write_index + 1]	= (WRITE_INDEX_TYPE)prev1_index;
	sbIndexArrayWrite[write_index + 2]	= (WRITE_INDEX_TYPE)index_value;
}

#endif // defined( AGL_COMPUTE_SHADER )
