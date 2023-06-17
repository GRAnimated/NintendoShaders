/**
 * @file	alMakeHalfTexture.glsl
 * @author	Matsuda Hirokazu  (C)Nintendo
 *
 * @brief	半分のサイズのテクスチャを作成する。SSAO などで使用
 */

#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable // 明示的な場所指定には必要。無いと GPU ハング。
#extension GL_AMD_texture_texture4 : enable // for PCF   (texture4 関数)
#endif

#define RENDER_TYPE		(0) // @@ id="cRenderType" choice="0,1,2,3" default="0"
#define IS_WHOLE		(0)
#define FAR_WHOLE		(1)
#define FAR_DISCARD		(2)
#define IS_DEPTH_WHOLE	(3)

#if defined( AGL_TARGET_GX2 ) || defined( AGL_TARGET_NVN )
layout(std140, binding = 1)
#endif
uniform TexAdjustInfo
{
	vec2	uTexWidthInv;
	float	uTexOffsetAdjust;
};

#if defined( AGL_TARGET_GX2 ) || defined( AGL_TARGET_NVN )
layout(binding = 0)
#endif
uniform sampler2D uTexture;

#if defined( AGL_TARGET_GX2 ) || defined( AGL_TARGET_NVN )
layout(binding = 1)
#endif
uniform sampler2D uDepth;


//------------------------------------------------------------------------------
// 頂点シェーダ
//------------------------------------------------------------------------------
#if defined(AGL_VERTEX_SHADER)

layout (location=0) in vec3 aPosition;				// @@ id="_p0" hint="position0"
out vec2  vTexCoord;

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

	vec2 adjust = uTexWidthInv * uTexOffsetAdjust;

	vTexCoord += adjust;
}

//------------------------------------------------------------------------------
// フラグメントシェーダ
//------------------------------------------------------------------------------
#elif defined(AGL_FRAGMENT_SHADER)

in vec2  vTexCoord;

// 出力変数
layout(location = 0)	out vec4 oColor;

void main ( void )
{
	#if (RENDER_TYPE == IS_WHOLE)
	{
		oColor = texture(uTexture, vTexCoord);
	}
	#elif (RENDER_TYPE == IS_DEPTH_WHOLE)
	{
		#if defined(AGL_TARGET_GX2)
		vec4 sh = texture4(uTexture, vTexCoord);
		#else
		vec4 sh = textureGather(uTexture, vTexCoord);
		#endif
		oColor.r = 0.25 * (sh.x + sh.y + sh.z + sh.w);
	}
	#elif (RENDER_TYPE == FAR_DISCARD)
	{
		float depth = texture(uDepth, vTexCoord).r;
		if (depth != 1.0) discard;
		oColor = texture(uTexture, vTexCoord);
	}
	#else
	{
		float depth = texture(uDepth, vTexCoord).r;
		// １(Far)のところだけ
		oColor = texture(uTexture, vTexCoord) * step(1.0, depth);
	}
	#endif // RENDER_TYPE
}

#endif // AGL_FRAGMENT_SHADER
