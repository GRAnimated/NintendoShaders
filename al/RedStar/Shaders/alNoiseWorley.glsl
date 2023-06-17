/**
 * @file	alNoiseWorley.glsl
 * @author	Matsuda Hirokazu  (C)Nintendo
 *
 * @brief	Worley ノイズ
 *			
 */
#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable // 明示的な場所指定には必要。無いと GPU ハング。
#endif

#define RENDER_TYPE				(0)
#define RENDER_3D_CLOUD			(0)
#define RENDER_WORLEY			(1)
#define RENDER_WORLEY_FROST		(2)
#define RENDER_3D_OCEAN_FOAM	(3)
#define RENDER_WORLEY_THIN		(4)

#if (RENDER_TYPE == RENDER_WORLEY_FROST)
	#define	IS_USE_MANHATTAN_DIST	(1)
#else
	#define	IS_USE_MANHATTAN_DIST	(0)
#endif

#include "alMathUtil.glsl"
#include "alCalcFullScreenTriangle.glsl"
#include "alDeclareUniformBlockBinding.glsl"
#include "alNoiseUtil.glsl"

#include "alNoiseWorleyUtil.glsl"
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
	float dist_offset_scale = uData.x;
	#if (RENDER_TYPE == RENDER_3D_CLOUD)
	{
		float w0  = calcWorleyNoise3D( 0.5*stu,  0.5*rep, dist_offset_scale);
		float w1  = calcWorleyNoise3D( 1.0*stu,  1.0*rep, dist_offset_scale);
		float w2  = calcWorleyNoise3D( 2.0*stu,  2.0*rep, dist_offset_scale);
		float w4  = calcWorleyNoise3D( 4.0*stu,  4.0*rep, dist_offset_scale);
		float w8  = calcWorleyNoise3D( 8.0*stu,  8.0*rep, dist_offset_scale);
		float w16 = calcWorleyNoise3D(16.0*stu, 16.0*rep, dist_offset_scale);
		float hf = 0.5;	float hf2 = hf*hf; float hf4 = hf2*hf2; float hf8 = hf4*hf4; float hf16 = hf8*hf8;
		
		float fbm0 = w0*(w1 + 0.5*w2)/(1.5);
		float fbm1 = w1*(w2 + 0.5*w4)/(1.5);
		float fbm2 = w2*(w4 + 0.5*w8)/(1.5);

		float worley_fbm_scale = uData.y;
		float fbm_p = worley_fbm_scale * (w0 + hf*w1 + hf2*w2 + hf4*w4 + hf8*w8 + hf16*w16)
					/(1.0 + hf + hf2 + hf4 + hf8 + hf16);
		float perlin_fbm = noisePerlin3DfBm(stu, rep) * 0.5 + 0.5;
		
		oColor = vec4(perlin_fbm + fbm_p, fbm0, fbm1, fbm2);
	}
	#elif (RENDER_TYPE == RENDER_3D_OCEAN_FOAM)
	{
		float w0  = calcWorleyNoise3D( 0.5*stu,  0.5*rep, dist_offset_scale);
		float w1  = calcWorleyNoise3D( 1.0*stu,  1.0*rep, dist_offset_scale);
		float w2  = calcWorleyNoise3D( 2.0*stu,  2.0*rep, dist_offset_scale);
		float fbm0 = w0*(w1 + 0.5*w2)/(1.5);
		oColor = vec4(fbm0);
	}
	#elif (RENDER_TYPE == RENDER_WORLEY)
	{
		float w1  = calcWorleyNoise3D( 1.0*stu,  1.0*rep, dist_offset_scale);
		oColor = vec4(vec3(w1), 1.0);
	}
	#elif (RENDER_TYPE == RENDER_WORLEY_FROST)
	{
		float n = 0.0;
		float a = 0.5;
		for (int i=0; i<4; ++i)
		{
			float nz = calcWorleyNoise3D(stu, rep, dist_offset_scale);
			n += a * nz;
			stu *= 2.0;
			rep *= 2.0;
			a *= 0.5;
		}
		oColor = vec4(vec3(n), 1.0);
	}
	#elif (RENDER_TYPE == RENDER_WORLEY_THIN)
	{
		#if 0
		float noise = pow(calcThinWorleyNoise3D(stu, rep, 1.5, 2.0), 0.25);
		noise = min(noise, pow(calcThinWorleyNoise3D(stu*2.0, rep, 2.0, 0.5), 0.5));
		#else
		vec3 rnd_offset1 = vec3(0.0);
		vec3 rnd_offset2 = vec3(0.25, -2.1, 7.0);
		vec3 rnd_offset3 = vec3(-0.3, 1.3, 3.7);
		float noise1 = pow(calcThinWorleyNoise3D(stu, rep, rnd_offset1, 3.0, 2.0), 0.5);
		float noise2 = pow(calcThinWorleyNoise3D(stu, rep, rnd_offset2, 3.0, 2.0), 0.5);
		float noise3 = pow(calcThinWorleyNoise3D(stu, rep, rnd_offset3, 3.0, 2.0), 0.5);
		float noise = min(noise1, min(noise2, noise3));
		#endif
		noise = 1.0 - noise;
		oColor = vec4(vec3(noise), 1.0);
	}
	#endif
	oColor *= DEBUG_SCALE;
}

#endif // AGL_FRAGMENT_SHADER
