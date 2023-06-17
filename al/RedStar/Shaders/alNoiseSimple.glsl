/**
 * @file	alNoiseSimple.glsl
 * @author	Matsuda Hirokazu  (C)Nintendo
 *
 * @brief	シンプルなノイズ
 */
#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable // 明示的な場所指定には必要。無いと GPU ハング。
#endif

#include "alMathUtil.glsl"
#include "alCalcFullScreenTriangle.glsl"
#include "alDeclareUniformBlockBinding.glsl"
#include "alNoiseUtil.glsl"

#define IS_SEAMLESS				(0)

//------------------------------------------------------------------------------
// 頂点シェーダ
//------------------------------------------------------------------------------
#if defined(AGL_VERTEX_SHADER)

layout (location=0) in vec4 aPosition;	// @@ id="_p0" hint="position0"

void main()
{
	// 全画面を覆う三角形
	CalcFullScreenTriPos(gl_Position, aPosition);
}

//------------------------------------------------------------------------------
// フラグメントシェーダ
//------------------------------------------------------------------------------
#elif defined(AGL_FRAGMENT_SHADER)

// 出力変数
layout(location = 0)	out vec4 oColor;

void main()
{
	vec2 uv = gl_FragCoord.xy * INV_RESOLUTION_XY * pow(vec2(2.0), uCoordScale.xy);
	#if (IS_SEAMLESS == 0)
	{
		float n = calcNoise(uv + TIME);
		oColor = vec4(vec3(n), 1.0);
	}
	#else
	{
	//	float n = MakeSeamless(uv, uCoordScale.zw, calcNoise);
	
		const float map = uData.z; //256.0;
		vec2 t = mod(uv, map);
		vec2 q = t/map;
		vec2 r = vec2(map);
		float n = MakeSeamless2(calcNoise, t, q, r);

		oColor = vec4(vec3(n), 1.0);
	}
	#endif
	oColor *= DEBUG_SCALE;
}

#endif // AGL_FRAGMENT_SHADER
