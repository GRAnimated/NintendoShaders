/**
 * @file	alComputeClearTexture3D.glsl
 * @author	Matsuda Hirokazu  (C)Nintendo
 *
 * @brief	3D テクスチャをクリアするコンピュートシェーダサンプル
 */

#extension GL_NV_gpu_shader5 : enable
#extension GL_NV_desktop_lowp_mediump : enable

#if defined( AGL_COMPUTE_SHADER )

uniform vec4 				uClearColor;
uniform writeonly image3D 	uDestImage;

// Switch は合計 1024 かも。16, 8, 8 は行けた。
layout (local_size_x = 16, local_size_y = 8, local_size_z = 8) in;

void main()
{
	// 32x32x32 の 3D テクスチャ専用で試す
	#if 0
	uint max_x = 32/(uint)gl_WorkGroupSize.x;
	uint max_y = 32/(uint)gl_WorkGroupSize.y;
	uint max_z = 32/(uint)gl_WorkGroupSize.z;
	for (uint x = 0; x < max_x; ++x)
	for (uint y = 0; y < max_y; ++y)
	for (uint z = 0; z < max_z; ++z)
	{
		uvec3 fetch_pos = gl_LocalInvocationID + uvec3(x,y,z) * gl_WorkGroupSize;
		imageStore(uDestImage, ivec3(fetch_pos), uClearColor);
	}
	#elif 1
	// WorkGroup 複数ディスパッチ
	uint max_x = 32/(uint)(gl_WorkGroupSize.x * gl_NumWorkGroups.x);
	uint max_y = 32/(uint)(gl_WorkGroupSize.y * gl_NumWorkGroups.y);
	uint max_z = 32/(uint)(gl_WorkGroupSize.z * gl_NumWorkGroups.z);
	for (uint x = 0; x < max_x; ++x)
	for (uint y = 0; y < max_y; ++y)
	for (uint z = 0; z < max_z; ++z)
	{
		uvec3 fetch_pos = gl_LocalInvocationID + gl_WorkGroupSize * gl_WorkGroupID + uvec3(x,y,z) * gl_WorkGroupSize * gl_NumWorkGroups;
		imageStore(uDestImage, ivec3(fetch_pos), uClearColor);
	}
	#elif 1
	// WorkGroup 複数ディスパッチ
	uint max_x = 32/(uint)(gl_WorkGroupSize.x * gl_NumWorkGroups.x);
	uint max_y = 32/(uint)(gl_WorkGroupSize.y * gl_NumWorkGroups.y);
	uint max_z = 32/(uint)(gl_WorkGroupSize.z * gl_NumWorkGroups.z);
	for (uint x = 0; x < max_x; ++x)
	for (uint y = 0; y < max_y; ++y)
	for (uint z = 0; z < max_z; ++z)
	{
		uvec3 fetch_pos = uvec3(x,y,z) + gl_LocalInvocationID * gl_NumWorkGroups + gl_WorkGroupID * gl_WorkGroupSize * gl_NumWorkGroups;
		imageStore(uDestImage, ivec3(fetch_pos), uClearColor);
	}
	#elif 0
	// local_size を 1 にして解像度分ディスパッチでやってみる。めっちゃ重かった(8.0%)
	imageStore(uDestImage, ivec3(gl_WorkGroupID), uClearColor);
	#else
	// gl_LocalInvocationID を散らす 複数ディスパッチ
	uvec3 local_offset = uvec3(32)/(gl_WorkGroupSize * gl_NumWorkGroups);
	for (uint x = 0; x < local_offset.x; ++x)
	for (uint y = 0; y < local_offset.y; ++y)
	for (uint z = 0; z < local_offset.z; ++z)
	{
		uvec3 fetch_pos = gl_LocalInvocationID * gl_NumWorkGroups + gl_WorkGroupID + uvec3(x,y,z) * gl_WorkGroupSize;
		imageStore(uDestImage, ivec3(fetch_pos), uClearColor);
	}
	#endif
}

#endif // defined( AGL_COMPUTE_SHADER )
