/**
 * @file	alCalcTouchPos.glsl
 * @author	Yosuke Mori  (C)Nintendo
 *
 * @brief	タッチ位置取得
 */

#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable // 明示的な場所指定には必要。無いと GPU ハング。
#endif

#define	BINDING_UBO_MDL_ENV_VIEW layout(std140, binding = 1)

#define USING_SCREEN_AND_TEX_COORD_CALC	(0)
#include "alMathUtil.glsl"
#include "alDefineVarying.glsl"
#include "alDeclareMdlEnvView.glsl"	// 環境と視点を合わせたデータ 

// ModelEnv とかぶらないように。
layout(std140, binding = 2) uniform CalcTouchPos
{
	vec2	uTouchPos;
	vec2	uMeshPos;
	vec2	uMeshSize;
};

#if defined( AGL_VERTEX_SHADER )

in vec3 aPosition;

void main( void )
{
	vec2 sign_pos = sign(aPosition.xy); // 画面を覆う -1 〜 1 の範囲のスクリーン座標になる
	gl_Position.xy = sign_pos;
	gl_Position.z = 1.0;
	gl_Position.w = 1.0;
}

#elif defined( AGL_FRAGMENT_SHADER )

layout(location = 0) out vec4 oColor;

layout(binding = 3)
uniform sampler2D	cTextureDepth;

void main()
{
	float depth = texture(cTextureDepth, uTouchPos).r;

	vec4 view_pos; // ビュー座標系における位置
	view_pos.z = -( depth * cRange + cNear );

	vec2 screen_pos = uTouchPos.xy * 2.0 - 1.0;
	screen_pos.xy *= -cTanFovyHalf.xy;
	screen_pos.xy -= cScrProjOffset.xy;
	view_pos.xy = screen_pos.xy * view_pos.z;
	view_pos.w = 1.0;

	vec4 touch_pos_w = multMtx34Vec4(cInvView, view_pos);

	vec2 touch_coord;
	touch_coord.x = touch_pos_w.x - uMeshPos.x;
	touch_coord.y = touch_pos_w.z - uMeshPos.y;

	if( touch_coord.x < 0.0 || touch_coord.x > uMeshSize.x || touch_coord.y < 0.0 || touch_coord.y > uMeshSize.y )
	{
	    oColor.r = -1.0;
	    oColor.g = -1.0;
	}
	else
	{
		oColor.r = touch_coord.x / uMeshSize.x;
		oColor.g = 1.0 - touch_coord.y / uMeshSize.y;
	}
}

#endif
