/**
 * @file	alPointSprite.glsl
 * @author	Matsuda Hirokazu  (C)Nintendo
 *
 * @brief	
 */

#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable // 明示的な場所指定には必要。無いと GPU ハング。
#endif

#include "alMathUtil.glsl"
#include "alDeclareUniformBlockBinding.glsl"
#include "alDeclareMdlEnvView.glsl"
#include "alDefineVarying.glsl"
#include "alDefineSampler.glsl"
#include "alDeclareSampler.glsl"
#include "alHdrUtil.glsl"
#include "alFetchCubeMap.glsl"

#define		DEPTH_TYPE			(0) // @@ id="cDepthType" choice = "0,1" default = "0"
#define		DEPTH_TYPE_POS		(0)
#define		DEPTH_TYPE_BUFFER	(1)

#define		RENDER_TYPE			(0) // @@ id="cRenderType" choice = "0,1" default = "0"
#define		RENDER_HDR			(0)
#define		RENDER_LDR			(1)

#define		IS_COMP_SEL_WORKAROUND	(0) // @@ id="cIsCompSelWorkAround" choice = "0, 1" default = "0"

#define		SCALE_TYPE	(0) // @@ id="cScaleType" choice = "0, 1, 2" default = "0"

uniform sampler2DArray	uTex;
uniform sampler2D		uDepth;


DECLARE_VARYING(vec4,	vColor);
DECLARE_VARYING(vec4,	vData0);
DECLARE_VARYING(vec4,	vData1); // xy : rotate (sin, cos), 
DECLARE_VARYING(vec4,	vData2); // xy : mul add  zw : mul add

#if (RENDER_TYPE == RENDER_HDR)
DECLARE_VARYING(vec4,	vIrradiance);
#endif // RENDER_TYPE


//------------------------------------------------------------------------------
// 頂点シェーダ
//------------------------------------------------------------------------------
#if defined(AGL_VERTEX_SHADER)

// aPosition  xyz : world position,  w : point sprite size
layout (location=0) in vec4 aPosition;	// @@ id="_p0" hint="position0"

// rgba : color
layout (location=1) in vec4 aColor;	// @@ id="_p1" hint="position1"

// x : texture layer, y : rotate radian, z : uv horizon scale, w : uv vertical scale
layout (location=2) in vec4 aData0; // @@ id="_p2" hint="position2"

#define	GetPointSize	aPosition.w

#define GetRotRadian	(aData0.y)
#define GetScaleH		(aData0.z)
#define GetScaleV		(aData0.w)

void main()
{
	getVarying(vColor) = aColor;
	getVarying(vData0) = aData0;
	getVarying(vData1) = vec4(sin(GetRotRadian), cos(GetRotRadian), 0, 0);

	getVarying(vData2).x = (GetScaleH < 0) ? -1 : 1; // mul
	getVarying(vData2).y = (GetScaleH < 0) ?  1 : 0; // add
	getVarying(vData2).z = (GetScaleV < 0) ? -1 : 1; // mul
	getVarying(vData2).w = (GetScaleV < 0) ?  1 : 0; // add

	gl_Position = multMtx44Vec3(cViewProj, aPosition.xyz); // ワールド空間の位置になっている
	float inv_w = 1.0 / gl_Position.w;

	#if (DEPTH_TYPE == DEPTH_TYPE_BUFFER)
	{
		vec2 tex_coord = gl_Position.xy * (inv_w * 0.5) + vec2(0.5); // [0, 1]に変換
		float depth = texture(uDepth, tex_coord).r;
		// デプスバッファの値からデプス値を決定する
		gl_Position.z = -depth;
	}
	#endif // DEPTH_TYPE
	gl_PointSize = GetPointSize * inv_w;

	// カラースケールにイラディアンスを利用する
	#if (RENDER_TYPE == RENDER_HDR) && (SCALE_TYPE == 1)
	{
		vec4 irradiance;
		fetchCubeMapIrradianceScaleConvertHdr(irradiance, cTexCubeMapRoughness, -aPosition.xyz); // 法線はワールド位置の逆方向
		getVarying(vIrradiance) = irradiance;
	}
	#endif // RENDER_TYPE
}

//------------------------------------------------------------------------------
// フラグメントシェーダ
//------------------------------------------------------------------------------
#elif defined(AGL_FRAGMENT_SHADER)

#define SIN_	getVarying(vData1).x
#define COS_	getVarying(vData1).y

#define GetXMul			(getVarying(vData2).x)
#define GetXAdd			(getVarying(vData2).y)
#define GetYMul			(getVarying(vData2).z)
#define GetYAdd			(getVarying(vData2).w)

out vec4 oColor;

void main ( void )
{
    float mid = 0.5;
	vec2 tex_crd_;
	tex_crd_.x = gl_PointCoord.x * GetXMul + GetXAdd;
	tex_crd_.y = gl_PointCoord.y * GetYMul + GetYAdd;
    vec2 tex_crd = vec2(COS_ * (tex_crd_.x - mid) + SIN_ * (tex_crd_.y - mid) + mid,
                        COS_ * (tex_crd_.y - mid) - SIN_ * (tex_crd_.x - mid) + mid);

	#if (IS_COMP_SEL_WORKAROUND == 1)
		oColor = texture(uTex, vec3(tex_crd, getVarying(vData0).x)).rrrg;
	#else
		oColor = texture(uTex, vec3(tex_crd, getVarying(vData0).x));
	#endif // IS_COMP_SEL_WORKAROUND
	oColor *= vColor;

	#if (RENDER_TYPE == RENDER_HDR) && (SCALE_TYPE == 1)
		oColor.rgb *= getVarying(vIrradiance).a;
	#elif (RENDER_TYPE == RENDER_HDR) && (SCALE_TYPE == 2)
		oColor.rgb *= cInvExposure;
	#endif // RENDER_TYPE
}

#endif // AGL_FRAGMENT_SHADER

