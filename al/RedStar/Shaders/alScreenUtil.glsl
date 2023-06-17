/**
 * @file	alScreenUtil.glsl
 * @author	Matsuda Hirokazu  (C)Nintendo
 *
 * @brief	スクリーン関連のユーティリティ
 */

#ifndef AL_SCREEN_UTIL_GLSL
#define AL_SCREEN_UTIL_GLSL

/**
 *	WiiU の場合だけ Y をフリップして PC 版のときはフリップしない
 */
#if defined( AGL_TARGET_GX2 ) || defined( AGL_TARGET_NVN )
	#define	FlipY(vec2)	vec2.y *= -1.0;
#else
	#define	FlipY(vec2)
#endif

/**
 *	スクリーン位置からレイを求める
 *	レイマーチングやディファードシェーディングなどで使う
 */
#define calcScreenRay(ray, gl_pos, tan_fovy_half, scr_proj_offset)	\
	ray = gl_pos.xy/gl_pos.w;		\
	FlipY(ray);						\
	ray *= -tan_fovy_half.xy;		\
	ray -= scr_proj_offset.xy;

/**
 *	スクリーン位置からレイとテクスチャ座標を求める
 *	レイマーチングやディファードシェーディングなどで使う
 */
#define calcScreenRayAndTexCoord(ray, crd, gl_pos, tan_fovy_half, scr_proj_offset) \
	ray = gl_pos.xy/gl_pos.w;		\
	FlipY(ray);						\
	crd = ray * 0.5 + 0.5;			\
	ray *= -tan_fovy_half.xy;		\
	ray -= scr_proj_offset.xy;

/**
 * Zバッファを正規化リニアデプスに変換
 */
#define DepthToLinear(linear_z, z, near, far, range, inv_range)	\
{ \
	float a = -far * inv_range; \
	float b = range / near; \
	linear_z = a / ((z + a) * b); \
	linear_z = linear_z - near * inv_range; \
}

/**
 *	全画面を覆う三角形の頂点
 */
#define VERTEX_SHADER_QUAD_TRIANGLE__CALC_POS	\
{\
	gl_Position.xy = aPosition.xy * 2;\
	gl_Position.z = 0.0;\
	gl_Position.w = 1.0;\
}

// PosとTexの計算
#if defined( AGL_TARGET_GL )
#define VERTEX_SHADER_QUAD_TRIANGLE__CALC_POS_TEX	\
{\
	VERTEX_SHADER_QUAD_TRIANGLE__CALC_POS\
	\
	vTexCoord = aTexCoord1;\
	vTexCoord.y = 1 - vTexCoord.y;\
}
#else
#define VERTEX_SHADER_QUAD_TRIANGLE__CALC_POS_TEX	\
{\
	VERTEX_SHADER_QUAD_TRIANGLE__CALC_POS\
	\
	vTexCoord = aTexCoord1;\
}
#endif

// スクリーン座標
#define VERTEX_SHADER_QUAD_TRIANGLE__CALC_SCREEN	\
{\
    vScreen.xy = gl_Position.xy;\
    vScreen.xy *= -cTanFovyHalf.xy;\
    vScreen.xy -= cProjOffset.xy;\
}

#endif // AL_SCREEN_UTIL_GLSL
