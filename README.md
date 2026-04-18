# BurnBench

Reproducible experiments on the [TS-SatFire dataset](https://github.com/zhaoyutim/TS-SatFire) (Nature Scientific Data, 2025).
This repository contains systematic label-quality audits, a novel architecture (**SpaSE-UNet3D**), and
self-contained Kaggle notebooks for three wildfire remote-sensing tasks:
Active Fire (AF) detection, Burned Area (BA) mapping, and Fire Progression (FP) prediction.

All code runs on Kaggle with a **T4 GPU** within the 12-hour session limit.
No local environment setup is required. The TS-SatFire dataset is referenced directly inside each notebook via the Kaggle input path.

---

## Results

### Active Fire Detection

| Model | TS | Val F1 | Test F1 | Test IoU | P | R | vs. Paper |
|-------|----|--------|---------|----------|---|---|-----------|
| SwinUNETR-3D (paper) | 2 | -- | 0.823 | 0.727 | -- | -- | baseline |
| **SpaSE-UNet3D (ours)** | **1** | **0.824** | **0.854** | **0.745** | **0.842** | **0.866** | **+3.1%** |
| **SpaSE-UNet3D (ours)** | **2** | **0.825** | **0.855** | **0.746** | **0.848** | **0.861** | **+3.2%** |

Test set: 15 verified fires (2 excluded due to missing labels, see audit report).
Optimal inference threshold: 0.20-0.22.

**Training curves (TS=2):**

![Training Curves](https://raw.githubusercontent.com/mavroul1s/DeepFire-Forecaster/main/active_fire/af_2_day_input/train/results/plots/curves_v6.png)

**Benchmark comparison vs. all paper baselines (TS=2):**

![Benchmark Comparison](https://raw.githubusercontent.com/mavroul1s/DeepFire-Forecaster/main/active_fire/af_2_day_input/inf/results/plots/model_comparison_test.png)

**Per-fire F1 on test set (TS=2):**

![Per Fire F1](https://raw.githubusercontent.com/mavroul1s/DeepFire-Forecaster/main/active_fire/af_2_day_input/inf/results/plots/per_fire_f1.png)

**TP / FP / FN overlays across all test fires (TS=2):**

![All Fires TPFPFN](https://raw.githubusercontent.com/mavroul1s/DeepFire-Forecaster/main/active_fire/af_2_day_input/inf/results/plots/all_fires_tpfpfn.png)

---

### Burned Area Mapping

Diagnostic audit completed. Label encoding clarified (finite band 8 = burned, not a threshold).
49 train / 5 val fires excluded due to missing labels.
Model development deferred; findings are reported as a standalone data-quality contribution.

---

### Fire Progression Prediction

| Model | TS | F1 | IoU | vs. Paper |
|-------|----|----|-----|-----------|
| U-Net-3D (paper best) | 6 | 0.375 | 0.338 | baseline |
| SwinUNETR-3D (paper) | 6 | 0.374 | 0.331 | -- |
| UNETR-3D (paper) | 6 | 0.371 | 0.336 | -- |
| SwinUNETR-3D (paper) | 2 | 0.366 | 0.321 | -- |
| **SpaSE-UNet3D (ours)** | **2** | **0.424** | **0.269** | **+4.9%** |

**Training curves and benchmark comparison:**

![FP Curves](https://raw.githubusercontent.com/mavroul1s/DeepFire-Forecaster/main/fire_progression/fire_pred_2_day_input/fire_pred_results/fp_curves.png)

![FP Benchmark](https://raw.githubusercontent.com/mavroul1s/DeepFire-Forecaster/main/fire_progression/fire_pred_2_day_input/fire_pred_results/fp_compare.png)

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

---

## Key Contributions

### 1. Label Quality Audit (all three tasks)

The original paper does not document label completeness.
We audited every fire in every split and found substantial missing labels:

| Task | Train excluded | Val excluded | Test excluded | Notes |
|------|---------------|--------------|---------------|-------|
| AF | 18 fires | 1 fire | 2 fires | Band 7 all-NaN |
| BA | 49 fires | 5 fires | -- | Band 8 all-NaN |
| FP | 49 fires | 6 fires | -- | Derived from BA labels |

Training on unaudited data capped AF recall at ~0.80. After exclusion, recall rose to 0.86.

### 2. Novel Architecture: SpaSE-UNet3D

SpaSE-UNet3D (Spatial Squeeze-and-Excitation 3D UNet):

- Encoder channels [64, 128, 256, 512], ~32.9M parameters
- ResBlock3D with spatial-only (1,3,3) convolutions — no temporal mixing across days
- Squeeze-and-Excitation (SE) channel attention at every encoder stage
- ASPP bottleneck with dilation rates [1, 6, 12] for multi-scale context
- Deep supervision on decoder outputs
- Dice + Focal combined loss
- OneCycleLR with 80-100 epoch budget
- Single config switch (`TS_LENGTH = 1` or `2`) for clean ablation

### 3. BA Label Encoding Discovery

The paper does not specify how BA labels are encoded.
We determined that band 8 finite values are Julian-day or perimeter-ID codes (range 2,119-908,660).
The correct label extraction is `(~np.isnan(band8)).astype(float)`, not a value threshold.
This is a necessary finding for any future BA modelling on this dataset.

---

## Repository Structure

```
DeepFire-Forecaster/
|
|-- README.md
|-- .gitignore
|
|-- docs/
|   |-- AF_LABEL_AUDIT_REPORT.md
|   |-- BA_LABEL_AUDIT_REPORT.md
|   |-- FP_LABEL_AUDIT_REPORT.md
|
|-- active_fire/
|   |-- README.md
|   |-- diagnostics/
|   |   |-- diag_train_val_af.ipynb
|   |   |-- diag_test_af.ipynb
|   |-- af_1_day_input/
|   |   |-- train/
|   |   |   |-- af_1_dy_input_train.ipynb
|   |   |   |-- results/
|   |   |       |-- history_v6.csv
|   |   |       |-- results_v6.json
|   |   |       |-- plots/
|   |   |-- inf/
|   |       |-- af_1_day_input_inf.ipynb
|   |       |-- results/
|   |           |-- per_fire_test_results.csv
|   |           |-- test_results.json
|   |           |-- plots/
|   |-- af_2_day_input/
|       |-- train/
|       |   |-- af_2day_input__train.ipynb
|       |   |-- results/
|       |       |-- history_v6.csv
|       |       |-- results_v6.json
|       |       |-- plots/
|       |-- inf/
|           |-- af_2_day_input_inf.ipynb
|           |-- results/
|               |-- per_fire_test_results.csv
|               |-- test_results.json
|               |-- plots/
|
|-- burned_area/
|   |-- README.md
|   |-- diagnostics/
|       |-- ba-label-audit.ipynb
|
|-- fire_progression/
|   |-- README.md
|   |-- diagnostics/
|   |   |-- fire_pred_diag.ipynb
|   |-- fire_pred_2_day_input/
|       |-- fire_pred_2day_input.ipynb
|       |-- fire_pred_results/
|           |-- fp_curves.png
|           |-- fp_compare.png
|           |-- fp_results.json
|           |-- fp_fire_maps/
|
|-- paper/
    |-- paper_draft.md
    |-- figures/
    |-- tables/
```

---

## How to Reproduce

1. Open any notebook directly on Kaggle.
2. Add the TS-SatFire dataset to the notebook input.
3. Run all cells. Each notebook is fully self-contained and completes within the 12-hour Kaggle session limit.

No pip installs are required beyond what Kaggle provides (PyTorch 2.x, rasterio, matplotlib).

---

## Citation

If you use the audit findings or architectures from this repository, please cite:

```
[paper citation will go here once published]
```

The original dataset paper:

```
Zhao, Y. et al. TS-SatFire: A temporal satellite image dataset for wildfire detection.
Scientific Data, 2025.
```