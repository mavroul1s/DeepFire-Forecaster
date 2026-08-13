# DeepFire-Forecaster — SpaSE-UNet3D

### 📄 [Read the paper — *Sensors* **26**(16), 5116 (2026)](https://www.mdpi.com/1424-8220/26/16/5116)

> **SpaSE-UNet3D: Sensor-Driven Wildfire Detection and Progression Prediction from VIIRS Multispectral Imagery**
> Nikolaos Mavros, Dimitrios Katsaros — University of Thessaly, Volos, Greece
> Published open access in *Sensors* (MDPI) · DOI [10.3390/s26165116](https://doi.org/10.3390/s26165116)

---

## What this is

Wildfire monitoring at continental scale is done from orbit. VIIRS (Suomi-NPP / NOAA-20) images the
planet once or twice daily in bands calibrated for fire radiometry, and the **TS-SatFire** benchmark
(Zhao, Gerard & Ban, *Sci Data* 2025) packages those observations into multi-day stacks for three
tasks:

| Task | Question | Input | Target |
|------|----------|-------|--------|
| **Active Fire (AF)** | What is burning *now*? | 8 VIIRS bands × 1–2 days | fire mask on the last day |
| **Burned Area (BA)** | What has burned *so far*? | same stack | cumulative burn mask |
| **Fire Progression (FP)** | What burns *tomorrow*? | 27 ch (VIIRS + weather/terrain/vegetation) × 2 days | new pixels between day *T* and *T*+1 |

This repository contributes two things.

**A model — SpaSE-UNet3D.** Published baselines treat the temporal axis the way a video or MRI
network treats depth: isotropic 3D convolutions or temporal attention. But a TS-SatFire window is
one or two daily acquisitions — there is almost no inter-day signal to learn from. SpaSE-UNet3D
removes learned temporal mixing entirely: every convolution is spatial-only `(1,3,3)`, and days are
combined only by global pooling in Squeeze-and-Excitation modules. It matches a full `(3,3,3)`
network's accuracy with **2.72× fewer parameters**, works about as well from **one day as from
two**, and trains both tasks in **under 15 hours on a single T4**.

**An audit — which turned out to matter as much as the model.** Establishing what the architecture
achieves meant checking how the benchmark is scored and whether its labels are complete. Neither had
been examined, and both are consequential:

- **Labels are missing at scale.** Two of the seventeen AF *test* fires (*Calf Canyon*, *Mosquito*)
  have no ground truth at all — no model can be scored on them, yet they enter the published test
  aggregate.
- **Scoring convention moves F1 by 0.10** on fixed weights — as much as separates all twelve
  published baselines from each other.
- **The BA label encoding is undocumented,** and the obvious wrong approach fails *silently*.
- **The standard 256×256 crop discards most of the target** — 26.8% of AF and 56.3% of FP labelled
  pixels on average.

Consequently **our numbers and the published numbers are not on a common axis**, and we claim no
ranking against them. We report ours on stated terms and release the exclusion lists and protocol
spec so future work can compare on a common basis.

Everything runs on Kaggle with a **T4 GPU** inside the 12-hour session limit — no local setup.

---

## Results

Protocol: pixel counts accumulated over the whole test population with the metric computed once,
unannotated fires excluded rather than scored, centred 256×256 crop, threshold selected on
validation. Every configuration is trained from **five seeds**; mean ± SD reported.

### Active Fire

| Model | TS | F1 | IoU |
|-------|----|----|-----|
| *Published baselines — reference protocol, 17 test fires* | | | |
| SwinUNETR-2D (best 2D) | 1 | 0.774 | 0.660 |
| T4Fire | 6 | 0.802 | 0.700 |
| UNETR-3D | 6 | 0.811 | 0.706 |
| SwinUNETR-3D (best published) | 2 | 0.823 | 0.727 |
| *This work — our protocol, 15 annotated test fires* | | | |
| **SpaSE-UNet3D** | **1** | **0.8520 ± 0.0008** | **0.7422 ± 0.0012** |
| **SpaSE-UNet3D** | **2** | **0.8549 ± 0.0005** | **0.7466 ± 0.0008** |

*(All twelve baselines are tabulated in the paper.)*

At TS = 2: precision ≈ 0.85, recall ≈ 0.86 — roughly six of every seven flagged pixels are correct,
and a similar fraction of burning pixels recovered. Balance holds fire by fire (per-fire precision
0.740–0.921, recall 0.670–0.895). Seed spread is 0.0005 F1. TS = 1 and TS = 2 differ by less than
that spread, so **one acquisition carries most of the detectable signal.**

![Training Curves](https://raw.githubusercontent.com/mavroul1s/DeepFire-Forecaster/main/active_fire/af_2_day_input/train/results/plots/curves_v6.png)

Validation F1 clears 0.80 within ten epochs, then oscillates as the operating point shifts before
OneCycle anneals. Train/val loss stay coupled — no overfitting. The P&R panel is the trace of the
label problem: recall pinned near 0.80 while precision swings, the asymmetry expected when some
windows carry all-negative targets from unannotated scenes.

![Threshold Sweep](https://raw.githubusercontent.com/mavroul1s/DeepFire-Forecaster/main/active_fire/af_2_day_input/inf/results/plots/test_threshold_sweep.png)

Performance is essentially flat in the decision threshold — F1 varies under 0.005 across the entire
range [0.20, 0.80] as precision and recall trade off symmetrically. The validation-selected value
landed within 0.0003 of the best achievable in every run, so nothing accrues from the selection.

![Per Fire F1](https://raw.githubusercontent.com/mavroul1s/DeepFire-Forecaster/main/active_fire/af_2_day_input/inf/results/plots/per_fire_f1.png)

14 of 15 fires reach F1 ≥ 0.792, median (*Double Creek*) 0.850. The outlier *Blue Ridge* (0.746) is a
low-intensity event whose signal is often a single pixel, persistently obscured by drifting smoke.

![All Fires TPFPFN](https://raw.githubusercontent.com/mavroul1s/DeepFire-Forecaster/main/active_fire/af_2_day_input/inf/results/plots/all_fires_tpfpfn.png)

Red (TP) dominates every panel. False positives cluster on smoke and hot-soil boundaries (*Sydney*,
*Chuckegg Creek*); false negatives sit on the periphery of large fronts (*Dixie*, *Creek*) where the
signal is borderline. No systematic spatial bias.

> Plots are from a representative single run; the table is the five-seed mean. The dashed
> paper-baseline reference lines predate the protocol analysis below and should be read as context,
> not as a like-for-like comparison.

### Fire Progression

| Model | TS | F1 | IoU |
|-------|----|----|-----|
| *Published baselines — reference protocol* | | | |
| U-Net-3D (best published) | 6 | 0.375 | 0.338 |
| SwinUNETR-3D | 6 | 0.374 | 0.331 |
| SwinUNETR-3D | 2 | 0.366 | 0.321 |
| *This work — our protocol, 5 seeds* | | | |
| **SpaSE-UNet3D** — all 24 official test fires | **2** | **0.3845 ± 0.0221** | **0.2380 ± 0.0169** |
| &nbsp;&nbsp;*18 fires with a usable window* | 2 | 0.3846 ± 0.0220 | 0.2381 ± 0.0169 |
| &nbsp;&nbsp;*16 fires with measurable progression signal* | 2 | 0.4179 ± 0.0124 | 0.2641 ± 0.0099 |

All three populations are reported rather than one. On the 16 fires where the crop retains a signal
we stand 0.043 above the best published value; over all 24 the separation narrows to 0.010 and falls
inside seed noise. That difference is a property of the test population, not the model.

**Run-to-run variance is the headline result here.** Across five seeds differing in nothing else,
σ = 0.0221 — essentially equal to the 0.021 range separating *all five* published FP baselines.
Single-run comparisons on this task cannot reliably distinguish architectures, ours included. The
dataset paper's own seed study reports σ = 0.003; that gap is itself an aggregation effect.

![FP F1 vs Crop](https://raw.githubusercontent.com/mavroul1s/DeepFire-Forecaster/main/new_deepfire/audit_findings_addendum2/fig_fp_f1_vs_crop.png)

Per-fire scores span 0.007–0.537, and the cause is measurable: **the crop, not fire behaviour.**
Per-fire F1 correlates strongly and negatively with the fraction of positive pixels lost to the
256×256 window (Spearman ρ = −0.685, p = 0.0034, n = 16; the plotted linear fit gives r = −0.59).
Fires below 0.375 lose on average 66.7% of their positive pixels to the crop; those above lose 34.6%.
In the extreme case (*CA-4086*, F1 = 0.007) the progression increment occupies under 0.01% of the
crop, the model correctly returns near-zero probability — and is scored near zero for it.

**Per-fire prediction maps (sample of test fires):**

<table>
<tr>
<td><img src="https://raw.githubusercontent.com/mavroul1s/DeepFire-Forecaster/main/fire_progression/fire_pred_2_day_input/fire_pred_results/fp_fire_maps/US_2021_CA3451712013120211011.png"/></td>
<td><img src="https://raw.githubusercontent.com/mavroul1s/DeepFire-Forecaster/main/fire_progression/fire_pred_2_day_input/fire_pred_results/fp_fire_maps/US_2021_CA3568711855020210818.png"/></td>
<td><img src="https://raw.githubusercontent.com/mavroul1s/DeepFire-Forecaster/main/fire_progression/fire_pred_2_day_input/fire_pred_results/fp_fire_maps/US_2021_CA3604711863120210910.png"/></td>
</tr>
<tr>
<td><img src="https://raw.githubusercontent.com/mavroul1s/DeepFire-Forecaster/main/fire_progression/fire_pred_2_day_input/fire_pred_results/fp_fire_maps/US_2021_ID4453211532920210810.png"/></td>
<td><img src="https://raw.githubusercontent.com/mavroul1s/DeepFire-Forecaster/main/fire_progression/fire_pred_2_day_input/fire_pred_results/fp_fire_maps/US_2021_WA4828511853120210713.png"/></td>
<td><img src="https://raw.githubusercontent.com/mavroul1s/DeepFire-Forecaster/main/fire_progression/fire_pred_2_day_input/fire_pred_results/fp_fire_maps/US_2021_MT4568311385420210708.png"/></td>
</tr>
</table>

Red = TP, green = FP, blue = FN. Predicted progression generally follows the ground-truth perimeter
shape; where it fails, the failure is a directional offset rather than a shape mismatch.

### Ablation (AF, TS = 2, validation, 40 epochs per arm)

| Configuration | Val F1 | Δ/σ | Params |
|---|---|---|---|
| Full model (3 runs) | 0.8214 ± 0.0009 | — | 32.88 M |
| Full `(3,3,3)` convolutions | 0.8205 | 1.1 | **89.36 M** |
| Without SE attention | 0.8219 | 0.6 | 32.44 M |
| Without deep supervision | 0.8229 | 1.6 | 32.88 M |

Read honestly: **no individual component is shown to improve accuracy** — every variant lies within
1.6σ of the full model, which is itself a robustness result. What the ablation *does* establish is
efficiency: the spatial-only design matches full `(3,3,3)` accuracy at **2.72× fewer parameters**.
On one- to two-day windows, isotropic temporal-mixing capacity is spent without return. The FP
variant is deliberately not ablated — its σ = 0.0221 dwarfs any single-component effect.

**Cost** (single T4, 16 GB): AF TS=1 32.88 M / 100 ep / 4.2 h · AF TS=2 32.88 M / 80 ep / 6.5 h ·
FP TS=2 24.28 M / 60 ep / 3.5 h.

---

## Evaluation protocol — read before comparing numbers

Baseline figures are quoted as published; we did not retrain them. **The two scoring procedures
differ in ways that make the figures incomparable.**

The discrepancy is visible in the published metrics themselves. For counts accumulated over a pixel
population, F1 and IoU obey `IoU = F1 / (2 − F1)`. Our measurements satisfy this to four decimals;
the published pairs do not — SwinUNETR-3D at TS = 2 reports F1 = 0.823 with IoU = 0.727, where the
identity gives 0.699. **This is a one-line check on any published F1/IoU pair before comparing it to
a micro-averaged one.**

Reading the reference implementation identifies eight differences:

| Aspect | Reference | This work |
|---|---|---|
| *Stated in the dataset paper — we depart by choice* | | |
| AF label rule | `nan_to_num(band 7) > 0` | band 7 ≥ 7 |
| FP target | accumulated AF, or union with BA, chosen per fire | clipped increment between consecutive BA masks |
| Missing values | replaced with zeros | NaN retained as unlabelled |
| Test stride | stride = TS; all *T* frames scored | stride 1, final frame scored |
| *Recoverable only from the released code* | | |
| **Aggregation** | per-frame F1, averaged over frames then fires | counts accumulated, metric computed once |
| **Empty ground truth** | scored 1.0 (`zero_division=1.0`) | contributes no counts |
| Spatial crop | 30% offset | centred |
| Threshold | fixed at 0.5 | selected on validation |

Applied cumulatively to our AF model **with weights held fixed**, so only the measurement changes
(all rows on the reference's 30% offset crop, so no row matches the headline table):

| Configuration | Fires | F1 |
|---|---|---|
| Our label rule and final-frame scoring | 15 | 0.7917 |
| &nbsp;&nbsp;+ all frames scored | 15 | 0.7714 |
| &nbsp;&nbsp;+ reference label rule (band 7 > 0) | 15 | 0.7567 |
| &nbsp;&nbsp;+ the two unannotated test fires | 17 | 0.6912 |

**Scoring convention alone moves F1 by 0.10** — comparable to the 0.713–0.823 spread across all
twelve baselines. The first two rows account for most of it: the reference scores each day
separately and awards 1.0 whenever that day's mask is empty and the model predicts nothing. Empty
days are common — before ignition, after burnout, under cloud — so the published figure blends
segmentation quality with correct abstention. A micro-averaged figure has no such term.

---

## Label audit

Every fire in every split was read day by day and tested for finite label pixels. Fires with no
annotation on *any* day are excluded outright; fires annotated on some days are retained with
unlabelled windows rejected individually.

| Task | Split | Total | No dir. | All NaN | <50% days | Excl. | **Usable** |
|------|-------|------:|--------:|--------:|----------:|------:|-----------:|
| AF | train | 137 | 13 | 4 | 3 | 17 | **120** |
| AF | val | 14 | 1 | 1 | 0 | 2 | **12** |
| AF | test | 17 | 0 | 2 | 1 | 2 | **15** |
| BA | train | 137 | 13 | 18 | 17 | 31 | **106** |
| BA | val | 14 | 1 | 5 | 0 | 6 | **8** |
| BA | test (named) | 17 | 0 | 7 | 1 | 7 | **10** |
| BA | test (US_2021) | 24 | 0 | 2 | 4 | 2 | **22** |
| FP | train | 137 | — | — | — | 48 | **89** |
| FP | val | 14 | — | — | — | 6 | **8** |
| FP | test | 24 | — | — | — | 6 | **18** |

FP exclusions are counted at window level (no consecutive *T*/*T*+1 pair with valid BA on both
days), so the band columns don't apply. No FP test fire is excluded — all 24 are reported.

**This matters more for evaluation than for training.** A controlled pair differing only in whether
unannotated windows are retained with all-negative targets gives 0.8533 (audited) vs 0.8514
(unaudited) — only 0.0019, because day-level filtering already rejects any window whose final day
lacks a label (71 of 1,790 windows differ). The real value is on the test side: **two of seventeen
AF test fires cannot be scored by any model.**

**BA label encoding** (audited only — we train no BA model). Band 8 finite values (2,119–908,660)
are Julian-day or perimeter-ID codes; NaN means unburned. 100% of finite pixels are burned pixels.
Correct extraction is `(~np.isnan(band8)).astype(float)`. A naïve `band8 > 0.5` happens to return
the right mask — every finite value exceeds it, NaN comparisons are false — so the error goes
unnoticed until the threshold changes. Running `np.nan_to_num` first, as the reference loader does
elsewhere, turns unburned pixels into valid zeros and silently shifts the class balance.

Full per-fire lists: [AF](docs/AF_LABEL_AUDIT_REPORT.md) · [BA](docs/BA_LABEL_AUDIT_REPORT.md) ·
[FP](docs/FP_LABEL_AUDIT_REPORT.md)

---

## Architecture

Shared: spatial-only `(1,3,3)` convolutions in every residual block, SE channel attention (r = 8)
inside every block, U-Net skip concatenations, Dice + Focal objective.

**The design claim, stated precisely.** Every feature-extraction convolution is `(1,3,3)` with
padding `(0,1,1)`; skips are 1×1×1, upsampling is `ConvTranspose3D(1,2,2)`, pooling is
`MaxPool3D(1,2,2)`. *T* is preserved through every stage. Temporal information is combined **only by
global pooling, never by learned temporal filters** — SE pools over (T, H, W), and the FP head
collapses *T* by a mean. This is not an absence of temporal mixing; it is an absence of *learned*
temporal mixing.

**AF variant** — 8 ch (6 daytime + 2 nighttime VIIRS), 32.88 M params. Encoder `[64,128,256,512]`,
bottleneck to 1024, mirrored decoder. ResBlock3D: two `(1,3,3)` convs + BN + ReLU, Dropout3D
(p = 0.1), SE, residual add. Deep supervision on decoder stage 3 (weight 0.3). Loss
`0.5·Dice + 0.5·Focal(α=0.75, γ=2) + 0.3·DS`. Supervised on the final frame only — AF labels exist
only for the last day.

**FP variant** — 27 ch (8 VIIRS + 18 auxiliary + cumulative burn mask), 24.28 M params. Input
projection mixes the heterogeneous channels first; the bottleneck is **ASPP3D** (spatial dilation
1/6/12 + global-pool branch, fused to 1024). GELU, no Dropout3D. Head collapses *T* by mean, then a
2D head. No deep supervision. Loss `0.5·Dice + 0.3·Focal(α=0.85, γ=3) + 0.2·weighted BCE`, positive
weight derived from the training split's class balance rather than hand-tuned. 8× TTA at inference.

**Training.** Batch 8, 256×256 centre crop, AdamW (lr 5e-4, wd 1e-4), OneCycleLR
(`pct_start = 0.1`), grad clip 1.0, AMP.

---

## Repository

```
docs/                    per-fire exclusion lists (AF / BA / FP)
active_fire/             README, diagnostics, af_1_day_input/ + af_2_day_input/ (train + inf)
burned_area/             README, label-audit notebook
fire_progression/        README, diagnostics, fire_pred_2_day_input/ (notebook + results)
new_deepfire/            revision-round experiments (see table below)
```

Checkpoints (`*.pt`, `*.pth`) and large binaries are gitignored; the notebooks regenerate them.

## Reproducing

Open any notebook on Kaggle, add the [TS-SatFire dataset](https://github.com/zhaoyutim/TS-SatFire)
as input, select a **T4 GPU**, run all cells. Self-contained, fits the 12-hour limit, no pip installs
beyond Kaggle's defaults (PyTorch 2.x, rasterio, matplotlib).

| Paper section | Notebook |
|---|---|
| Label audit, crop coverage | `new_deepfire/audit and crop/audit-and-crop-kaggle.ipynb` |
| FP criterion, F1 vs crop | `new_deepfire/audit_findings_addendum2/fp_criterion_kaggle.ipynb` |
| Evaluation protocol | `new_deepfire/protocol-eval-v2-kaggle/protocol-eval-v2-kaggle.ipynb` |
| AF results | `new_deepfire/af_ts2_newprotocol/`, `af_ts1_new_protocol/`, `af_seed43/`, `af_seed44/` |
| Impact of the audit | `new_deepfire/af_dirtyvsclean/af_dirtyvs_cleandata.ipynb` |
| FP results | `new_deepfire/fp_all_fires/`, `fp_43_seed/`, `fp_44_seed/` |
| Ablation | `new_deepfire/abblation v2/af-ablation-kaggle-v2.ipynb` |

---

## Limitations

Conclusions rest on a single benchmark and sensor family. Baselines were not retrained under our
protocol, so the decomposition isolates the measurement effect on our own weights but leaves open how
the baseline *architectures* would rank under a common evaluation. The ablation uses one run per arm
and rules out only large effects. We train no BA model.

## Citation

```bibtex
@article{mavros2026spase,
  title   = {{SpaSE-UNet3D}: Sensor-Driven Wildfire Detection and Progression
             Prediction from {VIIRS} Multispectral Imagery},
  author  = {Mavros, Nikolaos and Katsaros, Dimitrios},
  journal = {Sensors},
  volume  = {26}, number = {16}, pages = {5116}, year = {2026},
  publisher = {MDPI},
  doi     = {10.3390/s26165116},
  url     = {https://www.mdpi.com/1424-8220/26/16/5116}
}

@article{zhao2025tssatfire,
  title   = {{TS-SatFire}: A multi-task satellite image time-series dataset for
             wildfire detection and prediction},
  author  = {Zhao, Yu and Gerard, Sebastian and Ban, Yifang},
  journal = {Scientific Data},
  volume  = {12}, number = {1}, pages = {1817}, year = {2025},
  doi     = {10.1038/s41597-025-06271-3}
}
```

Released under [LICENSE](LICENSE). We thank the TS-SatFire authors for releasing their dataset **and
their baseline code** — the protocol analysis here was only possible because the reference
implementation is public.
