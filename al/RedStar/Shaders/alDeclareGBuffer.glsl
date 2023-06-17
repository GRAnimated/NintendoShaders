/**
 * @file	alDeclareGBuffer.glsl
 * @author	Yosuke Mori  (C)Nintendo
 *
 * @brief	Gバッファの定義
 */

#ifndef DECLARE_GBUFFER_GLSL
#define DECLARE_GBUFFER_GLSL

#if defined(AGL_FRAGMENT_SHADER)

// 出力変数
layout(location = 0)	out vec4 oLightBuf;
layout(location = 1)	out vec4 oWorldNrm;
layout(location = 2)	out vec4 oNormalizedLinearDepth;
layout(location = 3)	out vec4 oBaseColor;
layout(location = 4)	out vec4 oMotionVec;

#endif // defined(AGL_FRAGMENT_SHADER)

#endif // DECLARE_GBUFFER_GLSL
