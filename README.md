# BurnBench

Reproducible experiments on the [TS-SatFire dataset](https://github.com/zhaoyutim/TS-SatFire) (Nature Scientific Data, 2025).
This repository contains systematic label-quality audits, a novel architecture (**SpaSE-UNet3D**), and
self-contained Kaggle notebooks for three wildfire remote-sensing tasks:
Active Fire (AF) detection, Burned Area (BA) mapping, and Fire Progression (FP) prediction.

All code runs on Kaggle with a **T4 GPU** within the 12-hour session limit.
No local environment setup is required. The dataset is available as a
[Kaggle dataset](https://www.kaggle.com/datasets/...) and is referenced directly inside each notebook.

---

## Results

### Active Fire Detection

| Model | TS | Val F1 | Test F1 | Test IoU | P | R | vs. Paper |
|-------|----|--------|---------|----------|---|---|-----------|
| SwinUNETR-3D (paper) | 2 | -- | 0.823 | 0.727 | -- | -- | baseline |
| **SpaSE-UNet3D (ours)** | **1** | **0.824** | **0.854** | **0.745** | **0.842** | **0.866** | **+3.1%** |
| **SpaSE-UNet3D (ours)** | **2** | **0.825** | **0.855** | **0.746** | **0.848** | **0.861** | **+3.2%** |

Test set: 15 verified fires (2 excluded due to missing labels; see audit report).
Optimal inference threshold: 0.20-0.22.

### Burned Area Mapping

Diagnostic audit completed. Label encoding clarified (finite band 8 = burned, not a threshold).
49 train / 5 val fires excluded due to missing labels.
Model development deferred; findings are reported as a data-quality contribution.

### Fire Progression Prediction

| Model | TS | F1 | IoU | vs. Paper |
|-------|----|----|-----|-----------|
| U-Net-3D (paper best) | 6 | 0.375 | 0.338 | baseline |
| SwinUNETR-3D (paper) | 2 | 0.366 | 0.321 | -- |
| **SpaSE-UNet3D (ours)** | **2** | **0.424** | **0.269** | **+4.9%** |

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

- Encoder channels [64, 128, 256, 512], ~32.9M parameters
- ResBlock3D with spatial-only (1,3,3) convolutions (no temporal mixing)
- Squeeze-and-Excitation (SE) channel attention at every encoder stage
- ASPP bottleneck with dilation rates [1, 6, 12] for multi-scale context
- Deep supervision on decoder outputs
- Dice + Focal combined loss
- OneCycleLR with 80-100 epoch budget
- Single config switch (`TS_LENGTH = 1` or `2`) for ablation

### 3. BA Label Encoding Discovery

The paper does not specify how BA labels are encoded.
We determined that band 8 finite values are Julian-day or perimeter-ID codes (range 2,119-908,660).
The correct label extraction is `(~np.isnan(band8)).astype(float)`, not a value threshold.
This finding is necessary for any future BA modelling work on this dataset.

---

## Repository Structure

```
ts-satfire-benchmark/
|
|-- README.md
|
|-- docs/
|   |-- AF_LABEL_AUDIT_REPORT.md   # AF label completeness, per-fire breakdown
|   |-- BA_LABEL_AUDIT_REPORT.md   # BA label completeness + encoding analysis
|   |-- FP_LABEL_AUDIT_REPORT.md   # FP label completeness, window-level analysis
|
|-- active_fire/
|   |-- README.md                  # AF task details, architecture, ablation table
|   |-- diagnostics/
|   |   |-- diag_train_val_af.ipynb
|   |   |-- diag_test_af.ipynb
|   |-- training/
|   |   |-- af_ts1_train.ipynb     # SE-UNet3D, TS=1
|   |   |-- af_ts2_train.ipynb     # SE-UNet3D, TS=2
|   |-- inference/
|       |-- af_ts1_inf.ipynb
|       |-- af_ts2_inf.ipynb
|
|-- burned_area/
|   |-- README.md                  # BA task details, audit findings
|   |-- diagnostics/
|       |-- ba_label_audit.ipynb
|
|-- fire_progression/
|   |-- README.md                  # FP task details, SpaSE-UNet3D, results, AZ exclusion
|   |-- diagnostics/
|   |   |-- fire_pred_diag.ipynb
|   |-- fp_ts2.ipynb               # train + val + test eval + plots, single session
|
|-- paper/
    |-- paper_draft.md             # Working paper draft
    |-- figures/                   # Exported figures for paper
    |-- tables/                    # Formatted result tables
```

---

## How to Reproduce

1. Open any training notebook directly on Kaggle.
2. Add the TS-SatFire dataset to the notebook's input data.
3. Run all cells. Each notebook is self-contained and will train, validate,
   and save a checkpoint within the 12-hour Kaggle session limit.
4. Run the corresponding inference notebook, pointing it at the saved checkpoint.

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
