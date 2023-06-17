/**
 * @file	alCubeMapGenerateMipmapMRT.glsl
 * @author	Yosuke Mori  (C)Nintendo
 *
 * @brief	ミップマップ生成MRT版
 */

#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable
#endif

#include "alMathUtil.glsl"
#include "alCubeMapDrawUtil.glsl"


/**
 *	キューブマップフェッチ Lod 版
 *	dir は左手座標系に。
 */
#define	fetchCubeMapLod(fetch, sampler, dir, bias)										\
{																						\
	(fetch).rgba = textureLod((sampler), vec3((dir).x, (dir).y, -(dir).z), bias).rgba;	\
}


uniform samplerCube	uTexCube;

layout(std140) uniform RefMipLevel
{
	float	uMipLevel;
};

#if defined(AGL_VERTEX_SHADER)

in	vec4	aPosition; // OpenGL 側で vec3 として設定していても .w に 1.0 を入れてくれるらしい
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
out vec4	oColor[6];

void main()
{
	for (int f=0; f<6; ++f)
	{
        fetchCubeMapLod(oColor[f], uTexCube, vRay[f], uMipLevel);
	}
}

#endif
