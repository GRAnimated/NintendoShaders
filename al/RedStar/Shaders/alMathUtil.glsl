/**
 * @file	alMathUtil.glsl
 * @author	Yosuke Mori  (C)Nintendo
 *
 * @brief	数学関数ユーティリティ
 */

#ifndef MATH_UTIL_GLSL
#define MATH_UTIL_GLSL

const float PI = 3.1415926535897932384626433832795;
const float INV_PI = 1.0/PI;
const float INV_9PI = 1.0/(9*PI); // Blinn-Phong の正規化で使う
const float EULERS_NUMBER = 2.71828182845904;

#define clamp01(val)	clamp((val), 0.0, 1.0)

//------------------------------------------------------------------------------
// luminance
//------------------------------------------------------------------------------
#define calcLuminance( rgb )  dot( rgb, vec3( 0.298912, 0.586611, 0.114478 ) ) // 0.3086, 0.6094, 0.0820

// スカラー分解の内積計算
#define dot2(a, b)	((a).x * (b).x + (a).y * (b).y)
#define dot3(a, b)	(dot2((a), (b)) + (a).z * (b).z)
#define dot4(a, b)	(dot3((a), (b)) + (a).w * (b).w)
// 平行移動変換を見越す
#define calcDotVec4Vec3One(a, b)	(dot3((a), (b)) + (a).w)
#define calcDotVec4Vec3Zero(a, b)	(dot3((a), (b)))

/**
 *	ALU の詰まり具合の調整用に、ビルトインバージョン、展開バージョンの２パターンを用意
 *	E = expand, B = builtin
 */
#define DOT_E(a, b)		dot3(a, b)
#define DOT2_E(a, b)	dot2(a, b)
#define DOT4_E(a, b)	dot4(a, b)
#define DOT_B(a, b)		dot(a, b)

//@note NXではブレンダーが加算時のオーバフローを丸めてくれないため出力をクランプする(2048は適当)
#define CLAMP_LIGHTBUF(out_color, in_color) 	\
{												\
	out_color = clamp(in_color, 0.0, 2048.0);	\
}

/**
 *	normalize()を使うよりinversesqrtと掛け算に分解した方が速い。
 *	こともある・・・
 */
#define normalizeVec3(ret, vec, b_e)					\
{														\
	float inv_len = inversesqrt(DOT_##b_e(vec, vec));	\
	ret = vec * inv_len;								\
}

#define NORMALIZE_EB(ret, vec)	normalizeVec3(ret, vec, B)
#define NORMALIZE_EE(ret, vec)	normalizeVec3(ret, vec, EULERS_NUMBER)
#define NORMALIZE_B(ret, vec) { ret = normalize(vec); }

vec4 multMtx44Vec4( vec4 mtx[4], vec4 v )
{
	vec4 ret;
	ret.x = dot( mtx[0], v );
	ret.y = dot( mtx[1], v );
	ret.z = dot( mtx[2], v );
	ret.w = dot( mtx[3], v );
	return ret;
}

vec4 multMtx44Vec3( vec4 mtx[4], vec3 v )
{
	vec4 ret;
	ret.x = calcDotVec4Vec3One( mtx[0], v );
	ret.y = calcDotVec4Vec3One( mtx[1], v );
	ret.z = calcDotVec4Vec3One( mtx[2], v );
	ret.w = calcDotVec4Vec3One( mtx[3], v );
	return ret;
}

vec4 multMtx34Vec4( vec4 mtx[3], vec4 v )
{
	vec4 ret;
	ret.x = dot( mtx[0], v );
	ret.y = dot( mtx[1], v );
	ret.z = dot( mtx[2], v );
	ret.w = 1.0;
	return ret;
}

vec3 multMtx34Vec3( vec4 mtx[3], vec3 v )
{
	vec3 ret;
	ret.x = calcDotVec4Vec3One( mtx[0], v );
	ret.y = calcDotVec4Vec3One( mtx[1], v );
	ret.z = calcDotVec4Vec3One( mtx[2], v );
	return ret;
}

vec3 rotMtx34Vec3( vec4 mtx[3], vec3 v )
{
	vec3 ret;
	ret.x = dot3( mtx[0], v );
	ret.y = dot3( mtx[1], v );
	ret.z = dot3( mtx[2], v );
	return ret;
}

vec3 rotMtx33Vec3(in vec4 mtx[3], in vec3 v)
{
	vec3 ret;
	ret.x = dot3(mtx[0], v);
	ret.y = dot3(mtx[1], v);
	ret.z = dot3(mtx[2], v);
	return ret;
}

vec3 rotMtx33Vec3(in vec3 mtx[3], in vec3 v)
{
	vec3 ret;
	ret.x = dot3(mtx[0], v);
	ret.y = dot3(mtx[1], v);
	ret.z = dot3(mtx[2], v);
	return ret;
}

vec2 multMtx23Vec2( vec3 mtx[2], vec2 v )
{
	vec2 ret;
	ret.x = dot( mtx[0].xy, v ) + mtx[0].z;
	ret.y = dot( mtx[1].xy, v ) + mtx[1].z;
	return ret;
}

vec2 multMtx24Vec2( vec4 mtx[2], vec2 v )
{
	return vec2(mtx[0].xy * v.x + mtx[0].zw * v.y + mtx[1].xy);
}

//
// 法線マップからローカルな座標系上の法線ベクトルの成分を取得
//
vec3 calcMapNormal( in sampler2D sampler, in vec2 uv )
{
	// todo mapnrmの計算は1度だけにする
	vec3 mapnrm;
	mapnrm.xy = texture( sampler, uv ).rg;
	mapnrm.z = sqrt( 1.0 - min( dot( mapnrm.xy, mapnrm.xy ), 1.0 ) );
	mapnrm = normalize( mapnrm );
	return mapnrm;
}

//
// 法線マップの計算
//
void calcNormalView( inout vec3 normal, in vec3 mapnrm, in vec3 xaxis, in vec3 yaxis, in vec3 zaxis )
{
	normal.x = xaxis.x*mapnrm.x + yaxis.x*mapnrm.y + zaxis.x*mapnrm.z;
	normal.y = xaxis.y*mapnrm.x + yaxis.y*mapnrm.y + zaxis.y*mapnrm.z;
	normal.z = xaxis.z*mapnrm.x + yaxis.z*mapnrm.y + zaxis.z*mapnrm.z;
}

//
//	外積の計算
//
vec3 calcCrossVec3( in vec3 src, in vec3 dst )
{
	vec3 cross;
	cross.x = src.y*dst.z - src.z*dst.y;
	cross.y = src.z*dst.x - src.x*dst.z;
	cross.z = src.x*dst.y - src.y*dst.x;
	return cross;
}

/**
 *	カラーに対する閾値処理
 */
vec3 checkThresholdColorSimple(in vec3 color, in float threshold)
{
	const vec3 coef = vec3(0.33, 0.33, 0.34);
	float intensity = dot(color, coef);
	float stp = step(threshold, intensity);
	return (color - vec3(threshold)) * stp;
}

/**
 *	Schlick の位相関数
 */
float calcPhaseFunctionSchlick(in float k, in float cos)
{
	float tmp = 1 - k * cos; // Jensen 本だと逆。k>0 で前方散乱にしたい
	return (1-k*k)/(4*PI*tmp*tmp);
}

/**
 *	前方散乱と後方散乱を混ぜる
 */
float calcScatterPhaseFunctionSchlick(in float kf, in float kb, in float fb_rate, in float cos)
{
	float fs = calcPhaseFunctionSchlick(kf, cos);
	float bs = calcPhaseFunctionSchlick(-kb, cos);

	return mix(fs, bs, fb_rate);
}

/**
 *	二つの複素数の乗算
 */
vec2 multiplyComplex(in vec2 a, in vec2 b)
{
	return vec2(a[0]*b[0] - a[1]*b[1], a[1]*b[0] + a[0]*b[1]);
}
vec2 multiplyByI(in vec2 z) { return vec2(-z[1], z[0]); }


// 共役
vec4 QConjugate( vec4 quat )
{	
	return vec4( -quat.xyz, quat.w );	
}


// 積（quaternion × quaternion）
vec4 QMul( vec4 q1, vec4 q2 )
{
	return vec4( + q1.x*q2.w + q1.y*q2.z - q1.z*q2.y + q1.w*q2.x,
				 - q1.x*q2.z + q1.y*q2.w + q1.z*q2.x + q1.w*q2.y,
				 + q1.x*q2.y - q1.y*q2.x + q1.z*q2.w + q1.w*q2.z,
				 - q1.x*q2.x - q1.y*q2.y - q1.z*q2.z + q1.w*q2.w );
}

// 積（vector × quaternion）
vec4 QMul( vec3 v, vec4 q )
{
	return vec4( + v.x*q.w + v.y*q.z - v.z*q.y,
				 - v.x*q.z + v.y*q.w + v.z*q.x,
				 + v.x*q.y - v.y*q.x + v.z*q.w,
				 - v.x*q.x - v.y*q.y - v.z*q.z );
}

// 積（quaternion × vector）
vec4 QMul( vec4 q, vec3 v )
{
	return vec4(           + q.y*v.z - q.z*v.y + q.w*v.x,
				 - q.x*v.z           + q.z*v.x + q.w*v.y,
				 + q.x*v.y - q.y*v.x           + q.w*v.z,
				 - q.x*v.x - q.y*v.y - q.z*v.z             );
}

// 積（quaternion × quaternion）
// 戻り値を vector に限定
vec3 QMulRetV( vec4 q1, vec4 q2 )
{
	return vec3( + q1.x*q2.w + q1.y*q2.z - q1.z*q2.y + q1.w*q2.x,
				 - q1.x*q2.z + q1.y*q2.w + q1.z*q2.x + q1.w*q2.y,
				 + q1.x*q2.y - q1.y*q2.x + q1.z*q2.w + q1.w*q2.z );
}

// 回転
vec3 QRotVec( vec3 vec, vec4 rot_q )
{	
	return QMulRetV( QMul(rot_q, vec), QConjugate(rot_q) );	
}


// Quaternion -> Mattrix
void QtoM( out vec3 mat[3], vec4 q )
{
	float wx, wy, wz, xx, xy, xz, yy, yz, zz;

	wx = q.w*q.x;  wy = q.w*q.y; wz = q.w*q.z;
	xx = q.x*q.x;  xy = q.x*q.y; xz = q.x*q.z;
	yy = q.y*q.y;  yz = q.y*q.z; zz = q.z*q.z;

	mat[0].x = 2.0 * (0.5 - (yy+zz));	mat[1].x = 2.0 * (xy + wz);			mat[2].x = 2.0 * (xz - wy);
	mat[0].y = 2.0 * (xy - wz);			mat[1].y = 2.0 * (0.5 - (xx+zz));	mat[2].y = 2.0 * (yz + wx);
	mat[0].z = 2.0 * (xz + wy);			mat[1].z = 2.0 * (yz - wx);			mat[2].z = 2.0 * (0.5 - (xx+yy));
}


/**
 *	32ビットをビット単位でリバースする。
 *	ABCD EFGH IJKL MNOP QRST UVWX YZ01 2345 -> 5432 10ZY TSRQ PONM LKJI HGFE DCBA
 */
uint reverseBit32(in uint v)
{
	uint x;
	x = (v & 0x55555555)<<1 | (v & 0xaaaaaaaa)>>1;
	x = (x & 0x33333333)<<2 | (x & 0xcccccccc)>>2;
	x = (x & 0x0f0f0f0f)<<4 | (x & 0xf0f0f0f0)>>4;
	x = (x & 0x00ff00ff)<<8 | (x & 0xff00ff00)>>8;
	x = (x & 0x0000ffff)<<16| (x & 0xffff0000)>>16;
	return x;
}

/**
 *	32ビットの 1 を数え上げる
 */
uint countBit32(in uint x)
{
	x = x - ((x >> 1) & 0x55555555);
	x = (x & 0x33333333) + ((x >> 2) & 0x33333333);
	x = (x + (x >> 4)) & 0x0F0F0F0F;
	x = x + (x >> 8);
	x = x + (x >> 16);
	return x & 0x0000003F;
}

/**
 *	Van der Corput 列
 *	u32 ビット列から [0, 1] の浮動小数値を求める
 */
float calcVanDerCorput(in uint bits)
{
	uint rev = reverseBit32(bits);
	return float(rev)* 2.3283064365386963e-10; //   / (0xFFFFFFFF + 0x01)
}

/**
 *	Van der Corput 列を利用した二次元の点 Hammersley Point を求める
 */
void calcHammersleyPoint(out vec2 vec, in uint i, in uint num)
{
//	alAssertMsg(i <= num, "i(%d) <= num(%d)", i, num);
	vec = vec2(float(i) / float(num), calcVanDerCorput(i));
}

/**
 *	単位球の表面の点をピックする
 *	uniform1, uniform2  は [0, 1] の範囲で一様分布する値
 */
void calcSpherePointPicking(out vec3 ret, in float uniform1, in float uniform2)
{
	// u は [-1, 1], θ は [0, 2π)
	float u = uniform1*2 - 1.0;
	float theta = uniform2 * PI * 2;
	float sqrt_one_minus_u2 = sqrt(1-u*u);
	ret.x = sqrt_one_minus_u2 * cos(theta);
	ret.y = sqrt_one_minus_u2 * sin(theta);
	ret.z = u;
}

#endif // MATH_UTIL_GLSL
