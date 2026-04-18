# Active Fire Detection

## Task Definition

Given a temporal stack of VIIRS satellite imagery (TS=1 or TS=2 days), predict a binary
mask of actively burning pixels. Labels are stored in band 7 of the VIIRS_Day GeoTIFF;
pixels with finite values >= 7 are fire pixels.

## Data Splits

| Split | Total fires | Usable after audit | Excluded |
|-------|------------|-------------------|----------|
| Train | 138 | 120 | 18 (band 7 all-NaN or missing files) |
| Val | 13 | 12 | 1 (band 7 all-NaN) |
| Test | 17 | 15 | 2 (calfcanyon_fire, mosquito_fire -- 2022 fires with no labels) |

See `docs/AF_LABEL_AUDIT_REPORT.md` for the full per-fire breakdown.

## Architecture: SpaSE-UNet3D

SpaSE-UNet3D (Spatial Squeeze-and-Excitation 3D UNet) is a 3D UNet with
spatial-only convolutions and SE channel attention, designed for temporal
satellite stacks where temporal depth is small (1-2 days).

**Key design choices:**

- Spatial-only (1,3,3) convolutions in every ResBlock. This avoids temporal mixing
  across days, which was found to hurt performance on short windows (TS=1,2). It also
  makes the architecture portable: a model trained at TS=1 and TS=2 share the same
  weight shapes.

- Squeeze-and-Excitation (SE) attention after each encoder stage. Channels correspond
  to spectral bands; SE learns which bands are most informative per spatial context.

- ASPP bottleneck with dilation rates [1, 6, 12]. Active fire perimeters range from
  a few pixels to thousands; multi-scale receptive fields handle this variation.

- Deep supervision on all decoder outputs. Forces intermediate representations to be
  spatially meaningful, not just the final prediction head.

- Dice + Focal loss. Focal loss handles class imbalance (fire pixels are rare);
  Dice loss directly optimizes F1.

**Parameters:** 32.88M

## Results

| TS | Val F1 | Val IoU | Test F1 | Test IoU | Test P | Test R | Paper F1 | Delta |
|----|--------|---------|---------|----------|--------|--------|----------|-------|
| 1 | 0.824 | 0.700 | 0.854 | 0.745 | 0.842 | 0.866 | 0.823 | +3.1% |
| 2 | 0.825 | 0.702 | 0.855 | 0.746 | 0.848 | 0.861 | 0.823 | +3.2% |

Optimal inference threshold: 0.20-0.22 (tuned on validation set).

## Training Details

| Hyperparameter | Value |
|---------------|-------|
| Patch size | 256x256 |
| Batch size | 8 |
| Optimizer | AdamW |
| LR schedule | OneCycleLR |
| Epochs (TS=1) | 100 |
| Epochs (TS=2) | 80 |
| GPU | Kaggle T4 |
| Training time (TS=1) | ~4.2h |
| Training time (TS=2) | ~6.5h |

## Notebooks

| Notebook | Purpose |
|----------|---------|
| `diagnostics/diag_train_val_af.ipynb` | Label completeness audit for train+val splits |
| `diagnostics/diag_test_af.ipynb` | Label completeness audit for test split |
| `training/af_ts1_train.ipynb` | Full training run, TS=1 |
| `training/af_ts2_train.ipynb` | Full training run, TS=2 |
| `inference/af_ts1_inf.ipynb` | Test evaluation, threshold sweep, TP/FP/FN overlays, TS=1 |
| `inference/af_ts2_inf.ipynb` | Test evaluation, threshold sweep, TP/FP/FN overlays, TS=2 |
