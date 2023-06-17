/**
 * @file	alNoiseGem.glsl
 * @author	Matsuda Hirokazu  (C)Nintendo
 *
 * @brief	ボロノイ図を使った宝石乱反射みたいなノイズ
 *			
 */
#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable // 明示的な場所指定には必要。無いと GPU ハング。
#endif

#include "alMathUtil.glsl"
#include "alCalcFullScreenTriangle.glsl"
#include "alDeclareUniformBlockBinding.glsl"
#include "alDefineVarying.glsl"
#include "alDeclareMdlEnvView.glsl"
#include "alNoiseUtil.glsl"
#include "alNoiseWorleyUtil.glsl"

#define RENDER_TYPE		(0)
#define RENDER_STD		(0)
#define RENDER_CUBEMAP	(1)

/**
 *	3D ボロノイ図
 */
float calcVoronoi3DDistance(in vec3 stu, in vec3 rep)
{
	vec3 i_stu = floor(stu);
	vec3 f_stu = fract(stu);

	vec3 min_rel_pos, min_offset;
	float min_dist = 8.0;

	for (int z=-1; z<=1; ++z)
	for (int y=-1; y<=1; ++y)
	for (int x=-1; x<=1; ++x)
	{
		vec3 offset = vec3(x, y, z); // 隣へのオフセット
		vec3 rnd_idx = mod(i_stu + offset, rep); // 格子毎に点を求めるための元となるベクトル。格子毎に一意
		vec3 random01 = random3(rnd_idx); // ランダムベクトル。[0, 1]の範囲だが f_stu も[0, 1]なので[-1, 1]にしなくても良い
		vec3 neighbor_pt = random01 + offset;
		float n_dist = calcDist(neighbor_pt, f_stu);
		if (n_dist < min_dist)
		{
			min_dist = n_dist;
			min_rel_pos = neighbor_pt - f_stu;
			min_offset = offset;
		}
	//	dist = min(dist, n_dist);
	}

	min_dist = 8.0;
	const int range = 2;
	for (int z=-range; z<=range; ++z)
	for (int y=-range; y<=range; ++y)
	for (int x=-range; x<=range; ++x)
	{
		vec3 offset = min_offset + vec3(x, y, z);
		vec3 rnd_idx = mod(i_stu + offset, rep); // 格子毎に点を求めるための元となるベクトル。格子毎に一意
		vec3 random01 = random3(rnd_idx); // ランダムベクトル。[0, 1]の範囲だが f_stu も[0, 1]なので[-1, 1]にしなくても良い
		vec3 rel_pos = offset + random01 - f_stu;
		float dist = dot( 0.5*(min_rel_pos + rel_pos), normalize(rel_pos - min_rel_pos) );
		min_dist = min(min_dist, dist);
	}
	return 1.0-min_dist;
}

/**
 *	宝石表現【色収差とパワー】
 */
vec3 calcVoronoiGem(in vec3 stu, in vec3 rep, in float diff, in float power)
{
	vec3 color;
	color.r = calcVoronoi3DDistance(stu + vec3(0.0), rep);
	color.g = calcVoronoi3DDistance(stu + vec3(diff), rep);
	color.b = calcVoronoi3DDistance(stu + vec3(diff*2), rep);

	return pow(color, vec3(power));
}

uniform float uDepth;
DECLARE_VARYING(vec3,	vRay);

//------------------------------------------------------------------------------
// 頂点シェーダ
//------------------------------------------------------------------------------
#if defined(AGL_VERTEX_SHADER)

layout (location=0) in vec4 aPosition;	// @@ id="_p0" hint="position0"

void main()
{
	// 全画面を覆う三角形
	CalcFullScreenTriPos(gl_Position, aPosition);
	
	// ワールドでのレイに変換
	getVarying(vRay) = multMtx34Vec3(uInvProjViewNoTrans, vec3(gl_Position.xyz)).xyz;
}

//------------------------------------------------------------------------------
// フラグメントシェーダ
//------------------------------------------------------------------------------
#elif defined(AGL_FRAGMENT_SHADER)

// 出力変数
layout(location = 0)	out vec4 oColor;

void main()
{
	vec3 stu, rep;

	#if (RENDER_TYPE == RENDER_STD)
	{
		vec3 coord_scale = pow(vec3(2.0), uCoordScale.xyz);
		vec2 st = gl_FragCoord.xy * INV_RESOLUTION_XY * coord_scale.xy;
		float z = uDepth * coord_scale.z;
		z += uData.z;

		stu = vec3(st, z);
		rep = coord_scale;
	}
	#elif (RENDER_TYPE == RENDER_CUBEMAP)
	{
		vec3 ray = getVarying(vRay) * uCoordScale.x;
		stu = ray;
		rep = vec3(100.0); // 適当にでかい数
	}
	#endif

#if 0
	float noise = calcVoronoiGem(stu, rep);
	
	float noise_pow = pow(noise, 2.2);
	vec3 add_ = vec3(0.0, 0.07, 0.14) * 1.0;
	vec3 mul_ = vec3(1.0, 1.1, 1.25) * 4.0;
	float nz_cl = 1.0 - noise_pow;
//	nz_cl = noise_pow;
	vec3 nz_color = vec3(1.0)-fract(sin(nz_cl*mul_ + add_));
	nz_color *= 1.5;

	oColor.rgb = nz_color;
#else
	vec3 gem = calcVoronoiGem(stu + uData2.xyz, rep, uData.x, uData.y);
	oColor = vec4(gem, 1.0);
#endif
}

#endif // AGL_FRAGMENT_SHADER
