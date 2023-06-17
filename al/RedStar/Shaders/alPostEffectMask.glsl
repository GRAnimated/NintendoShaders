/**
 * @file	alPostEffectMask.glsl
 * @author	Matsuda Hirokazu  (C)Nintendo
 *
 * @brief	ポストエフェクトマスク
 */

#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable
#endif

// @@ group="render_type"		label="レンダリング設定"		order="10"

// 法線マップ
#define ENABLE_NORMAL			(0)
#define	ENABLE_BLEND_TANGENT	(0)

#include "alDeclareUniformBlockBinding.glsl"
#include "alMathUtil.glsl"
#include "alDeclareAttribute.glsl"
#include "alDefineVarying.glsl"
#include "alDeclareMdlEnvView.glsl"	// 環境と視点を合わせたデータ 
#include "alDefineSampler.glsl"
#include "alDeclareSampler.glsl"
#include "alDeclareVarying.glsl"

// 頂点カラーの使い道
#define VTX_COLOR_TYPE		(0) // @@ id="VtxColorType" choice="0:使用, -1:無し" default="0"
#define VTX_COLOR_NONE		(-1)
#define VTX_COLOR_USE		(0)

// テクスチャ使うかどうか
#define TEXTURE_USAGE		(0) // @@ id="TextureUsage" choice="0:無し, 1:使用" default="0"
#define TEXTURE_NONE		(0)
#define TEXTURE_USE			(1)

#define SKIN_WEIGHT_NUM	(0)	// @@ id="cSkinWeightNum" choice="0,1,2,3,4" default="0" visible="false"

BINDING_UBO_SHADER_OPTION uniform ShaderOption // @@ id="cShaderOption"		type="option"
{
	int VtxColorType;	// @@ id="VtxColorType"
	int TextureUsage;	// @@ id="TextureUsage"
	int cSkinWeightNum;	// @@ id="cSkinWeightNum"
};

#include "alCalcSkinning.glsl"

// アノテーション遠隔指定
// @@ option_id="VtxColorType"	label="頂点カラー"	order="8"	group="render_type"
// @@ option_id="TextureUsage"	label="テクスチャ"	order="9"	group="render_type"

//------------------------------------------------------------------------------
// 頂点シェーダ
//------------------------------------------------------------------------------
#if defined(AGL_VERTEX_SHADER)

void main()
{
#if 1
	SkinInfo skin;

	initSkin(skin);
	calcSkinning(skin);

	vec4 pos_proj = multMtx44Vec3(cViewProj, skin.position_w);
	gl_Position = pos_proj;

	// 頂点カラー
	getVarying(vColor) = vec4(1.0);
	if (VTX_COLOR_TYPE == VTX_COLOR_USE)
	{
		getVarying(vColor) = aColor;
	}
	// テクスチャ
	if (TEXTURE_USAGE == TEXTURE_USE)
	{
		FRAG_UV0 = aTexCoord0;
	}

#else

	// for Debug
	getVarying(vColor) = vec4(1.0);
	if (VTX_COLOR_TYPE == VTX_COLOR_USE)
	{
		getVarying(vColor) = aColor;
	}
	
	if (SKIN_WEIGHT_NUM == 0)
	{
		getVarying(vColor).r += 0.01;
	}
	else if (SKIN_WEIGHT_NUM == 1)
	{
		getVarying(vColor).g += 0.01;
	}
	else if (SKIN_WEIGHT_NUM == 2)
	{
		getVarying(vColor).b += 0.01;
	}
	
//	vec2 sign_pos = sign(aPosition.xy); // 画面を覆う -1 〜 1 の範囲のスクリーン座標になる
//	gl_Position.xy = sign_pos * 0.5;
	gl_Position.x = aPosition.x/500.0;
	gl_Position.y = aPosition.y/1000.0;
	gl_Position.z = 0;
	gl_Position.w = 1.0;
#endif // 0
}

//------------------------------------------------------------------------------
// フラグメントシェーダ
//------------------------------------------------------------------------------
#elif defined(AGL_FRAGMENT_SHADER)

// 出力変数
layout(location = 0)	out vec4 oOutput;

void main()
{
	vec3 color = getVarying(vColor).rgb;
	if (TEXTURE_USAGE == TEXTURE_USE)
	{
		color *= texture(cTextureBaseColor, FRAG_UV0).rgb;
	}
	oOutput = vec4(color, 1.0);
}

#endif

