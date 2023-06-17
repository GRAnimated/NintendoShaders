/**
 * @file	alVignettingShader.glsl
 * @author	Yosuke Mori  (C)Nintendo
 *
 * @brief	周辺減光/周辺ぼけ
 */
 
#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable
#endif

#include "alScreenUtil.glsl"
#include "alDefineVarying.glsl"
#include "alMathUtil.glsl"

#define PASS                ( 0 ) // @@ id="cPass"				choice="0,1"		default="0" 
#define VIGNETTING_BLEND    ( 0 ) // @@ id="cVignettingBlend"	choice="0,1,2"		default="0" 
#define VIGNETTING_BLACK    ( 0 ) // @@ id="cVignettingBlack"	choice="0,1"		default="0"
#define VIGNETTING_COLOR    ( 0 ) // @@ id="cVignettingColor"	choice="0,1"		default="0" 
#define VIGNETTING_BLUR     ( 0 ) // @@ id="cVignettingBlur"	choice="0,1"		default="0" 
#define BLUR_QUALITY  	    ( 1 ) // @@ id="cBlurQuality"		choice="0,1"		default="1" 
#define USE_MASK            ( VIGNETTING_BLUR )

uniform vec4		uTexParam;
uniform vec4		uVignettingParam;
uniform vec4		uVignettingTrans;
uniform vec4		uVignettingRadius;
uniform vec4		uVignettingColor;
uniform float		uExp2MipLevelMax;

uniform sampler2D	cTexColor;
uniform sampler2D	cTexMipMap;

#if defined( AGL_VERTEX_SHADER )

layout ( location = 0 ) in vec3 aPosition;
layout ( location = 1 ) in vec2 aTexCoord1;

out	vec2	vTexCoord;
out vec4	vTexCoordMipBlur;
out vec4	vVignettingParam;

void main( void ) 
{
#if ( PASS == 0 )
	VERTEX_SHADER_QUAD_TRIANGLE__CALC_POS_TEX

	vVignettingParam = vec4( 0.f );
	vTexCoordMipBlur = vec4( vTexCoord.xy + uTexParam.xy, vTexCoord.xy - uTexParam.xy );

#elif ( PASS == 1 )

	gl_Position.xy = vec2( aPosition.xy ) * 2.0;
	gl_Position.z  = -1.0;
	gl_Position.w  = 1.0;
	vTexCoord.xy   = aTexCoord1;

	float scale = uVignettingRadius[ int( aTexCoord1.y ) ];
	vec2 radius = vec2( uVignettingParam.x, uVignettingParam.y ) * scale;

	gl_Position.xy = aPosition.xy * radius + uVignettingTrans.xy;
    vTexCoord.xy   = gl_Position.xy * 0.5 + vec2( 0.5 );
    vTexCoord.y    = 1.0 - vTexCoord.y;

	vVignettingParam.x = clamp( uVignettingColor.a - aTexCoord1.x * uVignettingColor.a, 0.0, 1.0 );
	vVignettingParam.y = 1.0 - vVignettingParam.x;
    vVignettingParam.z = clamp( uVignettingParam.z - aTexCoord1.x * uVignettingParam.z, 0.0, 1.0 );
    vVignettingParam.w = 1.0 - vVignettingParam.z;

#endif
}

#elif defined( AGL_FRAGMENT_SHADER )

in	vec2	vTexCoord;
in	vec4	vVignettingParam;
in	vec4	vTexCoordMipBlur;

layout( location = 0 ) out vec4 output_color;

#if	( PASS == 0 )

void main( void )
{
	vec4 blur = vec4( 0.0 );

	#if ( BLUR_QUALITY == 0 )
	{
		blur  = texture( cTexColor, vTexCoord.xy );
	}
	#elif ( BLUR_QUALITY == 1 )
	{
		blur  = texture( cTexColor, vTexCoordMipBlur.xy );
		blur += texture( cTexColor, vTexCoordMipBlur.zy );
		blur *= 0.5;
		blur += texture( cTexColor, vTexCoordMipBlur.xw ) * 0.5;
		blur += texture( cTexColor, vTexCoordMipBlur.zw ) * 0.5;
		blur *= 0.5;
	}
	#endif
	output_color.rgb = blur.rgb;
	output_color.a = 0.0;
}

#elif ( PASS == 1 )

void main( void )
{
    #if ( VIGNETTING_BLUR )
    {
		float blur_size = mix( 1.0, uExp2MipLevelMax, vVignettingParam.z );
		float level = min( log2( blur_size ) - 1.0, uVignettingParam.w );
		float alpha = clamp01( level + 1.0 );
		vec3 rgb;
		rgb = textureLod( cTexMipMap, vTexCoord.xy, level ).rgb;
		output_color.a = alpha * vVignettingParam.y + vVignettingParam.x;

	    #if ( VIGNETTING_BLACK )
	    {
    	    output_color.rgb = rgb * alpha * vVignettingParam.y / output_color.a;
	    }
	    #elif ( VIGNETTING_COLOR )
    	{
        	output_color.rgb = mix( rgb * alpha, uVignettingColor.rgb, vVignettingParam.x ) / output_color.a;
	    }
	    #else
	    {
    	    output_color.rgb = rgb;
	    }
		#endif
    }
	#elif ( VIGNETTING_BLACK )
	{
		#if ( VIGNETTING_BLEND == 1 )
		{
			output_color = vec4( vec3( 1.0 - vVignettingParam.x ), 1.0 );
		}
		#else
		{
			output_color = vec4( vec3( 0 ), vVignettingParam.x );
		}
		#endif
	}
	#elif ( VIGNETTING_COLOR )
	{
		#if ( VIGNETTING_BLEND == 1 )
		{
			output_color = vec4( mix( vec3( 1 ), uVignettingColor.rgb, vVignettingParam.x ), 1.0 );
		}
		#elif ( VIGNETTING_BLEND == 2 )
		{
			output_color = vec4( mix( vec3( 0 ), uVignettingColor.rgb, vVignettingParam.x ), 1.0 );
		}
		#else
		{
			output_color = vec4( uVignettingColor.rgb, vVignettingParam.x );
		}
		#endif
	}
	#else
	{
		discard;
	}
	#endif
}

#endif //PASS

#endif //AGL_FRAGMENT_SHADER
