/**
 * @file	alHalfResBufferDepth.glsl
 * @author	Yosuke Mori  (C)Nintendo
 *
 * @brief	1/2 * 1/2の縮小デプスを作成
 */

#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable
#endif

#include "alScreenUtil.glsl"
#include "alDefineVarying.glsl"

#define IS_OUT_LINEAR			(1) // @@ id="cIsOutLinear" choice="0,1" default="1"

#define SAMPLING_TYPE			(0) // @@ id="cSamplingType" choice="0,1,2,3" default="0"
#define SAMPLING_TYPE_MAX		(0)
#define SAMPLING_TYPE_MIN		(1)
#define SAMPLING_TYPE_LINEAR	(2)
#define SAMPLING_TYPE_AVG		(3)

#define BINDING_SAMPLER_DEPTH		layout(binding = 0)

BINDING_SAMPLER_DEPTH uniform sampler2D	uDepth;

uniform vec2		uTexelSize;

#if IS_OUT_LINEAR == 1
uniform	float		uNear;
uniform	float		uFar;
uniform	float		uRange;
uniform	float		uInvRange;
#endif // IS_OUT_LINEAR

#if defined( AGL_VERTEX_SHADER )

#if IS_OUT_LINEAR == 1
DECLARE_VARYING(vec3,	vParameters);
#endif // IS_OUT_LINEAR

layout ( location = 0 )	in	vec4	aPosition;
layout ( location = 1 )	in	vec2	aTexCoord1;

out	vec2	vTexCoord;

void main()
{
	VERTEX_SHADER_QUAD_TRIANGLE__CALC_POS_TEX

#if IS_OUT_LINEAR == 1
	getVarying(vParameters)	= vec3( -uFar * uInvRange, uRange / uNear, uNear * uInvRange );
#endif // IS_OUT_LINEAR
}

#endif // defined( AGL_VERTEX_SHADER )

#if defined( AGL_FRAGMENT_SHADER )

in	vec2	vTexCoord;

#if IS_OUT_LINEAR == 1
layout(location = 0)	out vec4	oLinearDepth;
DECLARE_VARYING(vec3,	vParameters);
#endif // IS_OUT_LINEAR

#if defined( AGL_TARGET_GX2 )
#define TEX_GATHER(sampler, coord)	texture4(sampler, coord)
#else
#define TEX_GATHER(sampler, coord)	textureGather(sampler, coord)
#endif // defined( AGL_TARGET_GX2 )

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

#define GATHER_DEPTH_MIN(min_d, tex_coord)										\
	{																			\
		vec4 gather_d = TEX_GATHER(uDepth, tex_coord);							\
		min_d = min(gather_d.x, min(gather_d.y, min(gather_d.z, gather_d.w)));	\
	}

#define GATHER_DEPTH_AVG(avg_d, tex_coord)										\
	{																			\
		vec4 gather_d = TEX_GATHER(uDepth, tex_coord);							\
		avg_d = (gather_d.x + gather_d.y + gather_d.z + gather_d.w) * 0.25;		\
	}

#define GATHER_DEPTH_LINEAR(d, tex_coord)										\
	{																			\
		d = texture(uDepth, tex_coord).r;										\
	}

void main()
{
	float depth;
#if SAMPLING_TYPE == SAMPLING_TYPE_MAX
	GATHER_DEPTH_MAX(depth, vTexCoord + vec2(-uTexelSize.x * 0.5, -uTexelSize.y * 0.5 * Y_FLIP));
#elif SAMPLING_TYPE == SAMPLING_TYPE_MIN
	GATHER_DEPTH_MIN(depth, vTexCoord + vec2(-uTexelSize.x * 0.5, -uTexelSize.y * 0.5 * Y_FLIP));
#elif SAMPLING_TYPE == SAMPLING_TYPE_LINEAR
	GATHER_DEPTH_LINEAR(depth, vTexCoord + vec2(-uTexelSize.x * 0.5, -uTexelSize.y * 0.5 * Y_FLIP));
#elif SAMPLING_TYPE == SAMPLING_TYPE_AVG
	GATHER_DEPTH_AVG(depth, vTexCoord + vec2(-uTexelSize.x * 0.5, -uTexelSize.y * 0.5 * Y_FLIP));
#endif
	gl_FragDepth = depth;

#if IS_OUT_LINEAR == 1
	float a = getVarying(vParameters).x;
	float b = getVarying(vParameters).y;
	float linear_depth = 0.0;
	linear_depth = a / ((depth + a) * b);
	linear_depth = linear_depth - getVarying(vParameters).z;
	oLinearDepth = vec4(linear_depth);
#endif // IS_OUT_LINEAR
}

#endif // defined( AGL_FRAGMENT_SHADER )
