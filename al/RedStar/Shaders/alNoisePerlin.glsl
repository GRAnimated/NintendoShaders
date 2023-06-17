/**
 * @file	alNoisePerlin.glsl
 * @author	Matsuda Hirokazu  (C)Nintendo
 *
 * @brief	パーリンノイズ系
 */
#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable // 明示的な場所指定には必要。無いと GPU ハング。
#endif

#include "alMathUtil.glsl"
#include "alCalcFullScreenTriangle.glsl"
#include "alDeclareUniformBlockBinding.glsl"
#include "alNoiseUtil.glsl"
#include "alNoisePerlinUtil.glsl"

#define RENDER_TYPE			(0)
#define RENDER_PERLIN		(0)
#define RENDER_PERLIN_FBM	(1)
#define RENDER_RIDGE		(2)

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
	z += uData.z;

	vec3 stu = vec3(st, z);
	vec3 rep = coord_scale;
	
	float n;
	#if (RENDER_TYPE == RENDER_PERLIN)
	{
		n = noisePerlin3D(stu, rep).w*0.5 + 0.5;
	}
	#elif (RENDER_TYPE == RENDER_PERLIN_FBM || RENDER_TYPE == RENDER_RIDGE)
	{
		const int octaves = 4;
		n = 0.0;
		float w = 1.0;
		float total_w = 0.0;
		for (int i=0; i<octaves; ++i)
		{
			float nz = noisePerlin3D(stu, rep).w;
			#if (RENDER_TYPE == RENDER_PERLIN_FBM)
			{
				nz = nz * 0.5 + 0.5;
			}
			#elif (RENDER_TYPE == RENDER_RIDGE)
			{
				nz = 1.0 - abs(nz);
				nz = pow(nz, uData.x);
			}
			#endif // RENDER_RIDGE
			n += w * nz;
			total_w += w;
			stu *= 2.0;
			rep *= 2.0;
			w *= 0.5;
		}
		n /= total_w;
	}
	#endif // RENDER_TYPE

	oColor = vec4(vec3(n), 1.0);
	oColor *= DEBUG_SCALE;
}

#endif // AGL_FRAGMENT_SHADER
