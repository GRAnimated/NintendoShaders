/**
 *  @file   alVrRenderLimitUtil.glsl
 *  @author Matsuda Hirokazu  (C)Nintendo
 *
 *  @brief  描画範囲制限用ユーティリティ
 */
#ifndef AL_VR_RENDER_LIMIT_UTIL_GLSL
#define AL_VR_RENDER_LIMIT_UTIL_GLSL

/**
 *	TRIANGLE_FAN で描く
 */
void calcRenderLimitMeshPositionTriFan(inout vec4 gl_pos, in int poly_num, in int tri_fan_vtx_id, in float far)
{
	const float PI = 3.1415926535897932384626433832795;
	float A = 1.0 / cos(PI / poly_num);
	float B = 2.0 * (PI/poly_num) * (tri_fan_vtx_id);
	gl_pos.x = A * cos(B);
	gl_pos.y = A * sin(B);
	gl_pos.z = far;
	gl_pos.w = 1.0;
}

/**
 *	DirectX 10 以降は Triangle Fan が使えないので Triangle List で描画する場合
 */
void calcRenderLimitMeshPositionTriList(inout vec4 gl_pos, in int poly_num, in int vtx_id, in float far)
{
	int tri_list_local_idx = vtx_id % 3; // 三角形内のインデックス
	int tri_idx = vtx_id / 3;			 // どの三角形か
	int tri_fan_idx = (tri_list_local_idx == 0) ? 0 : tri_idx + tri_list_local_idx;	// Triangle Fan ならこのインデックスになるだろう値
	calcRenderLimitMeshPositionTriFan(gl_pos, poly_num, tri_fan_idx, far);
}

#endif // AL_VR_RENDER_LIMIT_UTIL_GLSL
