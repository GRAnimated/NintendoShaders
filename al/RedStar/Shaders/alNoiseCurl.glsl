/**
 * @file	alNoiseCurl.glsl
 * @author	Matsuda Hirokazu  (C)Nintendo
 *
 * @brief	カールノイズ
 */
#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable // 明示的な場所指定には必要。無いと GPU ハング。
#endif

#include "alMathUtil.glsl"
#include "alCalcFullScreenTriangle.glsl"
#include "alDeclareUniformBlockBinding.glsl"
#include "alNoiseUtil.glsl"
#include "alNoisePerlinUtil.glsl"

#define RENDER_TYPE		(0)
#define RENDER_CURL		(0)
#define RENDER_CURL_FBM	(1)

#define IS_NORMALIZE	(0)

// 3D テクスチャレンダリング
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
	vec3 n;
	#if (RENDER_TYPE == RENDER_CURL)
	{
		n = calcCurlNoisePerlin3D(vec3(st, z), coord_scale);
	}
	#elif (RENDER_TYPE == RENDER_CURL_FBM)
	{
		vec3 stu = vec3(st, z);
		vec3 rep = coord_scale;
		const int octaves = 3;
		n = vec3(0.0);
		float a = 0.5;
		for (int i=0; i<octaves; ++i)
		{
			vec3 curl = calcCurlNoisePerlin3D(stu, rep);
			n += a * curl;
			stu *= 2.0;
			rep *= 2.0;
			a *= 0.5;
		}
	}
	#endif // RENDER_TYPE

	// スケール
	n *= uData.x;
	
	#if (IS_NORMALIZE == 1)
	{
		n = normalize(n);
	}
	#endif // IS_NORMALIZE
	oColor = vec4(0.5 + 0.5 * n, 1.0);
	oColor *= DEBUG_SCALE;
}

#endif // AGL_FRAGMENT_SHADER
