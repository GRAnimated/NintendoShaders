/**
 * @file	alNoiseCloudLikeFbm.glsl
 * @author	Matsuda Hirokazu  (C)Nintendo
 *
 * @brief	fBm を多重に使って雲のような乱流ノイズ
 *			
 */
#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable // 明示的な場所指定には必要。無いと GPU ハング。
#endif

#define RENDER_TYPE				(0)

#include "alMathUtil.glsl"
#include "alCalcFullScreenTriangle.glsl"
#include "alDeclareUniformBlockBinding.glsl"
#include "alNoiseUtil.glsl"

#include "alNoisePerlinUtil.glsl"

uniform float uDepth;

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
	vec3 coord_scale = pow(vec3(2.0), uCoordScale.xyz);
	vec2 st = gl_FragCoord.xy * INV_RESOLUTION_XY * coord_scale.xy;
	float z = uDepth * coord_scale.z;
	z += uData.z;

	vec3 stu = vec3(st, z);
	vec3 rep = coord_scale;
	
	#if (RENDER_TYPE == 0)
	{
		float n = 0.0;
		vec2 q = vec2(noisePerlin3DfBm(stu, rep), noisePerlin3DfBm(stu + vec3(1.0,-1.0,0.5)*0.25, rep));
		vec2 r = vec2(noisePerlin3DfBm(stu + vec3(q+vec2(-1.7,9.2), 0.15)*0.25, rep)
					, noisePerlin3DfBm(stu + vec3(q+vec2(8.3,-2.8), -0.126)*0.25, rep));
		n = noisePerlin3DfBm(stu + vec3(r*0.5, 0.0), rep);
		oColor = vec4(vec3(n*0.5+0.5), 1.0);
	}
	#endif
	oColor *= DEBUG_SCALE;
}

#endif // AGL_FRAGMENT_SHADER
