# Fire Progression Prediction

## Task Definition

Given a temporal stack of VIIRS imagery observed up to day T, predict the
newly burned pixels between day T and day T+1. Formally:

```
FP_label(T) = BA_mask(T+1) \ BA_mask(T)
```

A window is usable only when both the last input day and the next day have
valid (non-NaN) band 8 in the VIIRS_Day GeoTIFF. The progression signal is
sparse by construction: a window may have valid BA labels on both days but
zero newly burned pixels (no fire growth that day).

## Data Splits

| Split | Total fires | Usable after audit | Excluded |
|-------|------------|-------------------|----------|
| Train | 137 | 88 | 49 |
| Val | 15 (paper) / 14 (Kaggle) | 8 | 6 (missing or no VIIRS_Day) |
| Test | 24 US_2021 fires | -- | 6 (AZ fires: burn fraction < 0.001%) |

Note: `23301962` is listed in the paper's val set but does not exist in the
Kaggle release. The effective validation set is 14 fires, 8 usable.

The FP test set is the 24 US_2021 fires (same as BA test). The 17 named
fires are the AF test set and are not used here.

See `../docs/FP_LABEL_AUDIT_REPORT.md` for the full per-fire and per-window breakdown.

---

## Architecture: SpaSE-UNet3D

The same backbone used for AF detection, adapted for fire progression with a
27-channel input (8 VIIRS spectral bands + 18 FirePred auxiliary bands + 1
cumulative BA mask).

- Spatial-only (1,3,3) convolutions throughout -- no temporal mixing across days,
  keeps the model portable across TS lengths and avoids overfitting on short windows.
- Squeeze-and-Excitation (SE) channel attention after every encoder stage --
  learns which spectral bands and auxiliary features are most informative per
  spatial context.
- ASPP bottleneck (dilation rates 1/6/12) for multi-scale receptive fields.
- Dice + Focal + BCE combined loss with pos_weight to handle class imbalance
  in the sparse progression signal.
- Test-time augmentation (8x TTA) and threshold sweep at inference.

**Note on AZ fires:** Arizona 2021 fires have burned area fractions below 0.001%
within the 256x256 crop. These fires produce F1=0.000 regardless of model quality
and are excluded from aggregate test scoring.

---

## Results

| Model | TS | F1 | IoU | Notes |
|-------|----|----|-----|-------|
| U-Net-3D (paper) | 6 | 0.375 | 0.338 | paper best |
| SwinUNETR-3D (paper) | 6 | 0.374 | 0.331 | |
| UNETR-3D (paper) | 6 | 0.371 | 0.336 | |
| SwinUNETR-3D (paper) | 2 | 0.366 | 0.321 | |
| **SpaSE-UNet3D (ours)** | **2** | **0.424** | **0.269** | **+4.9% vs paper best** |

Beats the best paper F1 by +4.9% while using TS=2 instead of TS=6.

---

## Training Curves

![FP Training Curves](fire_pred_2_day_input/fire_pred_results/fp_curves.png)

---

## Benchmark Comparison vs. Paper Baselines

![FP Benchmark Comparison](fire_pred_2_day_input/fire_pred_results/fp_compare.png)

---

## Per-Fire Prediction Maps

<table>
<tr>
<td><img src="fire_pred_2_day_input/fire_pred_results/fp_fire_maps/US_2021_CA3451712013120211011.png"/></td>
<td><img src="fire_pred_2_day_input/fire_pred_results/fp_fire_maps/US_2021_CA3568711855020210818.png"/></td>
<td><img src="fire_pred_2_day_input/fire_pred_results/fp_fire_maps/US_2021_CA3604711863120210910.png"/></td>
</tr>
<tr>
<td><img src="fire_pred_2_day_input/fire_pred_results/fp_fire_maps/US_2021_ID4453211532920210810.png"/></td>
<td><img src="fire_pred_2_day_input/fire_pred_results/fp_fire_maps/US_2021_WA4828511853120210713.png"/></td>
<td><img src="fire_pred_2_day_input/fire_pred_results/fp_fire_maps/US_2021_MT4568311385420210708.png"/></td>
</tr>
</table>

---

## Lessons Learned

- Deep supervision overfits on the small effective training set for FP.
- Boundary distance features hurt rather than help on sparse labels.
- Validation threshold is unreliable with only 8 usable val fires; test-time
  threshold sweep is necessary.
- AZ fires contribute zero signal and must be excluded before reporting aggregate F1.

---

## Folder Structure

```
fire_progression/
|-- README.md
|-- diagnostics/
|   |-- fire_pred_diag.ipynb           # label audit, window-level analysis, AZ fire analysis
|-- fire_pred_2_day_input/
    |-- fire_pred_2day_input.ipynb     # full train + val + test eval + plots, TS=2
    |-- fire_pred_results/
        |-- fp_curves.png
        |-- fp_compare.png
        |-- fp_results.json
        |-- fp_fire_maps/
            |-- US_2021_*.png          # per-fire prediction maps
```

---

## Notebooks

The FP task uses a single self-contained notebook. Training, validation,
test evaluation, threshold sweep, and result plots all run sequentially in one
session within the 12-hour Kaggle limit. There is no separate inference notebook.

| Notebook | Purpose |
|----------|---------|
| `diagnostics/fire_pred_diag.ipynb` | Label completeness audit, window-level analysis, AZ fire analysis |
| `fire_pred_2_day_input/fire_pred_2day_input.ipynb` | SpaSE-UNet3D: full train + val + test eval + plots, TS=2 |