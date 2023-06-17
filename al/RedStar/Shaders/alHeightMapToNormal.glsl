/**
 * @file	alHeightMapToNormal.glsl
 * @author	Tatsuya Kurihara  (C)Nintendo
 *
 * @brief	HeightMapから法線を求める
 */
#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable // 明示的な場所指定には必要。無いと GPU ハング。
#endif

precision highp float;

#include "alDeclareUniformBlockBinding.glsl"

#define NORMAL_CALC_TYPE	(0) // @@ id="cNormalCalcType" choice="0,1,2,3" default="0"
#define CALC_NORMAL			(0)
#define CALC_NORMAL_ABS		(1)
#define CALC_GRAD			(2)
#define CALC_DISP_MAP		(3)
#define CALC_PATTERN		(4)

#define NOISE_TYPE			(0)
#define NOISE_DISABLE		(0)
#define NOISE_ENABLE		(1)

uniform sampler2D uHeightTex;

#if NOISE_TYPE == NOISE_ENABLE
	uniform sampler3D cNoise3D;
#endif

//------------------------------------------------------------------------------
// 頂点シェーダ
//------------------------------------------------------------------------------
#if defined(AGL_VERTEX_SHADER)

layout (location = 0) in vec3 aPosition;	// @@ id="_p0" hint="position0"
layout (location = 1) in vec2 aTexCoord;
out vec2 vTexCrd;

void main()
{
	gl_Position.xy = 2.0 * aPosition.xy;
	gl_Position.z  = 0.0;
	gl_Position.w  = 1.0;

	vTexCrd = aTexCoord;
#if defined( AGL_TARGET_GL )
	vTexCrd.y = 1.0 - vTexCrd.y;
#endif
}

//------------------------------------------------------------------------------
// フラグメントシェーダ
//------------------------------------------------------------------------------
#elif defined(AGL_FRAGMENT_SHADER)

BINDING_UBO_OTHER_FIRST uniform HeightMapToNormal // @@ id="cOceanDispToNrmFold" comment="法線＋フォールディング生成パラメータ"
{
	vec4 uData; // xy : one texel
	vec4 uNoiseParam;
};

#define ONE_TEXEL_X		uData.x
#define ONE_TEXEL_Y		uData.y
#define TEXEL_DIST_X	uData.z
#define TEXEL_DIST_Y	uData.w
#define NOISE_TEX_CRD_ADD		uNoiseParam.xyz
#define NOISE_TEX_CRD_SCALE		uNoiseParam.w

in	vec2	vTexCrd;
out	vec4	oColor;

void main()
{
	// 近くのテクセルをサンプルする
	vec2 tc_negx = vec2(vTexCrd.x - ONE_TEXEL_X, vTexCrd.y);
	vec2 tc_posx = vec2(vTexCrd.x + ONE_TEXEL_X, vTexCrd.y);
	vec2 tc_negy = vec2(vTexCrd.x, vTexCrd.y - ONE_TEXEL_Y);
	vec2 tc_posy = vec2(vTexCrd.x, vTexCrd.y + ONE_TEXEL_Y);

	float disp_negx = texture(uHeightTex, tc_negx).r;
	float disp_posx = texture(uHeightTex, tc_posx).r;
	float disp_negy = texture(uHeightTex, tc_negy).r;
	float disp_posy = texture(uHeightTex, tc_posy).r;

	#if (NORMAL_CALC_TYPE == CALC_NORMAL || NORMAL_CALC_TYPE == CALC_NORMAL_ABS || NORMAL_CALC_TYPE == CALC_DISP_MAP || NORMAL_CALC_TYPE == CALC_PATTERN)
	{
		vec3 sub_x = vec3(1, (disp_posx - disp_negx) / (TEXEL_DIST_X * 2.0), 0.0);
		vec3 sub_y = vec3(0.0, (disp_posy - disp_negy) / (TEXEL_DIST_Y * 2.0), 1.0);
		vec3 nrm = cross(sub_y, sub_x);
		nrm = normalize(nrm);
		#if (NORMAL_CALC_TYPE == CALC_NORMAL_ABS)
		{
			nrm = abs(nrm);
		}
		#endif

		#if (NORMAL_CALC_TYPE == CALC_DISP_MAP)
		{
			float disp_y = clamp(1.0 - abs(nrm.y), 0, 1) * (-2.1); //FIXME: それっぽい値に見えるけどマジックナンバーです

			#if NOISE_TYPE == NOISE_ENABLE
				vec3 noise = texture(cNoise3D, vec3(vTexCrd.x, 0.0, vTexCrd.y) * NOISE_TEX_CRD_SCALE + NOISE_TEX_CRD_ADD).rgb;
				oColor = vec4(nrm.x, disp_y, nrm.z, 0.0);
				oColor.rgb += (1-oColor.rgb) * (noise.rgb - 0.5) * vec3(0.7, 0.15, 0.7);
			#else
				oColor = vec4(nrm.x, disp_y, nrm.z, 0.0);
			#endif
			
		}
		#elif (NORMAL_CALC_TYPE == CALC_PATTERN)
		{
			float v = 1.0 - nrm.y*nrm.y;
			#if NOISE_TYPE == NOISE_ENABLE
				float noise = texture(cNoise3D, vec3(vTexCrd.x, 0.0, vTexCrd.y) * NOISE_TEX_CRD_SCALE + NOISE_TEX_CRD_ADD).r;
				v *= noise;
				oColor = vec4(v,v,v,0.0);
			#else
				oColor = vec4(v,v,v,0.0);
			#endif
		}
		#else
			oColor = vec4(nrm.x, nrm.z, 0.0, 0.0);
		#endif
	}
	#elif (NORMAL_CALC_TYPE == CALC_GRAD)
	{
		oColor = vec4(-(disp_posx - disp_negx), -(disp_posy - disp_negy), 0.0, 0.0);
	}
	#endif
}
#endif // defined(AGL_FRAGMENT_SHADER)
