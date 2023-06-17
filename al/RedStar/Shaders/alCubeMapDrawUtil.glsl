/**
 * @file	alCubeMapDrawUtil.glsl
 * @author	Yosuke Mori  (C)Nintendo
 *
 * @brief	キューブマップ描画に使用するユーティリティ
 */

#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable
#endif

layout (std140) uniform CubeFaceViewArray
{
	vec4	uProjViewInvPosX[4];
	vec4	uProjViewInvNegX[4];
	vec4	uProjViewInvPosY[4];
	vec4	uProjViewInvNegY[4];
	vec4	uProjViewInvPosZ[4];
	vec4	uProjViewInvNegZ[4];
};


// 全画面を覆うメッシュを描画するときに使う、レイを計算する
#define CalcViewRayMtx(ray, sc_pos, mtx)		(ray = (mtx * vec4(sc_pos.xy, 1.0, 1.0)).xyz)
#define CalcViewRayMtxNear(ray, sc_pos, mtx)	(ray = (mtx * vec4(sc_pos.xy, 0.0, 1.0)).xyz)
#define CalcViewRayMtxProj(ray, sc_pos, mtx)		{vec4 ray_w = mtx * vec4(sc_pos.xy, 1.0, 1.0); ray = ray_w.xyz/ray_w.w;}
#define CalcViewRayMtxNearProj(ray, sc_pos, mtx)	{vec4 ray_w = mtx * vec4(sc_pos.xy, 0.0, 1.0); ray = ray_w.xyz/ray_w.w;}
