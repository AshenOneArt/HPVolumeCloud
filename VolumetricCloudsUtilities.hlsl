#ifndef VOLUMETRIC_CLOUD_UTILITIES_H
#define VOLUMETRIC_CLOUD_UTILITIES_H

#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Lighting/VolumetricLighting/VolumetricCloudsDef.cs.hlsl"

// The number of octaves for the multi-scattering
#define NUM_MULTI_SCATTERING_OCTAVES 3
#define PHASE_FUNCTION_STRUCTURE float3
// Density blow wich we consider the density is zero (optimization reasons)
#define CLOUD_DENSITY_TRESHOLD 0.1f
// 高空云（Ac/As）独立密度阈值：薄云密度更低，使用更小的阈值保留细节
#define HI_CLOUD_DENSITY_THRESHOLD 0.001f
// Forward/Backward eccentricity are now driven by _HP_ForwardEccentricity / _HP_BackwardEccentricity
// (set via HPVolumeCloudRenderDriver Inspector). Fallback defaults kept as comments:
//   FORWARD_ECCENTRICITY  was 0.7  → now Inspector default 0.85
//   BACKWARD_ECCENTRICITY was 0.7  → now Inspector default 0.3
// Maximal distance until which the "skybox"
#define MAX_SKYBOX_VOLUMETRIC_CLOUDS_DISTANCE 200000.0f

// Just define a flag when the other is not defined as it is easier for the logic
#if !defined(LOCAL_VOLUMETRIC_CLOUDS)
    #define DISTANT_VOLUMETRIC_CLOUDS
#endif

// Cloud description tables
Texture2D<float4> _CloudMapTexture;
Texture2D<float3> _CloudLutTexture;

// HanPi 天气图：Mirror 寻址，使世界 XZ 超出单张图范围时对称平铺而非 repeat 跳变
SamplerState s_linear_mirror_sampler
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = Mirror;
    AddressV = Mirror;
};

// Noise textures for adding details
// Declared as float4 to support HanPi multi-channel noise textures (RGBA).
Texture3D<float4> _Worley128RGBA;
Texture3D<float4> _ErosionNoise;

// ── HanPi VolumeCloud custom parameters ─────────────────────────────────────
// Injected each frame by HPCloudRenderCallbacks.BindCloudCustomParams.
// Base noise channels: R=PerlinWorley, G=Worley (same layout as _CloudNoiseTex)
// Weather map layout:
//   Lo (_CloudMapTexture)  : R=LoCoverage  G=CloudType(Cu/Tcu/Cb)  B=ScMask  A=reserved
//   Hi (_CloudMapHiTexture): R=HiMask      G=HiType(As/Ac)         B=0       A=0
// Profile LUT layout: UV=(normalizedHeight, radialDist), RGB=(Cu, Tcu, Cb)
Texture2D<float4> _CloudMapHiTexture;

// Detail blend weights per cloud type
float _HP_BillowyLowStr;
float _HP_BillowyHighStr;
float _HP_WispyLowStr;
float _HP_WispyHighStr;

// Per-type detail erosion strength
float _HP_DetailStrengthCu;
float _HP_DetailStrengthTcu;
float _HP_DetailStrengthCb;

// Density thresholding
float _HP_DensityThreshold;
float _HP_DensityMultiplier;
// 各云类型的独立密度倍率（在全局 _HP_DensityMultiplier 之前乘入低云 base_cloud）。
// Cu=积云（对流旺盛、密度高），Tcu=塔状积云（过渡），Cb=积雨云（最厚最密）。
// 范围建议 0.5~3.0，默认 1.0（等价于不分类型）。
float _HP_DensityMultiplierCu;
float _HP_DensityMultiplierTcu;
float _HP_DensityMultiplierCb;
// 云边缘柔化
float _HP_CloudEdgeSoftnessTop;       // 顶/侧柔化倍率（直接缩放 1-heightGradient，1=原始密度反向）
float _HP_CloudEdgeSoftnessBottom;    // 底部独立柔化宽度（height=0 处取到此值）
float _HP_CloudEdgeSoftnessBottomPow; // 底部衰减指数：>1 快速收窄到底部（推荐 2~6）
// 云底 3D 噪声淡出：局部高度 localHeight 接近 0 时 baseShape→1、detail→0，云底 XZ 密度均匀。
// _HP_BottomSmoothHeight : 淡出区间（归一化局部高度 0~1），0=禁用
// _HP_BottomSmoothPow    : 淡出曲线指数，>1=底部平坦区更长
float _HP_BottomSmoothHeight;
float _HP_BottomSmoothPow;

// Noise sampling
float3 _HP_NoiseScale;
float3 _HP_NoiseOffset;
float  _HP_DetailNoiseScale;
float  _HP_DetailNoiseSpeed;

// 噪声风偏移：由 HPVolumeCloudRenderDriver 每帧从 HPWindField.WindUVOffset × WorldSize 计算后注入。
// 单位：世界坐标米（XZ 累积偏移），各噪声层再乘自身分速度系数。
// _HP_BaseNoiseWindSpeed  : base shape 噪声的风速倍率，1.0=与天气图同速，默认 1.0
// _HP_DetailNoiseWindSpeed       : detail 侵蚀噪声的水平风速倍率，通常略快，默认 1.5
// _HP_DetailNoiseVerticalWindSpeed: detail 竖直速度（UV/秒）= 倍率 × 风场中心风速向量长度，由 C# 预乘后注入
float2 _HP_NoiseWindOffset;
float  _HP_BaseNoiseWindSpeed;
float  _HP_DetailNoiseWindSpeed;
float  _HP_DetailNoiseVerticalWindSpeed;

// Wispy/Billowy edge blend widths
float _HP_WispyEdgeWidth;
float _HP_WispyReach;
// Wispy 高度范围限制：wispy 仅存在于 _HP_WispyTopHeight 以下，超过后以幂函数柔和衰减至 0。
// PositivePow(1-t, Hardness)，无 smoothstep 硬边。
// _HP_WispyTopHeight    : wispy 衰减起始归一化高度（0~1），低于此值全量保留。
// _HP_WispyTopHardness  : 衰减曲线指数（>1=长尾柔和，1=线性，<1=底部快速衰减）。推荐 1~4。
float _HP_WispyTopHeight;
float _HP_WispyTopHardness;

// World-space weather map parameters
float2 _HP_WeatherMapCenter;
float  _HP_WeatherMapWorldSize;

float2 HP_ComputeWeatherMapUV(float2 worldXZ)
{
    return (worldXZ - _HP_WeatherMapCenter) / max(_HP_WeatherMapWorldSize, 0.01) + 0.5;
}

bool HP_IsInsideWeatherMapUV(float2 weatherUV)
{
    return weatherUV.x >= 0.0 && weatherUV.x <= 1.0
        && weatherUV.y >= 0.0 && weatherUV.y <= 1.0;
}

// ── 层积云（Sc）参数 ───────────────────────────────────────────────────────────
// _HP_ScCellNoiseTex：预烘焙可 tiling Worley/细胞噪声（R 通道，中心亮=1，边界暗=0）。
TEXTURE2D(_HP_ScCellNoiseTex);
float2 _HP_ScCellScale;        // 细胞纹理 UV 缩放（XZ 独立，越大格子越小）
float  _HP_ScWorleyStrength;   // Sc 整体权重：>0 激活，1=完全层积云（不依赖 GlobalCoverage 渐入渐出）
// _HP_ScWorleyInStart / _HP_ScWorleyInEnd 已删除（不再用 GlobalCoverage 控制渐入渐出）
// _HP_ScWorleyOutStart / _HP_ScWorleyOutEnd / _HP_StThickness 已删除（层云逻辑移除）
float  _HP_ScHeightScale;      // Sc 层高度压缩比：积云廓形被压进 slab 底部此比例范围（0.05=极薄，0.5=半高）
float  _HP_ScDetailStr;        // Sc 独立侵蚀强度（替换 cloudType 驱动的 detailStrength）
float  _HP_ScCellThickPow;     // cell pow 曲线（>1=中心更厚，边界更薄；推荐 1~3）
float  _HP_ScCellThickStr;     // cell 调制密度/厚度强度（0=忽略 cell，1=完全跟随 cell）
float  _HP_ScCellNoiseStr;     // cell 噪声采样强度（采样值 × 此倍率后 saturate，>1 增强对比）
float  _HP_ScCovIntensity;     // Sc 专用 coverage 强度倍率（独立于低云全局路径）：1=不变，>1 提亮
float  _HP_ScCovContrast;      // Sc 专用 coverage 对比度（pow 曲线）：1=线性，>1 增对比
// _HP_ScCellBottomAmp 已删除（底部由 ScBottomCovScale + coverage 统一驱动）

// ── 低云运行时 Coverage 调整（从 WeatherMap 烘焙侧移过来，拆为 Cover/Height 两套）──
// Cover 套（影响密度阈值）：pow 对比度 + 强度倍率，对 weather.r 在用于 threshold 之前调整。
float _HP_LoCovCoverIntensity;  // 密度路径强度倍率：1=不变，>1 提亮，<1 压暗
float _HP_LoCovCoverContrast;   // 密度路径对比度（pow 曲线）：1=线性，>1 增对比
// Height 套（影响 coverage 驱动云顶高度）：独立调整，不影响密度计算。
float _HP_LoCovHeightIntensity; // 高度路径强度倍率
float _HP_LoCovHeightContrast;  // 高度路径对比度（pow 曲线）

// ── 低云覆盖率→云顶高度拉伸（只加不减）────────────────────────────────────
// coverage 驱动 LUT 高度压缩：heightForLUT = h / scale，scale ∈ [1, LoCoverTopMax]。
// coverage=0 → scale=1（无变化）；coverage=1 → scale=LoCoverTopMax（云体向上拉伸）。
float _HP_LoCoverTopStr;       // 效果强度：0=禁用，1=完全启用
// float _HP_LoCoverTopMin;    // 已废弃（原"截断底部"，压缩方案不需要）
float _HP_LoCoverTopMax;       // 高度压缩最大倍率：coverage=1 时 scale=此值（≥1.0，建议 1.2~3.0）
float _HP_LoCoverTopCurvePow;  // pow 曲线：<1=低 cover 已有变化，>1=需高 cover 才明显，1=线性
// float _HP_LoCoverTopSoft;   // 已废弃（原"截断边缘软度"，压缩方案不需要）

// ── 高空云（高积云 Ac / 高层云 As）参数 ──────────────────────────────────────
TEXTURE2D(_HP_HiCellNoiseTex);  // 高空云专用细胞噪声（独立于低云 ScCellNoiseTex）
TEXTURE2D(_HP_HiCellWarpTex);  // cell noise UV 扰动纹理（RG 双通道，采样前 warp UV）
TEXTURE2D(_HP_HiWispTex);      // 高空云云絮纹理（R 通道，留空则回退至 ScCellNoiseTex）
float2 _HP_HiCellScale;         // UV 缩放（Ac 格子通常比 Sc 大，建议 2~6）
float  _HP_HiCellWindSpeed;     // cell 噪声 UV 漂移倍率（相对风场），建议 1~3
float2 _HP_HiCellWarpScale;    // warp 纹理 UV 缩放，建议比 cell scale 小 2~4 倍
float  _HP_HiCellWarpStr;      // warp 强度（UV 空间位移量），建议 0.05~0.3
float  _HP_HiCellThickStr;      // 积云（Ac，G=1）cell 厚度/密度调制强度
float  _HP_HiAsCellThickStr;    // 层云（As，G=0）cell 厚度/密度调制强度（独立于 Ac）
float  _HP_HiCellThickPow;     // 厚度调制 pow 曲线（>1=中心更厚边缘更薄）
float  _HP_HiCloudBottom;       // 高度带底部基准（归一化，0=slab底，1=slab顶）
float  _HP_HiCloudTop;          // 高积云（Ac）高度带顶部（归一化）
float  _HP_HiBottomCovScale;    // 底部随 cover 下降幅度（相对 top-bottom 范围的比例）；0=固定，1=与顶部等幅
float  _HP_HiHeightCurvePow;    // cover→高度响应曲线指数（<1=低覆盖迅速升高，>1=高覆盖才明显）
float  _HP_HiDensityThreshold;  // 密度阈值：cover 低于此值时密度为 0
float  _HP_HiDensitySoftness;   // 阈值过渡宽度（softness）
float  _HP_HiCloudSoft;         // 高度带上下边缘 smoothstep 扩展宽度
float2 _HP_HiWispScale;         // 云絮噪声 UV 缩放
float  _HP_HiWispStrength;      // 云絮叠加强度
float  _HP_HiHorizonDistStart;  // 远处压低渐 START（米，相机 XZ 水平距）
float  _HP_HiHorizonDistEnd;    // 远处压低渐 END（米，满强度时云底降至 height=0）
// 高空云独立密度倍率（与低云 _HP_DensityMultiplier 完全解耦）。薄云建议 0.2~1.5，默认 1.0。
float  _HP_DensityMultiplierHi;

// Cloud slab world Y bounds (used to compute normalized height h)
float _HP_CloudSlabBottom;
float _HP_CloudSlabTop;

// ── 低密度散射门控 ────────────────────────────────────────────────────────────
// 稀薄边缘不具备足够光学厚度建立完整散射；此项按密度缩短散射积分的有效步长。
// _HP_DensityScatterGateThresh : 门控生效的密度上界（0~1），密度低于此值时散射步长打折
// _HP_DensityScatterGatePow    : 门控曲线指数（>1 更硬截止，1=线性，<1 更软）
float _HP_DensityScatterGateThresh;
float _HP_DensityScatterGatePow;

// HP_DENSITY_SCATTER_GATE(d, thresh, power)
// 密度→有效散射步长比例的非线性映射：
//   d      : 当前采样点密度（cloudProperties.density）
//   thresh : 密度阈值（_HP_DensityScatterGateThresh），低于此值映射结果 < 1
//   power  : 曲线指数（_HP_DensityScatterGatePow），>1 截止更硬（边缘衰减更快），1 = 线性
// 返回 [0, 1]，高密度内部趋近 1（全步长），低密度边缘趋近 0（有效步长缩短）。
#define HP_DENSITY_SCATTER_GATE(d, thresh, power) \
    PositivePow(saturate((d) / max((thresh), 0.001)), max((power), 0.01))

// ── 独立吸收系数 ──────────────────────────────────────────────────────────────
// _HP_LightAbsorption : 光线（太阳→采样点）方向的吸收倍率，控制自阴影强度。
//                       越大暗部越暗，真实感越强。建议 0.5~3.0，默认 1.0
// _HP_ViewAbsorption  : 视线方向的吸收倍率，独立控制云的不透明厚实感。
//                       越大云越实越厚，建议 0.5~2.0，默认 1.0
float _HP_LightAbsorption;
float _HP_ViewAbsorption;

// ── 光照质量参数（Inspector 可调） ────────────────────────────────────────────
// 前向散射偏心率：越高云边向阳面越亮（银边效果）。推荐范围 0.5~0.95，默认 0.85
float _HP_ForwardEccentricity;
// 后向散射偏心率：控制背光面散射晕。推荐范围 0.0~0.7，默认 0.3
float _HP_BackwardEccentricity;
// 云顶环境光倍增：补偿多重散射导致云顶偏白。推荐范围 1.0~4.0，默认 1.5
float _HP_AmbientTopMultiplier;
// 云底环境光倍增：独立控制云底漫射亮度。>1 提亮，<1 压暗（减少过灰的底面）。建议 0.2~1.5
float _HP_AmbientBottomMultiplier;
// 向上透射率 AO 强度：用太阳光路 lightExtinctionOD × sin(仰角) 估算竖直方向遮蔽透射率。
// upwardAO = exp(-lightExtinctionOD × sin(elev) × AOUpwardScale)
// 0=禁用（AO=1 全亮）；1=物理值；>1 加强遮蔽（补偿低仰角路径偏长的误差）。建议 0.5~2.0。
float _HP_AOUpwardScale;
// 多重散射三参数（Hillaire 2020 拆分方案）
// 将原 _MultiScattering 单参数拆为三个独立维度，可分别调节穿透/亮度/各向异性：
// _HP_MS_Attenuation : 消光衰减率（per octave）——越小高阶 MS 光路穿透越深，默认 0.5
// _HP_MS_Contribution: 散射能量权重（per octave）——越大云内部越白，默认 0.5
// _HP_MS_Eccentricity: 相函数偏心率衰减率（per octave）——越小高阶越趋近各向同性，默认 0.5
float _HP_MS_Attenuation;
float _HP_MS_Contribution;
float _HP_MS_Eccentricity;

// ── msWeight 对消光 & MS 强度的独立调制 ─────────────────────────────────────
// _HP_MSW_ExtIntensity : msWeight 对视线消光的门控强度。1=完全门控（msWeight=0 则消光为 0），0=msWeight 不影响消光。
// _HP_MSW_ExtContrast  : msWeight→消光的曲线指数。1=线性；>1=更陡（阈值化）；<1=更软。
// _HP_MSW_MSContrast   : msWeight 作为 MS 直接比例因子的曲线指数。1=线性；>1=只有厚云柱才有明显 MS。
// _HP_MSW_MSIntensity  : msWeight 路径 MS 贡献的整体强度倍率。0=禁用；1=不变；>1 增强 cover 驱动 MS。
float _HP_MSW_ExtIntensity;
float _HP_MSW_ExtContrast;
float _HP_MSW_MSIntensity;
float _HP_MSW_MSContrast;

// ── phi_fwd 物理漫射场（PhiFwd Diffuse Field） ─────────────────────────────────
// τ≫1 扩散 regime：ω_0 写死；每步从局部 σ_t 拆 σ_s、σ_a。g_eff=0 → σ_tr=σ_t，故
//   κ = sqrt(3σ_a σ_tr) = σ_t·sqrt(3(1−ω_0))，∫κ ds = sqrt(3(1−ω_0))·OD（无需逐步 sqrt）
#define HP_PHIFWD_OMEGA0         0.999f
#define HP_PHIFWD_KAPPA_OD_SCALE sqrt(3.0f * (1.0f - HP_PHIFWD_OMEGA0))
// _HP_PhiFwd_Intensity  : 整体强度（0=禁用，建议 0.1~2.0）
// _HP_PhiFwd_ODScale    : ∫κ ds 的艺术倍率（1=物理；>1 衰减更快）
// _HP_PhiFwd_DepthPow   : 漫射场深度衰减指数。修正 phi_fwd 在云底偏大的问题（物理上漫射场从云顶向下衰减）。
//                         saturate(localHeight + Bias)^DepthPow：DepthPow=1线性，0=禁用。建议 0.5~2.0。
// _HP_PhiFwd_DepthBias  : 深度曲线垂直偏移。>0 底面保留更多漫射光（不降到0）；<0 过渡区上移，底面更暗。建议 -0.3~0.5。
// _HP_PhiFwd_BoundaryConfidence : 2D 高度差分边界受光置信度强度。0=禁用，1=全量使用 wrap 边界受光。
float _HP_PhiFwd_Intensity;
float _HP_PhiFwd_ODScale;
float _HP_PhiFwd_DepthPow;
float _HP_PhiFwd_DepthBias;
float _HP_PhiFwd_BoundaryConfidence;

// 用低云天气图重建一个便宜的云顶高度代理，供 phi_fwd 边界受光判断使用。
// 这里只关心“最近相关边界是否面向太阳”，不参与密度本身的精确评估。
float HP_EvaluatePhiFwdTopHeightProxy(float2 worldXZ)
{
    float2 weatherUV = HP_ComputeWeatherMapUV(worldXZ);
    if (!HP_IsInsideWeatherMapUV(weatherUV))
        return 0.0;

    float4 weather = SAMPLE_TEXTURE2D_LOD(_CloudMapTexture, s_linear_clamp_sampler, weatherUV, 0);
    float coverageHeight = saturate(PositivePow(weather.r, max(_HP_LoCovHeightContrast, 0.001)) * _HP_LoCovHeightIntensity);
    float loCoverForTop = PositivePow(coverageHeight, max(_HP_LoCoverTopCurvePow, 0.01));
    float loCoverTopScale = lerp(1.0, max(_HP_LoCoverTopMax, 1.0), loCoverForTop * _HP_LoCoverTopStr);

    return saturate(coverageHeight * loCoverTopScale / max(_HP_LoCoverTopMax, 1.0));
}

float HP_EvaluatePhiFwdBoundaryLight(float3 positionWS, float3 sunDirection)
{
    float sampleStep = clamp(_HP_WeatherMapWorldSize * 0.001, 25.0, 200.0);

    float hL = HP_EvaluatePhiFwdTopHeightProxy(positionWS.xz - float2(sampleStep, 0.0));
    float hR = HP_EvaluatePhiFwdTopHeightProxy(positionWS.xz + float2(sampleStep, 0.0));
    float hD = HP_EvaluatePhiFwdTopHeightProxy(positionWS.xz - float2(0.0, sampleStep));
    float hU = HP_EvaluatePhiFwdTopHeightProxy(positionWS.xz + float2(0.0, sampleStep));

    float slabThickness = max(_HighestCloudAltitude - _LowestCloudAltitude, 1.0);
    float dHdx = (hR - hL) * slabThickness / max(2.0 * sampleStep, 1.0);
    float dHdz = (hU - hD) * slabThickness / max(2.0 * sampleStep, 1.0);
    float3 topNormalWS = normalize(float3(-dHdx, 1.0, -dHdz));

    float nDotL = dot(topNormalWS, sunDirection);
    float wrap = 0.5;
    float boundaryLitWarp = saturate((nDotL + wrap) / (1.0 + wrap));
    return lerp(1.0, boundaryLitWarp, saturate(_HP_PhiFwd_BoundaryConfidence));
}

// ── 高空云（Ac/As）独立光照参数 ──────────────────────────────────────────────
// 与低云参数完全独立，允许高空云呈现更透明、更蓝白的薄云光照特征。
float _HP_Hi_ForwardEccentricity;   // 前向散射偏心率（Ac 晕圈效果）
float _HP_Hi_BackwardEccentricity;  // 后向散射偏心率
float _HP_Hi_AmbientTopMultiplier;    // 云顶环境光倍增
float _HP_Hi_AmbientBottomMultiplier; // 云底环境光倍增
float _HP_Hi_SkyBlendStrength;        // 高空云向天空色混合强度（越高层越接近天空）
float _HP_Hi_MS_Attenuation;        // 多重散射消光衰减率（per octave）
float _HP_Hi_MS_Contribution;       // 多重散射散射能量权重（per octave）
float _HP_Hi_MS_Eccentricity;       // 多重散射相函数偏心率衰减率（per octave）
float _HP_Hi_LightAbsorption;       // 光线方向吸收（自阴影强度）
float _HP_Hi_ViewAbsorption;        // 视线方向吸收（不透明度）
float _HP_Hi_CoverAbsorptionStr;    // Cover 亮度对太阳光吸收的额外调制强度（0=无影响，>0=Cover越亮自阴影越强）

// Ambient probe. Contains a convolution with Cornette Shank phase function so it needs to sample a different buffer.
StructuredBuffer<float4> _VolumetricCloudsAmbientProbeBuffer;

// Function that interects a ray with a sphere (optimized for very large sphere), returns up to two positives distances.
int RaySphereIntersection(float3 startWS, float3 dir, float radius, out float2 result)
{
    float3 startPS = startWS + float3(0, _EarthRadius, 0);
    float a = dot(dir, dir);
    float b = 2.0 * dot(dir, startPS);
    float c = dot(startPS, startPS) - (radius * radius);
    float d = (b*b) - 4.0*a*c;
    result = 0.0;
    int numSolutions = 0;
    if (d >= 0.0)
    {
        // Compute the values required for the solution eval
        float sqrtD = sqrt(d);
        float q = -0.5*(b + FastSign(b) * sqrtD);
        result = float2(c/q, q/a);
        // Remove the solutions we do not want
        numSolutions = 2;
        if (result.x < 0.0)
        {
            numSolutions--;
            result.x = result.y;
        }
        if (result.y < 0.0)
            numSolutions--;
    }
    // Return the number of solutions
    return numSolutions;
}

// Function that interects a ray with a sphere (optimized for very large sphere), and says if there is at least one intersection
bool RaySphereIntersection(float3 startWS, float3 dir, float radius)
{
    float3 startPS = startWS + float3(0, _EarthRadius, 0);
    float a = dot(dir, dir);
    float b = 2.0 * dot(dir, startPS);
    float c = dot(startPS, startPS) - (radius * radius);
    float d = (b * b) - 4.0 * a * c;
    bool flag = false;
    if (d >= 0.0)
    {
        // Compute the values required for the solution eval
        float sqrtD = sqrt(d);
        float q = -0.5 * (b + FastSign(b) * sqrtD);
        float2 result = float2(c/q, q/a);
        flag = result.x > 0.0 || result.y > 0.0;
    }
    return flag;
}

// Function that intersects a ray with a plane and returns a flag and the intersection point
bool IntersectPlane(float3 ray_originWS, float3 ray_dir, float3 pos, float3 normal, out float t)
{
    float3 ray_originPS = ray_originWS + float3(0, _EarthRadius, 0);
    float denom = dot(normal, ray_dir);
    bool flag = false;
    t = -1.0f;
    if (abs(denom) > 1e-6)
    {
        float3 d = pos - ray_originPS;
        t = dot(d, normal) / denom;
        flag = (t >= 0);
    }
    return flag;
}

// Structure that holds all the lighting data required to light the cloud particles
struct EnvironmentLighting
{
    // Light direction (point to sun)
    float3 sunDirection;

    // Light intensity/color of the sun, this already takes into account the atmospheric scattering
    float3 sunColor0;
    float3 sunColor1;

    // Ambient term from the ambient probe
    float3 ambientTermTop;
    float3 ambientTermBottom;

    // Angle between the light and the ray direction
    float cosAngle;

    // Phase functions for the individual
    PHASE_FUNCTION_STRUCTURE phaseFunction;
};

// This functions evaluates the sun color attenuation at a given point (if the physicaly based sky is active)
void EvaluateSunColorAttenuation(float3 evaluationPointWS, float3 sunDirection, inout float3 sunColor)
{
#ifdef PHYSICALLY_BASED_SUN
    if(_PhysicallyBasedSun == 1)
    // TODO: move this into a shared function
    {
        float3 X = evaluationPointWS;
        float3 C = _PlanetCenterPosition.xyz;

        float r        = distance(X, C);
        float cosHoriz = ComputeCosineOfHorizonAngle(r);
        float cosTheta = dot(X - C, sunDirection) * rcp(r); // Normalize

        if (cosTheta >= cosHoriz) // Above horizon
        {
            float3 oDepth = ComputeAtmosphericOpticalDepth(r, cosTheta, true);
            // Cannot do this once for both the sky and the fog because the sky may be desaturated. :-(
            float3 transm  = TransmittanceFromOpticalDepth(oDepth);
            float3 opacity = 1 - transm;
            sunColor *= 1 - (Desaturate(opacity, _AlphaSaturation) * _AlphaMultiplier);
        }
        else
        {
            // return 0; // Kill the light. This generates a warning, so can't early out. :-(
           sunColor = 0;
        }
    }
#endif
}

// Structure that holds all the data required for the cloud ray marching
struct CloudRay
{
    // Depth value of the pixel
    float depthValue;
    // Origin of the ray in world space
    float3 originWS;
    // Direction of the ray in world space
    float3 direction;
    // Maximal ray length before hitting the far plane or an occluder
    float maxRayLength;
    // Flag to track if we are inside the cloud layers
    float insideClouds;
    // Distance to earth center
    float toEarthCenter;
    // Integration Noise
    float integrationNoise;
    // Environement lighting
    EnvironmentLighting envLighting;
};

// Phase term function
float HenyeyGreenstein(float cosAngle, float g)
{
    // There is a mistake in the GPU Gem7 Paper, the result should be divided by 1/(4.PI)
    float g2 = g * g;
    return (1.0 / (4.0 * PI)) * (1.0 - g2) / PositivePow(1.0 + g2 - 2.0 * g * cosAngle, 1.5);
}

// Functions that evaluates all the lighting data that will be needed by the cloud ray
EnvironmentLighting EvaluateEnvironmentLighting(CloudRay ray, float3 entryEvaluationPointWS, float3 exitEvaluationPointWS)
{
    // Sun parameters
    EnvironmentLighting lighting;
    lighting.sunDirection = _SunDirection.xyz;
    lighting.sunColor0 = _SunLightColor.xyz * GetCurrentExposureMultiplier();
    lighting.sunColor1 = lighting.sunColor0;
    lighting.ambientTermTop    = SampleSH9(_VolumetricCloudsAmbientProbeBuffer, float3(0,  1, 0)) * GetCurrentExposureMultiplier() * _HP_AmbientTopMultiplier;
    lighting.ambientTermBottom = max(SampleSH9(_VolumetricCloudsAmbientProbeBuffer, float3(0, -1, 0)), 0) * GetCurrentExposureMultiplier() * _HP_AmbientBottomMultiplier;

    // evaluate the attenuation at both points (entrance and exit of the cloud layer)
    EvaluateSunColorAttenuation(entryEvaluationPointWS, lighting.sunDirection, lighting.sunColor0);
    EvaluateSunColorAttenuation(exitEvaluationPointWS, lighting.sunDirection, lighting.sunColor1);

    // Evaluate cos of the theta angle between the view and light vectors
    lighting.cosAngle = dot(ray.direction, lighting.sunDirection);

    // Evaluate the phase function for each of the octaves.
    // Eccentricity shrinks per octave by _HP_MS_Eccentricity (independent from extinction/contribution).
    float forwardP = HenyeyGreenstein(lighting.cosAngle, _HP_ForwardEccentricity  * PositivePow(_HP_MS_Eccentricity, 0));
    float backwardsP = HenyeyGreenstein(lighting.cosAngle, -_HP_BackwardEccentricity * PositivePow(_HP_MS_Eccentricity, 0));
    lighting.phaseFunction[0] = forwardP + backwardsP;

    #if NUM_MULTI_SCATTERING_OCTAVES >= 2
    forwardP   = HenyeyGreenstein(lighting.cosAngle,  _HP_ForwardEccentricity  * PositivePow(_HP_MS_Eccentricity, 1));
    backwardsP = HenyeyGreenstein(lighting.cosAngle, -_HP_BackwardEccentricity * PositivePow(_HP_MS_Eccentricity, 1));
    lighting.phaseFunction[1] = forwardP + backwardsP;
    #endif

    #if NUM_MULTI_SCATTERING_OCTAVES >= 3
    forwardP   = HenyeyGreenstein(lighting.cosAngle,  _HP_ForwardEccentricity  * PositivePow(_HP_MS_Eccentricity, 2));
    backwardsP = HenyeyGreenstein(lighting.cosAngle, -_HP_BackwardEccentricity * PositivePow(_HP_MS_Eccentricity, 2));
    lighting.phaseFunction[2] = forwardP + backwardsP;
    #endif

    return lighting;
}

// Function that evaluates the sun color along the ray
float3 EvaluateSunColor(EnvironmentLighting envLighting, float relativeRayDistance)
{
    return lerp(envLighting.sunColor0, envLighting.sunColor1, relativeRayDistance);
}

// Density remapping function
float DensityRemap(float x, float a, float b, float c, float d)
{
    return (((x - a) / (b - a)) * (d - c)) + c;
}

// Horizon zero dawn technique to darken the clouds
float PowderEffect(float cloudDensity, float cosAngle, float intensity)
{
    float powderEffect = 1.0 - exp(-cloudDensity * 4.0);
    powderEffect = saturate(powderEffect * 2.0);
    return lerp(1.0, lerp(1.0, powderEffect, smoothstep(0.5, -0.5, cosAngle)), intensity);
}

// Function that takes a clip space positions and converts it to a view direction
float3 GetCloudViewDirWS(float2 positionCS)
{
    float4 viewDirWS = mul(float4(positionCS, 1.0f, 1.0f), _CloudsPixelCoordToViewDirWS);
    return -normalize(viewDirWS.xyz);
}

// Fonction that takes a world space position and converts it to a depth value
float ConvertCloudDepth(float3 position)
{
    float4 hClip = TransformWorldToHClip(position);
    return hClip.z / hClip.w;
}

// Function that converts an oblique depth to a non oblique one (for planar reflection probes)
float ConvertObliqueDepthToNonOblique(int2 currentCoord, float obliqueDepth)
{
    // Compute the world position of the tapped pixel
    // Note: the view matrix here is not really used, but a valid matrix needs to be passed to this function.
    PositionInputs centralPosInput = GetPositionInput(currentCoord, _FinalScreenSize.zw, obliqueDepth, UNITY_MATRIX_I_VP, UNITY_MATRIX_V);

    // For some reason, with oblique matrices, when the point is on the background the reconstructed position ends up behind the camera and at the wrong position
    float3 rayDirection = normalize(-centralPosInput.positionWS);
    rayDirection = obliqueDepth == 0.0 ? -rayDirection : rayDirection;

    // Adjust the position
    centralPosInput.positionWS = obliqueDepth == 0.0 ? rayDirection * _ProjectionParams.z : centralPosInput.positionWS;

    // Re-do the projection, but this time without the oblique part and export it
    float4 hClip = mul(_CameraViewProjection_NO, float4(centralPosInput.positionWS, 1.0));

    // Divide by the homogenous coordinate
    return saturate(hClip.z / hClip.w);
}

// Structure that describes the ray marching ranges that we should be iterating on
struct RayMarchRange
{
    // The start of the range
    float start;
    // The length of the range
    float distance;
};

bool GetCloudVolumeIntersection(float3 originWS, float3 dir, float insideClouds, float toEarthCenter, out RayMarchRange rayMarchRange)
#ifdef LOCAL_VOLUMETRIC_CLOUDS
{
    ZERO_INITIALIZE(RayMarchRange, rayMarchRange);

    // intersect with all three spheres
    float2 intersectionInter, intersectionOuter;
    int numInterInner = RaySphereIntersection(originWS, dir, _LowestCloudAltitude + _EarthRadius, intersectionInter);
    int numInterOuter = RaySphereIntersection(originWS, dir, _HighestCloudAltitude + _EarthRadius, intersectionOuter);
    bool intersectEarth = RaySphereIntersection(originWS, dir, insideClouds < -1.5 ? toEarthCenter : _EarthRadius);

    // Did we achieve any intersection ?
    bool intersect = numInterInner > 0 || numInterOuter > 0;

    // If we are inside the lower cloud bound
    if (insideClouds < -0.5)
    {
        // The ray starts at the first intersection with the lower bound and goes up to the first intersection with the outer bound
        rayMarchRange.start = intersectionInter.x;
        rayMarchRange.distance = intersectionOuter.x - intersectionInter.x;
    }
    else if (insideClouds == 0.0)
    {
        // If we are inside, the ray always starts at 0
        rayMarchRange.start = 0;

        // if we intersect the earth, this means the ray has only one range
        if (intersectEarth)
            rayMarchRange.distance = intersectionInter.x;
        // if we do not untersect the earth and the lower bound. This means the ray exits to outer space
        else if(numInterInner == 0)
            rayMarchRange.distance = intersectionOuter.x;
        // If we do not intersect the earth, but we do intersect the lower bound, we have two ranges.
        else
            rayMarchRange.distance = intersectionInter.x;
    }
    // We are in outer space
    else
    {
        // We always start from our intersection with the outer bound
        rayMarchRange.start = intersectionOuter.x;

        // If we intersect the earth, ony one range
        if(intersectEarth)
            rayMarchRange.distance = intersectionInter.x - intersectionOuter.x;
        else
        {
            // If we do not intersection the lower bound, the ray exits from the upper bound
            if(numInterInner == 0)
                rayMarchRange.distance = intersectionOuter.y - intersectionOuter.x;
            else
                rayMarchRange.distance = intersectionInter.x - intersectionOuter.x;
        }
    }
    // Mke sure we cannot go beyond what the number of samples
    rayMarchRange.distance = clamp(0, rayMarchRange.distance, _MaxRayMarchingDistance);

    // Return if we have an intersection
    return intersect;
}
#else
{
    ZERO_INITIALIZE(RayMarchRange, rayMarchRange);

    // intersect with all three spheres
    float2 intersectionInter, intersectionOuter;
    int numInterInner = RaySphereIntersection(originWS, dir, _LowestCloudAltitude + _EarthRadius, intersectionInter);
    int numInterOuter = RaySphereIntersection(originWS, dir, _HighestCloudAltitude + _EarthRadius, intersectionOuter);

    // The ray starts at the first intersection with the lower bound and goes up to the first intersection with the outer bound
    rayMarchRange.start = intersectionInter.x;
    rayMarchRange.distance = intersectionOuter.x - intersectionInter.x;

    // Return if we have an intersection
    return true;
}
#endif

// Structure that holds all the data used to define the cloud density of a point in space
struct CloudCoverageData
{
    // From a top down view, in what proportions this pixel has clouds
    float2 coverage;
    // From a top down view, in what proportions this pixel has clouds
    float rainClouds;
    // Value that allows us to request the cloudtype using the density
    float cloudType;
    // Maximal cloud height
    float maxCloudHeight;
};

// Function that returns if a given point in planet space position in inside or outside the cloud volume
bool PointInsideCloudVolume(float3 positionPS)
{
    float toEarthCenter2 = dot(positionPS, positionPS);
    return toEarthCenter2 < _CloudRangeSquared.y && toEarthCenter2 > _CloudRangeSquared.x;
}

// Function that returns the normalized height inside the cloud layer
float EvaluateNormalizedCloudHeight(float3 positionPS)
{
    return (length(positionPS) - (_LowestCloudAltitude + _EarthRadius)) / ((_HighestCloudAltitude + _EarthRadius) - (_LowestCloudAltitude + _EarthRadius));
}

// Animation of the cloud map position
float3 AnimateCloudMapPosition(float3 positionPS)
{
    return positionPS + float3(_WindVector.x, 0.0, _WindVector.y) * _LargeWindSpeed;
}

struct CloudProperties
{
    // Normalized float that tells the "amount" of clouds that is at a given location
    float density;
    // Ambient occlusion for the ambient probe
    float ambientOcclusion;
    // Normalized value that tells us the height within the cloud volume (vertically)
    float height;
    // Normalized height within the LOCAL cloud profile (0=cloud bottom, 1=cloud top).
    // Unlike height (global slab), this is remapped by the LUT/profile curve so that
    // thin low clouds near the slab floor still reach 1.0 at their own top.
    // Used for ambient AO so the cloud top always sees full sky ambient.
    float localHeight;
    // Transmittance of the cloud
    float sigmaT;
};

// Function that evaluates the coverage data for a given point in planet space
void GetCloudCoverageData(float3 positionPS, out CloudCoverageData data)
{
    // Convert the position into dome space and center the texture is centered above (0, 0, 0)
    float2 normalizedPosition = AnimateCloudMapPosition(positionPS).xz / _NormalizationFactor * _CloudMapTiling.xy + _CloudMapTiling.zw - 0.5;
    // Read the data from the texture
    float4 cloudMapData =  SAMPLE_TEXTURE2D_LOD(_CloudMapTexture, s_linear_repeat_sampler, float2(normalizedPosition), 0);
    data.coverage = float2(cloudMapData.x, cloudMapData.x * cloudMapData.x);
    data.rainClouds = cloudMapData.y;
    data.cloudType = cloudMapData.z;
    data.maxCloudHeight = cloudMapData.w;
}

// ── HanPi VolumeCloud density algorithm ──────────────────────────────────────
// Replaces the original EvaluateCloudProperties() with the Nubis3-style
// Billowy / Wispy dual-layer erosion pipeline from VolumeCloudShader.shader.
// positionWS is the same absolute world-space position as before.
// noiseMipOffset / erosionMipOffset drive 3D noise LOD (distance / light-step based).
// ─────────────────────────────────────────────────────────────────────────────
// simpleMode=true：跳过 _ErosionNoise 采样（billowy/wispy 保持 0，相当于无细节侵蚀）。
// 用于大步跳的密度检测（快速判断是否有云体），可节省一次 3D 纹理采样。
// simpleMode=false：完整计算，包含 Billowy/Wispy detail erosion（用于精细积分）。
void EvaluateCloudProperties(float3 positionWS, float noiseMipOffset, float erosionMipOffset,
                            bool simpleMode, out CloudProperties properties)
{
    ZERO_INITIALIZE(CloudProperties, properties);
    properties.ambientOcclusion = 1.0;
    properties.localHeight      = 0.0; // 默认等于全局 slab 底部；由低云路径覆盖为 lutSampleHeight

    // ── 体积范围检查（复用官方球面 slab） ─────────────────────────────────────
    float3 positionPS = positionWS + float3(0, _EarthRadius, 0);
    if (!PointInsideCloudVolume(positionPS) || positionPS.y < 0.0f)
        return;

    // ── 云层归一化高度（0=slab 底，1=slab 顶） ───────────────────────────────
    properties.height = EvaluateNormalizedCloudHeight(positionPS);

    // ── 天气图采样（R=Coverage，B=CloudType） ────────────────────────────────
    // UV：以世界 XZ 坐标相对天气图中心归一化，[0,1] 对应整张天气图的世界范围。
    float2 weatherUV = HP_ComputeWeatherMapUV(positionWS.xz);
    if (!HP_IsInsideWeatherMapUV(weatherUV))
        return;
    float4 weather    = SAMPLE_TEXTURE2D_LOD(_CloudMapTexture, s_linear_clamp_sampler, weatherUV, 0);
    // Lo 纹理通道：R=LoCoverage  G=CloudType  B=ScMask  A=reserved
    float  cloudType  = weather.g;
    float  scAtlasMask = weather.b;

    // ── 运行时 Coverage 双路调整 ────────────────────────────────────────────
    // 原始值先统一读出，再各自经 pow(contrast)×intensity 后用于不同计算路径。
    float coverageRaw    = weather.r;
    float coverage       = saturate(PositivePow(coverageRaw, max(_HP_LoCovCoverContrast,  0.001)) * _HP_LoCovCoverIntensity);
    float coverageHeight = saturate(PositivePow(coverageRaw, max(_HP_LoCovHeightContrast, 0.001)) * _HP_LoCovHeightIntensity);

    // Sc 空间强度：B 通道 = 层积云 Mask（高 → Sc 区域）。
    float scStr = _HP_ScWorleyStrength * scAtlasMask;

    // ── 层积云细胞噪声采样 ────────────────────────────────────────────────────
    // scCell ∈ [0,1]：1=细胞中心（致密），0=细胞边界（稀疏/空隙）。
    // ScCellNoiseStr > 1：提亮格子中心、压暗边界，增强空隙对比；< 1：柔化格子边界。
    float scCell = saturate(SAMPLE_TEXTURE2D_LOD(_HP_ScCellNoiseTex, s_linear_repeat_sampler,
                                                  weatherUV * _HP_ScCellScale, 0).r * _HP_ScCellNoiseStr);

    // ── Sc 空隙塑形（ScWorleyStrength > 0 时激活，不依赖 GlobalCoverage）─────
    // Sc 使用独立 contrast/intensity 从 coverageRaw 重新计算 coverage，不复用低云全局路径。
    // ScWorleyStrength=0：不影响 coverage（纯积云模式）
    // ScWorleyStrength=1：coverage 完全由 ScCovContrast/Intensity + scCell 决定（完全层积云模式）
    float scCoverage = saturate(PositivePow(coverageRaw, max(_HP_ScCovContrast, 0.001)) * _HP_ScCovIntensity);
    coverage = lerp(coverage, scCoverage * scCell, scStr);

    // 低云和高空云分别判断是否需要计算，任意一个有效即继续执行。
    // Hi 纹理 R=HiMask（高空云覆盖率），改从 _CloudMapHiTexture 读取。
    float4 hiWeatherLo = SAMPLE_TEXTURE2D_LOD(_CloudMapHiTexture, s_linear_clamp_sampler, weatherUV, 0);
    bool needHighCloud = hiWeatherLo.r > 0.001;
    if (coverage < CLOUD_DENSITY_TRESHOLD && !needHighCloud)
        return;

    // ── Coverage 驱动高度拉伸（只加不减，底部锚定）─────────────────────────────
    // 用 Möbius 变换 f(h) = h / (1 + (scale-1)*h) 代替均匀除法：
    //   h=0  → heightForLUT=0    （底部精确不变，避免云底被抬高）
    //   h→大 → 压缩越强          （顶部拉伸最大，云顶向上延伸）
    //   scale=1 → f(h)=h         （无效果时完全等价）
    float loCoverForTop   = PositivePow(saturate(coverageHeight), max(_HP_LoCoverTopCurvePow, 0.01));
    float loCoverTopScale = lerp(1.0, max(_HP_LoCoverTopMax, 1.0),
                                 loCoverForTop * _HP_LoCoverTopStr);
    float heightForLUT    = properties.height / (1.0 + (loCoverTopScale - 1.0) * properties.height);

    // ── Sc 高度压缩：把完整积云廓形压进 slab 底部 ScHeightScale 比例范围内 ────────
    // properties.height / ScHeightScale：超过 ScHeightScale 后 saturate=1，廓形归零，
    // 实现层积云的薄层约束；ScHeightScale→1 时退化为普通积云高度。
    float scCompressedHeight    = saturate(properties.height / max(_HP_ScHeightScale, 0.01));
    float lutSampleHeight       = lerp(heightForLUT, scCompressedHeight, scStr);
    properties.localHeight      = lutSampleHeight; // 云体局部归一化高度（0=云底，1=云顶），供 AO 使用

    // ── Profile LUT 高度梯度（低云密度 + 边缘柔化共用） ───────────────────────
    float  radialDist      = saturate(length(weatherUV - 0.5) * 2.0);
    float3 profiles        = SAMPLE_TEXTURE2D_LOD(_CloudLutTexture, s_linear_clamp_sampler,
                                                   float2(lutSampleHeight, radialDist), 0);
    float  heightGradient;
    if (cloudType < 0.5)
        heightGradient = lerp(profiles.r, profiles.g, cloudType * 2.0);
    else
        heightGradient = lerp(profiles.g, profiles.b, (cloudType - 0.5) * 2.0);
    // Sc 廓形：scStr=1 时使用积云 R 通道（在压缩高度下采样，廓形即为压扁的积云形体）
    heightGradient = lerp(heightGradient, profiles.r, scStr);
    // （层云压平逻辑已删除，不再有 toStratus）
    // 底部：物理高度驱动，BottomPow 控制衰减集中度，不影响云体中上部。
    float bottomSoftness = PositivePow(1.0 - properties.height, max(_HP_CloudEdgeSoftnessBottomPow, 0.01))
                         * _HP_CloudEdgeSoftnessBottom;
    // 顶/侧：LUT 密度反向，乘以 Top 倍率可整体缩放软化宽度。
    float topSoftness    = saturate(1.0 - heightGradient) * _HP_CloudEdgeSoftnessTop;
    float edgeSoftness   = max(bottomSoftness, topSoftness);

    // ── Base shape 噪声（低云和高空云共用，R 通道 = PerlinWorley） ────────────
    // 风偏移由 HPWindField 累积 UV 偏移（世界空间 XZ）驱动。
    float3 windOffset   = float3(_HP_NoiseWindOffset.x, 0.0, _HP_NoiseWindOffset.y) * _HP_BaseNoiseWindSpeed;
    float3 baseUVW      = positionWS * _HP_NoiseScale + _HP_NoiseOffset + windOffset;
    float4 baseNoise    = SAMPLE_TEXTURE3D_LOD(_Worley128RGBA, s_trilinear_repeat_sampler, baseUVW, max(noiseMipOffset, 0.0));
    // pow(0.6) 软化高端分布，使云体边缘更柔和。结果已在 [0,1]，无需 saturate/remap。
    float  baseShape    = pow(abs(baseNoise.r), 0.6);

    // 云底平滑：localHeight→0 时强制 baseShape=1 并关闭 detail，仅保留 2D coverage/profile 分布。
    float bottomNoiseFade = 1.0;
    if (_HP_BottomSmoothHeight > 0.0)
    {
        bottomNoiseFade = PositivePow(
            saturate(properties.localHeight / _HP_BottomSmoothHeight),
            max(_HP_BottomSmoothPow, 0.01));
    }
    baseShape = lerp(1.0, baseShape, bottomNoiseFade);

    // ── Detail erosion 噪声（Nubis3 四通道） ───────────────────────────────────
    // R=WispyLow G=WispyHigh B=BillowyLow A=BillowyHigh
    // simpleMode=true 时跳过采样，billowy/wispy=0 等价于无侵蚀（base shape 直接映射密度）。
    float billowy = 0.0;
    float wispy   = 0.0;
    if (!simpleMode)
    {
        float3 detailWindOffset = float3(_HP_NoiseWindOffset.x, 0.0, _HP_NoiseWindOffset.y) * _HP_DetailNoiseWindSpeed
                                + float3(0.0, _TimeParameters.x * _HP_DetailNoiseVerticalWindSpeed, 0.0);
        float3 detailUVW        = float3(positionWS.x, -positionWS.y, positionWS.z) * _HP_DetailNoiseScale
                                + _HP_NoiseOffset * 0.5 + detailWindOffset;
        float4 d = SAMPLE_TEXTURE3D_LOD(_ErosionNoise, s_linear_repeat_sampler, detailUVW, max(erosionMipOffset, 0.0));
        billowy  = (d.b * _HP_BillowyLowStr + d.a * _HP_BillowyHighStr) * bottomNoiseFade;
        wispy    = (d.r * _HP_WispyLowStr   + d.g * _HP_WispyHighStr)   * bottomNoiseFade;
    }

    // ── 低云密度计算（仅在低云 coverage 有效时执行） ──────────────────────────
    float base_cloud = 0.0;
    if (coverage >= CLOUD_DENSITY_TRESHOLD)
    {
        // ── Sc 细胞厚度调制 ──────────────────────────────────────────────────────
        // heightGradient 已在 LUT 采样前通过 lutSampleHeight 高度压缩 + profiles.r 混合完成廓形，
        // 此处只需用 cell 噪声调制最终密度（间隙处归零，格子中心保留满密度）。
        float scCellShaped  = PositivePow(max(scCell, 0.001), max(_HP_ScCellThickPow, 0.01));
        float scCellFactor  = lerp(1.0, scCellShaped, _HP_ScCellThickStr);
        float heightClip    = lerp(1.0, scCellFactor, scStr);

        float threshold = (1.0 - coverage) + _HP_DensityThreshold;

        // cloudType 按三段插值决定 detail 侵蚀强度（Cu/Tcu/Cb 对应不同侵蚀感）。
        float detailStrength;
        if (cloudType < 0.5)
            detailStrength = lerp(_HP_DetailStrengthCu,  _HP_DetailStrengthTcu, cloudType * 2.0);
        else
            detailStrength = lerp(_HP_DetailStrengthTcu, _HP_DetailStrengthCb,  (cloudType - 0.5) * 2.0);
        // Sc 使用独立侵蚀强度：层积云通常比积云侵蚀更柔和（薄层内细节少）
        detailStrength = lerp(detailStrength, _HP_ScDetailStr, scStr);

        // detail 侵蚀：用 DensityRemap 把 baseShape 按 detail 噪声向低端收缩。
        float erodedBillowy = saturate(DensityRemap(baseShape, billowy * detailStrength, 1.0, 0.0, 1.0));
        float erodedWispy   = saturate(DensityRemap(baseShape, wispy   * detailStrength, 1.0, 0.0, 1.0));
        erodedBillowy *= heightGradient;
        erodedWispy   *= heightGradient;

        // wispyThreshold：比 billowy 更低，使 wispy 在 billowy 归零后仍能向外延伸。
        float wispyThreshold = threshold - _HP_WispyReach;
        float densityBillowy = saturate(DensityRemap(erodedBillowy, threshold,      threshold      + edgeSoftness, 0.0, 1.0));
        float densityWispy   = saturate(DensityRemap(erodedWispy,   wispyThreshold, wispyThreshold + edgeSoftness, 0.0, 1.0));

        // ── Wispy 高度衰减（PositivePow 幂函数，无 smoothstep 硬边）──────────────
        // t：在 [WispyTopHeight, 1] 区间归一化，低于 WispyTopHeight 时 t=0（mask=1）。
        // PositivePow(1-t, Hardness)：幂函数从 1 衰减到 0，无硬边，Hardness 控制尾巴长短。
        //   Hardness>1 → 长尾（wispy 在阈值以上仍保留较多，顶端才快速归零）
        //   Hardness=1 → 线性衰减
        //   Hardness<1 → 短尾（越过阈值后迅速消失）
        float wispyT          = saturate((properties.height - _HP_WispyTopHeight)
                                         / max(1.0 - _HP_WispyTopHeight, 0.001));
        float wispyHeightMask = PositivePow(1.0 - wispyT, max(_HP_WispyTopHardness*10, 0.01));
        densityWispy *= wispyHeightMask;

        // 致密核心（densityBillowy 高）→ billowy；边缘/外部 → wispy。
        float billowyByShape = smoothstep(0.0, _HP_WispyEdgeWidth, densityBillowy);
        base_cloud = lerp(densityWispy, densityBillowy, billowyByShape) * heightClip;

        // ── 低云 per-type 密度倍率（Cu / Tcu / Cb 三段插值） ────────────────────
        float typeDensityMult;
        if (cloudType < 0.5)
            typeDensityMult = lerp(_HP_DensityMultiplierCu,  _HP_DensityMultiplierTcu, cloudType * 2.0);
        else
            typeDensityMult = lerp(_HP_DensityMultiplierTcu, _HP_DensityMultiplierCb,  (cloudType - 0.5) * 2.0);
        base_cloud *= typeDensityMult;
    }

    // ── 环境光遮蔽 ──────────────────────────────────────────────────────────
    // AO 已改为在 EvaluateCloud 中用向上 Beer-Lambert 透射率计算（msWeight×(1-height)×scale），
    // 此处保留字段初始值 1.0（由 ZERO_INITIALIZE 之后的显式赋值保证），不再用局部密度近似。

    properties.density = max(0.0, base_cloud * _HP_DensityMultiplier);

    // sigmaT：固定值（HanPi WeatherMap 无降水/云类型分层数据）。
    properties.sigmaT = 1;
}

// ─────────────────────────────────────────────────────────────────────────────
// EvaluateHighCloudDensity — 仅使用 2D 纹理的高空云（Ac/As）密度评估
//
// 与 EvaluateCloudProperties 的高空云分支完全等价，但作为独立函数存在，
// 专用于高空云的独立步进循环，不采样任何 3D 体积噪声。
//
// outNormalizedHeight : 采样点在主 slab 中的归一化高度（0=slab底，1=slab顶）
// 返回值              : 最终密度（已乘 _HP_DensityMultiplierHi），0 表示该点无高空云
// ─────────────────────────────────────────────────────────────────────────────
float EvaluateHighCloudDensity(float3 positionWS, out float outNormalizedHeight)
{
    outNormalizedHeight = 0.0;

    float3 positionPS = positionWS + float3(0, _EarthRadius, 0);
    if (!PointInsideCloudVolume(positionPS) || positionPS.y < 0.0f)
        return 0.0;

    float normalizedHeight  = EvaluateNormalizedCloudHeight(positionPS);
    outNormalizedHeight     = normalizedHeight;

    // Hi 纹理通道：R=HiMask(高空云覆盖)  G=HiType(As/Ac)
    float2 weatherUV = HP_ComputeWeatherMapUV(positionWS.xz);
    if (!HP_IsInsideWeatherMapUV(weatherUV))
        return 0.0;
    float4 hiWeather     = SAMPLE_TEXTURE2D_LOD(_CloudMapHiTexture, s_linear_clamp_sampler, weatherUV, 0);
    float  hiEffCoverage = hiWeather.r;
    float  hiType        = hiWeather.g;
    if (hiEffCoverage < 0.001) return 0.0;

    // 按云型选择 cell 强度：G=1 积云 Ac，G=0 层云 As
    float hiCellThickStr = lerp(_HP_HiAsCellThickStr, _HP_HiCellThickStr, hiType);

    // 细胞噪声采样（2D，仅用于高度带厚度调制）
    float2 hiWindUV     = float2(_HP_NoiseWindOffset.x, _HP_NoiseWindOffset.y)
                        / max(_HP_WeatherMapWorldSize, 0.01);
    float2 hiCellBaseUV = weatherUV * _HP_HiCellScale     + hiWindUV * _HP_HiCellWindSpeed;
    float2 hiCellWarpUV = weatherUV * _HP_HiCellWarpScale + hiWindUV * _HP_HiCellWindSpeed * 0.5;
    float2 hiCellWarp   = (SAMPLE_TEXTURE2D_LOD(_HP_HiCellWarpTex, s_linear_repeat_sampler,
                                                hiCellWarpUV, 0).rg * 2.0 - 1.0) * _HP_HiCellWarpStr;
    float  hiCellRaw    = saturate(SAMPLE_TEXTURE2D_LOD(_HP_HiCellNoiseTex, s_linear_repeat_sampler,
                                                        hiCellBaseUV + hiCellWarp, 0).r);

    // cover → 云顶：pow 曲线调节响应速度，底部固定在 HiCloudBottom
    float hiCoverForHeight = pow(hiEffCoverage, max(_HP_HiHeightCurvePow, 0.01));
    float hiDrivenTop      = lerp(_HP_HiCloudBottom, _HP_HiCloudTop, hiCoverForHeight);

    // cell pow 曲线：>1 使格子中心更亮、边界更暗
    float hiCellShaped  = pow(max(hiCellRaw, 0.001), max(_HP_HiCellThickPow, 0.01));

    // cell 向上压顶（次效果：间隙处云层变薄）
    float hiThickFactor = lerp(1.0, hiCellShaped, hiCellThickStr * 0.5);
    float hiCellEffTop    = _HP_HiCloudBottom + (hiDrivenTop - _HP_HiCloudBottom) * hiThickFactor;

    // 底部随 cover 下降：与顶部使用相同 hiCoverForHeight 曲线，向下扩展 _HP_HiBottomCovScale 倍范围
    float hiCellEffBottom = _HP_HiCloudBottom
                          - (_HP_HiCloudTop - _HP_HiCloudBottom) * _HP_HiBottomCovScale * hiCoverForHeight;

    // 远处水平压低：XZ 距离越大，高度带整体平行下移，厚度不变
    float hiDistXZ      = length((positionWS - _WorldSpaceCameraPos.xyz).xz);
    float hiDistT       = smoothstep(_HP_HiHorizonDistStart,
                                     max(_HP_HiHorizonDistStart + 1.0, _HP_HiHorizonDistEnd), hiDistXZ);
    float hiHorizonShift = hiDistT * hiCellEffBottom;
    float hiAdjBottom    = hiCellEffBottom - hiHorizonShift;
    float hiAdjTop       = hiCellEffTop    - hiHorizonShift;

    // 高度带蒙版（软边，底部向下扩、顶部向上扩）
    float hiBandMask  = smoothstep(hiAdjBottom - _HP_HiCloudSoft, hiAdjBottom + _HP_HiCloudSoft, normalizedHeight)
                      * (1.0 - smoothstep(hiAdjTop - _HP_HiCloudSoft, hiAdjTop + _HP_HiCloudSoft, normalizedHeight));

    // 云絮：独立纹理槽（_HP_HiWispTex），留空时由 RenderDriver 传入 Texture2D.whiteTexture
    float2 hiWispUV   = weatherUV * _HP_HiWispScale + hiWindUV * _HP_HiCellWindSpeed;
    float  hiWisp     = SAMPLE_TEXTURE2D_LOD(_HP_HiWispTex, s_linear_repeat_sampler, hiWispUV, 0).r;
    hiWisp = saturate(pow(hiWisp,2));

    // 密度：cover 经阈值化后驱动，低于阈值为 0，超出后在 softness 宽度内线性升至 1
    float hiBaseDensity = saturate(DensityRemap(hiEffCoverage,
                                                _HP_HiDensityThreshold,
                                                _HP_HiDensityThreshold + max(_HP_HiDensitySoftness, 0.001),
                                                0.0, 1.0));

    // cell 直接调制密度（主效果）：间隙处密度归零，格子中心保留满密度
    float hiCellFactor = lerp(1.0, hiCellShaped, hiCellThickStr);
    float hiDensity = (hiBaseDensity * hiCellFactor - hiWisp * _HP_HiWispStrength * hiType) * hiBandMask;

    return max(0.0, hiDensity * _HP_DensityMultiplierHi);
}

// Structure that holds the result of our volumetric ray
struct VolumetricRayResult
{
    // Amount of lighting that comes from the clouds
    float3 inScattering;
    // Transmittance through the clouds
    float transmittance;
    // Mean distance of the clouds
    float meanDistance;
    // Flag that defines if the ray is valid or not
    bool invalidRay;
};

// Function that intersects a ray in absolute world space, the ray is guaranteed to start inside the volume
bool GetCloudVolumeIntersection_Light(float3 originWS, float3 dir, out float totalDistance)
{
    // Given that this is a light ray, it will always start from inside the volume and is guaranteed to exit
    float2 intersection, intersectionEarth;
    RaySphereIntersection(originWS, dir, _HighestCloudAltitude + _EarthRadius, intersection);
    bool intersectEarth = RaySphereIntersection(originWS, dir, _EarthRadius);
    totalDistance = intersection.x;
    // If the ray intersects the earth, then the sun is occlued by the earth
    return !intersectEarth;
}

// ── EvaluateSunLuminance 光步：HanPi 锥形采样 ─────────────────────────────────
// 几何级数的相邻步比率（越大→近密远疏越明显；越接近 1→越接近均匀步进）
#define CONE_RATIO      2.0f
// 首步宽度下限（m）。步数很多时反解出的 w0 可能过小，用它兜底防止退化。
#define CONE_MIN_STEP   5.0f
// 锥形采样的总覆盖距离上限（m）。应贴近真实云内光程，别用过大值，
// 否则步数会被浪费在远处空气上（那里 density≈0，对自阴影无贡献）。
#define CONE_MAX_DISTANCE 6000.0f

// Function that evaluates the luminance at a given cloud position (only the contribution of the sun)
float3 EvaluateSunLuminance(float3 positionWS, float3 sunDirection, float3 sunColor, PHASE_FUNCTION_STRUCTURE phaseFunction, out float lightExtinctionOD, out float phiFwd)
{
    float totalLightDistance = 0.0;
    float3 luminance = float3(0.0, 0.0, 0.0);
    lightExtinctionOD = 0.0;
    phiFwd           = 0.0;

    if (GetCloudVolumeIntersection_Light(positionWS, sunDirection, totalLightDistance))
    {
        // ── HanPi 锥形采样（自适应首步：步数=精度）──────────────────────────
        // 固定比率 r，反解首步宽度 w0，使 N 步几何级数正好覆盖 coverDist：
        //   coverDist = w0·(rⁿ−1)/(r−1)  →  w0 = coverDist·(r−1)/(rⁿ−1)
        // 步数越多 → w0 越小 → 近处采样越密，而总覆盖不变 → 加步数真正提精度。
        float coverDist = clamp(totalLightDistance, 0.0f, CONE_MAX_DISTANCE);

        int   numSteps = max(_NumLightSteps, 1);
        float r        = CONE_RATIO;
        // r^N 用 PositivePow，避免 N 较大时数值问题；r>1 时分母恒为正。
        float w0       = coverDist * (r - 1.0f) / max(PositivePow(r, (float)numSteps) - 1.0f, 1e-4f);
        w0             = max(w0, CONE_MIN_STEP);

        float extinctionSum = 0.0f;
        float kappaODSum    = 0.0f; // phi_fwd：观测点→当前步入口的 ∫κ ds 累积
        float T_cum         = 1.0f;
        float curWidth      = w0;
        float cumDist       = 0.0f;
        [loop]
        for (int j = 0; j < numSteps; j++)
        {
            float stepWidth = min(curWidth, coverDist - cumDist);
            if (stepWidth <= 0.0f) break;

            float dist = cumDist + stepWidth * 0.5f; // 步中心距观测点，作 r_j 与 κ 积分终点

            float3 samplePosWS = positionWS + sunDirection * dist;
            CloudProperties lightRayCloudProperties;
            float mipOffset = (float)j / max((float)(numSteps - 1), 1.0f) * 3.0f;
            EvaluateCloudProperties(samplePosWS, mipOffset, 0.0, false, lightRayCloudProperties);

            // 局部 σ：每步从 density·sigmaT 拆出；ω_0 写死，源强 Q ∝ σ_s·Δs
            float sigma_t   = lightRayCloudProperties.density * lightRayCloudProperties.sigmaT;
            float sigma_s   = sigma_t * HP_PHIFWD_OMEGA0;
            float localOD   = sigma_t * stepWidth;   // ∫σ_t ds，本步光学厚度
            float localOD_s = sigma_s * stepWidth;   // 散射源强度 ∝ σ_s·Δs

            // ── phi_fwd 1D 格林函数：φ += T_src·Q·exp(−∫κ ds)·(1/r) ──
            // T_src 用扩散源的慢衰减近似，而不是单次散射的 exp(-τ) 快速衰减。
            // g=0 → κ = σ_t·sqrt(3(1−ω_0))，故 κ·Δs = localOD·KAPPA_OD_SCALE（sqrt 在宏里）
            float kappaStep     = localOD * HP_PHIFWD_KAPPA_OD_SCALE;
            // 体积衰减积到步中心（与 samplePosWS / dist 一致）：入口累积 + 本步半步（中点法则）
            float kappaToCenter = kappaODSum + kappaStep * 0.5f;
            float perSrcExp    = exp(-kappaToCenter);
            float invR         = 1.0f / max(dist, stepWidth * 0.5f); // 几何衰减 1/r_j，r_j = 到步中心距离
            phiFwd            += (T_cum) * localOD_s * perSrcExp * invR;

            extinctionSum += localOD;
            kappaODSum    += kappaStep; // 下一步入口的 ∫κ ds

            float T_step = exp(-localOD * _HP_PhiFwd_ODScale);

            T_cum            *= T_step;

            cumDist  += stepWidth;
            curWidth *= CONE_RATIO;
        }
        lightExtinctionOD = extinctionSum; // 传出：沿光线方向的原始光学厚度，供 EvaluateCloud 计算向上 AO
        

        // exp(-κr) 和 1/r 均已在循环内逐步施加，循环外不再需要额外 transport 衰减。

        float3 extinction = _ScatteringTint.xyz * extinctionSum * _HP_LightAbsorption;
        // Hillaire 2020 three-parameter MS: attenuation(a), contribution(b), eccentricity(c) are independent.
        // attFactor scales the optical depth per octave; conFactor scales the luminance weight.
        // 方向性散射（各向异性）不施加 powder effect，保留云边缘的真实前向散射亮边。
        for (int o = 0; o < NUM_MULTI_SCATTERING_OCTAVES; ++o)
        {
            float attFactor = PositivePow(_HP_MS_Attenuation,  o);
            float conFactor = PositivePow(_HP_MS_Contribution, o);
            float3 transmittance = exp(-extinction * attFactor);
            luminance += transmittance * sunColor * phaseFunction[o] * conFactor;
        }
    }

    return luminance;
}

// ─────────────────────────────────────────────────────────────────────────────
// EvaluateSunLuminanceHighCloud — 高空云专用太阳光照评估
//
// 与 EvaluateSunLuminance 结构相同，但光步全部用 EvaluateHighCloudDensity，
// 不采样 3D 噪声，适合高空云自阴影（薄层，少量均匀步进已足够）。
// ─────────────────────────────────────────────────────────────────────────────
float3 EvaluateSunLuminanceHighCloud(float3 positionWS, float3 sunDirection, float3 sunColor,
                                     float powderEffect, PHASE_FUNCTION_STRUCTURE phaseFunction,
                                     float coverBright)
{
    float  totalLightDistance = 0.0;
    float3 luminance          = float3(0.0, 0.0, 0.0);

    if (!GetCloudVolumeIntersection_Light(positionWS, sunDirection, totalLightDistance))
        return luminance;

    // 高空云光步：限制在 3km 内（超出后密度≈0，不影响自阴影）
    int   numSteps     = max(_NumLightSteps, 1);
    float coverDist    = min(totalLightDistance, 3000.0);
    float intervalSize = coverDist / (float)numSteps;

    float extinctionSum = 0.0;
    [loop]
    for (int j = 0; j < numSteps; j++)
    {
        float  dist      = intervalSize * (0.5 + (float)j);
        float3 samplePos = positionWS + sunDirection * dist;
        float  dummyH;
        extinctionSum += EvaluateHighCloudDensity(samplePos, dummyH) * intervalSize;
    }

    float3 sunColorXPowder = sunColor * powderEffect;
    // Cover 越亮 → 太阳光吸收越强（云层越厚实，自阴影越明显）
    float  coverAbsMod     = 1.0 + coverBright * _HP_Hi_CoverAbsorptionStr;
    float3 extinction      = _ScatteringTint.xyz * extinctionSum * _HP_Hi_LightAbsorption * coverAbsMod;

    for (int o = 0; o < NUM_MULTI_SCATTERING_OCTAVES; ++o)
    {
        float  attFactor     = PositivePow(_HP_Hi_MS_Attenuation,  o);
        float  conFactor     = PositivePow(_HP_Hi_MS_Contribution, o);
        float3 transmittance = exp(-extinction * attFactor);
        luminance += transmittance * sunColorXPowder * phaseFunction[o] * conFactor;
    }

    return luminance;
}

// Evaluates the inscattering from this position
void EvaluateCloud(CloudProperties cloudProperties, EnvironmentLighting envLighting,
                float3 currentPositionWS, float stepSize, float relativeRayDistance,
                inout VolumetricRayResult volumetricRay)
{

    // ── 低云 Cover（R）：MS Boost 强度代理 ─────────────────────────────────────
    float2 msWeatherUV = HP_ComputeWeatherMapUV(currentPositionWS.xz);
    float  msWeight    = HP_IsInsideWeatherMapUV(msWeatherUV)
                       ? SAMPLE_TEXTURE2D_LOD(_CloudMapTexture, s_linear_clamp_sampler, msWeatherUV, 0).r
                       : 0.0;

    // Apply the extinction
    // 消光门控仍用高空云天气图 A 通道（原逻辑）；msWeight 仅驱动下方 MS Boost。
    // ExtContrast 曲线调制后，在 [1-ExtIntensity, 1] 区间内缩放消光。
    float msWeightForExt  = HP_IsInsideWeatherMapUV(msWeatherUV)
                          ? SAMPLE_TEXTURE2D_LOD(_CloudMapHiTexture, s_linear_clamp_sampler, msWeatherUV, 0).a
                          : 0.0;
    float msWeightExt     = PositivePow(saturate(msWeightForExt), _HP_MSW_ExtContrast);
    float extMSScale      = lerp(1.0 - _HP_MSW_ExtIntensity, 1.0, msWeightExt);
    const float extinction = cloudProperties.density * cloudProperties.sigmaT
        * _HP_ViewAbsorption
        * extMSScale;
    const float transmittance = exp(-extinction * stepSize);

    // Evaluate the sun color at the position
    float3 sunColor = EvaluateSunColor(envLighting, relativeRayDistance);

    // Evaluate the sun's luminance
    float lightExtinctionOD;
    float phiFwd;
    float3 totalLuminance = EvaluateSunLuminance(currentPositionWS, envLighting.sunDirection, sunColor, envLighting.phaseFunction, lightExtinctionOD, phiFwd);

    // phi_fwd 仍由 msWeight 调制强度。
    float msWeightMS = PositivePow(saturate(msWeight), _HP_MSW_MSContrast);

    // ── 散射积分步长 ──────────────────────────────────────────────────────────
    // 低密度边缘不具备足够光学厚度建立完整散射，因此方向性、phi_fwd 与环境散射
    // 共用同一个密度门控后的有效散射步长；视线透射率仍用完整 extinction 保持云体不透明度。
    float densityScatterGate   = HP_DENSITY_SCATTER_GATE(
        cloudProperties.density,
        _HP_DensityScatterGateThresh,
        _HP_DensityScatterGatePow);
    float scatterTransmittance = exp(-extinction * stepSize * densityScatterGate);

    // 方向性散射：密度门控后的有效步长积分
    float3 integScatt = totalLuminance - totalLuminance * scatterTransmittance;

    // ── phi_fwd 物理漫射场加性散射（PhiFwd Diffuse Field） ───────────────────
    // phiFwd 是沿光线步进积累的各向同性漫射场能量密度（无量纲 OD 加权积分）。
    // 与 Hillaire 乘性 MS 正交：这是独立的加性散射项，代表真实扩散的漫射辐射场。
    // 使用 scatterTransmittance（density-gated）做步长积分：
    //   densityScatterGate≈0（稀薄边缘）→ 积分量趋近 0
    //   densityScatterGate≈1（稠密核心）→ 完整散射积分
    //
    // DepthPow 修正：phi_fwd 从视线采样点出发向太阳积分，云底采样点会积累到整个云柱的散射源，
    // 导致底部 phiFwd 反而最大——与真实扩散场（从顶向下衰减）相反。
    // 用 localHeight^DepthPow 修正：localHeight=1（云顶）→ 权重满；localHeight=0（云底）→ 权重最小。
    if (_HP_PhiFwd_Intensity > 0.0)
    {
        float phiFwdDepthCorrect = (_HP_PhiFwd_DepthPow > 0.0)
            ? PositivePow(saturate(cloudProperties.localHeight + _HP_PhiFwd_DepthBias), _HP_PhiFwd_DepthPow)
            : 1.0;
        float phiFwdBoundaryLight = HP_EvaluatePhiFwdBoundaryLight(currentPositionWS, envLighting.sunDirection);
        phiFwdDepthCorrect *= phiFwdBoundaryLight;
        float3 phiFwdLuminance = phiFwd * sunColor * (_HP_PhiFwd_Intensity * msWeightMS * _HP_MSW_MSIntensity * phiFwdDepthCorrect);
        integScatt += phiFwdLuminance - phiFwdLuminance * scatterTransmittance;
    }

    // ── 环境光散射（独立积分，使用完整 stepSize）────────────────────────────
    // upwardAO：用太阳光路的真实光学深度估算当前点到天顶方向的透射率。
    // lightExtinctionOD 是沿太阳方向的真实 OD；乘以 sin(仰角) 折算为竖直方向 OD。
    //   太阳仰角 90°（正午）：sinElev=1，折算精确。
    //   太阳仰角 30°：sinElev=0.5，折算保守（实际遮蔽可能更强），但远比几何代理准确。
    // _HP_AOUpwardScale 语义从"指数"变为"OD 缩放"：1.0=物理值，>1 加强遮蔽，<1 减弱。
    float  sinElev             = max(envLighting.sunDirection.y, 0.05);
    float  zenithOD            = lightExtinctionOD * sinElev;
    float  upwardAO            = exp(-zenithOD * max(_HP_AOUpwardScale, 0.0));
    // 上方天空光：被当前点上方的云遮挡 → upwardAO（由 lightExtinctionOD × sinElev 估算）
    // 下方地面/大气光：被当前点下方的云遮挡 → (1 - height) 几何代理
    //   height = slab 归一化真实海拔高度，与廓形/LUT/Sc 无关，单调反映竖直距离。
    //   height=0（slab底）→ 下方几乎无云 → bottom 光自由到达 → downwardAO≈1
    //   height=1（slab顶）→ 整层云在下方 → bottom 光大量遮蔽 → downwardAO≈0
    float3 ambientTerm         = envLighting.ambientTermTop    * upwardAO
                               + envLighting.ambientTermBottom * (1.0 - cloudProperties.height);
    integScatt                += ambientTerm - ambientTerm * scatterTransmittance;

    volumetricRay.inScattering += integScatt * volumetricRay.transmittance;
    volumetricRay.transmittance *= transmittance;
}

// Global attenuation of the density based on the camera distance
float DensityFadeValue(float distanceToCamera)
{
    return saturate((distanceToCamera - _FadeInStart) / (_FadeInStart + _FadeInDistance));
}

// This function compute the checkerboard undersampling position
int ComputeCheckerBoardIndex(int2 traceCoord, int subPixelIndex)
{
    int localOffset = ((traceCoord.x & 1) + (traceCoord.y & 1)) & 1;
    int checkerBoardLocation = (subPixelIndex + localOffset) & 0x3;
    return checkerBoardLocation;
}

float EvaluateFinalTransmittance(float3 color, float transmittance)
{
    // Due to the high intensity of the sun, we often need apply the transmittance in a tonemapped space
    // As we only produce one transmittance, we evaluate the approximation on the luminance of the color
    float luminance = Luminance(color);    // Apply the tone mapping and then the transmittance
    float resultLuminance = luminance / (1.0 + luminance) * transmittance;

    // reverse the tone mapping
    resultLuminance = resultLuminance / (1.0 - resultLuminance);

    // By softening the transmittance attenuation curve for pixels adjacent to cloud boundaries when the luminance is super high,  
    // We can prevent sun flicker and improve perceptual blending. (https://www.desmos.com/calculator/vmly6erwdo)
    float finalTransmittance = max(resultLuminance / luminance, pow(transmittance, 6));

    // This approach only makes sense if the color is not black
    return luminance > 0.0 ? lerp(transmittance, finalTransmittance, _ImprovedTransmittanceBlend) : transmittance;
}

// ─────────────────────────────────────────────────────────────────────────────
// HPTraceVolumetricRay — 球壳求交 + HZD 风格分层步进
//
// 解决的根本问题：
//   原先 stepS = totalDist / _NumPrimarySteps 在低仰角 / 地平线方向，
//   totalDist 会因为球壳几何膨胀到几十公里，导致单步动辄几百~几千米，
//   近处只有几百米厚的小云被整步跨过 → 你看到了"后面的云"。
//
// 做法（参考 Horizon Zero Dawn GPU Pro 7 / UE5 VolumetricCloud）：
//   1) stepLarge 距离自适应：近端 cap=slabH/16 防近云被跨过，远端 cap=slabH/2 让 budget 走完全程。
//   2) 天气图+LUT 门控后做完整密度采样，命中云体后精细积分。
//   3) 小步精细累积 inScattering / transmittance（small = large/4）。
//   4) 连续若干空小步后切回大步，继续找下一团云。
//   5) meanDistance 按 transmittance*density 加权，深度更稳定。
// ─────────────────────────────────────────────────────────────────────────────
VolumetricRayResult HPTraceVolumetricRay(CloudRay cloudRay)
{
    VolumetricRayResult result;
    result.inScattering  = 0.0;
    result.transmittance = 1.0;
    result.meanDistance  = _MaxCloudDistance;
    result.invalidRay    = true;

    RayMarchRange rayMarchRange;
    if (!GetCloudVolumeIntersection(cloudRay.originWS, cloudRay.direction,
                                    cloudRay.insideClouds, cloudRay.toEarthCenter,
                                    rayMarchRange))
        return result;

    if (cloudRay.maxRayLength < rayMarchRange.start)
        return result;

    float totalDist = min(rayMarchRange.distance, cloudRay.maxRayLength - rayMarchRange.start);
    if (totalDist <= 0.0)
        return result;

    // ── 基础步长 + 距离自适应上限 ─────────────────────────────────────
    // cap 由两项取 min：
    //   1) 绝对视距 cap：absDist / HP_STEP_VIEW_DIV
    //      与相机到采样点的绝对距离成正比，50m处→约6m，200m处→约25m，真正解决近云跨步问题。
    //   2) 云层厚度 cap：lerp(slabH/16, slabH/2, pow(distNorm, EXP))
    //      按云层内行进距离渐变，防止远端步长超过云层结构尺度。
    // 两项 min 保证近处绝对精细、远处按厚度约束、中间平滑过渡。
    #define HP_STEP_CAP_CURVE_EXP 2.0
    #define HP_STEP_VIEW_DIV      8.0   // 视距步长比：absDist/8，越大步长越细但迭代越多
    float slabThickness    = max(_HighestCloudAltitude - _LowestCloudAltitude, 1.0);
    float stepLargeRaw     = totalDist / max((float)_NumPrimarySteps, 1.0);
    float stepLargeNearCap = slabThickness * 0.0625;   // 云层厚度近端 cap：slabH/16
    float stepLargeFarCap  = slabThickness * 0.5;      // 云层厚度远端 cap：slabH/2
    float farDistRef       = _MaxRayMarchingDistance;  // 50km：远端 cap 完全生效的距离

    // ── 预计算环境光照（入口/出口两点）────
    float3 rayMarchStartPos = cloudRay.originWS + rayMarchRange.start * cloudRay.direction;
    float3 rayMarchEndPos   = rayMarchStartPos  + totalDist           * cloudRay.direction;
    cloudRay.envLighting = EvaluateEnvironmentLighting(cloudRay, rayMarchStartPos, rayMarchEndPos);

    // 起点抖动：用近端步长，避免初始就跳太远
    float dist           = cloudRay.integrationNoise * stepLargeNearCap;
    float meanDistAccum  = 0.0;
    float meanDistWeight = 0.0;

    // ── 简单模式步进（距离驱动 + 迭代保险上限）────────────────────────────────
    // 主循环以 dist < totalDist 为条件，保证走完整个云层范围，不会因云层过厚提前截断。
    // _NumPrimarySteps * 4 作为保险上限（近处 stepSmall ≈ stepLarge/4，最多约 4× 倍迭代）。
    // 每步用 EvaluateCloudProperties(simpleMode=true) 做快速密度探测（跳过 erosion noise）：
    //   无密度 → 大步跳过（stepLarge），节省完整 3D 采样开销。
    //   有密度 → 补做完整采样（simpleMode=false）并积分，然后 stepSmall 推进。
    int iterCount = 0;
    int maxIter   = _NumPrimarySteps * 4;
    [loop]
    while (dist < totalDist && iterCount < maxIter)
    {
        iterCount++;

        float distNorm   = saturate(dist / farDistRef);
        float absDist    = rayMarchRange.start + dist;
        float viewCap    = absDist / HP_STEP_VIEW_DIV;
        float slabCap    = lerp(stepLargeNearCap, stepLargeFarCap, pow(distNorm, HP_STEP_CAP_CURVE_EXP));
        float stepLarge  = min(stepLargeRaw, min(viewCap, slabCap));
        float stepSmall  = stepLarge * 0.25;

        float3 pos = cloudRay.originWS + absDist * cloudRay.direction;

        // ── 简单模式统一门控：用 EvaluateCloudProperties(simpleMode=true) 判断是否有云 ──
        // 有密度 → 补做完整采样并积分，步进 stepSmall。
        // 无密度 → 大步跳过，节省完整 3D 噪声采样开销。
        CloudProperties simpleProps;
        EvaluateCloudProperties(pos, 1.0, 0.0, /*simpleMode=*/true, simpleProps);

        // ── Debug：可视化简单模式密度，取消注释下行即可开启 ──────────────────────
        // #define HP_DEBUG_SIMPLE_DENSITY
        #ifdef HP_DEBUG_SIMPLE_DENSITY
        {
            // Beer-Lambert 直接积分简单模式密度，跳过完整采样和光照，纯白色雾化显示。
            // 密度越高越不透明；stepSmall 单位 m，sigma 系数可调整显示对比度。
            #ifndef HP_DEBUG_SIMPLE_DENSITY_SCALE
            #define HP_DEBUG_SIMPLE_DENSITY_SCALE 1.0
            #endif
            float sigma = simpleProps.density * HP_DEBUG_SIMPLE_DENSITY_SCALE;
            float alpha = 1.0 - exp(-sigma * stepSmall);
            result.inScattering  += result.transmittance * alpha * 1.0;
            result.transmittance *= (1.0 - alpha);
            result.invalidRay     = false;
            if (result.transmittance < 0.003) { result.transmittance = 0.0; break; }
            dist += (simpleProps.density > HI_CLOUD_DENSITY_THRESHOLD) ? stepSmall : stepLarge;
            continue;
        }
        #endif

        if (simpleProps.density > HI_CLOUD_DENSITY_THRESHOLD)
        {
            // 简单模式找到云，补做完整采样以获得精确密度和 erosion 细节
            CloudProperties fullProps;
            EvaluateCloudProperties(pos, 0.0, 0.0, /*simpleMode=*/false, fullProps);

            if (fullProps.density > HI_CLOUD_DENSITY_THRESHOLD)
            {
                if (result.invalidRay) result.invalidRay = false;
                float twd = result.transmittance * fullProps.density;
                meanDistAccum  += absDist * twd;
                meanDistWeight += twd;

                // ── Debug：可视化高度，取消注释对应行开启 ───────────────────────────
                // #define HP_DEBUG_LOCAL_HEIGHT  // localHeight（LUT坐标，已证明不到顶）
                // #define HP_DEBUG_SLAB_HEIGHT   // height（slab真实海拔，用于downwardAO）
                #if defined(HP_DEBUG_LOCAL_HEIGHT) || defined(HP_DEBUG_SLAB_HEIGHT)
                {
                    // 颜色映射：0=黑，0.5=红，1=白（热力图）
                    #ifdef HP_DEBUG_SLAB_HEIGHT
                    float h = saturate(fullProps.height);
                    #else
                    float h = saturate(fullProps.localHeight);
                    #endif
                    float3 debugColor = lerp(float3(0,0,0), float3(1,0,0), saturate(h * 2.0))
                                      + lerp(float3(0,0,0), float3(1,1,1), saturate(h * 2.0 - 1.0));
                    float alpha = 1.0 - exp(-fullProps.density * fullProps.sigmaT * stepSmall);
                    result.inScattering  += result.transmittance * alpha * debugColor;
                    result.transmittance *= (1.0 - alpha);
                    result.invalidRay     = false;
                    if (result.transmittance < 0.003) { result.transmittance = 0.0; break; }
                    dist += stepSmall;
                    continue;
                }
                #endif

                EvaluateCloud(fullProps, cloudRay.envLighting, pos, stepSmall, dist / totalDist, result);
                if (result.transmittance < 0.003) { result.transmittance = 0.0; break; }
            }
            dist += stepSmall;
        }
        else
        {
            dist += stepLarge;
        }
    }

    if (meanDistWeight > 0.0)
        result.meanDistance = meanDistAccum / meanDistWeight;

    // ── 高空云（Ac/As）独立步进循环 ──────────────────────────────────────────
    // 高空云仅依赖 2D 纹理（无 3D 噪声），可用较少步数独立步进。
    // 结果累积到 hiResult，最后按相机与高云层的相对位置合成到 result。

    // 方案4：整条射线天气图门控
    // 在射线入口处用低 mip 采样天气图 .a，整片区域无高空云则跳过后续所有计算。
    // Mip=2 取面积平均，既抑制单点误判，又比 Mip=0 更快（纹理缓存友好）。
    float2 hiGateUV  = HP_ComputeWeatherMapUV(rayMarchStartPos.xz);
    float  hiGateCov = HP_IsInsideWeatherMapUV(hiGateUV)
                     ? SAMPLE_TEXTURE2D_LOD(_CloudMapHiTexture, s_linear_clamp_sampler, hiGateUV, 2).r
                     : 0.0;

    // hiGateCov > 0 时才进入高空云的全部计算（相函数/循环/合成）
    if (hiGateCov > 0.001)
    {
        // 预计算高空云专用相函数（使用独立偏心率参数，与低云无关）
        PHASE_FUNCTION_STRUCTURE hiPhaseFunction = 0;
        {
            float hiCos = cloudRay.envLighting.cosAngle;
            hiPhaseFunction[0] = HenyeyGreenstein(hiCos,  _HP_Hi_ForwardEccentricity  * PositivePow(_HP_Hi_MS_Eccentricity, 0))
                               + HenyeyGreenstein(hiCos, -_HP_Hi_BackwardEccentricity * PositivePow(_HP_Hi_MS_Eccentricity, 0));
            #if NUM_MULTI_SCATTERING_OCTAVES >= 2
            hiPhaseFunction[1] = HenyeyGreenstein(hiCos,  _HP_Hi_ForwardEccentricity  * PositivePow(_HP_Hi_MS_Eccentricity, 1))
                               + HenyeyGreenstein(hiCos, -_HP_Hi_BackwardEccentricity * PositivePow(_HP_Hi_MS_Eccentricity, 1));
            #endif
            #if NUM_MULTI_SCATTERING_OCTAVES >= 3
            hiPhaseFunction[2] = HenyeyGreenstein(hiCos,  _HP_Hi_ForwardEccentricity  * PositivePow(_HP_Hi_MS_Eccentricity, 2))
                               + HenyeyGreenstein(hiCos, -_HP_Hi_BackwardEccentricity * PositivePow(_HP_Hi_MS_Eccentricity, 2));
            #endif
        }

        // 高空云环境光（云顶倍增独立，云底复用低云底部项）
        float3 hiAmbientTop    = cloudRay.envLighting.ambientTermTop
                               / max(_HP_AmbientTopMultiplier, 0.001) * _HP_Hi_AmbientTopMultiplier;
        float3 hiAmbientBottom = cloudRay.envLighting.ambientTermBottom * _HP_Hi_AmbientBottomMultiplier;

        VolumetricRayResult hiResult;
        hiResult.inScattering  = 0.0;
        hiResult.transmittance = 1.0;
        hiResult.meanDistance  = _MaxCloudDistance;
        hiResult.invalidRay    = true;

        {
            // 均匀步进，与主循环步数一致（高空云无 3D 噪声，均匀分布足够精确）
            int   hiMaxIter  = max(_NumPrimarySteps*2, 4);
            float hiStepSize = totalDist / (float)hiMaxIter;
            float hiDist     = cloudRay.integrationNoise * hiStepSize;
            float hiMeanAccum  = 0.0;
            float hiMeanWeight = 0.0;

            [loop]
            for (int hi = 0; hi < hiMaxIter && hiDist < totalDist; hi++, hiDist += hiStepSize)
            {
                float  hiAbsDist = rayMarchRange.start + hiDist;
                float3 hiPos     = cloudRay.originWS + hiAbsDist * cloudRay.direction;

                float hiNormH;
                float hiDensity = EvaluateHighCloudDensity(hiPos, hiNormH);

                if (hiDensity > HI_CLOUD_DENSITY_THRESHOLD)
                {
                    if (hiResult.invalidRay) hiResult.invalidRay = false;

                    float hiTwd     = hiResult.transmittance * hiDensity;
                    hiMeanAccum    += hiAbsDist * hiTwd;
                    hiMeanWeight   += hiTwd;

                    // ── 天气图采样（R=Cover亮度，A=MS权重），供消光映射与亮度 Boost 共用 ──
                    float2 hiMsUV        = HP_ComputeWeatherMapUV(hiPos.xz);
                    float4 hiWeatherSamp = HP_IsInsideWeatherMapUV(hiMsUV)
                                        ? SAMPLE_TEXTURE2D_LOD(_CloudMapHiTexture, s_linear_clamp_sampler, hiMsUV, 0)
                                        : float4(0, 0, 0, 0);
                    float  hiMsWeight    = hiWeatherSamp.a;
                    // Cover 亮度（R 通道）传入光照函数，供太阳光吸收调制使用
                    float  hiCoverBright = hiWeatherSamp.r;

                    // 高空云消光使用独立 _HP_Hi_ViewAbsorption
                    // hiMsWeight 高（厚云列）时多重散射保留更多能量，有效消光降低。
                    float hiExtinct = hiDensity * _HP_Hi_ViewAbsorption * hiMsWeight;
                    float hiTransm  = exp(-hiExtinct * hiStepSize);

                    float  powderEffect   = PowderEffect(hiDensity, cloudRay.envLighting.cosAngle, _PowderEffectIntensity);
                    float3 sunColor       = EvaluateSunColor(cloudRay.envLighting, hiDist / totalDist);
                    float3 totalLuminance = EvaluateSunLuminanceHighCloud(
                                                hiPos,
                                                cloudRay.envLighting.sunDirection,
                                                sunColor, powderEffect,
                                                hiPhaseFunction,
                                                hiCoverBright);

                    // 环境光：使用高空云独立 AmbientTopMultiplier
                    totalLuminance += lerp(hiAmbientBottom, hiAmbientTop, hiNormH);

                    // hiMsWeight 高（厚云列）时 MS 贡献更强。
                    totalLuminance *= hiMsWeight;

                    // ── 高空云天空色混合（Sky Blend） ─────────────────────────────
                    // hiNormH 越大（云层顶部）→ 越接近天空色，模拟大气稀薄处云体溶入天空的效果。
                    // 使用视线方向采样 SH 探针，与相机朝向天空的颜色对齐。
                    float3 skyColorForBlend = SampleSH9(_VolumetricCloudsAmbientProbeBuffer, cloudRay.direction)
                                           * GetCurrentExposureMultiplier();
                    float  skyBlend        = smoothstep(0.0, 1.0, hiNormH) * _HP_Hi_SkyBlendStrength;
                    totalLuminance         = lerp(totalLuminance, skyColorForBlend, skyBlend);

                    // Beer-Lambert 解析积分（与 EvaluateCloud 相同形式，高空云暂不使用低密度散射门控）
                    const float3 integScatt = (totalLuminance - totalLuminance * hiTransm);
                    hiResult.inScattering  += integScatt * hiResult.transmittance;
                    hiResult.transmittance *= hiTransm;

                    if (hiResult.transmittance < 0.003) { hiResult.transmittance = 0.0; break; }
                }
            }

            if (hiMeanWeight > 0.0)
                hiResult.meanDistance = hiMeanAccum / hiMeanWeight;
        }

        // ── 合成低云 + 高空云 ─────────────────────────────────────────────────
        // 叠加顺序取决于相机相对高云层底部的位置：
        //   相机在高云层以下（地面视角）：沿射线先遇低云 → lo + T_lo * hi
        //   相机在高云层以上（高空俯视）：沿射线先遇高云 → hi + T_hi * lo
        if (!hiResult.invalidRay)
        {
            float hiCloudBottomAlt = _LowestCloudAltitude
                                   + _HP_HiCloudBottom * (_HighestCloudAltitude - _LowestCloudAltitude);
            if (_WorldSpaceCameraPos.y >= hiCloudBottomAlt)
            {
                // 高云在前：hi + T_hi * lo
                float3 combined  = hiResult.inScattering + hiResult.transmittance * result.inScattering;
                float  combinedT = hiResult.transmittance * result.transmittance;
                result.inScattering  = combined;
                result.transmittance = combinedT;
            }
            else
            {
                // 低云在前：lo + T_lo * hi
                result.inScattering  += result.transmittance * hiResult.inScattering;
                result.transmittance *= hiResult.transmittance;
            }

            // meanDistance：取两层中贡献更大（更近）的那个
            if (result.invalidRay)
            {
                result.meanDistance = hiResult.meanDistance;
                result.invalidRay   = false;
            }
            else
            {
                result.meanDistance = min(result.meanDistance, hiResult.meanDistance);
            }
        }
    } // end if (hiGateCov > 0.001)

    return result;
}

#endif // VOLUMETRIC_CLOUD_UTILITIES_H
