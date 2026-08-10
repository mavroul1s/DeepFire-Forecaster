# DeepFire-Forecaster — SpaSE-UNet3D

Official code, results, and audit reports for:

> **SpaSE-UNet3D: Sensor-Driven Wildfire Detection and Progression Prediction from VIIRS Multispectral Imagery**
> Nikolaos Mavros and Dimitrios Katsaros — Department of Electrical and Computer Engineering, University of Thessaly, Volos, Greece
> **Accepted 10 August 2026 in *Sensors* (MDPI).**

The compiled manuscript is in [paper/main.pdf](paper/main.pdf).

---

## What this project is about

Wildfire monitoring at continental scale is done with satellites. The VIIRS instrument aboard
Suomi-NPP and NOAA-20 images the whole planet once or twice a day in bands calibrated for fire
radiometry, and the **TS-SatFire** benchmark (Zhao, Gerard & Ban, *Scientific Data*, 2025) packages
those observations into multi-day image stacks for three tasks:

| Task | Question it answers | Input | Target |
|------|--------------------|-------|--------|
| **Active Fire (AF)** | Which pixels are burning *right now*? | 8 VIIRS bands × 1–2 days | per-pixel fire mask on the last day |
| **Burned Area (BA)** | Which pixels have burned *so far*? | same stack | cumulative burn mask |
| **Fire Progression (FP)** | Which pixels will burn *tomorrow*? | 27 channels (VIIRS + weather, terrain, vegetation) × 2 days | newly burned pixels between day *T* and *T*+1 |

This repository does two things with that benchmark.

**1. It proposes a model — SpaSE-UNet3D.** The published baselines treat the temporal axis of a
satellite stack the way a video or MRI network treats depth: with isotropic 3D convolutions or
temporal attention. But a TS-SatFire window is one or two daily acquisitions — there is almost no
inter-day signal for a temporal filter to learn from. SpaSE-UNet3D removes learned temporal mixing
entirely: every convolution is spatial-only `(1,3,3)`, and days are combined only by global pooling
in Squeeze-and-Excitation modules. The result matches the accuracy of a full `(3,3,3)` network with
**2.72× fewer parameters**, works about as well from **one day of imagery as from two**, and trains
both tasks in **under 15 hours on a single NVIDIA T4**.

**2. It audits the benchmark — and this turned out to matter as much as the model.** Establishing
what the architecture actually achieves meant checking how TS-SatFire is scored and whether its
labels are complete. Neither had been examined before, and both are consequential:

- **Labels are missing at scale.** Many fires carry no annotation on any day. Two of the seventeen
  active-fire *test* fires (*Calf Canyon*, *Mosquito*) have no ground truth at all — no model can be
  scored on them, yet they enter the published test aggregate.
- **The scoring convention moves F1 by 0.10** on fixed model weights — as much as separates all
  twelve published baselines from each other. The published numbers average a per-frame F1 over
  frames and then over fires (awarding 1.0 to empty frames); ours accumulates pixel counts and
  computes the metric once.
- **The burned-area label encoding is undocumented.** Band 8 stores Julian-day/perimeter codes in
  NaN-padded floats, not a probability or class score. The correct extraction is presence-of-finite,
  not a threshold — and the obvious wrong approach fails *silently*.
- **The standard 256×256 centre crop discards most of the target.** A mean of 26.8% of labelled
  active-fire pixels and 56.3% of progression pixels fall outside it.

Because of this, **the numbers in this repository and the numbers in the TS-SatFire paper are not on
a common axis**, and we do not claim a ranking against them. We report ours on stated terms, publish
the exclusion lists and the protocol specification, and show that on those terms SpaSE-UNet3D
matches or exceeds the strongest published baselines while using a **two-day observation window
against the baselines' six**.

Everything runs on Kaggle with a **T4 GPU** inside the 12-hour session limit. No local setup is
required; each notebook reads the TS-SatFire dataset directly from the Kaggle input path.

---

## Results

All figures below are measured under the protocol described in
[Evaluation protocol](#evaluation-protocol-read-this-before-comparing-numbers): pixel counts
accumulated over the whole test population with the metric computed once, unannotated fires excluded
rather than scored, a centred 256×256 crop, and a threshold selected on validation and applied
unmodified at test time. Each configuration is trained from **five independent seeds**; we report the
mean and standard deviation.

### Active Fire Detection

| Model | TS | F1 | IoU |
|-------|----|----|-----|
| *Published baselines — reference protocol, 17 test fires* | | | |
| U-Net (2D) | 1 | 0.731 | 0.605 |
| Att-U-Net (2D) | 1 | 0.763 | 0.648 |
| UNETR-2D | 1 | 0.733 | 0.621 |
| SwinUNETR-2D | 1 | 0.774 | 0.660 |
| GRU-3 | 6 | 0.713 | 0.601 |
| LSTM-3 | 6 | 0.765 | 0.654 |
| T4Fire | 6 | 0.802 | 0.700 |
| U-Net-3D | 6 | 0.748 | 0.628 |
| Att-U-Net-3D | 6 | 0.770 | 0.654 |
| UNETR-3D | 6 | 0.811 | 0.706 |
| SwinUNETR-3D | 6 | 0.797 | 0.688 |
| SwinUNETR-3D | 2 | 0.823 | 0.727 |
| *This work — our protocol, 15 annotated test fires, 5 seeds* | | | |
| **SpaSE-UNet3D** | **1** | **0.8520 ± 0.0008** | **0.7422 ± 0.0012** |
| **SpaSE-UNet3D** | **2** | **0.8549 ± 0.0005** | **0.7466 ± 0.0008** |

At TS = 2 this corresponds to precision ≈ 0.85 and recall ≈ 0.86 on the audited test fires: roughly
six of every seven flagged pixels are correct, and a similar fraction of truly burning pixels is
recovered. The balance holds fire by fire (per-fire precision 0.740–0.921, recall 0.670–0.895), so
the aggregate does not hide a lopsided operating point. The seed spread is 0.0005 F1 — the number is
a property of the model, not of a lucky initialisation.

The TS = 1 and TS = 2 results differ by less than the seed spread of a single configuration, so we
treat them as equivalent rather than ordering them: **one acquisition carries most of the detectable
signal.** Performance is also essentially flat in the decision threshold — test F1 varies by under
0.005 across the entire range [0.20, 0.80].

**Training curves (TS=2):**

![Training Curves](https://raw.githubusercontent.com/mavroul1s/DeepFire-Forecaster/main/active_fire/af_2_day_input/train/results/plots/curves_v6.png)

Validation F1 clears 0.80 within ten epochs, then oscillates as the operating point shifts between
precision- and recall-favouring regimes before the OneCycle schedule anneals. Train and validation
loss stay coupled throughout — no overfitting. The precision/recall panel is the empirical trace of
the label problem: recall sits near 0.80 for much of training, the asymmetry expected when some
windows are supervised by all-negative targets derived from unannotated scenes.

**Benchmark comparison vs. all paper baselines (TS=2):**

![Benchmark Comparison](https://raw.githubusercontent.com/mavroul1s/DeepFire-Forecaster/main/active_fire/af_2_day_input/inf/results/plots/model_comparison_test.png)

> ⚠️ This plot predates the protocol analysis and places both groups on one axis. As explained
> below, they are scored differently and should be read as *two independent measurements*, not as a
> ranking. The published landscape is shown for context.

**Per-fire F1 on test set (TS=2):**

![Per Fire F1](https://raw.githubusercontent.com/mavroul1s/DeepFire-Forecaster/main/active_fire/af_2_day_input/inf/results/plots/per_fire_f1.png)

14 of the 15 annotated test fires reach F1 ≥ 0.792, and the median fire (*Double Creek*) reaches
0.850. The one outlier is *Blue Ridge* at 0.746: a low-intensity event whose fire signal is often
confined to a single pixel and is persistently obscured by drifting smoke.

**TP / FP / FN overlays across all test fires (TS=2):**

![All Fires TPFPFN](https://raw.githubusercontent.com/mavroul1s/DeepFire-Forecaster/main/active_fire/af_2_day_input/inf/results/plots/all_fires_tpfpfn.png)

Red (true positive) dominates every panel. False positives cluster along smoke and hot-soil
boundaries (*Sydney*, *Chuckegg Creek*); false negatives sit on the periphery of large active fronts
(*Dixie*, *Creek*) where the radiometric signal is borderline. No fire shows a systematic spatial
bias.

*Plots above are from a representative single run; the headline table is the five-seed mean.*

---

### Burned Area Mapping

**Audited only — we train no BA model.** The task is included because auditing it produced two
results that any future BA work on this dataset needs:

- **The label encoding.** Band 8 holds Julian-day or perimeter-ID codes in the range
  [2,119 – 908,660], with NaN for unburned pixels. The correct binary extraction is
  `(~np.isnan(band8)).astype(float)` — *presence*, not *magnitude*. A naïve `band8 > 0.5` happens to
  return the right mask (every finite value exceeds it, NaN comparisons are false), so the mistake
  goes unnoticed until someone changes the threshold. Worse, running `np.nan_to_num` first — as the
  reference loader does elsewhere — turns unburned pixels into valid zeros and silently shifts the
  class balance.
- **The missing labels.** 31 of 137 training fires, 6 of 14 validation fires and 7 of the 17 named
  test fires carry no burned-area supervision at all.

See [docs/BA_LABEL_AUDIT_REPORT.md](docs/BA_LABEL_AUDIT_REPORT.md) and
[burned_area/README.md](burned_area/README.md).

---

### Fire Progression Prediction

| Model | TS | F1 | IoU |
|-------|----|----|-----|
| *Published baselines — reference protocol* | | | |
| U-Net-3D | 6 | 0.375 | 0.338 |
| SwinUNETR-3D | 6 | 0.374 | 0.331 |
| UNETR-3D | 6 | 0.371 | 0.336 |
| Att-U-Net-3D | 6 | 0.354 | 0.312 |
| SwinUNETR-3D | 2 | 0.366 | 0.321 |
| *This work — our protocol, 5 seeds* | | | |
| **SpaSE-UNet3D** — all 24 official test fires | **2** | **0.3845 ± 0.0221** | **0.2380 ± 0.0169** |
| &nbsp;&nbsp;*18 fires with a usable window* | 2 | 0.3846 ± 0.0220 | 0.2381 ± 0.0169 |
| &nbsp;&nbsp;*16 fires with measurable progression signal* | 2 | 0.4179 ± 0.0124 | 0.2641 ± 0.0099 |

We report all three populations rather than picking one. On the 16 fires where the crop actually
retains a progression signal our figure stands 0.043 above the highest published baseline value —
more than three times the run-to-run spread. Over the full 24-fire set the separation narrows to
0.010 and falls inside seed noise. The difference between those two readings is a property of the
test population, not of the model.

**Run-to-run variance is the headline result on this task.** Across five seeds differing in nothing
else, test F1 has σ = 0.0221 — essentially equal to the 0.021 range separating *all five* published
FP baselines from one another. Single-run comparisons on fire progression cannot reliably
distinguish architectures, ours included. (The dataset paper's own seed study reports σ = 0.003; the
gap is itself an aggregation effect — averaging per-frame scores concentrates the distribution,
accumulating counts does not.)

**Training curves and benchmark comparison:**

![FP Curves](https://raw.githubusercontent.com/mavroul1s/DeepFire-Forecaster/main/fire_progression/fire_pred_2_day_input/fire_pred_results/fp_curves.png)

![FP Benchmark](https://raw.githubusercontent.com/mavroul1s/DeepFire-Forecaster/main/fire_progression/fire_pred_2_day_input/fire_pred_results/fp_compare.png)

> ⚠️ Same caveat as the AF comparison: the two groups use different scoring conventions. Also note
> that the epoch of best validation F1 varied by more than twenty epochs across seeds while
> validation F1 itself barely moved — with only eight validation fires carrying usable progression
> windows, validation is a weak predictor of test performance here. That is a structural limit of
> the benchmark, not of the model.

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

Red = true positive, green = false positive, blue = false negative. Most fires show predicted
progression that follows the ground-truth perimeter shape — the model propagates the front in the
direction implied by the cumulative burn channel and the terrain/weather covariates. Where it fails,
the failure is usually a slight directional offset rather than a shape mismatch.

**Per-fire scores vary enormously (0.007 to 0.537), and the cause is measurable: the crop.**
Per-fire F1 correlates strongly and negatively with the fraction of positive pixels lost to the
256×256 window (Spearman ρ = −0.685, p = 0.0034, n = 16). Fires scoring below 0.375 lose on average
66.7% of their positive pixels to the crop; those scoring above lose 34.6%. In the extreme case
(*CA-4086*, F1 = 0.007) the progression increment occupies under 0.01% of the crop and the model
correctly returns near-zero probability — and is scored near zero for it. A model asked to predict a
target largely absent from its input is being measured on the crop, not on fire behaviour.

---

### Component ablation (AF, TS = 2, validation split, 40 epochs per arm)

| Configuration | Val F1 | Δ | Δ/σ | Params |
|---|---|---|---|---|
| Full model (3 runs) | 0.8214 ± 0.0009 | — | — | 32.88 M |
| Full `(3,3,3)` convolutions | 0.8205 | −0.0010 | 1.1 | **89.36 M** |
| Without SE attention | 0.8219 | +0.0005 | 0.6 | 32.44 M |
| Without deep supervision | 0.8229 | +0.0015 | 1.6 | 32.88 M |

Read this honestly: **no individual component is shown to improve accuracy.** Every reduced variant
lies within 1.6σ of the full model, so at this sample size the arms are statistically
indistinguishable — which is itself a robustness result.

What the ablation *does* establish is efficiency. The spatial-only design matches the full `(3,3,3)`
network's accuracy (agreement within 1.1σ) using **2.72× fewer parameters** (32.88 M vs 89.36 M).
On one- to two-day windows the temporal-mixing capacity of isotropic 3D kernels is spent without
return. SE attention is retained because it supplies channel reweighting for 0.44 M parameters —
1.3% of the model — at no measured cost.

The FP variant is deliberately **not** ablated: its seed variance (σ = 0.0221) dwarfs any plausible
single-component effect, so a single-run ablation would be uninterpretable.

### Training resource footprint (single NVIDIA T4, 16 GB)

| Task | Params | Epochs | Time (h) | Peak VRAM |
|------|--------|--------|----------|-----------|
| AF (TS = 1) | 32.88 M | 100 | 4.2 | 13.2 GB |
| AF (TS = 2) | 32.88 M | 80 | 6.5 | 14.1 GB |
| FP (TS = 2) | 24.28 M | 60 | 3.5 | 13.7 GB |

---

## The architecture: SpaSE-UNet3D

A family of two closely related encoder–decoder networks sharing four principles: spatial-only
`(1,3,3)` convolutions in every residual block, SE channel attention inside every block, symmetric
U-Net skip concatenations, and a combined Dice + Focal objective.

**The central design choice.** Every feature-extraction convolution has kernel shape `(1,3,3)` with
padding `(0,1,1)`, so **no convolution in the network combines information across days**. Everything
else is spatial too: residual skips are 1×1×1 projections, upsampling is `ConvTranspose3D(1,2,2)`,
pooling is `MaxPool3D(1,2,2)`. The temporal dimension *T* is preserved through every stage.

The claim is precise, and worth stating in its exact form: temporal information is combined **only
by global pooling, never by learned temporal filters**. The SE modules pool over (T, H, W) when
computing channel gates, and the FP head collapses *T* with a mean before its final 2D convolutions.
This is not an absence of temporal mixing — it is an absence of *learned* temporal mixing.

**AF variant** — 8-channel input (6 daytime + 2 nighttime VIIRS bands), 32.88 M parameters.

- Encoder `[64, 128, 256, 512]`, ResBlock3D bottleneck widening to 1024, mirrored decoder
- ResBlock3D: two `(1,3,3)` convs + BN + ReLU, Dropout3D (p = 0.1) between them, SE (r = 8), residual add
- Deep supervision on decoder stage 3 (256 ch), weight 0.3
- Loss: `0.5·Dice + 0.5·Focal(α=0.75, γ=2) + 0.3·DS`
- Supervised on the final frame only — AF labels exist only for the last day of a window

**FP variant** — 27-channel input (8 VIIRS + 18 FirePred auxiliary bands + 1 cumulative burn mask),
24.28 M parameters.

- Input projection `Conv3d(27, 64, (1,3,3)) → BN → GELU` mixes the heterogeneous channels first
- Same four-stage encoder, but the bottleneck is an **ASPP3D** module: parallel spatial dilation
  rates 1 / 6 / 12 plus a global-pool branch, concatenated (4 × 341 ch) and fused to 1024
- GELU instead of ReLU; no Dropout3D (it hurt convergence on the smaller effective training set)
- Head collapses *T* by mean, then a 2D head — the FP label is a single 2D mask
- No deep supervision (auxiliary losses introduced conflicting gradients on sparse targets)
- Loss: `0.5·Dice + 0.3·Focal(α=0.85, γ=3) + 0.2·weighted BCE`, with the positive weight derived
  from the training split's class balance at preload time rather than hand-tuned
- 8× test-time augmentation (flips + rotations) at inference

**Shared training setup.** Batch size 8, 256×256 centre crop, AdamW (lr 5e-4, wd 1e-4), OneCycleLR
with `pct_start = 0.1`, gradient clipping at 1.0, AMP. AF keeps training windows with ≥ 10 fire
pixels at a ≤ 2:1 negative ratio; FP uses ≥ 3 burned pixels at 1.5:1.

---

## Evaluation protocol — read this before comparing numbers

Baseline figures throughout are quoted from Zhao et al. as published; we did not retrain them. Our
evaluation was implemented independently, and **the two scoring procedures differ in ways that make
the figures incomparable**.

The discrepancy is visible in the published metrics themselves. For metrics accumulated over a pixel
population, F1 and IoU are related by a deterministic identity:

```
IoU = F1 / (2 − F1)
```

Our own measurements satisfy this to four decimal places. The published pairs do not — SwinUNETR-3D
at TS = 2 reports F1 = 0.823 with IoU = 0.727, where the identity gives 0.699. That is the signature
of a different aggregation. **This identity is a useful one-line check on any published F1/IoU pair
before comparing it to a micro-averaged one.**

Reading the reference implementation identifies eight concrete differences:

| Aspect | Reference implementation | This work |
|---|---|---|
| *Stated in the dataset publication — we depart by choice* | | |
| AF label rule | `nan_to_num(band 7) > 0` | band 7 ≥ 7 |
| FP target | accumulated active fire, or its union with burned area, chosen per fire | clipped increment between consecutive BA masks |
| Missing values | replaced with zeros | NaN retained as unlabelled |
| Test stride | stride = TS; all *T* frames scored | stride 1, final frame scored |
| *Recoverable only from the released code* | | |
| **Aggregation** | per-frame F1, averaged over frames, then over fires | counts accumulated over all pixels, metric computed once |
| **Empty ground truth** | scored 1.0 (`zero_division=1.0`) | contributes no counts |
| Spatial crop | 30% offset | centred |
| Threshold | fixed at 0.5 | selected on validation |

Because these are separable, their cost can be measured. Applying them cumulatively to our AF model
**with the weights held fixed**, so only the measurement changes (all rows on the reference's 30%
offset crop, so no row corresponds to the headline table):

| Configuration | Test fires | F1 |
|---|---|---|
| Our label rule and final-frame scoring | 15 | 0.7917 |
| &nbsp;&nbsp;+ all frames scored | 15 | 0.7714 |
| &nbsp;&nbsp;+ reference label rule (band 7 > 0) | 15 | 0.7567 |
| &nbsp;&nbsp;+ the two unannotated test fires | 17 | 0.6912 |

**Scoring convention alone moves F1 by 0.10 — a range comparable to the 0.713–0.823 spread across
all twelve published baselines.** The first two rows account for most of it: the reference scores
each day separately and awards 1.0 whenever the reference mask for that day is empty and the model
predicts nothing. Empty days are common — before ignition, after burnout, under cloud cover — so the
published figure blends segmentation quality on days with fire and correct abstention on days
without. A micro-averaged figure has no equivalent term. The two conventions measure different
quantities, and the difference is not recoverable from the published tables.

Retraining all baselines under one stated protocol is the right way to rank the architectures, and
we identify it as future work; holding our own weights fixed is what lets the measurement effect be
isolated cleanly here.

---

## Key contributions

### 1. Label-quality audit (all three tasks, all splits)

Every fire in every split was read day by day and tested for finite label pixels. Missing labels
occur at two granularities and conflating them wastes data: some fires carry no annotation on *any*
day (excluded outright), others on a subset of days (retained, with unlabelled windows rejected
individually).

| Task | Split | Total | No dir. | All NaN | <50% days | Excluded | **Usable** |
|------|-------|------:|--------:|--------:|----------:|---------:|-----------:|
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

The adopted fire-level criterion excludes only the first two categories; `<50% days` fires are
retained with day-level filtering. FP exclusions are counted at the window level (a fire is unusable
when no consecutive *T*/*T*+1 pair has valid BA on both days), so the band columns do not apply. No
FP test fire is excluded — all 24 are reported, with the six carrying no usable window contributing
no counts.

**Why this matters more for evaluation than for training.** We trained a controlled pair differing
only in whether windows from unannotated days are retained with all-negative targets: audited F1 =
0.8533 vs unaudited 0.8514, a difference of 0.0019. The effect is small because day-level filtering
already rejects any window whose final day lacks a label — only 71 of 1,790 windows differ. The real
value of the audit is on the test side: **two of the seventeen AF test fires cannot be scored by any
model**, so any full-split aggregate depends on the empty-ground-truth convention rather than on
model behaviour.

Full per-fire exclusion lists: [docs/AF_LABEL_AUDIT_REPORT.md](docs/AF_LABEL_AUDIT_REPORT.md),
[docs/BA_LABEL_AUDIT_REPORT.md](docs/BA_LABEL_AUDIT_REPORT.md),
[docs/FP_LABEL_AUDIT_REPORT.md](docs/FP_LABEL_AUDIT_REPORT.md).

### 2. Crop-coverage analysis

TS-SatFire scenes are supplied at ~596×595 px; every pipeline (ours and the reference) trains on a
256×256 crop for memory reasons, retaining ~19% of the imaged area. Fires are not centred in their
scenes, so this is not a neutral choice:

- **AF:** a mean of 26.8% of labelled fire pixels fall outside the crop; the worst case loses 86.2%.
- **BA/FP:** a mean of 56.3% fall outside; four progression test fires lose over 87% and one loses
  all of them.

For a substantial fraction of events the model is asked to predict a target largely absent from its
input, then scored on the discrepancy. This applies equally to every method evaluated under the
convention. We report everything under the cropped protocol for consistency with the baselines and
identify full-scene evaluation as necessary future work.

### 3. Burned-area label encoding

Band 8 finite values (range 2,119–908,660) are Julian-day or perimeter-ID codes; NaN means unburned.
100% of finite pixels are burned pixels — there are no finite non-burn values. Correct extraction is
`(~np.isnan(band8)).astype(float)`. See the [Burned Area](#burned-area-mapping) section for why a
threshold appears to work and why `nan_to_num` breaks it.

### 4. Seed variance as a reporting requirement

Every configuration is trained from five seeds. AF is tight (σ = 0.0005 F1); FP is not (σ = 0.0221,
essentially equal to the entire published baseline spread). Reporting seed variance before
attributing a difference to an architecture is, we think, the most transferable lesson of the study.

---

## Repository structure

```
DeepFire-Forecaster/
|
|-- README.md
|-- LICENSE
|
|-- paper/
|   |-- main.pdf                      # accepted manuscript
|
|-- docs/                             # per-fire exclusion lists
|   |-- AF_LABEL_AUDIT_REPORT.md
|   |-- BA_LABEL_AUDIT_REPORT.md
|   |-- FP_LABEL_AUDIT_REPORT.md
|
|-- active_fire/
|   |-- README.md
|   |-- diagnostics/                  # label audit notebooks
|   |   |-- diag_train_val_af.ipynb
|   |   |-- diag_test_af.ipynb
|   |-- af_1_day_input/               # TS = 1
|   |   |-- train/  (notebook + history, results, plots)
|   |   |-- inf/    (notebook + per-fire results, plots)
|   |-- af_2_day_input/               # TS = 2
|       |-- train/  (notebook + results, plots)
|       |-- inf/    (notebook + per-fire results, plots)
|
|-- burned_area/
|   |-- README.md
|   |-- diagnostics/ba-label-audit.ipynb
|
|-- fire_progression/
|   |-- README.md
|   |-- diagnostics/fire_pred_diag.ipynb
|   |-- fire_pred_2_day_input/
|       |-- fire_pred_2day_input.ipynb
|       |-- fire_pred_results/        # curves, comparison, per-fire maps, fp_results.json
|
|-- new_deepfire/                     # revision-round experiments
    |-- REVISION_PLAN.md
    |-- audit and crop/               # full audit + crop-coverage run (AUDIT_FINDINGS.md)
    |-- audit_findings_addendum2/     # FP criterion + F1-vs-crop correlation
    |-- protocol-eval-v2-kaggle/      # protocol decomposition (Table 6)
    |-- af_ts1_new_protocol/          # AF TS=1 under the final protocol
    |-- af_ts2_newprotocol/           # AF TS=2 under the final protocol
    |-- af_seed43/, af_seed44/        # AF seed replicates
    |-- fp_43_seed/, fp_44_seed/      # FP seed replicates
    |-- fp_all_fires/                 # FP rescored on all 24 official test fires
    |-- af_dirtyvsclean/              # audited vs unaudited controlled pair
    |-- ablation/, abblation v2/      # component ablation
    |-- audit_value_kaggle.ipynb
```

Model checkpoints (`*.pt`, `*.pth`) and large binaries are excluded by `.gitignore`; each notebook
regenerates them.

---

## How to reproduce

1. Open any notebook on Kaggle.
2. Add the [TS-SatFire dataset](https://github.com/zhaoyutim/TS-SatFire) to the notebook input.
3. Select a **T4 GPU** accelerator and run all cells.

Each notebook is self-contained and finishes within the 12-hour Kaggle session limit. No pip
installs are needed beyond what Kaggle provides (PyTorch 2.x, rasterio, matplotlib).

Suggested reading order for reproducing the paper:

| Paper section | Notebook |
|---|---|
| §4 Label-quality audit, §3.3 crop coverage | `new_deepfire/audit and crop/audit-and-crop-kaggle.ipynb` |
| §4.3 FP criterion, §6.4 F1 vs crop | `new_deepfire/audit_findings_addendum2/fp_criterion_kaggle.ipynb` |
| §6.2 Evaluation protocol (Table 6) | `new_deepfire/protocol-eval-v2-kaggle/protocol-eval-v2-kaggle.ipynb` |
| §6.3 AF results | `new_deepfire/af_ts2_newprotocol/`, `new_deepfire/af_ts1_new_protocol/`, `af_seed43/`, `af_seed44/` |
| §6.3 Impact of the audit | `new_deepfire/af_dirtyvsclean/af_dirtyvs_cleandata.ipynb` |
| §6.4 FP results | `new_deepfire/fp_all_fires/`, `fp_43_seed/`, `fp_44_seed/` |
| §6.5 Component ablation | `new_deepfire/abblation v2/af-ablation-kaggle-v2.ipynb` |

---

## Limitations

Stated plainly, as in the paper: conclusions rest on a **single benchmark and sensor family**. The
baselines were not retrained under our protocol, so the decomposition isolates the measurement
effect on our own weights but leaves open how the baseline *architectures* would rank under a common
evaluation. The ablation uses one run per arm and rules out only large effects. The FP variant is not
ablated, given its seed variance. We train no BA model, leaving open whether the band-8 Julian-day
codes can support multi-class or regression targets.

---

## Citation

```bibtex
@article{mavros2026spase,
  title   = {SpaSE-UNet3D: Sensor-Driven Wildfire Detection and Progression
             Prediction from VIIRS Multispectral Imagery},
  author  = {Mavros, Nikolaos and Katsaros, Dimitrios},
  journal = {Sensors},
  year    = {2026},
  note    = {Accepted 10 August 2026; volume, issue and article number forthcoming},
  publisher = {MDPI}
}
```

The dataset this work builds on:

```bibtex
@article{zhao2025tssatfire,
  title   = {{TS-SatFire}: A multi-task satellite image time-series dataset for
             wildfire detection and prediction},
  author  = {Zhao, Yu and Gerard, Sebastian and Ban, Yifang},
  journal = {Scientific Data},
  volume  = {12},
  number  = {1},
  pages   = {1817},
  year    = {2025},
  publisher = {Nature Publishing Group},
  doi     = {10.1038/s41597-025-06271-3}
}
```

---

## License

Released under the terms in [LICENSE](LICENSE). Code, trained-model results, and audit reports are
publicly available for research use.

## Acknowledgements

We thank the TS-SatFire authors for releasing their dataset **and their baseline code** in a form
that makes this audit and comparison possible. The protocol analysis in this repository was only
possible because the reference implementation is public.
