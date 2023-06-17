/**
 * @file	alRenderWorldAo.glsl
 * @author	Satoshi Miyama  (C)Nintendo
 *
 * @brief	WorldAo 描画
 */

#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable // 明示的な場所指定には必要。無いと GPU ハング。
#endif

precision highp float;

#include "alDeclareUniformBlockBinding.glsl"
#include "alMathUtil.glsl"

#define USING_SCREEN_AND_TEX_COORD_CALC	(1)
#include "alDefineVarying.glsl"
#include "alDeclareMdlEnvView.glsl"	// 環境と視点を合わせたデータ 

uniform sampler2D cWorldAo;
uniform sampler2D cViewDepth;

//------------------------------------------------------------------------------
// 頂点シェーダ
//------------------------------------------------------------------------------
#if defined(AGL_VERTEX_SHADER)

layout (location = 0) in vec3 aPosition;	// @@ id="_p0" hint="position0"

void main()
{
	gl_Position.xy = 2.0 * aPosition.xy;
	gl_Position.z  = 0.0;
	gl_Position.w  = 1.0;

	calcScreenAndTexCoord();
}

//------------------------------------------------------------------------------
// フラグメントシェーダ
//------------------------------------------------------------------------------
#elif defined(AGL_FRAGMENT_SHADER)

BINDING_UBO_OTHER_FIRST uniform RenderWorldAoTex // @@ id="cRenderWorldAo" comment="WorldAoパラメータ"
{
	vec4	uAoTexViewProj[4];
	float	uAoTexCamY;
	float	uAoTexRange;		// mAoTexFar - mAoTexNear
	float	uAoMaxDensity;
	float	uAoMaxDepth;
};

layout(location = 0)	out vec4 oColor;

void main()
{
	float depth_tex	= texture(cViewDepth, getScreenCoord()).r;

	// ビュー座標系における位置
	vec4 view_pos;
	view_pos.z = -( depth_tex * cRange + cNear );
	view_pos.xy = getScreenRay().xy * view_pos.z;
	view_pos.w = 1.0;

	// ワールド位置
	vec4 world_pos = multMtx34Vec4(cInvView, view_pos);

	// AoTextureからその位置(x,y)の高さ
	vec2 ao_tex_coord = multMtx44Vec4(uAoTexViewProj, world_pos).xy;
	float ao_depth		= texture(cWorldAo, ao_tex_coord).r;

	if( ao_depth == 1.0 )
	{
		oColor = vec4(1, 1, 1, 1);
	}
	else
	{
		// AoTextureから求めたその地点の高さ (world座標系)
		float ao_height = uAoTexCamY - (ao_depth * uAoTexRange);

		// step(world_pos.y, ao_height) : world_pos.yが ao_height より低ければ 1, 高ければ 0
		// float ao = 1 - step(world_pos.y, ao_height) * ( (ao_height - world_pos.y) / (uAoTexRange/2) );

		// Linear or Hermite
		// float ao = 1.0 - clamp((ao_height - world_pos.y) / uAoMaxDepth, 0, 1) * uAoMaxDensity;
		float ao = 1.0 - smoothstep(0.0, 1.0, (ao_height - world_pos.y) / uAoMaxDepth) * uAoMaxDensity;
		oColor = vec4(ao, 1, 1, 1);
	}
}

#endif // defined(AGL_FRAGMENT_SHADER)+
