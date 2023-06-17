/**
 * @file	alTemporalInterlace.glsl
 * @author	Yosuke Mori  (C)Nintendo
 *
 * @brief	テンポラルリプロジェクションを使った1/2解像度のバッファの合成
 */

#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable
#endif

#include "alScreenUtil.glsl"
#include "alDefineVarying.glsl"
#include "alMathUtil.glsl"

#define IS_DRAW_EVEN_FRAME						(0) // @@ id="cIsDrawEvenFrame" 	choice="bool"		default="0"
#define IS_USE_MOTION_VEC						(1) // @@ id="cIsUseMotionVec" 		choice="bool"		default="1"
#define IS_DEBUG_FALL_PIXEL						(0) // @@ id="cIsDebugFallPixel"	choice="bool"		default="0"

#define IS_USE_TEST								(0) // @@ id="cIsUseTest"			choice="bool"		default="0"
#define IS_OUTPUT_LUMA							(0) // @@ id="cIsOutputLuma"		choice="bool"		default="0"
#define IS_COMPOSE_CAMERA_BLUR					(0) // @@ id="cIsComposeCameraBlur"	choice="bool"		default="0"

#define MOTION_THRESHOLD_X						(0.0016) // 1/640
#define MOTION_THRESHOLD_Y						(0.0013) // 1/720

#define BINDING_SAMPLER_CUR_HALF_TEX		layout(binding = 0)
#define BINDING_SAMPLER_PREV_HALF_TEX		layout(binding = 1)
#define BINDING_SAMPLER_MOTIONVEC_TEX		layout(binding = 2)
#define BINDING_SAMPLER_PREV_MOTIONVEC_TEX	layout(binding = 3)
#define BINDING_SAMPLER_PREV_PREV_HALF_TEX	layout(binding = 4)
#define BINDING_SAMPLER_CAMERA_BLUR_TEX		layout(binding = 5)

BINDING_SAMPLER_CUR_HALF_TEX		uniform sampler2D	uCurFrame;
BINDING_SAMPLER_PREV_HALF_TEX		uniform sampler2D	uPrevFrame;
BINDING_SAMPLER_PREV_PREV_HALF_TEX	uniform sampler2D	uPrevPrevFrame;
BINDING_SAMPLER_MOTIONVEC_TEX		uniform sampler2D	uMotionVector;
BINDING_SAMPLER_PREV_MOTIONVEC_TEX	uniform sampler2D	uPrevMotionVector;
BINDING_SAMPLER_CAMERA_BLUR_TEX		uniform sampler2D	uCameraBlurFrame;

uniform float		uBaseOffsetHeight;
uniform float		uMaxWidthCoord;
uniform float		uInvWidth;
uniform float		uInvHeight;
uniform float		uInvMotionWidth;
uniform float		uInvMotionHeight;
uniform float		uColorThresold;
uniform vec4		uLumaCoeff;
uniform vec4		uVignettingParam;
uniform vec4		uVignettingParam2;

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

// MotuionVecは-1.0 ~ 1.0で格納されている
#define getMotionVector(motion_vec, tex_coord, tex) \
{ \
	motion_vec   = texture(tex, tex_coord).rg; \ 
	motion_vec.y *= -1.0; \
}

// 1. まずそのピクセルが現在動いているかどうかで条件を分ける
// 2. 前のフレームの同座標のピクセルから取得できるかのチェック
//    前のフレームでは動いているピクセルに隠されてそのピクセルが描画されていない可能性もある
//    そのため前のフレームで同座標のピクセルが動いているなら怪しいのでとってこない
// 3. その場合前のフレームに情報がないので、現在のフレームでの隣のピクセルとの中間としておく
// 4. 現在動いているなら現在のフレームのモーションベクトルで推測
//    ここでMacCormackを使う？とりあえず隣のモーションベクトルとの補間
// 5. 取得したピクセルの色があまりにも離れていたらここでも隣のピクセルとの中間
#if IS_DEBUG_FALL_PIXEL
#define interpolate_color(o_color, color_c, tex_coord, offset) \
{ \
	o_color = vec3(1.0, 0.0, 0.0);	\
}
#else
#define interpolate_color(o_color, color_c, tex_coord, offset)	\
{ \
	vec2 new_coord = tex_coord; \
	new_coord.x = clamp(new_coord.x + offset, 0.0, uMaxWidthCoord); \
	vec3 color_next = texture(uCurFrame, new_coord).rgb; \
	o_color = (color_c + color_next) * 0.5; \
}
#endif

#define reprojection(o_color, color_c, coord, motion_coord, offset, motion_offset) \
{ \
	vec2 motion_vec = vec2(0.0); \
	getMotionVector(motion_vec, motion_coord, uMotionVector); \
	if( abs(motion_vec.x) < MOTION_THRESHOLD_X && abs(motion_vec.y) < MOTION_THRESHOLD_Y ) \
	{ \
		vec3 color_pp = texture(uPrevPrevFrame, coord).rgb; \
		if( abs(color_c.r - color_pp.r) > 0.01 || abs(color_c.g - color_pp.g) > 0.01 || abs(color_c.b - color_pp.b) > 0.01 ) \
		{ \
			interpolate_color(o_color, color_c, coord, offset); \
		} \
		else \
		{ \
			o_color = texture(uPrevFrame, coord).rgb; \
		} \
	} \
	else \
	{ \
		vec2 next_motion_vec = vec2(0.0); \
		getMotionVector(next_motion_vec, motion_coord + motion_offset, uMotionVector); \
		vec2 prev_coord = coord - (motion_vec + next_motion_vec) * 0.5; \
		prev_coord.x = clamp(prev_coord.x, 0.0, uMaxWidthCoord); \
		prev_coord.y = clamp(prev_coord.y, uBaseOffsetHeight, 1.0); \
		o_color = texture(uPrevFrame, prev_coord).rgb; \
		if( abs(o_color.r - color_c.r) > uColorThresold || abs(o_color.g - color_c.g) > uColorThresold || abs(o_color.b - color_c.b) > uColorThresold ) \
		{ \
			interpolate_color(o_color, color_c, coord, offset); \
		} \
	} \
}

layout(location = 0)	out vec4	oColor;
#if IS_OUTPUT_LUMA
layout(location = 1)	out float	oLuma;
#endif

in	vec2	vTexCoord;

void main()
{
	vec2 coord = vec2(0.0);
	coord.x = float(int(gl_FragCoord.x * 0.5)) * uInvWidth * 2.0 + uInvWidth;
	coord.y = gl_FragCoord.y * uInvHeight + uBaseOffsetHeight;

	vec2 motion_coord = vec2(0.0);
	motion_coord.x = float(int(gl_FragCoord.x * 0.5)) * uInvMotionWidth * 2.0 + uInvMotionWidth;
	motion_coord.y = gl_FragCoord.y * uInvMotionHeight;

	vec3 color_c = texture(uCurFrame, coord).rgb;
	if( (int(gl_FragCoord.x) & 1) == 0 )
	{
		#if IS_DRAW_EVEN_FRAME
		{
			oColor.rgb = color_c;
		}
		#else
		{
			float offset = -uInvWidth * 2.0;
			float motion_offset = -uInvMotionWidth * 2.0;
			#if IS_USE_MOTION_VEC
			{
				vec3 o_color = vec3(0.0);
				reprojection(o_color, color_c, coord, motion_coord, offset, motion_offset);
				oColor.rgb = o_color;
			}
			#else
			{
				vec2 new_coord = coord;
				new_coord.x = clamp(new_coord.x + offset, 0.0, uMaxWidthCoord);
				vec3 color_next = texture(uCurFrame, new_coord).rgb;
				oColor.rgb = (color_c + color_next) * 0.5;
			}
			#endif
		}
		#endif
	}
	else
	{
		#if IS_DRAW_EVEN_FRAME
		{
			float offset = uInvWidth * 2.0;
			float motion_offset = uInvMotionWidth * 2.0;
			#if IS_USE_MOTION_VEC
			{
				vec3 o_color = vec3(0.0);
				reprojection(o_color, color_c, coord, motion_coord, offset, motion_offset);
				oColor.rgb = o_color;
			}
			#else
			{
				vec2 new_coord = coord;
				new_coord.x = clamp(new_coord.x + offset, 0.0, uMaxWidthCoord);
				vec3 color_next = texture(uCurFrame, new_coord).rgb;
				oColor.rgb = (color_c + color_next) * 0.5;
			}
			#endif
		}
		#else
		{
			oColor.rgb = color_c;
		}
		#endif
	}

	#if IS_COMPOSE_CAMERA_BLUR
	{
		vec2 center_pos = uVignettingParam2.xy;
		float len = (vTexCoord.x - center_pos.x) * (vTexCoord.x - center_pos.x) * 4.0 + (vTexCoord.y - center_pos.y) * (vTexCoord.y - center_pos.y);
		len = sqrt(len);
		float range = clamp01( len - uVignettingParam.y );
		float vignet = clamp01( range / (1.0 - uVignettingParam.y) );
		float blur_size = mix( 1.0, uVignettingParam2.z, uVignettingParam.z );
		float level = min( log2( blur_size ), uVignettingParam.w ) * uVignettingParam2.w;
		float alpha = clamp01( level + 1.0 );
		vec2 new_coord = coord;
		new_coord.x = clamp(new_coord.x, 0.0, uMaxWidthCoord - uInvWidth * 4.0);
		new_coord.y = clamp(new_coord.y, uBaseOffsetHeight + uInvHeight * 2.0, 1.0);
		vec3 rgb = textureLod( uCameraBlurFrame, new_coord, level * vignet ).rgb;
		alpha = alpha * vignet + uVignettingParam.x * range;
		oColor.rgb = mix(oColor.rgb, rgb, clamp01(alpha));
	}
	#endif

	#if IS_OUTPUT_LUMA
	{
		oLuma = oColor.r * uLumaCoeff.x + oColor.g * uLumaCoeff.y + oColor.b * uLumaCoeff.z;
	}
	#endif
}

#endif // defined( AGL_FRAGMENT_SHADER )
