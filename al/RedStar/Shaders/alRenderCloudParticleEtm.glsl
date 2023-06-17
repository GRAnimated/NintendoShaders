/**
 *	@file	alRenderCloudParticleEtm.glsl
 *	@author	Matsuda Hirokazu  (C)Nintendo
 *
 *	@brief	パーティクルによる雲のレンダリングに必要な、正規化された最大距離、最小距離を RG16 にレンダリングする
 */
 
#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable // 明示的な場所指定には必要。無いと GPU ハング。
#endif

#include "alCloudParticleUtil.glsl"
#include "alDeclareMdlEnvView.glsl"
#include "alETMUtil.glsl"

#define RENDER_TYPE		(0)
#define RENDER_DIST		(0)
#define RENDER_ETM		(1)

uniform sampler2D uEtmDistTex;

/**
 *	ETM 変換行列
 */
BINDING_UBO_OTHER_SECOND uniform ETMMtxUbo
{
	EtmMtx	uEtmMtx;
};

//------------------------------------------------------------------------------
// 頂点シェーダ
//------------------------------------------------------------------------------
#if defined(AGL_VERTEX_SHADER)

void main()
{
	uint vtx_id = gl_VertexID;
	CloudParticle pt;
	initCloudParticle(pt);
	calcCloudParticleInfo(pt, vtx_id);

	gl_Position = multMtx44Vec3(uEtmMtx.uToETMMtx, pt.local_pos);
	
	// パーティクルの幅から PointSize を求めたい
	gl_PointSize = CalcPointSize(pt);
}

//------------------------------------------------------------------------------
// フラグメントシェーダ
//------------------------------------------------------------------------------
#elif defined(AGL_FRAGMENT_SHADER)

layout(location = 0)	out vec4 oColor;

void main()
{
	float d = gl_FragCoord.z;
	float shape; calcCloudParticleCircle(shape, gl_PointCoord);
	if (shape <= 0) discard;
	// 深さに shape を考慮してみる
//	d = clamp01(d - 0.085*shape);

	#if (RENDER_TYPE == RENDER_DIST)
	{
		// max blend でブレンドしていくので start = 1 - d と逆転して格納しておく
		oColor = vec4(1.0-d, d, 0, shape);
	}
	#elif (RENDER_TYPE == RENDER_ETM)
	{
		vec2 start_end;
		vec2 etm_coord = gl_FragCoord.xy * INV_ETM_TEX_RESO;
		getTraversalStartEnd(start_end, etm_coord.xy, uEtmDistTex);
		
		float x = d;
		d = clamp01(d - start_end.x); // 雲が始まってからの距離
		float d_max = start_end.y;
		x = x*DIST_SCALE + CAM_TO_NEAR_DIST; d *= DIST_SCALE; d_max *= DIST_SCALE;
		calcEtmDctCoefficient(oColor, x, d, d_max, EXTINCTION*shape, uDctWeight);
	}
	#endif // RENDER_TYPE
}

#endif // AGL_FRAGMENT_SHADER
