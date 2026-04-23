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

See `../docs/AF_LABEL_AUDIT_REPORT.md` for the full per-fire breakdown.

---

## Architecture: SpaSE-UNet3D (AF variant)

SpaSE-UNet3D (Spatial Squeeze-and-Excitation 3D UNet) is a 3D encoder-decoder
with spatial-only convolutions and SE channel attention.

**Input:** 8 channels — 6 VIIRS Day bands + 2 VIIRS Night bands.
**Parameters:** 32.88M

### ResBlock3D

The core building block. Each block applies two spatial-only convolutions,
Dropout3D between them, SE channel attention after the second conv,
and a residual skip connection with BN projection when channel dimensions change.

```
Conv3d(ic, oc, kernel=(1,3,3))  ->  BN  ->  ReLU
Dropout3D(p=0.1)
Conv3d(oc, oc, kernel=(1,3,3))  ->  BN
SEBlock3D(oc)
+ skip (Conv3d(ic,oc,1) + BN if ic != oc, else Identity)
ReLU
```

Activation: **ReLU** throughout.
Dropout: **Dropout3D(p=0.1)** applied between the two convolutions in every ResBlock.

### Encoder

Four stages with spatial MaxPool3D(1,2,2) for downsampling between stages.
Only the spatial dimensions are pooled — the temporal dimension is preserved.

```
Input [B, 8, T, H, W]
  -> ResBlock3D(8,   64)   + MaxPool3D(1,2,2)
  -> ResBlock3D(64,  128)  + MaxPool3D(1,2,2)
  -> ResBlock3D(128, 256)  + MaxPool3D(1,2,2)
  -> ResBlock3D(256, 512)  + MaxPool3D(1,2,2)
```

### Bottleneck

A plain ResBlock3D that doubles the channel dimension: 512 → 1024.
No ASPP in the AF variant — the bottleneck is a single residual block.

### Decoder

Symmetric upsampling with ConvTranspose3D(1,2,2) + skip connections from the encoder.
Each decoder stage is a ResBlock3D on the concatenated (upsampled + skip) features.

```
  -> ConvTranspose3D(1024, 512) + cat(enc4 skip) -> ResBlock3D(1024, 512)
  -> ConvTranspose3D(512,  256) + cat(enc3 skip) -> ResBlock3D(512,  256)
  -> ConvTranspose3D(256,  128) + cat(enc2 skip) -> ResBlock3D(256,  128)
  -> ConvTranspose3D(128,  64)  + cat(enc1 skip) -> ResBlock3D(128,  64)
```

### Deep Supervision

Auxiliary segmentation heads are attached to intermediate decoder outputs.
The total loss combines the main head loss and the auxiliary losses
with DS_WEIGHT=0.3. This forces intermediate feature maps to maintain
spatial specificity and regularizes training on the small dataset.

### Loss Function

```
Loss = 0.5 * Dice + 0.5 * Focal(alpha=0.75, gamma=2.0)
```

Focal loss handles the severe class imbalance (fire pixels are rare).
Dice loss directly optimizes the F1 metric.

### Training

| Hyperparameter | Value |
|---------------|-------|
| Input channels | 8 |
| Encoder channels | [64, 128, 256, 512] |
| Bottleneck | ResBlock3D 512→1024 |
| Activation | ReLU |
| Dropout | Dropout3D(p=0.1) |
| Deep supervision | Yes (weight=0.3) |
| Loss | Dice(0.5) + Focal(0.5) |
| Batch size | 8 |
| Optimizer | AdamW |
| LR schedule | OneCycleLR |
| Epochs (TS=1) | 100 |
| Epochs (TS=2) | 80 |
| Patch size | 256x256 |
| GPU | Kaggle T4 |
| Training time (TS=1) | ~4.2h |
| Training time (TS=2) | ~6.5h |

---

## Results

| TS | Val F1 | Val IoU | Test F1 | Test IoU | Test P | Test R | Paper F1 | Delta |
|----|--------|---------|---------|----------|--------|--------|----------|-------|
| 1 | 0.824 | 0.700 | 0.854 | 0.745 | 0.842 | 0.866 | 0.823 | +3.1% |
| 2 | 0.825 | 0.702 | 0.855 | 0.746 | 0.848 | 0.861 | 0.823 | +3.2% |

Optimal inference threshold: 0.20-0.22 (tuned on validation set).
Test set: 15 verified fires (calfcanyon_fire and mosquito_fire excluded).

---

## Training Curves

**TS=1**

![Training Curves TS1](af_1_day_input/train/results/plots/curves_v6.png)

**TS=2**

![Training Curves TS2](af_2_day_input/train/results/plots/curves_v6.png)

---

## Threshold Sweep (Validation)

**TS=1**

![Threshold Sweep TS1](af_1_day_input/train/results/plots/threshold_v6.png)

**TS=2**

![Threshold Sweep TS2](af_2_day_input/train/results/plots/threshold_v6.png)

---

## Test Set Results

### Benchmark Comparison vs. Paper Baselines

**TS=1**

![Benchmark TS1](af_1_day_input/inf/results/plots/model_comparison_test.png)

**TS=2**

![Benchmark TS2](af_2_day_input/inf/results/plots/model_comparison_test.png)

### Per-Fire F1

**TS=1**

![Per Fire F1 TS1](af_1_day_input/inf/results/plots/per_fire_f1.png)

**TS=2**

![Per Fire F1 TS2](af_2_day_input/inf/results/plots/per_fire_f1.png)

### TP / FP / FN Overlays (all 15 test fires)

**TS=1**

![All Fires TS1](af_1_day_input/inf/results/plots/all_fires_tpfpfn.png)

**TS=2**

![All Fires TS2](af_2_day_input/inf/results/plots/all_fires_tpfpfn.png)

---

## Folder Structure

```
active_fire/
|-- README.md
|-- diagnostics/
|   |-- diag_train_val_af.ipynb   # label audit for train + val splits
|   |-- diag_test_af.ipynb        # label audit for test split
|-- af_1_day_input/
|   |-- train/
|   |   |-- af_1_dy_input_train.ipynb
|   |   |-- results/
|   |       |-- history_v6.csv
|   |       |-- results_v6.json
|   |       |-- plots/
|   |           |-- curves_v6.png
|   |           |-- comparison_v6.png
|   |           |-- threshold_v6.png
|   |-- inf/
|       |-- af_1_day_input_inf.ipynb
|       |-- results/
|           |-- per_fire_test_results.csv
|           |-- test_results.json
|           |-- plots/
|               |-- all_fires_tpfpfn.png
|               |-- model_comparison_test.png
|               |-- per_fire_f1.png
|               |-- test_threshold_sweep.png
|-- af_2_day_input/
    |-- train/
    |   |-- af_2day_input__train.ipynb
    |   |-- results/
    |       |-- history_v6.csv
    |       |-- results_v6.json
    |       |-- plots/
    |           |-- curves_v6.png
    |           |-- comparison_v6.png
    |           |-- threshold_v6.png
    |-- inf/
        |-- af_2_day_input_inf.ipynb
        |-- results/
            |-- per_fire_test_results.csv
            |-- test_results.json
            |-- plots/
                |-- all_fires_tpfpfn.png
                |-- model_comparison_test.png
                |-- per_fire_f1.png
                |-- test_threshold_sweep.png
```

## Notebooks

| Notebook | Purpose |
|----------|---------|
| `diagnostics/diag_train_val_af.ipynb` | Label completeness audit for train + val splits |
| `diagnostics/diag_test_af.ipynb` | Label completeness audit for test split |
| `af_1_day_input/train/af_1_dy_input_train.ipynb` | Full training run, TS=1 |
| `af_1_day_input/inf/af_1_day_input_inf.ipynb` | Test evaluation + threshold sweep + overlays, TS=1 |
| `af_2_day_input/train/af_2day_input__train.ipynb` | Full training run, TS=2 |
| `af_2_day_input/inf/af_2_day_input_inf.ipynb` | Test evaluation + threshold sweep + overlays, TS=2 |
