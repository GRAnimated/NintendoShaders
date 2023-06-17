/**
 * @file	alQuaterResBuffer.glsl
 * @author	Kitazono Yusuke  (C)Nintendo
 *
 * @brief	1/4 * 1/4の縮小バッファを作成
 */

#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable
#endif

#include "alScreenUtil.glsl"

#define IS_VDM		(0) // @@ id="cIsVdm" choice = "0,1" default = "0"

#define BINDING_SAMPLER_DEPTH		layout(binding = 0)

BINDING_SAMPLER_DEPTH uniform sampler2D	uDepth;
uniform vec2		uTexelSize;
uniform	float		uNear;
uniform	float		uFar;
uniform	float		uRange;

#if defined( AGL_VERTEX_SHADER )

layout ( location = 0 )	in	vec4	aPosition;
layout ( location = 1 )	in	vec2	aTexCoord1;

out	vec2	vTexCoord;

void main()
{
	VERTEX_SHADER_QUAD_TRIANGLE__CALC_POS_TEX
}

#endif // defined( AGL_VERTEX_SHADER )

#if defined( AGL_FRAGMENT_SHADER )

in	vec2	vTexCoord;

out	vec4	oColor;
out vec4	oLinearDepth;
#if IS_VDM
out	vec4	oVdm;
#endif // IS_VDM

#if defined( AGL_TARGET_GX2 )
#define TEX_GATHER(sampler, coord)	texture4(sampler, coord)
#else
#define TEX_GATHER(sampler, coord)	textureGather(sampler, coord)
#endif //defined( AGL_TARGET_GX2 )

#if defined( AGL_TARGET_GX2 ) || defined( AGL_TARGET_NVN )
#define Y_FLIP						-1
#else
#define Y_FLIP						1
#endif // defined( AGL_TARGET_GX2 ) || defined( AGL_TARGET_NVN )

#define GATHER_DEPTH_MAX(max_d, tex_coord)										\
	{																			\
		vec4 gather_d = TEX_GATHER(uDepth, tex_coord);							\
		max_d = max(gather_d.x, max(gather_d.y, max(gather_d.z, gather_d.w)));	\
	}

void main()
{
	float max1, max2, max3, max4;
	GATHER_DEPTH_MAX(max1, vTexCoord + vec2(-uTexelSize.x * 1.5,  uTexelSize.y * 1.5 * Y_FLIP));		// 左上
	GATHER_DEPTH_MAX(max2, vTexCoord + vec2( uTexelSize.x * 0.5,  uTexelSize.y * 1.5 * Y_FLIP));		// 右上
	GATHER_DEPTH_MAX(max3, vTexCoord + vec2(-uTexelSize.x * 1.5, -uTexelSize.y * 0.5 * Y_FLIP));		// 左下
	GATHER_DEPTH_MAX(max4, vTexCoord + vec2( uTexelSize.x * 0.5, -uTexelSize.y * 0.5 * Y_FLIP));		// 右下
	float max_d = max(max1, max(max2, max(max3, max4)));
	float linear_max_d = 0.0;
	float inv_range = 1 / uRange;
	DepthToLinear(linear_max_d, max_d, uNear, uFar, uRange, inv_range);
	gl_FragDepth = max_d;
	oColor = vec4(0.0);
	oLinearDepth = vec4(linear_max_d);

#if IS_VDM == 1
	oVdm = vec4(0.0);
#endif // IS_VDM
}

#endif // defined( AGL_FRAGMENT_SHADER )
