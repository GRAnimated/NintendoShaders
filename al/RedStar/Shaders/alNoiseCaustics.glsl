/**
 * @file	alNoiseCaustics.glsl
 * @author	Matsuda Hirokazu  (C)Nintendo
 *
 * @brief	コースティクスノイズ
 *			
 */
#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable // 明示的な場所指定には必要。無いと GPU ハング。
#endif

#define RENDER_TYPE					(0)
#define RENDER_CAUSTICS_3D			(0)
#define RENDER_CAUSTICS_3D_1CH		(1)
#define RENDER_CAUSTICS_3D_OLD		(2)
#define RENDER_CAUSTICS_3D_OLD_1CH	(3)

#include "alMathUtil.glsl"
#include "alCalcFullScreenTriangle.glsl"
#include "alDeclareUniformBlockBinding.glsl"
#include "alNoiseUtil.glsl"

#include "alNoisePerlinUtil.glsl"
#include "alNoiseWorleyUtil.glsl"

uniform float uDepth;

#define ITER_ONE(v, stu__, rep__)				\
{												\
	vec3 dF = noisePerlin3D(stu__, rep__).xyz;	\
	v += amp * dF;								\
	stu__ *= 2.0;								\
	rep__ *= 2.0;								\
	amp *= 0.5;									\
}

#define diff		uData.x
#define power		uData.y
#define SMOOTH1		uData.z
#define SMOOTH2		uData.w
#define FLOW_SCALE	uData2.x

vec3 fbmDerivative(in vec3 stu, in vec3 rep)
{
	#if 1
	vec3 v = vec3(0.0);
	float a = 0.5;
	for (int d=0; d<3; ++d)
	{
		vec3 flow = noisePerlin3D(stu, rep).xyz;
		v += a * flow;
		stu *= 2.0;
		rep *= 2.0;
		a *= 0.5;
	}
	return v;
	#else
	vec3 v = vec3(0.0);
	float amp = 0.5;
	ITER_ONE(v, stu, rep);
	ITER_ONE(v, stu, rep);
	ITER_ONE(v, stu, rep);
	return v;
	#endif
}

float fbm(in vec3 stu, in vec3 rep)
{
	float v = 0.0;
	float a = 1.0;
	float total_a = 0.0;
	for (int i=0; i<3; ++i)
	{
		vec4 nz = noisePerlin3D(stu, rep);
		v += a * nz.w;
		total_a += a;
		stu *= 2.0;
		rep *= 2.0;
		a *= 0.5;
	}
	return v/total_a;
}

float calcCaustics(in vec3 stu, in vec3 rep)
{
	vec3 flow = fbmDerivative(stu, rep) * FLOW_SCALE;
	float nz = fbm(stu + flow, rep) * 0.5 + 0.5;
	return smoothstep(SMOOTH1, SMOOTH2, pow(nz, power));
}

layout(binding = 0)	uniform sampler3D cNoise3D;

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
	vec3 uv_3d = stu / coord_scale.xyz;
	#if (RENDER_TYPE == RENDER_CAUSTICS_3D)
	{
		vec3 color;
		for (int c=0; c<3; ++c)	{ color[c] = calcCaustics(stu + vec3(diff*c), rep); }
		oColor = vec4(color, 1.0);
	}
	#elif (RENDER_TYPE == RENDER_CAUSTICS_3D_1CH)
	{
		oColor = vec4(vec3(calcCaustics(stu, rep)), 1.0);
	}
	#elif (RENDER_TYPE == RENDER_CAUSTICS_3D_OLD)
	{
		vec3 color;
		vec3 flow = (texture(cNoise3D, uv_3d).xyz * 2.0 - 1.0) * uData2.x;
	//	vec3 flow = calcCurlNoisePerlin3D(stu, rep).xyz;
		for (int c=0; c<3; ++c)
		{
//			float nz = 1.0 - clamp01(noisePerlin3D(stu + vec3(diff*c), rep).w*0.5+0.5);
			float nz = 1.0 - abs(noisePerlin3D(stu + flow + vec3(diff*c), rep).w);
			nz = pow(nz, power);
			color[c] = smoothstep(SMOOTH1, SMOOTH2, nz);
		}
		oColor = vec4(color, 1.0);
	}
	#elif (RENDER_TYPE == RENDER_CAUSTICS_3D_OLD_1CH)
	{
		vec3 flow = (texture(cNoise3D, uv_3d).xyz * 2.0 - 1.0) * uData2.x;
		float nz = 1.0 - abs(noisePerlin3D(stu + flow, rep).w);
		nz = pow(nz, power);
		oColor = vec4(vec3(smoothstep(SMOOTH1, SMOOTH2, nz)), 1.0);
	}
	#endif
	oColor *= DEBUG_SCALE;
}

#endif // AGL_FRAGMENT_SHADER
