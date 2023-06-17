/**
 * @file	alVrDepthMask.glsl
 * @author	Matsuda Hirokazu  (C)Nintendo
 *
 * @brief	視界外を描画しないためのデプスマスク。Near でクリアしてこのメッシュで Far にする。
 */

#define PRIMITIVE_TYPE		(0)
#define PRIMITIVE_TRI_LIST	(0)
#define PRIMITIVE_TRI_FAN	(1)

#include "alVrRenderLimitUtil.glsl"

//------------------------------------------------------------------------------
// 頂点シェーダ
//------------------------------------------------------------------------------
#if defined(AGL_VERTEX_SHADER)

layout(std140) uniform VrDepthMaskUbo
{
	vec4	uFarPolyNum;	// x : far, y : poly num (float)
};

void main()
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
}

//------------------------------------------------------------------------------
// フラグメントシェーダ
//------------------------------------------------------------------------------
#elif defined(AGL_FRAGMENT_SHADER)
out	vec4	oColor;

void main ( void )
{
	oColor = vec4(1.0);
}

#endif // AGL_FRAGMENT_SHADER
