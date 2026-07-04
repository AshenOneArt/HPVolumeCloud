# 从辐射传输方程到 phi_fwd：物理推导

本文档记录 HanPi 体积云 **phi_fwd 漫射场** 的物理推导链：从辐射传输方程（RTE）出发，经扩散近似与格林函数积分解，到离散近似公式。

---

## 一、辐射传输方程（RTE）

云的光照本质是求解**辐射传输方程**：

```math
\frac{dL(\mathbf{x}, \boldsymbol{\omega})}{ds}
= -\sigma_t \, L
+ \sigma_s \int_{4\pi} f_p(\boldsymbol{\omega}', \boldsymbol{\omega}) \, L(\mathbf{x}, \boldsymbol{\omega}') \, d\boldsymbol{\omega}'
```

| 符号 | 含义 |
|---|---|
| L(x, ω) | 位置 x、沿方向 ω 的**方向性**辐亮度 |
| σ_t | 总消光系数（吸收 + 散射） |
| σ_s | 散射系数 |
| f_p | 相位函数（HG 等，描述散射方向分布） |

**关键点：** 积分里的 L(x, ω') 本身已是多重散射后的结果——方程是**递归的**，无法解析求解，必须近似。

### 单次散射 vs 多重散射

| — | 单次散射 | 多重散射 |
|---|---|---|
| 光子路径 | 太阳 → 云内一点 → 眼睛 | 太阳 → 云内多次弹射 → 眼睛 |
| 方向性 | 强相位函数（HG 向前散射） | 越来越各向同性 |
| 厚云内部 | 指数衰减，内部极暗 | 亮度在 τ > 1 后趋于饱和 |
| 云底 | 接近 0 | 侧面和底面有可见发光 |

---

## 二、扩散近似（τ ≫ 1）

RTE 中的 L(x, ω) 同时依赖位置和方向，且源项递归依赖自身，无法直接解析。当光学厚度 τ = σ_t · d ≫ 1 时，光子在介质内经历大量散射，方向记忆消失，运动退化为随机游走；此时方向性分量可忽略，用标量漫射场 φ(x)（各向同性辐照度）代替完整辐射场，RTE 退化为扩散方程。

**τ ≫ 1 的推论：** 有效各向异性 g_eff → 0，散射近乎各向同性，故 σ_tr = σ_a + σ_s(1-g) → σ_t。后文 phi_fwd 链及用光学深度 OD（∫ σ_t ds）近似 ∫ κ ds，均建立在此 regime 上。

```math
-D \nabla^2 \phi(\mathbf{x}) + \sigma_a \phi(\mathbf{x}) = Q(\mathbf{x})
```

| 项 | 符号 | 含义 |
|---|---|---|
| 漫射场 | φ(x) | 位置 x 处的漫射辐照度（各向同性分量） |
| 扩散项 | -D ∇² φ(x) | 能量从高处向低处扩散；∇² 为拉普拉斯算子，D 为扩散系数 |
| 吸收项 | σ_a φ(x) | 介质对漫射光的吸收损耗；σ_a 为吸收系数 |
| 源项 | Q(x) | 位置 x 处注入的散射能量（如直射光在云内沉积） |

---

## 三、积分解：格林函数 G 的形式

将扩散方程改写为 Helmholtz 型：

```math
\nabla^2 \phi(\mathbf{x}) - \kappa^2 \phi(\mathbf{x}) = -\frac{Q(\mathbf{x})}{D},
\qquad \kappa^2 = \frac{\sigma_a}{D}
```

用格林函数 G(x, x') 的形式解：

```math
\phi(\mathbf{x})
= \int_V G(\mathbf{x}, \mathbf{x}') \,\frac{Q(\mathbf{x}')}{D}\, dV'
\;+\; \text{边界项}
```

| 项 | 含义 |
|---|---|
| φ(x) | 观测点 x 处的漫射辐照度 |
| ∫_V … dV' | 对体积内所有源点 x' 求和（积分） |
| G(x, x') | 扩散核：源点 x' 对观测点 x 的传播响应 |
| Q(x') | 源点 x' 处注入的散射能量 |
| D | 扩散系数，出现在源项归一化中 |
| 边界项 | 云面/云底边界条件对 φ(x) 的额外贡献 |

即：φ(x) = 体积内每个散射源 Q(x') 经核 G 传到 x 的叠加，加上边界贡献。

---

**后续推导**

接下来需要：

1. 给出 G 的显式形式（§3.1，均匀介质闭式解）
2. 近似源项 Q、离散化为沿太阳方向的 1D 积分（§4）

方程中出现 D、κ、σ_a、σ_tr 等介质参数，G 的具体形式直接依赖 κ。下方前置知识用于说明这些符号，并在代入 G 前完成 κ 的推导。

---

**前置物理量说明**

| 符号 | 含义 | 物理直觉 |
|---|---|---|
| σ_t | 总消光系数，σ_t = σ_a + σ_s | 沿路径「会不会碰到粒子」；Beer–Lambert 自阴影、OD 用此项 |
| σ_a | 吸收系数 | 碰到后以非光形式消失；典型云 ω_0 ≈ 0.999，吸收极小 |
| σ_s | 散射系数 | 碰到后改向继续传播；多次散射累积形成漫射场 |
| σ_tr | Transport 消光，σ_tr = σ_a + σ_s(1-g)；τ ≫ 1 时 ≈ σ_t | 对随机游走 **真正有效**的消光；扩散 regime 下与 σ_t 等同 |
| ω_0 | 单散射反照率，ω_0 = σ_s / σ_t | 碰撞中散射 vs 吸收的比例；越接近 1 云越「白」、光越难被吃掉 |
| g | HG 相位函数偏心率（0 ~ 1） | 单次散射的前向程度；g 大 → 方向记忆久 → σ_tr ≪ σ_t |
| D | 扩散系数，见下方说明 | 漫射能量在体积里扩散的快慢 |
| κ | 扩散衰减系数，见下方推导 | 漫射能量传播时的「射程」倒数；κ 小 → 传得远、内部越均匀 |
| Q(x) | 源项（直射光在云内沉积的散射能量） | 把直射光「注入」漫射场的速率；面积分里的被积源 |

σ_t 管「碰不碰到」；σ_a / σ_s 管「碰到之后消失还是改向」；σ_tr 管「改向有没有真正打乱方向、能不能推动扩散」。

**注（τ ≫ 1）：** 本文扩散近似只适用于光学深度远大于 1 的区域。此时以各向同性散射为主，g_eff ≈ 0，可令 σ_tr ≈ σ_t；用 OD = ∫ σ_t ds 近似 ∫ κ ds 亦同此假设。τ ≪ 1 的边缘薄区不在此近似范围内。

---

**前置 σ_t、σ_a、σ_s 建模**

三者满足 σ_t = σ_a + σ_s。建模时通常**先定 σ_t 和 ω_0**，再拆分：

```math
\sigma_s = \omega_0 \cdot \sigma_t,
\qquad
\sigma_a = (1 - \omega_0) \cdot \sigma_t
```

**1. σ_t：总消光 — 由密度与质量消光系数决定**

```math
\sigma_t(\mathbf{x}) = \rho(\mathbf{x}) \cdot \kappa_e
```

| 符号 | 含义 |
|---|---|
| ρ(x) | 体积密度（如液态水含量 LWC，kg/m³） |
| κ_e | 质量消光系数（m²/kg） |

常用取值（可见光、典型水云）：κ_e ≈ 100 m²/kg（滴谱变化时约 50~150 m²/kg）。

积云芯部典型：ρ ≈ 0.001 kg/m³ → σ_t ≈ 0.1 m⁻¹。

**注（归一化）：** Beer–Lambert 与 OD 只依赖 σ_t，不单独依赖 ρ 或 κ_e。程序中 `density` ∈ [0,1] 为归一化场时，ρ_max 与 κ_e 可合并进一个系数：

```math
\sigma_t(\mathbf{x}) = \text{density}(\mathbf{x}) \cdot \underbrace{(\rho_{\max} \cdot \kappa_e)}_{\sigma_{t,\mathrm{ref}}}
```

| 标定方式 | 含义 |
|---|---|
| 固定 `density` 0~1，调 σ_t,ref | ρ_max κ_e 合并进参考消光；积云典型 ≈ 0.1 ~ 0.2 m⁻¹ |
| 固定 σ_t,ref，调 density 倍率 | ρ_max κ_e 合并进 density 缩放 |
| 两者同时调 | 只要乘积 σ_t 与现实同量级即可 |

物理上 ρ、κ_e 用于理解尺度；实现里不必分开，保证 σ_t 对就行。

**2. ω_0：单散射反照率 — 材质常数**

| 云类型 | 典型 ω_0 |
|---|---|
| 水云 | 0.999 ~ 0.9999 |
| 含少量吸收（烟尘、黑碳） | 略低 |

ω_0 接近 1 时，σ_a ≪ σ_s，云几乎只散射、不吸收。

**3. σ_s、σ_a：由 σ_t 与 ω_0 拆分**

源项 Q ≈ σ_s · T_sun 依赖 σ_s；扩散方程吸收项 σ_a φ 依赖 σ_a。

在 τ ≫ 1 的扩散 regime 下，ω_0 ≈ 1 时可进一步近似 σ_s ≈ σ_t、σ_a ≈ 0，此时 OD 与散射源强度共用同一 σ_t 尺度。

---

**前置 D 说明**

Eddington 近似下，扩散系数与 transport 消光的关系：

```math
D = \frac{1}{3\sigma_{tr}}
```

| 符号 | 含义 |
|---|---|
| D | 漫射场空间扩散的快慢；D 越大，能量扩散越快 |
| σ_tr | 光子随机游走时方向混合的有效消光；见上表 |

σ_tr 越小（如前向散射 g 大）→ D 越大 → 漫射传播越快。此式将扩散方程中的 D 与可测量的介质参数 σ_tr 联系起来，是后续推导 κ 的中间步骤。

---

**前置 κ 推导**

Helmholtz 型给出 κ^2 = σ_a / D，故 κ = √(σ_a / D)。代入上式 D = 1/(3σ_tr)：

```math
\kappa = \sqrt{\frac{\sigma_a}{D}} = \sqrt{3\sigma_a \sigma_{tr}}
```

---

### 3.1 均匀无限介质中的 G（κ 为常数）

```math
\boxed{
G(\mathbf{x}, \mathbf{x}') = \frac{e^{-\kappa r}}{4\pi r}
},
\qquad r = |\mathbf{x} - \mathbf{x}'|
```

| 因子 | 含义 |
|---|---|
| e^(-κ r) | 漫射光子在介质中随机游走到达 r 距离时的**体积衰减** |
| 1/(4π r) | 点源向球面辐射的**几何扩展**（与介质参数无关） |

**前提：** 介质均匀（κ、D、σ_a 处处相同）且无限大（无边界）。此条件下 G 有上述闭式解。

### 3.2 非均匀介质：变量 κ(x)

真实云中密度、反照率、有效各向异性随位置变化，κ 非常数：

```math
\kappa(\mathbf{x}) = \sqrt{3\,\sigma_a(\mathbf{x})\,\sigma_{tr}(\mathbf{x})}
```

此时 e^(-κ r) 的闭式 G **不再严格成立**，但可将体积衰减推广为**沿路径积分**：

```math
e^{-\kappa r}
\;\Rightarrow\;
\exp\!\left(-\int_{\mathbf{x}'}^{\mathbf{x}} \kappa(\mathbf{s})\, ds\right)
```

离散光步：

```math
\exp\!\left(-\sum_{k \le j} \kappa_k\, \Delta s_k\right),
\qquad
\kappa_j = \sqrt{3\,\sigma_a(\mathbf{x}_j)\,\sigma_{tr}(\mathbf{x}_j)}
```

| — | 常数 κ | 变量 κ(x) |
|---|---|---|
| 体积衰减 | e^(-κ r) | exp(-∫ κ ds) |
| 闭式 G | ✅ 有 | ❌ 一般无 |
| 数值离散 | 直接代入 | ✅ 每步算 κ_j 并累积 |
| 几何项 1/(4π r) | 仍成立 | 仍成立（只依赖距离） |

云芯深处多次散射后 g_eff → 0，σ_tr → σ_t（见 §2 τ ≫ 1 推论）。phi_fwd 即针对此 regime；边缘薄区 τ ≪ 1 时 σ_tr ≪ σ_t，扩散近似本身不再成立。

**phi_fwd 简化（g_eff=0，ω_0 写死）：**

取 g=0，则 σ_tr = σ_a + σ_s = σ_t。又 σ_a = (1-ω_0)σ_t，代入：

```math
\kappa = \sqrt{3\,\sigma_a\,\sigma_{tr}}
= \sqrt{3(1-\omega_0)\,\sigma_t^2}
= \sigma_t \sqrt{3(1-\omega_0)}
```

路径积分：

```math
\int \kappa\, ds
= \sqrt{3(1-\omega_0)} \int \sigma_t\, ds
= \sqrt{3(1-\omega_0)} \cdot \text{OD}
```

ω_0 为常数时 √(3(1-ω_0)) 可**编译期预计算**，每步只需 `kappaStep = localOD × sqrt(3(1−ω_0))`，**无需逐步 `sqrt`**。密度非均匀性仍通过局部 σ_t（即 `localOD`）进入。

离散：

```math
\kappa_j \Delta s_j = \text{localOD}_j \cdot \sqrt{3(1-\omega_0)}
```

### 3.3 换算为 OD 尺度

κ 与 σ_t 同源；在 τ ≫ 1、σ_tr ≈ σ_t 前提下，路径积分可写为光学深度形式：

```math
\int \kappa(\mathbf{s})\, ds \;\approx\; \text{OD} \times \text{ODScale},
\qquad
\text{OD} = \int \sigma_t\, ds
```

```math
\text{ODScale} = \frac{\kappa}{\sigma_t}
= \sqrt{3(1-\omega_0)\,\frac{\sigma_{tr}}{\sigma_t}}
```

**phi_fwd（g=0，ω_0=0.999）：** σ_tr=σ_t，故

```math
\text{ODScale} = \sqrt{3(1-\omega_0)} \approx \sqrt{0.003} \approx 0.055
```

代入典型云参数（ω_0 = 0.999，材料本征 g = 0.85 仅用于非 phi_fwd 方向性散射）：

```math
\sigma_{tr}/\sigma_t \approx 0.001 + 0.999 \times 0.15 \approx 0.151
\quad\Rightarrow\quad
\text{ODScale}_{\text{方向性}} \approx 0.021
```

（上式含 g=0.85，**不用于 phi_fwd**；phi_fwd 用 ODScale=√(3(1-ω_0))≈ 0.055。）

对 τ=20 的云，phi_fwd 下 e^(-OD· 0.055) ≈ 0.33，内部漫射场近均匀。

在 τ ≫ 1 下 OD 沿路径累积 σ_t，已处理密度非均匀；phi_fwd 中 ∫κ ds = √(3(1-ω_0))·OD，无逐步 `sqrt`。

---

## 四、源项 Q/D 的思路与近似

积分解中：

```math
\phi(\mathbf{x})
= \int_V
G(\mathbf{x}, \mathbf{x}')
\frac{Q(\mathbf{x}')}{D}
dV'
+ \text{边界项}
```

前文 §3.1~§3.3 主要解决的是 G 里的扩散传播核：体积衰减 e^(-∫κ ds) 与几何扩展 1/r。接下来要近似的是公式中的源项归一化：

```math
\frac{Q(\mathbf{x}')}{D}
```

也就是：**哪些位置可以被视为可信的扩散源，以及这些源有多强**。

### 4.1 严格源项：直射光沉积

从扩散方程的标准形式看，源项 Q 是外部辐射注入漫射场的能量。对云来说，最直接的源是太阳直射光在体积内发生散射：

```math
Q_{\text{single}}(\mathbf{x}')
\approx
\sigma_s(\mathbf{x}') \cdot T_{\text{sun}}(\mathbf{x}')
```

其中：

| 项 | 含义 |
|---|---|
| σ_s(x') | 源点处的散射系数，决定单位长度能把多少直射光转入散射场 |
| T_sun(x') | 太阳光从受光边界到达源点的透射率 |

离散到一个小体积元或一小段路径：

```math
Q_{\text{single},j}\Delta s_j
\approx
T_{\text{sun},j}\cdot \sigma_{s,j}\Delta s_j
```

当 ω_0 ≈ 1 时：

```math
\sigma_s\Delta s
= \omega_0\sigma_t\Delta s
\approx \sigma_t\Delta s
```

这给出最基础的源强：**有密度、且能被太阳直射照到的位置，才向扩散场注入能量**。

### 4.2 为什么不能只用单次散射源

若直接用：

```math
T_{\text{sun}} = e^{-\tau}
```

则源项会按单次散射透射率快速衰减。对厚云而言，这会导致云内部过暗，与高反照率水云的物理直觉不符。

真实云中 ω_0 ≈ 0.999，吸收很弱。光子被散射后并不会立刻消失，而是进入随机游走。接近各向同性的多重散射场，其衰减尺度应接近扩散尺度，而不是单次散射的 Beer–Lambert 尺度：

```math
e^{-\tau}
\quad\Rightarrow\quad
e^{-\tau\cdot s},
\qquad s \ll 1
```

因此这里的 T_src 不是普通单次散射透射率，而是**用于扩散源沉积的有效光照权重**。

### 4.3 有效源项：Q_eff

如果不显式求解完整 3D 扩散方程，可以把 (Q(x'))/(D) 近似为一个有效源：

```math
\frac{Q(\mathbf{x}')}{D}
\;\Rightarrow\;
\tilde{Q}_{\text{eff}}(\mathbf{x}')
```

可写成：

```math
\tilde{Q}_{\text{eff},j}
=
\underbrace{T_{\text{src},j}}_{\text{扩散源光照权重}}
\cdot
\underbrace{\sigma_{s,j}\Delta s_j}_{\text{局部散射沉积}}
\cdot
\underbrace{C_{\text{boundary},j}}_{\text{边界受光可信度}}
```

其中：

| 因子 | 作用 |
|---|---|
| T_src | 表示受光能量沿光深进入云体后仍能作为扩散源保留多少；使用慢衰减 |
| σ_sΔ s | 局部介质把能量耦合进散射场的能力；无密度则无源 |
| C_boundary | 判断当前区域是否靠近可信的受光边界；背光/逃逸边界处降低源可信度 |

这里没有要求必须显式逐点除以 D。在近似模型中，D=1/(3σ_tr) 的尺度影响可以被吸收到有效源强、扩散长度或整体归一化系数中。也就是说：

```math
\tilde{Q}_{\text{eff}}
\approx
\frac{Q}{D}
\quad\text{的实时近似}
```

而不是严格物理量。

### 4.4 边界受光可信度

仅靠慢衰减的 T_src 仍不足以解释背光边界变暗。高反照率云中吸收极弱，单纯距离衰减不会让背光处迅速变暗；真正关键的是**边界条件**：

- 如果最近相关边界是受光边界，说明外部太阳能量能从该边界注入云体，局部扩散源可信。
- 如果最近相关边界是背光/逃逸边界，光子更容易离开云体而非从该处注入，局部扩散源不应被完全相信。

因此引入边界受光可信度：

```math
C_{\text{boundary}}
=
\mathrm{wrap}(N_{\text{boundary}}\cdot L)
```

其中 N_boundary 是由 2D 云顶高度代理差分得到的边界法线，L 为太阳方向。

SSS 风格的包裹光照可以写为：

```math
\mathrm{wrap}(n)
=
\mathrm{saturate}\left(\frac{n+w}{1+w}\right)
```

含义：

| 项 | 含义 |
|---|---|
| n=N_boundary· L | 边界朝向太阳的程度 |
| w | 背光侧包裹程度；越大，受光判断越柔 |
| C_boundary | 最终边界受光可信度，可在完全禁用与全量使用之间混合 |

这不是完整边界项求解，而是把公式里的“边界项”对源可信度的影响折回 ~Q_eff 中。

### 4.5 低密度散射门控

扩散近似要求 τ≫1。云边缘、薄雾、低密度区不满足这个条件，即使有直射光，也不应该产生完整的各向同性散射积分。

因此引入密度门控：

```math
C_{\text{density}}
=
\left[
\mathrm{saturate}\left(
\frac{\rho}{\rho_{\text{thresh}}}
\right)
\right]^p
```

该门控的作用是缩短低密度区域的有效散射积分长度，而不是简单把云体几何或透射率删除。它可以作用于整体散射贡献：

- 方向性太阳散射
- 各向同性漫射场
- 环境光散射

含义是：**低密度区可以透明，但不应贡献完整散射能量**。

### 4.6 当前 1D 离散式

完整 3D 体积积分代价过高，当前使用沿太阳方向的 1D 近似。对观测点 x，沿太阳方向取源点 x'_j：

```math
\phi(\mathbf{x})
\approx
\sum_j
\tilde{Q}_{\text{eff},j}
\cdot
\underbrace{
\exp\!\left(
-\int_{\mathbf{x}'_j}^{\mathbf{x}}\kappa(\mathbf{s})\,ds
\right)
}_{\text{扩散体积衰减}}
\cdot
\underbrace{\frac{1}{r_j}}_{\text{几何扩展}}
```

代入有效源：

```math
\phi(\mathbf{x})
\approx
\sum_j
\left(
T_{\text{src},j}
\cdot
\sigma_{s,j}\Delta s_j
\cdot
C_{\text{boundary},j}
\right)
\cdot
\exp\!\left(-\int \kappa ds\right)
\cdot
\frac{1}{r_j}
```

其中：

| 数学项 | 含义 |
|---|---|
| T_src,j | 慢衰减的扩散源光照权重 |
| σ_s,jΔ s_j | 源点处的局部散射沉积 |
| C_boundary,j | 边界受光可信度 |
| exp(-∫ κ ds) | 源点到观测点的扩散体积衰减 |
| 1/r_j | 几何扩展 |

### 4.7 当前近似的定位

该模型不是严格求解完整扩散方程，而是把公式拆成三层近似：

1. **传播核 G**：用 e^(-∫κ ds)/r 近似。
2. **源项 Q/D**：用慢衰减源权重、局部散射沉积、边界受光可信度构造 ~Q_eff。
3. **边缘适用性**：用低密度散射门控限制 τ≪1 区域的散射贡献。

因此该近似的物理意图是：

> 受光边界附近产生可信的扩散源；源能以高反照率云的慢衰减尺度进入体积；背光/逃逸边界降低源可信度；稀薄边缘不贡献完整散射。
