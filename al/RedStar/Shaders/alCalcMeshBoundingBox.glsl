/**
 * @file	alCalcMeshBoundingBox.glsl
 * @author	Yosuke Mori  (C)Nintendo
 *
 * @brief	メッシュのワールド座標系の描画範囲を求める
 */

#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable // 明示的な場所指定には必要。無いと GPU ハング。
#endif

#include "alMathUtil.glsl"

// バリエーション
#define	CALC_TYPE					(0) // @@ id="cCalcType"
#define CALC_TYPE_MAX				(0)
#define CALC_TYPE_MIN				(1)

layout(std140, binding = 1)
uniform CalcMeshBoundingBox
{
	vec4	uWorldMtx[3];
	vec2	uLocalSize;
};

#if defined( AGL_VERTEX_SHADER )

layout(binding = 2)
uniform sampler2D	cTextureHeightMap;

in vec3 aPosition;
out vec3 vWorldPos;

void main( void )
{
	vec4 pos = vec4(aPosition, 1);

	vec4 pos_w = multMtx34Vec4(uWorldMtx, pos);

	vec2 coord;
	coord.x = (aPosition.x + uLocalSize.x * 0.5)/ uLocalSize.x;
	coord.y = (aPosition.z + uLocalSize.y * 0.5)/ uLocalSize.y;
	pos_w.y += texture(cTextureHeightMap, coord).r;

#if (CALC_TYPE == CALC_TYPE_MAX)
	vWorldPos = pos_w.xyz;
#else
	vWorldPos = -pos_w.xyz;
#endif

	gl_Position.x = 0.0;
	gl_Position.y = 0.0;
	gl_Position.z = 1.0;
	gl_Position.w = 1.0;
}

#elif defined( AGL_FRAGMENT_SHADER )

layout(location = 0) out vec4 oColor;

in vec3 vWorldPos;

void main()
{
	oColor.rgb	= vWorldPos;
}

#endif
