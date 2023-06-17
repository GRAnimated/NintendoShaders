/*
 ** @file   cubemap_importance_ggx.sh
 *  @brief  cubemap の重点サンプリングGGX
 *  @author Yosuke Mori, Matsuda Hirokazu
 *  @copyright  (C) Nintendo
 */

#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable
#endif

#define NUM_SAMPLES	(8)		// @@ id="cNumSamples"	choice="8,16,32"	default="8"
#define MAX_SAMPLES	(32)	// @@ id="cMaxSamples"	choice="32"			default="32"
#define USING_HDR_TO_LDR_ENCODE (0) // @@ id="cUsingHdrToLdrEncode" choice="0,1"	default="0"

// agl に持っていくときは関数をコピペしてインクルードを消す
#include "alDeclareUniformBlockBinding.glsl"
#include "alHdrUtil.glsl"
#define IS_USE_TEXTURE_BIAS 0
#include "alFetchCubeMap.glsl"

/**
 *	ローカルのライトベクトルをワールドに変換するマトリックスを求める
 */
void calcTangentToWorldMtx33(out vec3 mtx[3], in vec3 nrm)
{
	vec3 tangent_y = abs(nrm.z) < 0.999 ? vec3(0,0,1) : vec3(1,0,0);
	vec3 tangent_x = normalize(cross(tangent_y, nrm));
	tangent_y = cross(nrm, tangent_x);
	// もしかしたら転置が必要かも
	// mtx[0] = tangent_x;
	// mtx[1] = tangent_y;
	// mtx[2] = nrm;

	mtx[0] = vec3(tangent_x.x, tangent_y.x, nrm.x);
	mtx[1] = vec3(tangent_x.y, tangent_y.y, nrm.y);
	mtx[2] = vec3(tangent_x.z, tangent_y.z, nrm.z);
}

#include "alMathUtil.glsl"
#include "alCubeMapDrawUtil.glsl"

layout(std140) uniform Samples
{
	float	uInvTotalWeight;
	vec3	uSampleDir[MAX_SAMPLES];
	float	uMipLevel[MAX_SAMPLES];
	float	uWeight[MAX_SAMPLES];
};

uniform samplerCube	uTexCube;

#if defined(AGL_VERTEX_SHADER)

in	vec4	aPosition;
out	vec3	vRay[6];

void main()
{
	// フルスクリーン三角形の描画
	gl_Position.xy = aPosition.xy * 2;
	gl_Position.z = 1.0;
	gl_Position.w = 1.0;

	vec4 pos = vec4(gl_Position.xy, 1.0, 1.0);
	vRay[0] = multMtx44Vec4( uProjViewInvPosX, pos ).xyz;
	vRay[1] = multMtx44Vec4( uProjViewInvNegX, pos ).xyz;
	vRay[2] = multMtx44Vec4( uProjViewInvPosY, pos ).xyz;
	vRay[3] = multMtx44Vec4( uProjViewInvNegY, pos ).xyz;
	vRay[4] = multMtx44Vec4( uProjViewInvPosZ, pos ).xyz;
	vRay[5] = multMtx44Vec4( uProjViewInvNegZ, pos ).xyz;
}

#elif defined(AGL_FRAGMENT_SHADER)

in	vec3	vRay[6];
out	vec4	oColor[6];

void main()
{
	for (int f=0; f<6; ++f)
	{
		vec3 tangent_to_world[3];
		calcTangentToWorldMtx33(tangent_to_world, vRay[f]);	//頂点シェーダに持ってくる検討

		vec3 color = vec3(0.0);
		for (int i=0; i<NUM_SAMPLES; ++i)
		{
			vec3 light = rotMtx33Vec3(tangent_to_world, uSampleDir[i].xyz);
			#if (USING_HDR_TO_LDR_ENCODE == 1)
			{
				vec4 fetch = vec4(0.0);
				fetchCubeMapConvertHdr(fetch, uTexCube, light, uMipLevel[i]);
				color += fetch.rgb * uWeight[i];
			}
			#else
			{
				vec3 fetch;
				fetchCubeMapLod(fetch, uTexCube, light, uMipLevel[i]);
				color += fetch * uWeight[i];
			}
			#endif // USING_HDR_TO_LDR_ENCODE
		}
		// アルファに輝度を入れる対応
		#if (USING_HDR_TO_LDR_ENCODE == 1)
		{
			vec3 hdr = color.rgb * uInvTotalWeight;
			CalcHdrToLdr(oColor[f], hdr);
		}
		#else
		{
			oColor[f].rgb = color.rgb * uInvTotalWeight;
		}
		#endif // USING_HDR_TO_LDR_ENCODE
	}
}

#endif
