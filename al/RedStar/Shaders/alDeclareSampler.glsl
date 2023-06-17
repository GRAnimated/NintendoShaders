/**
 * @file	alDeclareSampler.glsl
 * @author	Yosuke Mori  (C)Nintendo
 *
 * @brief	サンプラー定義
 */

BINDING_SAMPLER_BASE_COLOR				uniform sampler2D cTextureBaseColor;	// @@ id="_a0"	hint="albedo0"
BINDING_SAMPLER_NORMAL					uniform sampler2D cTextureNormal;		// @@ id="_n0"	hint="normal0"
BINDING_SAMPLER_UNIFORM0				uniform sampler2D cTextureUniform0;		// @@ id="_u0"
BINDING_SAMPLER_UNIFORM1				uniform sampler2D cTextureUniform1;		// @@ id="_u1"
BINDING_SAMPLER_UNIFORM2				uniform sampler2D cTextureUniform2;		// @@ id="_u2"
BINDING_SAMPLER_UNIFORM3				uniform sampler2D cTextureUniform3;		// @@ id="_u3"
BINDING_SAMPLER_UNIFORM4				uniform sampler2D cTextureUniform4;		// @@ id="_u4"
BINDING_SAMPLER_MATERIAL_LIGHT_CUBE		uniform samplerCube cTextureMaterialLightCube;	// @@ id="_m0" visible="false"
BINDING_SAMPLER_MATERIAL_LIGHT_SPHERE	uniform sampler2D cTextureMaterialLightSphere;	// @@ id="_m1" visible="false"

BINDING_SAMPLER_GBUF_BC	uniform sampler2D cGBufferBaseColorTex;
BINDING_SAMPLER_GBUF_NRM uniform sampler2D cGBufferNormalTex;
BINDING_SAMPLER_DEPTH	uniform sampler2D cTextureLinearDepth;	// @@ id="linear_depth"	hint="linear_depth"	visible="false"	label="線形デプス"

// ディレクショナルライトカラーテクスチャ
BINDING_SAMPLER_DIR_LIT_COLOR	uniform sampler2D cDirectionalLightColor;

// ラフネス対応キューブマップ
BINDING_SAMPLER_ENV_CUBE_MAP_ROUGHNESS	uniform samplerCube cTexCubeMapRoughness;

// デプスシャドウ(キューブマップ用)
BINDING_SAMPLER_DEPTH_SHADOW uniform sampler2D cDepthShadow;

// シャドウマップ
BINDING_SAMPLER_SHADOW_MAP uniform sampler2D cShadowMap;

// 特殊用途
BINDING_SAMPLER_TEMPORARY	uniform sampler2D cFrameBufferTex;		// インダイレクト
BINDING_SAMPLER_MIRROR		uniform sampler2D cMirrorTex;			// 鏡

// 露出
BINDING_SAMPLER_EXPOSURE	uniform sampler2D cExposureTexture;

// 頂点フェッチ用
BINDING_SAMPLER_DISPLACEMENT0	uniform sampler2D cTextureDisplacement0;	// @@ id="_d0"
BINDING_SAMPLER_DISPLACEMENT1	uniform sampler2D cTextureDisplacement1;	// @@ id="_d1"

// 宝石用キューブマップ FIXME:CubeMapArrayにする
BINDING_SAMPLER_CUBEMAP_GEM0	uniform samplerCube cTextureCubeMapGem0;	// @@ id="_gem0"
BINDING_SAMPLER_CUBEMAP_GEM1	uniform samplerCube cTextureCubeMapGem1;	// @@ id="_gem1"

// 構造色キューブマップ
BINDING_SAMPLER_CUBEMAP_STRUCTURAL_COLOR	uniform samplerCube cTextureCubeMapStructuralColor;	// @@ id="_stcol0"

// プログラム生成テクスチャ
BINDING_SAMPLER_PROG_TEXTURE0			uniform sampler2D 		cTextureProg0;
BINDING_SAMPLER_PROG_CUBEMAP_GEM0		uniform samplerCube		cTextureCubeMapGemProg0;
BINDING_SAMPLER_PROC_TEXTURE_2D			uniform sampler2D		cTextureProcTexture2D;
BINDING_SAMPLER_PROC_TEXTURE_3D			uniform sampler3D		cTextureProcTexture3D;

