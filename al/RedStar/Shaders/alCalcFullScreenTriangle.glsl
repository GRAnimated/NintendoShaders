/**
 * @file	alCalcFullScreenTriangle.glsl
 * @author	Matsuda Hirokazu  (C)Nintendo
 *
 * @brief	全画面を覆うトライアングルを使う
 */

#define	CalcFullScreenTriPos(gl_pos, pos)	{ gl_pos = pos; }
#define	CalcFullScreenTriPosUv(gl_pos, pos, uv)	{ CalcFullScreenTriPos(gl_pos, pos); uv.xy = gl_pos.xy * 0.5 + 0.5; uv.y = 1.0 - uv.y; }
