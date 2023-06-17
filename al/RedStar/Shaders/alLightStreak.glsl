/**
 * @file	alLightStreak.glsl
 * @author	Matsuda Hirokazu  (C)Nintendo
 *
 * @brief	ライトストリーク
 */

#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable // 明示的な場所指定には必要。無いと GPU ハング。
#endif

#include "alMathUtil.glsl"

// バリエーション
#define	RENDER_TYPE			(0) // @@ id="cRenderType"
#define MAKE_MASK			(0)
#define COMPOSE				(1)
#define MAKE_BLUR_MRT		(2)
#define MAKE_BLUR_MRT_COLOR	(3)
#define RENDER_TO_BUFFER	(4) // 一時的。HDRCompose を作ったら要らなくなる。

#define STREAK_TYPE			(0) // @@ id="cStreakType"
#define STREAK_CROSS		(0)
#define STREAK_STAR			(1)
#define STREAK_HEX			(2)

#define	IS_SRC_TEX_ARRAY	(0) // @@ id="cIsSrcTexArray"

#if defined( AGL_TARGET_GX2 ) || defined( AGL_TARGET_NVN )
layout(binding = 0)
#endif
uniform sampler2D uTextureSrc;

#if defined( AGL_TARGET_GX2 ) || defined( AGL_TARGET_NVN )
layout(binding = 1)
#endif
uniform sampler2DArray uTextureArray;

#if defined(AGL_TARGET_GX2) || defined( AGL_TARGET_NVN )
layout(std140, binding = 2)
#endif
uniform LightStreakInfo
{
	float	uIntensity;
	float	uAttn;
	float	uThreshold;
	vec2	uDeltaTexel[6];
	vec3	uColor[3];
};

#define CM	(1.0) // ColorMain
#define CS	(0.2) // ColorSub

#define SAMPLE_NUM	(4)
const vec3 cColor[SAMPLE_NUM] = vec3[SAMPLE_NUM](
												  vec3(1.0)
												, vec3(1.0, 0.3, 0.3)
												, vec3(0.2, 1.0, 0.35)
												, vec3(0.2, 0.84, 1.0)
												);

#if (STREAK_TYPE == STREAK_CROSS)
	#define STREAK_NUM	(4)
#elif (STREAK_TYPE == STREAK_STAR)
	#define STREAK_NUM	(5)
#else
	#define STREAK_NUM	(6)
#endif // STREAK_TYPE

//------------------------------------------------------------------------------
// 頂点シェーダ
//------------------------------------------------------------------------------
#if defined(AGL_VERTEX_SHADER)

layout (location=0) in vec3 aPosition;				// @@ id="_p0" hint="position0"

out vec2 vTexCoord;

void main()
{
	vec2 sign_pos = sign(aPosition.xy); // 画面を覆う -1 〜 1 の範囲のスクリーン座標になる
	gl_Position.xy = sign_pos;
	gl_Position.z = 0;
	gl_Position.w = 1.0;

	vTexCoord.x =  sign_pos.x * 0.5 + 0.5;
	vTexCoord.y = -sign_pos.y * 0.5 + 0.5;

#if defined( AGL_TARGET_GL )
	vTexCoord.y = 1.0 - vTexCoord.y;
#endif
}

//------------------------------------------------------------------------------
// フラグメントシェーダ
//------------------------------------------------------------------------------
#elif defined(AGL_FRAGMENT_SHADER)

in vec2 vTexCoord;

#if IS_SRC_TEX_ARRAY == 0
#define SRC_TEXTURE_FETCH(uv, slice)	texture(uTextureSrc, uv).rgb
#else
#define SRC_TEXTURE_FETCH(uv, slice)	texture(uTextureArray, vec3(uv, slice)).rgb
#endif

#if (RENDER_TYPE == MAKE_BLUR_MRT_COLOR)

#define STREAK_BLUR_MRT(s, attn1, attn2, attn3)															\
{																										\
	gl_FragData[s].rgb += SRC_TEXTURE_FETCH(vTexCoord + uDeltaTexel[s]*1, s).rgb * uColor[0] * attn1;	\
	gl_FragData[s].rgb += SRC_TEXTURE_FETCH(vTexCoord + uDeltaTexel[s]*2, s).rgb * uColor[1] * attn2;	\
	gl_FragData[s].rgb += SRC_TEXTURE_FETCH(vTexCoord + uDeltaTexel[s]*3, s).rgb * uColor[2] * attn3;	\
	gl_FragData[s].rgb = clamp(gl_FragData[s].rgb, 0.0, 2048.0); \
}

#else

#define STREAK_BLUR_MRT(s, attn1, attn2, attn3)												\
{																							\
	gl_FragData[s].rgb += SRC_TEXTURE_FETCH(vTexCoord + uDeltaTexel[s]*1, s).rgb * attn1;	\
	gl_FragData[s].rgb += SRC_TEXTURE_FETCH(vTexCoord + uDeltaTexel[s]*2, s).rgb * attn2;	\
	gl_FragData[s].rgb += SRC_TEXTURE_FETCH(vTexCoord + uDeltaTexel[s]*3, s).rgb * attn3;	\
	gl_FragData[s].rgb = clamp(gl_FragData[s].rgb, 0.0, 2048.0); \
}

#endif

void main ( void )
{
	#if ((RENDER_TYPE == MAKE_BLUR_MRT) || (RENDER_TYPE == MAKE_BLUR_MRT_COLOR))
	{
		// カラーを適用したらめっちゃ重くなったので手動でループをアンロール
		gl_FragData[0].rgb = SRC_TEXTURE_FETCH(vTexCoord, 0);
		gl_FragData[1].rgb = SRC_TEXTURE_FETCH(vTexCoord, 1);
		gl_FragData[2].rgb = SRC_TEXTURE_FETCH(vTexCoord, 2);
		gl_FragData[3].rgb = SRC_TEXTURE_FETCH(vTexCoord, 3);
		#if (4 < STREAK_NUM)
		{
			gl_FragData[4].rgb = SRC_TEXTURE_FETCH(vTexCoord, 4);
			#if (5 < STREAK_NUM)
			{
				gl_FragData[5].rgb = SRC_TEXTURE_FETCH(vTexCoord, 5);
			}
			#endif
		}
		#endif // STREAK_NUM
		float attn1 = uAttn;
		float attn2 = uAttn * uAttn;
		float attn3 = uAttn * uAttn * uAttn;
		STREAK_BLUR_MRT(0, attn1, attn2, attn3);
		STREAK_BLUR_MRT(1, attn1, attn2, attn3);
		STREAK_BLUR_MRT(2, attn1, attn2, attn3);
		STREAK_BLUR_MRT(3, attn1, attn2, attn3);
		#if (4 < STREAK_NUM)
		{
			STREAK_BLUR_MRT(4, attn1, attn2, attn3);
			#if (5 < STREAK_NUM)
			{
				STREAK_BLUR_MRT(5, attn1, attn2, attn3);
			}
			#endif
		}
		#endif // STREAK_NUM
	}
	#elif (RENDER_TYPE == COMPOSE)
	{
		gl_FragColor.rgb = vec3(0.0);
		for (int s=0; s<STREAK_NUM; ++s)
		{
			gl_FragColor.rgb += SRC_TEXTURE_FETCH(vTexCoord, s);
		}
		gl_FragColor.rgb *= uIntensity;
	}
	#elif (RENDER_TYPE == MAKE_MASK)
	{
		vec3 color  = texture(uTextureSrc, vTexCoord).rgb;
		gl_FragColor.rgb = checkThresholdColorSimple(color, uThreshold);
	}
	#elif (RENDER_TYPE == RENDER_TO_BUFFER)
	{
		gl_FragColor.rgb = texture(uTextureSrc, vTexCoord).rgb;
	}
	#endif
}

#endif // AGL_FRAGMENT_SHADER
