/**
 * @file	alRenderRetroColor.glsl
 * @author	Yosuke Mori  (C)Nintendo
 *
 * @brief	古いゲーム機風描画
 */
#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable // 明示的な場所指定には必要。無いと GPU ハング。
#endif

#define PASS						( 0 ) // @@ id="cPass" 					choice="bool"		default="0"
#define IS_USE_COLOR_PALETTE		( 0 ) // @@ id="cIsUseColorPalette" 	choice="bool"		default="0"
#define IS_CHECK_PALETTE_LUMA		( 0 ) // @@ id="cIsCheckPaletteLuma" 	choice="bool"		default="0"
#define IS_BASE_COLOR_MODE			( 0 ) // @@ id="cIsBaseColorMode" 		choice="bool"		default="0"
#define IS_DRAW_CRT_DISPLAY			( 0 ) // @@ id="cIsDrawCrtDisplay" 		choice="bool"		default="0"
#define IS_DRAW_CRT_PIXEL_SELECT	( 0 ) // @@ id="cIsDrawCrtPixelSelect" 	choice="bool"		default="0"
#define IS_DRAW_STN_DISPLAY			( 0 ) // @@ id="cIsDrawStnDisplay" 		choice="bool"		default="0"

#include "alMathUtil.glsl"
#include "alScreenUtil.glsl"

layout( binding = 0 ) uniform sampler2D uFinalColor;
layout( binding = 1 ) uniform sampler2D uColorPalette;
layout( binding = 2 ) uniform sampler2D uBaseColor;

uniform vec4	uPaletteParams;		//x: palette_w y: palette_h
uniform vec4	uPaletteParams2;	//x: inv_palette_w y: inv_palette_h z: inv_half_palette_w w: inv_half_palette_h
uniform vec4	uBitParams;			//x: red_bit y: green_bit z: blue_bit, w:mix_rate
uniform vec4	uCrtParams;			
uniform vec4	uCrtNoiseParams;	
uniform vec4	uCrtScanLineParams;	
uniform vec4	uStnParams;	

//------------------------------------------------------------------------------
// 頂点シェーダ
//------------------------------------------------------------------------------
#if defined(AGL_VERTEX_SHADER)

layout ( location = 0 ) in vec3 aPosition;	// @@ id="_p0" hint="position0"
layout ( location = 1 ) in vec2 aTexCoord1;
out vec2 vTexCoord;

void main()
{
	VERTEX_SHADER_QUAD_TRIANGLE__CALC_POS_TEX
}

//------------------------------------------------------------------------------
// フラグメントシェーダ
//------------------------------------------------------------------------------
#elif defined(AGL_FRAGMENT_SHADER)

in	vec2	vTexCoord;
out	vec4	oColor;

float rand(float val) {
	return fract(sin(val * 12.9898) * 43758.5453);
}

void main()
{
	#if ( PASS == 0 )
	{
		vec3 base_color = vec3( 0.0 );
		#if (IS_BASE_COLOR_MODE)
		{
			base_color = texture( uBaseColor, vTexCoord ).rgb;
			vec3 final_color = texture( uFinalColor, vTexCoord ).rgb;
			if( base_color.r == 0.0 && base_color.g == 0.0 && base_color.b == 0.0 )
			{
				base_color = final_color;
			}
		}
		#else
		{
			base_color = texture( uFinalColor, vTexCoord ).rgb;
		}
		#endif

		vec3 color = vec3( 0.0 );
#if IS_CHECK_PALETTE_LUMA
		float base_luma = base_color.r * 0.298912 + base_color.g * 0.586611 + base_color.b * 0.114478;
#endif
		#if IS_USE_COLOR_PALETTE
		{
			vec2 coord = vec2( 0.0 );
			float dist_min = 3.0;
			for( int w = 0; w < int( uPaletteParams.x ); ++w )
			{
				for( int h = 0; h < int( uPaletteParams.y ); ++h )
				{
					coord.x = w * uPaletteParams2.x + uPaletteParams2.z;
					coord.y = h * uPaletteParams2.y + uPaletteParams2.w;
					vec3 palette_color = texture( uColorPalette, coord ).rgb;
#if IS_CHECK_PALETTE_LUMA
					float palette_luma = palette_color.r * 0.298912 + palette_color.g * 0.586611 + palette_color.b * 0.114478;
					float dist = abs(base_luma - palette_luma);
#else
					float dist = abs(base_color.r - palette_color.r) + abs(base_color.g - palette_color.g) + abs(base_color.b - palette_color.b);
#endif
					if( dist < dist_min )
					{
						color = palette_color;
						dist_min = dist;
					}
				}
			}
		}
		#else
		{
			color.r = float( uint( base_color.r * 255 ) & ( ( ( 1u << uint( uBitParams.x ) ) - 1u ) << ( 8u - uint( uBitParams.x ) ) ) ) / 255.0;
			color.g = float( uint( base_color.g * 255 ) & ( ( ( 1u << uint( uBitParams.y ) ) - 1u ) << ( 8u - uint( uBitParams.y ) ) ) ) / 255.0;
			color.b = float( uint( base_color.b * 255 ) & ( ( ( 1u << uint( uBitParams.z ) ) - 1u ) << ( 8u - uint( uBitParams.z ) ) ) ) / 255.0;
		}
		#endif
		oColor = vec4( color, 1.0 );
	}
	#elif ( PASS == 1 )
	{
		vec3 color = vec3( 0.0 );
		#if ( IS_DRAW_CRT_DISPLAY == 1 )
		{
			vec2 tex_coord = vTexCoord - vec2( 0.5, 0.5 );
			vec2 new_tex_coord = vTexCoord;
			float vignet = length( tex_coord );
			// 画面を歪ませる
			tex_coord /= 1.0 - vignet * uCrtParams.z;
			new_tex_coord = tex_coord + 0.5;
 			if ( max( abs( tex_coord.y ) - 0.5, abs( tex_coord.x ) - 0.5 ) > 0.0 )
			{
				oColor = vec4( 0.0, 0.0, 0.0, 1.0 );
				return;
			}

			// フェッチ位置にノイズをかける
			new_tex_coord.x += ( rand( floor( new_tex_coord.y * uCrtParams.y ) ) - 0.5 ) * uCrtNoiseParams.x;
			new_tex_coord = clamp01( new_tex_coord );

			// RGB
			color.r = texture( uFinalColor, new_tex_coord ).r;
			color.g = texture( uFinalColor, new_tex_coord - vec2( uCrtNoiseParams.y, 0.0 ) ).g;
			color.b = texture( uFinalColor, new_tex_coord - vec2( uCrtNoiseParams.z, 0.0 ) ).b;

			// ピクセルごとに描画するRGBを決める
			#if ( IS_DRAW_CRT_PIXEL_SELECT == 1 )
			{
				float floor_x = fract(vTexCoord.x * uCrtParams.x / 3.0);
				color.r *= float(floor_x > 0.3333);
				color.g *= float(floor_x < 0.3333 || floor_x > 0.6666);
				color.b *= float(floor_x < 0.6666);
			}
			#endif

			// スキャンライン描画
			float scan_line_color = sin( new_tex_coord.y * uCrtParams.y * uCrtScanLineParams.x ) / 2.0 + 0.5;
			color *= (1.0 - uCrtScanLineParams.y) + clamp01( scan_line_color + 0.5 ) * uCrtScanLineParams.y;

			// 画面端を暗くする
			color *= 1.0 - vignet * uCrtParams.w;
		}
		#elif ( IS_DRAW_STN_DISPLAY == 1 )
		{
			color = texture( uFinalColor, vTexCoord ).rgb;
			if( int( gl_FragCoord.x ) % int( uStnParams.x ) == 0 || int( gl_FragCoord.y ) % int( uStnParams.x ) == 0 )
			{
				color *= uStnParams.y; 
				color = clamp01( color );
			}
		}
		#else
		{
			color = texture( uFinalColor, vTexCoord ).rgb;
		}
		#endif
		oColor = vec4( color, 1.0 );
	}
	#endif
}
#endif // defined(AGL_FRAGMENT_SHADER)

