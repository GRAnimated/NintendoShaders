/**
 * @file	alMakeLinearDepth.glsl
 * @author	YosukeMori  (C)Nintendo
 *
 * @brief	デプスバッファからリニアデプスを生成
 */

#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable // 明示的な場所指定には必要。無いと GPU ハング。
#endif

#include "alDeclareUniformBlockBinding.glsl"
#include "alMathUtil.glsl"
#include "alScreenUtil.glsl"

#define USING_SCREEN_AND_TEX_COORD_CALC	(1)
#include "alDefineVarying.glsl"
#include "alDeclareMdlEnvView.glsl"

// プロジェクションによって変わる
#define PROJ_TYPE			(0)	// @ id="cProjType"	choice="0,1", default="0"
#define PROJ_TYPE_STD		(0)
#define PROJ_TYPE_REV_INF	(1)


uniform sampler2D			cDepthBuffer;

//------------------------------------------------------------------------------
// 頂点シェーダ
//------------------------------------------------------------------------------
#if defined(AGL_VERTEX_SHADER)

layout (location=0) in vec3 aPosition;				// @@ id="_p0" hint="position0"

DECLARE_VARYING(vec3,	vParameters);

void main()
{
	gl_Position.xy = 2.0 * aPosition.xy;
	gl_Position.z  = 0.0;
	gl_Position.w  = 1.0;

	calcScreenAndTexCoord();
	
	#if (PROJ_TYPE == PROJ_TYPE_STD)
	{
		getVarying(vParameters)	= vec3( -cFar * cInvRange, cRange / cNear, cNear * cInvRange );
	}
	#elif (PROJ_TYPE == PROJ_TYPE_REV_INF)
	{
		getVarying(vParameters).x = cNear/cFar;
		// linear_depth = (n/d - n)/range
		// = (n/range) / d - (n/range)
		// ↑mad になるように。
		getVarying(vParameters).y = cNear * cInvRange;
	}
	#endif // PROJ_TYPE
}

//------------------------------------------------------------------------------
// フラグメントシェーダ
//------------------------------------------------------------------------------
#elif defined(AGL_FRAGMENT_SHADER)

// 出力変数
layout(location = 0)	out vec4 oColor;

DECLARE_VARYING(vec3,	vParameters);

#if (PROJ_TYPE == PROJ_TYPE_STD)

#elif (PROJ_TYPE == PROJ_TYPE_REV_INF)

	#define NEAR		cNear
	// near / far
	#define MIN_DEPTH		getVarying(vParameters).x
	#define INV_RANGE		cInvRange
	#define NEAR_INV_RANGE	getVarying(vParameters).y

#endif // PROJ_TYPE

void main()
{
	float depth			= texture(cDepthBuffer, getScreenCoord()).r;

	#if (PROJ_TYPE == PROJ_TYPE_STD)
	{
		float a = getVarying(vParameters).x;
		float b = getVarying(vParameters).y;
		float linear_depth = 0.0;
		linear_depth = a / ((depth + a) * b);
		linear_depth = linear_depth - getVarying(vParameters).z;
		oColor = vec4(linear_depth);
	}
	#elif (PROJ_TYPE == PROJ_TYPE_REV_INF)
	{
		// [1, 0] -> [n, ∞] となってしまうがクランプして [n, f] にしたい
		// [1, n/f] -> [n, f] より n/f を最小値としてクランプすればよい
		depth = max(depth, MIN_DEPTH);
//		depth = (depth < MIN_DEPTH) ? MIN_DEPTH : depth;
//		float linear_depth = NEAR/depth - NEAR;
		float linear_depth = NEAR_INV_RANGE/depth - NEAR_INV_RANGE;
		oColor = vec4(linear_depth);
	}
	#endif // PROJ_TYPE
}

#endif



