/**
 * @file	alComputeCullPrepass.glsl
 * @author	Matsuda Hirokazu  (C)Nintendo
 *
 * @brief	ComputeShader による事前カリング
 */
#extension GL_NV_gpu_shader5 : enable
#extension GL_NV_desktop_lowp_mediump : enable
#extension GL_ARB_shading_language_packing : enable
#extension GL_NV_shader_thread_shuffle : require
#extension GL_NV_shader_thread_group : require

#include "alComputeCullPrepassUtil.glsl"

#define IS_USING_SHUFFLE_VOTE		(0)
#define IS_ENABLE_CULL_BACK_FACE	(0)
#define IS_USING_ATOMIC_INDIRECT	(0)

// Switch は合計 1536。xの最大値は 1536, y の最大値は 1024, z の最大値は 64 参考ソース： nvn_DeviceConstantsNX.h
// dispatch の最大数は十分あるようだ。
#define WORK_GROUP_SIZE				(1536)

#if IS_USING_SHUFFLE_VOTE
	#define WriteIndex(ind, write_index)	\
		sbIndexArrayWrite[write_index]	= (WRITE_INDEX_TYPE)ind
		
	#define WriteIndexInvalid(write_index)	\
		sbIndexArrayWrite[write_index]	= INVALID_INDEX

	// シャッフルして隣のデータを教えてもらう
	#define GetTrianglePos(ind)			\
		{								\
			if (thread_index_id == 0)		\
			{								\
				pos0 = getPos3f(ind);		\
				pos1 = shuffleDownNV(pos0, 1, 32);	\
				pos2 = shuffleDownNV(pos0, 2, 32);	\
			}								\
			else if (thread_index_id == 1)	\
			{								\
				pos1 = getPos3f(ind);		\
				pos0 = shuffleUpNV  (pos1, 1, 32);	\
				pos2 = shuffleDownNV(pos1, 1, 32);	\
			}								\
			else if (thread_index_id == 2)	\
			{								\
				pos2 = getPos3f(ind);		\
				pos0 = shuffleUpNV(pos2, 2, 32);	\
				pos1 = shuffleUpNV(pos2, 1, 32);	\
			}	\
		}

#else
	#define WriteIndex(ind, write_index)								\
		sbIndexArrayWrite[write_index]		= (WRITE_INDEX_TYPE)ind.x;	\
		sbIndexArrayWrite[write_index + 1]	= (WRITE_INDEX_TYPE)ind.y;	\
		sbIndexArrayWrite[write_index + 2]	= (WRITE_INDEX_TYPE)ind.z;

	#define WriteIndexInvalid(write_index)						\
		sbIndexArrayWrite[write_index]		= INVALID_INDEX;	\
		sbIndexArrayWrite[write_index + 1]	= INVALID_INDEX;	\
		sbIndexArrayWrite[write_index + 2]	= INVALID_INDEX;
	
	#define GetTrianglePos(ind)		\
		pos0 = getPos3f(ind.x);		\
		pos1 = getPos3f(ind.y);		\
		pos2 = getPos3f(ind.z);
#endif


#if defined( AGL_COMPUTE_SHADER )

layout (local_size_x = WORK_GROUP_SIZE, local_size_y = 1, local_size_z = 1) in;
void main()
{
	// Case : Triangle List
	// global_invocation_index を三角形のインデックスとする
//	uint tri_index = gl_WorkGroupID.x * gl_WorkGroupSize.x + gl_LocalInvocationID.x;
	#if IS_USING_SHUFFLE_VOTE
	if (30 <= gl_ThreadInWarpNV)
		return; // [0, 29] までの 30 スレッドが 30 インデックス = 10 トライアングル処理する
	// １スレッド１インデックスなのでトライアングルのインデックスとしては３で割る
	uint proc_index = gl_WorkGroupID.x * (gl_WorkGroupSize.x-2) + gl_ThreadInWarpNV;
	uint tri_index = (proc_index)/3;
	// トライアングルのどのインデックスか
	uint thread_index_id = gl_ThreadInWarpNV % 3;
	#else
	uint tri_index = gl_WorkGroupID.x * gl_WorkGroupSize.x + gl_ThreadInWarpNV;
	#endif

	// SubMeshRange
	SMR_TYPE range = uSubMeshRange[gl_WorkGroupID.y];

	// 頂点数だけ処理（それ以外は範囲外アクセスになる）
	if (SMR_TRI_NUM(range) <= tri_index)
	{
		return;
	}
	
	bool is_cull = false;
	// インデックスバッファを読む
	#if IS_USING_SHUFFLE_VOTE
		uint ind = getIndexRead(proc_index, range);
	#else
		uvec3 ind = getIndexReadTriangle(tri_index, range);
	#endif // IS_USING_SHUFFLE_VOTE

	// 裏面カリング
	#if (IS_ENABLE_CULL_BACK_FACE == 1)
	{
		#if 1
		vec3 pos0, pos1, pos2;
		GetTrianglePos(ind);
		vec3 p1_p0 = pos1 - pos0;
		vec3 p2_p0 = pos2 - pos0;
		// ２次元ベクトルで外積計算
	//	float cross = p1_p0.x * p2_p0.y - p1_p0.y * p2_p0.x;
		vec3 c = cross(p1_p0, p2_p0);
		is_cull = (c.z < 0.0);
		#elif 0
		// 偶数ポリゴンだけ通してみる
		is_cull = ((tri_index % 2) == 1);
		#else
		{
			// 座標で判定してみる
			vec2 pos0 = getPos2f(ind.x);
		//	vec4 pos0 = sbVertexArray[ind0].pos;
		//	float pos0_y = sbVertexArray[ind0].pos_y;
			is_cull = (pos0.y < uPosCullTestValue.y && pos0.x < uPosCullTestValue.x);
		}
		#endif
	}
	#endif // IS_ENABLE_CULL_BACK_FACE

	#if IS_USING_ATOMIC_INDIRECT
	if (!is_cull)
	{
		uint write_index = atomicAdd(count, 3);
		// 書き込み
		WriteIndex(ind, write_index);
	}

	#else
		#if IS_USING_SHUFFLE_VOTE
		uint write_index = proc_index + SMR_BASE_WRITE_INDEX(range);	// 書き込み先インデックス
		// vote を使ったカリングの投票
		uint result = ballotThreadNV(is_cull);
		uint shift = (gl_ThreadInWarpNV / 3) * 3;
		if ((result & (0x7 << shift)) != 0) // 3bit 見て、どれか一つでもビットが立っていたらカリング
		#else
		uint write_index = tri_index*3 + SMR_BASE_WRITE_INDEX(range);	// 書き込み先インデックス
		if (is_cull)
		#endif
		{
			WriteIndexInvalid(write_index);
			return;
		}
	#endif // IS_USING_ATOMIC_INDIRECT

	// ind にはベース頂点インデックスも加算されていることに注意。bit 幅が変わる場合はうまく行かないはず
	WriteIndex(ind, write_index);
}

#if 0
// vote を使ったカリングの投票
uint result = ballotThreadNV( is_cull );
int shift = (gl_ThreadInWarpNV / 3)*3;
if (result & (0x7 << shift))
{
	sbIndexArrayWrite[write_index]		= INVALID_INDEX 
}
#endif

#endif // defined( AGL_COMPUTE_SHADER )
