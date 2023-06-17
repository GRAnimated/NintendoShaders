/**
 *	@file	alRenderThunder.glsl
 *	@author	Matsuda Hirokazu  (C)Nintendo
 *
 *	@brief	雷レンダリング
 */
 
#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable // 明示的な場所指定には必要。無いと GPU ハング。
#endif

// ジオメトリシェーダ用定義
#define IS_USING_GEOMETRY_SHADER 	(1)

#include "alDeclareUniformBlockBinding.glsl"
#include "alDefineVarying.glsl"
#include "alMathUtil.glsl"
#include "alHdrUtil.glsl"
#include "alGpuRandom.glsl"
#include "alDeclareMdlEnvView.glsl"

#define RENDER_TYPE				(0) // @@ id="cRenderType"	choice="0,1,2,3"	default="0"
#define RENDER_FORWARD			(0)
#define RENDER_MRT				(1)
#define RENDER_CUBEMAP			(2)

#define IS_GENERATE_BRANCH		(0)
#define B_INDEX (1)

DECLARE_VARYING(vec3,	vColor);
DECLARE_VARYING(uint,	vGenerateBranch);
DECLARE_VARYING(uint, 	vRandomSeed);
DECLARE_VARYING(vec4,	vBranchDirIntensity);
DECLARE_VARYING(vec4,	vBranchBeginPos);	// xyz : branch begin pos

// UniformBlock の定義。ModelEnv とかぶらないように。
BINDING_UBO_OTHER_FIRST uniform Thunder
{
	vec4	uStart;					// xyz : start pos
	vec4	uGoal;					// xyz : goal pos
	vec4 	uThunderParam;			// xyz : color,  w : flush rate
	vec4 	uRandomParam;			// x : trunk shift max, y : branch shift max, z : branch probability
	ivec4	uUintData;				// x : vtx num,  y : add index
};

#define MAX_VTX_NUM					uUintData.x
#define ADD_INDEX					uUintData.y
#define START_POS					uStart.xyz
#define GOAL_POS					uGoal.xyz
#define THUNDER_COLOR				uThunderParam.xyz
#define FLUSH_RATE					uThunderParam.w
#define TRUNK_SHIFT_MAX				uRandomParam.x
#define BRANCH_SHIFT_MAX			uRandomParam.y
#define BRANCH_PROBABILITY			uRandomParam.z

/**
 *	[0, 1] レートから放物線を用いたレートを算出する。0->0, 0.5->1, 1->0 となる
 *	y = -(2x-1)^2 - 1
 */
float calcConvergenceRate(float raw_rate)
{
	float x = raw_rate*raw_rate;
	return x*x*x*x;
}

// 行列による変換をジオメトリシェーダで行うかどうか
#define IS_GS_MULT_MTX	(IS_USING_GEOMETRY_SHADER == 0 || IS_GENERATE_BRANCH == 1)

/**
 *	仮想設定位置からシフトさせたずれた位置を求める。
 *	trunk でも branch でも同じ処理を利用する
 */
void calcShift(out vec3 disp_pos, in vec3 ref_pos, in vec3 segment_arrow, in float segment_len, in float u1, in float u2, in float shift_max)
{
	vec3 sphere_pick;
	calcSpherePointPicking(sphere_pick, u1, u2);
	float shift_sphere_center_rate = clamp01(shift_max) * 0.5;
	vec3 sphere_center = ref_pos - segment_arrow * shift_sphere_center_rate;
	float sphere_r = shift_sphere_center_rate * segment_len;
	disp_pos = sphere_center + sphere_pick * sphere_r;
}

//------------------------------------------------------------------------------
// 頂点シェーダ
//------------------------------------------------------------------------------
#if defined(AGL_VERTEX_SHADER)

void main()
{
	float inv_vtx_minus_one = 1.0 / float(MAX_VTX_NUM-1);
	// 頂点バッファは存在しない。インデックスバッファだけ
	float raw_rate = float(gl_VertexID) * inv_vtx_minus_one; // 頂点の最初から最後を [0, 1] にマッピング

	// シフトしないときの位置
	vec3 start_to_goal = GOAL_POS - START_POS;
	vec3 no_displacement_pos = START_POS + start_to_goal * raw_rate;

	uint seed = calcHashWang(gl_VertexID + ADD_INDEX);
	// シフトディスプレースメントの計算
	float u1 = calcGpuRandomXorshift(seed);	float u2 = calcGpuRandomXorshift(seed);

	// Sphere Point Picking を使って方向を揺らす
	vec3 start_to_goal_segment = start_to_goal * inv_vtx_minus_one;
	float segment_len = length(start_to_goal_segment);
	vec3 prev_ref_pos = no_displacement_pos - start_to_goal_segment;

	vec3 displacement_pos;
	calcShift(displacement_pos, no_displacement_pos, start_to_goal_segment, segment_len, u1, u2, TRUNK_SHIFT_MAX);
	// 終端は指定位置に収束させたい
	float convergence_rate = calcConvergenceRate(raw_rate);
	displacement_pos = mix(displacement_pos, no_displacement_pos, convergence_rate);

	float start_to_goal_len = length(start_to_goal);
	
	// 枝分かれさせるかどうか
	#if (IS_GENERATE_BRANCH == 1)
	{
		uint blanch_length_max = (MAX_VTX_NUM - gl_VertexID - 1); // カラーの補間を切るための1点を考慮する
		float blanch_intensity = float(blanch_length_max) / float(MAX_VTX_NUM-1);
		getVarying(vBranchDirIntensity).xyz = displacement_pos - prev_ref_pos;
		getVarying(vBranchDirIntensity).w = blanch_intensity*blanch_intensity;
		getVarying(vBranchBeginPos).xyz = displacement_pos;
		getVarying(vGenerateBranch) = (BRANCH_PROBABILITY < u1) ? 0 : max(blanch_length_max, 2);
	}
	#endif // IS_GENERATE_BRANCH

	gl_Position = multMtx44Vec4(cViewProj, vec4(displacement_pos, 1.0));

	getVarying(vColor) = THUNDER_COLOR*FLUSH_RATE;
	getVarying(vRandomSeed) = seed;
}

//------------------------------------------------------------------------------
// ジオメトリシェーダ
//------------------------------------------------------------------------------
#elif defined(AGL_GEOMETRY_SHADER)

layout(lines) in;
layout(line_strip, max_vertices=64) out;

// 枝分かれはラインの後ろから伸びていく
#define BRANCH_BEGIN_POS	getVaryingIn(vBranchBeginPos, B_INDEX).xyz

void main()
{
	// 自分自身はそのまま出す
	gl_Position = gl_in[0].gl_Position;
	getVaryingOut(vColor) = getVaryingIn(vColor, 0);
	EmitVertex();

	gl_Position = gl_in[1].gl_Position;
	getVaryingOut(vColor) = getVaryingIn(vColor, 1);
	EmitVertex();

#if (IS_GENERATE_BRANCH == 1)
	// カラーの補間を切りたいので同じ頂点をカラーだけ変えて出しておく
	vec3 color = getVaryingIn(vColor, B_INDEX) * getVaryingIn(vBranchDirIntensity, B_INDEX).w;
	getVaryingOut(vColor) = color;
	EmitVertex();

	// 枝分かれ
	vec3 begin_pos = BRANCH_BEGIN_POS;
	vec3 branch_dir = getVaryingIn(vBranchDirIntensity, B_INDEX).xyz;
	uint seed = calcHashWang(getVaryingIn(vRandomSeed, B_INDEX));
	uint iter_num = getVaryingIn(vGenerateBranch, B_INDEX);
	float intensity_coef = 1.0 / float(iter_num-1);
	for (int i=0; i<iter_num; ++i)
	{
		// シフトディスプレースメントの計算
		float u1 = calcGpuRandomXorshift(seed);	float u2 = calcGpuRandomXorshift(seed);
		vec3 ref_pos = begin_pos + branch_dir;
		calcShift(begin_pos, ref_pos, branch_dir, length(branch_dir), u1, u2, BRANCH_SHIFT_MAX);
		
		gl_Position = multMtx44Vec4(cViewProj, vec4(begin_pos, 1.0));

		// 先端に行くほど色を弱めていく
		float intensity = 1.0 - float(i) * intensity_coef;
		getVaryingOut(vColor) = color * intensity;
		EmitVertex();
	}
#endif // 0

	EndPrimitive();
}

//------------------------------------------------------------------------------
// フラグメントシェーダ
//------------------------------------------------------------------------------
#elif defined(AGL_FRAGMENT_SHADER)

#if (RENDER_TYPE == RENDER_MRT)
	#include "alDeclareGBuffer.glsl"
#else
	layout(location = 0)	out vec4 oColor;
#endif // IS_MRT

void main()
{
	// ディファードなら MRT 出力
	#if (RENDER_TYPE == RENDER_MRT)
	{
		oBaseColor	= vec4(0.0);
		oWorldNrm	= vec4(0.0);
		oNormalizedLinearDepth.rg = vec2(1.0, 1.0);
		oMotionVec.rg = vec2(0.0);
		oLightBuf	= vec4(getVarying(vColor), 1.0);
	}
	#elif (RENDER_TYPE == RENDER_CUBEMAP)
	{
		CalcHdrToLdr(oColor, getVarying(vColor));
	}
	#else
	{
		oColor.rgb = getVarying(vColor);
		oColor.a = 1.0;
	}
	#endif //(RENDER_TYPE == RENDER_MRT)
}

#endif // AGL_FRAGMENT_SHADER

