/**
 * @file	alOceanDispToNormalFold.glsl
 * @author	Matsuda Hirokazu  (C)Nintendo
 *
 * @brief	ディスプレースメントマップから法線のグラディエントとフォールディングを求める
 *			フォールディングはサブサーフェイススキャタリングのスケールに使う
 */
#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable // 明示的な場所指定には必要。無いと GPU ハング。
#endif

precision highp float;

#include "alDeclareUniformBlockBinding.glsl"

uniform sampler2D uDisplacementTex;

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

BINDING_UBO_OTHER_FIRST uniform OceanDispToNrmFold // @@ id="cOceanDispToNrmFold" comment="法線＋フォールディング生成パラメータ"
{
	vec4 uData; // xy : one texel
};

#define ONE_TEXEL_X		uData.x
#define ONE_TEXEL_Y		uData.y

in	vec2	vTexCrd;
out	vec4	oColor;

void main()
{
	// 近くのテクセルをサンプルする
	vec2 tc_negx = vec2(vTexCrd.x - ONE_TEXEL_X, vTexCrd.y);
	vec2 tc_posx = vec2(vTexCrd.x + ONE_TEXEL_X, vTexCrd.y);
	vec2 tc_negy = vec2(vTexCrd.x, vTexCrd.y - ONE_TEXEL_Y);
	vec2 tc_posy = vec2(vTexCrd.x, vTexCrd.y + ONE_TEXEL_Y);

	vec3 disp_negx = texture(uDisplacementTex, tc_negx).xyz;
	vec3 disp_posx = texture(uDisplacementTex, tc_posx).xyz;
	vec3 disp_negy = texture(uDisplacementTex, tc_negy).xyz;
	vec3 disp_posy = texture(uDisplacementTex, tc_posy).xyz;

	// Calculate Jacobian correlation from the partial differential of height field
	vec2 Dx = (disp_posx.xz - disp_negx.xz);
	vec2 Dz = (disp_posy.xz - disp_negy.xz);
	float J = (1.0 + Dx.x) * (1.0 + Dz.y) - Dx.y * Dz.x;
	// サブサーフェイススケール計算：max(0, (1-J)+Amplitude*(2*Coverage-1));
	float fold = max(1.0 - J, 0);
	{
		// 法線情報をそのまま格納するのではなく二つの微分値を持つ傾きを使う
		vec2 gradient = vec2(-(disp_posx.y-disp_negx.y)
							,-(disp_posy.y-disp_negy.y));
		oColor = vec4(gradient, fold, 0.0);
	}
}
#endif // defined(AGL_FRAGMENT_SHADER)
