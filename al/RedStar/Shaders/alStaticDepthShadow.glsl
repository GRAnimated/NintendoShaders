/**
 * @file	alStaticDepthShadow.glsl
 * @author	Musa Kazuhiro  (C)Nintendo
 *
 * @brief	StaticDepthShadow 描画
 */

#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable // 明示的な場所指定には必要。無いと GPU ハング。
#extension GL_AMD_texture_texture4 : enable // for PCF   (texture4 関数)
#endif

//precision highp float;

#include "alDeclareUniformBlockBinding.glsl"
#include "alDefineVarying.glsl"
#include "alMathUtil.glsl"

#define USING_SCREEN_AND_TEX_COORD_CALC	(1)

#define DEPTH_TEST_TYPE_NORMAL	(0)
#define DEPTH_TEST_TYPE_ESM		(1)
#define DEPTH_TEST_TYPE_PCF		(2)// NXにtexture4命令がないので、NXではPCFはやらない
#define DEPTH_TEST_TYPE_PCF_ESM	(3)

#define DEPTH_TEST_TYPE		(2) // @@ id="cDepthTestType"		choice="0,1,2,3"	default="2"
#define IS_ENABLE_DISCARD	(0) // @@ id="cIsEnableDiscard"		choice="0,1"		default="0"
#define IS_USE_TEXTURE_PROJ	(0) // @@ id="cIsUseTextureProj"	choice="0,1"		default="0"
#define IS_ENABLE_Z_POW		(0) // @@ id="cIsEnableZPow"		choice="0,1"		default="0"
#define IS_DRAW_COLOR_TO_AO	(0) // @@ id="cIsDrawColorToAo"		choice="0,1"		default="0"
#define IS_OUTPUT_STEP		(0) // @@ id="cIsOutputStep"		choice="0,1"		default="0"

#define MASK_TYPE_NONE		(0)
#define MASK_TYPE_MULT		(1)	// マスク画像1の部分を描画
#define MASK_TYPE_MULT_INV	(2)	// マスク画像0の部分を描画

#define MASK_TYPE			(0) // @@ id="cMaskType"			choice="0,1,2"		default="0"

#if defined(AGL_TARGET_NVN)
#define cDiscardRange 0.47	// 暫定対応 テクスチャのボーダー部分で影が出てしまうので
#else
#define cDiscardRange 0.5
#endif

#include "alDeclareMdlEnvView.glsl"	// 環境と視点を合わせたデータ 
#include "alDeclareShadowUniformBlock.glsl"	// UBOの定義

//------------------------------------------------------------------------------
// 頂点シェーダ
//------------------------------------------------------------------------------
#if defined(AGL_VERTEX_SHADER)

layout (location=0) in vec3 aPosition;	// @@ id="_p0" hint="position0"

void main()
{
    vec4 pos = vec4( aPosition.xyz, 1.0 );

    gl_Position.x = dot( cCubeWorldViewProj[ 0 ], pos );
    gl_Position.y = dot( cCubeWorldViewProj[ 1 ], pos );
    gl_Position.z = dot( cCubeWorldViewProj[ 2 ], pos );
    gl_Position.w = dot( cCubeWorldViewProj[ 3 ], pos );

	calcScreenAndTexCoord();
}

//------------------------------------------------------------------------------
// フラグメントシェーダ
//------------------------------------------------------------------------------
#elif defined(AGL_FRAGMENT_SHADER)

#if		( DEPTH_TEST_TYPE == DEPTH_TEST_TYPE_NORMAL && IS_USE_TEXTURE_PROJ )
uniform sampler2DShadow cDepthShadow;
#else
uniform sampler2D cDepthShadow;
#endif
uniform sampler2D cViewDepth;
#if 	MASK_TYPE > MASK_TYPE_NONE
uniform sampler2D cMask;
#endif

layout(location = 0)	out vec4 oColor;

void main()
{
	vec2 depth_tex = texture( cViewDepth, getScreenCoord() ).rg;

	vec4 view_pos;
	view_pos.z  = -( depth_tex.r * cRange + cNear );
	view_pos.xy = getScreenRay().xy * view_pos.z;
	view_pos.w  = 1;

	// キューブモデル座標系での座標を求めます
    vec3 local_pos;
    local_pos.x = dot( cCubeInvWorldView[ 0 ], view_pos );
    local_pos.y = dot( cCubeInvWorldView[ 1 ], view_pos );
    local_pos.z = dot( cCubeInvWorldView[ 2 ], view_pos );

#if IS_ENABLE_DISCARD
	// モデル範囲外のピクセルは捨てます
	// discardの方が早い場合がある シャドウモデル外の描画対象ピクセル面積が大きいとき
	if( abs(local_pos.x) > cDiscardRange || abs(local_pos.y) > cDiscardRange || abs(local_pos.z) > cDiscardRange ) discard;
#endif

#if MASK_TYPE > MASK_TYPE_NONE
	// マスク処理
	float mask_tex = texture( cMask, getScreenCoord() ).r;
 #if MASK_TYPE == MASK_TYPE_MULT
	if( mask_tex == 0 ) discard;
 #else
	if( mask_tex > 0 ) discard;
 #endif
#endif // MASK_TYPE > MASK_TYPE_NONE

	vec4 world_pos = multMtx34Vec4( cInvView,      view_pos );
	vec4 tex_coord = multMtx44Vec4( cShadowMatrix, world_pos );

	// これでもいいみたい
//	tex_coord.x =  local_pos.x+0.5;
//	tex_coord.y = -local_pos.y+0.5;
//	tex_coord.z = -local_pos.z+0.5;

	// ShadowMap撮影時の正規化カメラ空間での奥行き

	// 地形に寝かせてデプスシャドウのエリアを配置したときなどに
	// エリアの底面が地形に届かなかったり、突き抜けたりして、デプスが埋められてない状態のShadowMapができることがあり
	// その領域と比較すると不正な影ができてしまうので大きめにclampして暫定対処します
	float depth_pos    = clamp(tex_coord.z,0.0, 0.95); // clamp01(tex_coord.z);
	float result;

#if		( DEPTH_TEST_TYPE == DEPTH_TEST_TYPE_PCF ) && defined(AGL_TARGET_GX2)
	//※ NXではtexture4命令がないようです
	float offset = 0.005;
	vec4 depth_map = texture4( cDepthShadow, tex_coord.xy );
	vec4 step_4    = step( vec4(0), depth_map + vec4(-depth_pos+offset) );
	result = dot(vec4(1.0), step_4) * 0.25f;
#elif	( DEPTH_TEST_TYPE == DEPTH_TEST_TYPE_ESM )
	// ESMはdが大きいほどresultが0に近くなり影が濃くなるので、アクターに影行列が固定されているときはジャンプすると影が濃くなる
	// セルフシャドウや、動かない地形などdがほぼ一定なものに対して使える
	float depth_map = texture( cDepthShadow, tex_coord.xy ).r;
	float d = depth_pos - depth_map;
	result = clamp( exp2( -cEsmC * d ), 0.0 , 1.0 );
#elif	( DEPTH_TEST_TYPE == DEPTH_TEST_TYPE_PCF_ESM ) && defined(AGL_TARGET_GX2)
	vec4 depth_map = texture4( cDepthShadow, tex_coord.xy );
	float depth_map_pcf = ( depth_map.r + depth_map.g + depth_map.b + depth_map.a ) * 0.25;
	float d = depth_pos - depth_map_pcf;
	result = clamp( exp2( -cEsmC * d ), 0.0 , 1.0 );
#elif	( DEPTH_TEST_TYPE == DEPTH_TEST_TYPE_NORMAL )

	#if IS_USE_TEXTURE_PROJ
		result = textureProj( cDepthShadow, tex_coord );
	#else
		float depth_map = texture( cDepthShadow, tex_coord.xy ).r;
		result = step( 0, depth_map - depth_pos );
		result = max( result, cShadowDensity );
	#endif

#else
	result = 0;
#endif

#if IS_ENABLE_Z_POW
	// 遠くの影ほど薄くする処理
	float shadow_rate_z = pow( clamp01( abs(cShadowCenterZ-tex_coord.z) - cShadowWidthZ )/cShadowWidthZGradation, cZPow );

	float range_xy = 0.5 - cShadowWidthXY;
	float shadow_rate_x = ( abs( tex_coord.x - 0.5 ) - cShadowWidthXY )/ range_xy;
	float shadow_rate_y = ( abs( tex_coord.y - 0.5 ) - cShadowWidthXY )/ range_xy;
	float shadow_rate = max( max( shadow_rate_x, shadow_rate_y ), shadow_rate_z );
	result = result + ( 1.0-result )*shadow_rate;
#endif


#if IS_OUTPUT_STEP
	result = step(0.5, result);
#endif

#if IS_DRAW_COLOR_TO_AO
	oColor = vec4( result, 1.0, 1.0, 1.0 );
#else
	oColor = vec4( 1.0, result, 1.0, 1.0 );
#endif
}

#endif // defined(AGL_FRAGMENT_SHADER)
