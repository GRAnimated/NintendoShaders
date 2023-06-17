/**
 * @file	alCalcNormal.glsl
 * @author	Matsuda Hirokazu  (C)Nintendo
 *
 * @brief	法線計算やビューデプス計算
 *			alMathUtil.glslとalDefineVarying.glsl,alDeclareVarying.glslを先にインクルードする必要があります。
 */

#ifndef CALC_NORMAL_GLSL
#define CALC_NORMAL_GLSL

#if !defined(clamp01)
#include "alMathUtil.glsl"
#endif 

// カメラからの距離を求め、0-1 に正規化して格納
#define calcNormalizedLinearViewDepth(view_proj, pos_proj, near, inv_range)		\
{																				\
	getVarying(vNormalWorldDepthView).w = (pos_proj.w - near) * inv_range;		\
}

// 法線マップ使用&2タンジェント
#define calcWorldNormalMapVtxAndBlendTangent(skin)						\
{																		\
	getVarying(vNormalWorldDepthView).xyz	= skin.normal_w;			\
	PACKED_VARYING_3_1(0, skin.tangent0_w, skin.binormal0_w.x);			\
	PACKED_VARYING_2_0(1, skin.binormal0_w.yz);							\
	PACKED_VARYING_3_1(3, skin.tangent1_w, skin.binormal1_w.x);			\
	PACKED_VARYING_2_0(4, skin.binormal1_w.yz);							\
}

// 法線マップ使用
#define calcWorldNormalMapVtx(skin)										\
{																		\
	getVarying(vNormalWorldDepthView).xyz	= skin.normal_w;			\
	PACKED_VARYING_3_1(0, skin.tangent0_w, skin.binormal0_w.x);			\
	PACKED_VARYING_2_0(1, skin.binormal0_w.yz);							\
}

// 法線マップ未使用時
#define calcWorldNormalVtx(skin)										\
{																		\
	getVarying(vNormalWorldDepthView).xyz	= skin.normal_w;			\
}

//------------------------------------------------------------------------------
/// unorm -> snorm
// ( 2.0 * ( val ) - 1.0 )という計算は厳密ではない
// max( ( texutre( sampler).x - 128.0f / 255.0f ) / ( 127.0f / 255.0f ), -1.0f );
#define convUnormToSnorm( val ) ( 2.007874 * val - 1.007874 )

#define calcNrmZ(b) sqrt( clamp01(1.0 - dot2(b, b)) )
#define decodeNormalMap(nm, tex, unorm)	\
{										\
	nm.xy = tex.rg;						\
	if (unorm)							\
	{									\
		nm.xy = convUnormToSnorm(nm.xy);\
	}									\
	nm.z = calcNrmZ(nm.xy);				\
}

#define calcNormalByBumpTBN(out_nrm, bump, t, b, n)	\
{													\
	out_nrm.x = t.x * bump.x + b.x * bump.y + n.x * bump.z;		\
	out_nrm.y = t.y * bump.x + b.y * bump.y + n.y * bump.z;		\
	out_nrm.z = t.z * bump.x + b.z * bump.y + n.z * bump.z;		\
	NORMALIZE_B(out_nrm.xyz, out_nrm.xyz);						\
}

#define calcNormal(world_nrm, vtx)	\
{									\
	world_nrm.xyz = vtx.normal;		\
}

#endif // CALC_NORMAL_GLSL
