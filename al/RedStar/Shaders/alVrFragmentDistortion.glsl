/**
 * @file	alVrFragmentDistortion.glsl
 * @author	Matsuda Hirokazu  (C)Nintendo
 *
 * @brief	
 */
#include "alVrDistortionUtil.glsl"
#include "alCalcFullScreenTriangle.glsl"
#include "alDefineVarying.glsl"
#include "alVrRenderLimitUtil.glsl"
 
#define PRIMITIVE_TYPE				(0)
#define PRIMITIVE_TRI_LIST			(0)
#define PRIMITIVE_TRI_FAN			(1)
#define PRIMITIVE_TRI_FULLSCREEN	(2)


#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable // 明示的な場所指定には必要。無いと GPU ハング。
#endif

#define	IS_OCULUS_DISTORTION	(0) // @@ id="cIsOculus" choice="0,1" default="0"

layout(binding = 0)
uniform sampler2D uTexture;

DECLARE_VARYING(vec2,	vTexCoord);

//------------------------------------------------------------------------------
// 頂点シェーダ
//------------------------------------------------------------------------------
#if defined(AGL_VERTEX_SHADER)

layout (location = 0) in vec3 aPosition;	// @@ id="_p0" hint="position0"

void main()
{
	#if (PRIMITIVE_TYPE == PRIMITIVE_TRI_FULLSCREEN)
	{
		CalcFullScreenTriPosUv(gl_Position.xyz, aPosition, getVarying(vTexCoord));
		gl_Position.w = 1.0;
	}
	#else
	{
		int vtx_id = gl_VertexID;
		int poly_num = int(uFarPolyNum.y);
		float far = uFarPolyNum.x;
		#if (PRIMITIVE_TYPE == PRIMITIVE_TRI_LIST)
		{
			calcRenderLimitMeshPositionTriList(gl_Position, poly_num, vtx_id, far);
		}
		#elif (PRIMITIVE_TYPE == PRIMITIVE_TRI_FAN)
		{
			calcRenderLimitMeshPositionTriFan(gl_Position, poly_num, vtx_id, far);
		}
		#endif
		vec2 tex_uv = vec2(gl_Position.xy * 0.5 + 0.5);
		tex_uv.y = 1.0 - tex_uv.y;
		getVarying(vTexCoord).xy = tex_uv;
	}
	#endif
}

//------------------------------------------------------------------------------
// フラグメントシェーダ
//------------------------------------------------------------------------------
#elif defined(AGL_FRAGMENT_SHADER)

out	vec4	oColor;

void main ( void )
{
	vec2 uv_01 = getVarying(vTexCoord);
	float RI = 1.0;
	calcDistortedUv_Fs(RI, uv_01);

#if 0
	// 黒半径の外側を真っ黒ではなく薄くする
	RI = max(0.5, RI); // debug 用に薄くする
#endif

	oColor  = texture(uTexture, uv_01 + UV_OFFSET);
	if (oColor.a == 0.0) discard;
	oColor.rgb /= oColor.a;
	oColor.rgb *= RI;
	
#if 0
	// テクスチャ座標の長さが１以下を黒く、外側を赤く
	float tex_crd_len = length(getVarying(vTexCoord));
	oColor.rgb = (0.999 < tex_crd_len) ? vec3(1.0, 0.0, 0.0) : vec3(0,0,0);
#elif 0
	// イメージサークルの外側を赤くしてデバッグ
	vec2 uv_nrm = getVarying(vTexCoord) * 2.0 - 1.0;
	float len_mm = length(uv_nrm) * IMG_CIRCLE_R_MM;
	oColor.rgb *= (36.050 < len_mm) ? vec3(1.0, 0.0, 0.0) : vec3(1,1,1);
#endif
}

#endif // AGL_FRAGMENT_SHADER
