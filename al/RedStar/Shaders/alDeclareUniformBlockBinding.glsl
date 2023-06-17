/**
 * @file	alDeclareUniformBlockBinding.glsl
 * @author	Yosuke Mori  (C)Nintendo
 *
 * @brief	ユニフォームブロック定義
 */

#ifndef AL_DECLARE_UNIFORM_BLOCK_BINDING
#define AL_DECLARE_UNIFORM_BLOCK_BINDING

#define	BINDING_UBO_MDL_ENV_VIEW			layout(std140, binding = 1)
#define	BINDING_UBO_MAT						layout(std140, binding = 2)
#define	BINDING_UBO_MDL_MTX					layout(std140, binding = 3)
#define	BINDING_UBO_SHP						layout(std140, binding = 4)
#define	BINDING_UBO_MIRROR					layout(std140, binding = 5)
#define	BINDING_UBO_MODEL_ADDITIONAL_INFO	layout(std140, binding = 6)
#define	BINDING_UBO_PREV_SHP				layout(std140, binding = 11)
#define	BINDING_UBO_PREV_MDL_MTX			layout(std140, binding = 12)

// シャドウマトリックス
#define	BINDING_UBO_DEPTH_SHADOW			layout(std140, binding = 8)

// HDR情報とライト情報
#define BINDING_UBO_HDR_TRANSLATE			layout(std140, binding = 7)
#define BINDING_UBO_LIGHT_ENV				layout(std140, binding = 13)

// 独自描画などで UBO を使う場合は以下の数字から設定してください
#define BINDING_UBO_OTHER_FIRST				layout(std140, binding = 9)
#define BINDING_UBO_OTHER_SECOND			layout(std140, binding = 10)
#define BINDING_UBO_OTHER_THIRD				layout(std140, binding = 11)

#if defined( AGL_TARGET_GX2 )
#define BINDING_UBO_SHADER_OPTION			layout(std140, binding = 14)
#else
#define BINDING_UBO_SHADER_OPTION			layout(std140)
#endif

#endif //AL_DECLARE_UNIFORM_BLOCK_BINDING
