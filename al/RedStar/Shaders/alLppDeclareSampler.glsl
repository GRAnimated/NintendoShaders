/**
 * @file	alLppDeclareSampler.glsl
 * @author	Yosuke Mori  (C)Nintendo
 *
 * @brief	ライトプリパス用サンプラー定義
 */

#define BINDING_SAMPLER_BASECOLOR		layout(binding = 0)
#define BINDING_SAMPLER_NORMAL			layout(binding = 1)
#define BINDING_SAMPLER_LINEAR_DEPTH	layout(binding = 2)
#define BINDING_SAMPLER_PROJ_TEX		layout(binding = 3)
#define BINDING_SAMPLER_SPEC_POW_TABLE	layout(binding = 4)
#define BINDING_SAMPLER_DEPTH_SHADOW	layout(binding = 5)
