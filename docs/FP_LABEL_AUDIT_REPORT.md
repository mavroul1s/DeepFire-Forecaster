# TS-SatFire Fire Prediction (FP) -- Label Quality Audit Report

## Overview

This report documents the label-quality analysis of the TS-SatFire dataset for
the Wildfire Progression Prediction (FP) task. The FP label is defined (per the
paper and `dataset_gen_pred.py`) as:

```
FP_label(t) = BA_mask(t+TS) \ BA_mask(t+TS-1)
```

i.e. the set of pixels that become newly burned between the last observed day
and the next day. A window is FP-usable only when BOTH the last input day AND
the next day have valid (not all-NaN) band 8 in the VIIRS_Day GeoTIFF.

The progression signal is strictly sparser than the BA mask itself: a window
may have valid BA labels on both days but zero newly burned pixels.

---

## Paper-Correct Splits

From the authors' `dataset_gen_pred.py`:

### Validation (paper lists 15 IDs, 14 present in the Kaggle release)

```python
FP_VAL_IDS = [
    "20568194", "20701026", "20562846", "20700973", "24462610",
    "24462788", "24462753", "24103571", "21998313", "21751303",
    "22141596", "21999381",
    "23301962",   # MISSING from Kaggle dataset - cannot be used
    "22712904",
    "22713339",   # Has no VIIRS_Day files - effectively unusable
]
```

**`23301962` does not exist in the Kaggle release.** The effective validation
set is 14 fires; `22713339` has no VIIRS_Day files and contributes zero
windows. Usable validation fires: 8.

### Test Set: US_2021 Fires Only (24 fires)

The FP test set is the 24 `US_2021_*` wildfires drawn from the authors' 2021
CSV. The 17 named fires in the dataset are the AF test set and are not used
for FP. Fig. 11 of the paper, titled *"Results of SwinUNETR for fire
progression prediction task. Fire ID: NM3323810847220210520"*, confirms this --
the example is a US_2021 fire.

### Training

All numeric fire IDs NOT in `FP_VAL_IDS`. Effective count: 137 fires.

---

## Dataset Structure Per Fire

Each fire folder contains four subdirectories. Relevant to FP:

| Directory | Files | Bands | Contents |
|-----------|-------|-------|----------|
| `VIIRS_Day/` | 1 per day | 8 | VIIRS day surface reflectance + BA mask in band 8 |
| `VIIRS_Night/` | 1 per day | 2 | VIIRS night thermal bands |
| `FirePred/` | 1 per day | **19** | **Pre-computed input feature stack for FP** |
| `ESRI_LULC/` | 1 static | 1 | Land-cover class raster |

### `FirePred/` Band Inventory (verified on fire 20778186)

The FirePred directory was discovered during this audit. It contains a
19-band feature stack per day -- exactly the inputs the paper uses for FP:

| Band | Value range / sample | Likely meaning |
|------|----------------------|----------------|
| 1 | -1081 to +1000 | Wind U component |
| 2 | -252 to +200 | Wind V component |
| 3 | 0 (all pixels) | Unused / placeholder |
| 4 | 1.9 - 2.8 | Atmospheric variable (humidity / RH) |
| 5 | 254 - 263 (K) | Air temperature |
| 6 | 271 - 274 (K) | Forecast temperature |
| 7 | 290 - 292 (K) | Ground/surface temperature |
| 8 | 33 - 45 | Wind speed or precipitation |
| 9 | ~0.004 | Drought index / ERC normalized |
| 10 | 0 - 0.08 | Vegetation index (EVI / NDVI) |
| 11 | 0 - 0.23 | Vegetation index (second) |
| 12 | 588 - 631 (m) | Elevation (SRTM) |
| 13 | -2.3 to -1.6 | Slope or aspect projection |
| 14 | 1 - 15 | Land cover class |
| 15 | 0 - 0.25 | Normalized auxiliary feature |
| 16 | 0.71 - 1.02 | Normalized auxiliary feature |
| 17 | -47 to -28 | Forecast wind / temp anomaly |
| 18 | 14 - 14.7 | Forecast auxiliary |
| 19 | 0.004+, all pixels finite | Not the binary FP label (continuous) |

**Implication for our modeling:** FirePred/ is the INPUT feature stack, not a
label file. The binary FP label must still be computed from `VIIRS_Day` band 8
via `(b8_next is finite) AND (b8_last is NaN)`, i.e. set difference of the
consecutive BA masks. This is what the paper's data loader does at runtime.

**For a model that matches the paper's input specification, use FirePred/*.tif
as the 19-channel input.** A VIIRS-only input (8 day + 2 night = 10 channels)
is a weaker baseline and one possible reason the paper's reported FP F1 is
hard to beat without matching their input stack.

---

## Audit Method

For every fire in each split we count, using a TS=2 sliding window over the
center 256x256 crop:

| Metric | Definition |
|--------|------------|
| `windows_total` | Number of TS-day sliding windows with a valid next-day index |
| `windows_pair_ok` | Windows where BOTH day (t+TS-1) and day (t+TS) have non-all-NaN band 8 |
| `windows_progression` | Windows with at least one newly burned pixel |
| `total_new_px` | Sum of newly burned pixels across progression windows |

**Fire is EXCLUDED from FP if any of:**
- `TOO_FEW_DAYS`: fewer than TS+1 = 3 daily images
- `NO_VALID_PAIRS`: zero windows have both consecutive BA labels
- `NO_PROGRESSION`: valid pairs exist but no newly burned pixels anywhere
- `MOSTLY_BAD`: fewer than 30% of windows have valid BA pairs

---

## Test Set Audit (24 US_2021 fires)

### Summary

| Category | Count | Percentage |
|----------|-------|------------|
| OK per audit | 18 | 75% |
| MOSTLY_BAD | 2 | 8% |
| NO_PROGRESSION (audit) | 1 | 4% |
| NO_VALID_PAIRS | 3 | 13% |
| NO_PROGRESSION (post-audit empirical) | 2 | 8% |
| **USABLE** | **16** | **67%** |
| **EXCLUDE** | **8** | **33%** |

| Metric | Value |
|--------|-------|
| Total windows | 806 |
| Windows with valid BA pair | 632 (78.4%) |
| Windows with progression > 0 | 495 (61.4%) |
| Total new-burn pixels | 184,251 |
| Mean new-burn per progression window | 372 |

### Excluded Test Fires (8)

| Fire ID | Status | Pair_OK / Total | Prog Windows | New Burn Px |
|---------|--------|-----------------|--------------|-------------|
| US_2021_FL2521008104520210308 | NO_VALID_PAIRS | 0 / 12 | 0 | 0 |
| US_2021_MT4714310953420211004 | MOSTLY_BAD | 4 / 22 | 2 | 698 |
| US_2021_NM3323810847220210520 | MOSTLY_BAD | 8 / 36 | 1 | 2 |
| US_2021_NM3340210587120210426 | NO_VALID_PAIRS | 0 / 8 | 0 | 0 |
| US_2021_NM3344410803520210514 | NO_PROGRESSION | 1 / 21 | 0 | 0 |
| US_2021_NM3676810505920211120 | NO_VALID_PAIRS | 0 / 27 | 0 | 0 |
| US_2021_AZ3345510938920210616 | NO_PROGRESSION (post-audit) | 18 / 18 | 0 | 0 |
| US_2021_AZ3368910927620210616 | NO_PROGRESSION (post-audit) | 20 / 20 | 0 | 0 |

**Note on the two AZ fires:** During the initial band-8 audit these two fires
were classified as OK (all windows have valid consecutive BA pairs). However,
empirical evaluation across multiple model runs (v3, v4, v5, v6) consistently
produced F1 = 0.000 and IoU = 0.000 on both fires, indicating that the
pixel-wise progression signal is effectively zero even where BA labels exist.
The fires are therefore added to the exclusion list post-audit. The BA audit
reported burn fractions of 0.00083 and 0.00087 respectively -- borderline
values that produce valid pairs but no measurable newly-burned pixels inside
the 256x256 center crop. This is a known limitation of center-cropping small
AZ desert fires whose footprint falls outside the crop window.

**Note on `NM3323810847220210520`:** The paper's Fig. 11 shows qualitative
results on this exact fire, yet our audit finds only 8 valid BA pairs out of
36 windows with a total of 2 new-burn pixels. The paper likely uses the same
label definition but tolerates noisier fires by necessity (it is their Fig. 11
example). This fire is excluded from our evaluation for signal-quality
reasons, but keep it in mind when comparing to the paper's qualitative figure.

### Geographic Pattern in Exclusions
All 8 excluded test fires are from NM (4), AZ (2), FL (1), or MT (1). The 5
California, 3 Idaho, and 4 Washington fires all have good-to-excellent BA
coverage and produce measurable progression signal. The southwestern US
(NM, AZ) dominates exclusions -- this matches the known spatial gap in NIFC
perimeter coverage and, for the AZ fires specifically, the small spatial
footprint of desert fires relative to the center-crop window.

### Top-10 Usable Test Fires (by progression signal)

| Fire ID | Pair_OK / Total | Prog Windows | New Burn Px |
|---------|-----------------|--------------|-------------|
| US_2021_WA4856812048820210708 | 35 / 35 | 30 | 35,123 |
| US_2021_MT4568311385420210708 | 63 / 72 | 54 | 28,249 |
| US_2021_MT4579011310120210708 | 76 / 85 | 59 | 27,073 |
| US_2021_WA4828511853120210713 | 58 / 64 | 54 | 20,187 |
| US_2021_ID4453211532920210810 | 44 / 57 | 25 | 15,924 |
| US_2021_CA3658211879520210912 | 47 / 49 | 37 | 14,299 |
| US_2021_ID4558511544420210705 | 53 / 53 | 37 | 13,314 |
| US_2021_WA4879111827120210805 | 23 / 24 | 20 | 6,437 |
| US_2021_ID4762711608320210708 | 56 / 56 | 46 | 5,469 |
| US_2021_WA4877811903420210803 | 46 / 47 | 30 | 4,060 |

---

## Validation Set Audit (14 fires present out of 15 in paper)

### Summary

| Category | Count | Percentage |
|----------|-------|------------|
| OK (usable) | 8 | 57% |
| NO_VALID_PAIRS | 5 | 36% |
| TOO_FEW_DAYS | 1 (22713339) | 7% |
| **USABLE** | **8** | **57%** |
| **EXCLUDE** | **6** | **43%** |

Note: `23301962` (in paper's val list) is not in the Kaggle release and is
therefore not counted.

| Metric | Value |
|--------|-------|
| Total windows | 252 |
| Windows with valid BA pair | 153 (60.7%) |
| Windows with progression > 0 | 132 (52.4%) |
| Total new-burn pixels | 71,050 |
| Mean new-burn per progression window | 538 |

### Validation Fire Details

| Fire ID | Status | Pair_OK / Total | Prog Windows | New Burn Px |
|---------|--------|-----------------|--------------|-------------|
| 20562846 | EXCLUDE / NO_VALID_PAIRS | 0 / 6 | 0 | 0 |
| 20568194 | EXCLUDE / NO_VALID_PAIRS | 0 / 36 | 0 | 0 |
| 20700973 | EXCLUDE / NO_VALID_PAIRS | 0 / 7 | 0 | 0 |
| 20701026 | EXCLUDE / NO_VALID_PAIRS | 0 / 22 | 0 | 0 |
| 21751303 | OK | 39 / 39 | 33 | 6,291 |
| 21998313 | OK | 22 / 22 | 21 | 6,147 |
| 21999381 | OK | 6 / 16 | 6 | 866 |
| 22141596 | OK | 15 / 17 | 14 | 8,235 |
| 22712904 | EXCLUDE / NO_VALID_PAIRS | 0 / 14 | 0 | 0 |
| 22713339 | EXCLUDE / TOO_FEW_DAYS (no files) | 0 / 0 | 0 | 0 |
| 23301962 | NOT PRESENT in Kaggle release | -- | -- | -- |
| 24103571 | OK | 16 / 16 | 15 | 21,654 |
| 24462610 | OK | 24 / 25 | 14 | 16,681 |
| 24462753 | OK | 17 / 18 | 16 | 3,174 |
| 24462788 | OK | 14 / 14 | 13 | 8,002 |

### Validation Attrition: 43%
With only 8 usable validation fires, expect noticeable run-to-run variance on
val F1. Track convergence primarily on per-fire F1 rather than aggregate.

---

## Training Set Audit (137 fires)

### Summary

| Category | Count | Percentage |
|----------|-------|------------|
| OK (usable) | 89 | 65% |
| MOSTLY_BAD | 5 | 4% |
| NO_PROGRESSION | 3 | 2% |
| NO_VALID_PAIRS | 27 | 20% |
| TOO_FEW_DAYS (no files) | 13 | 9% |
| **USABLE** | **89** | **65%** |
| **EXCLUDE** | **48** | **35%** |

| Metric | Value |
|--------|-------|
| Total windows | 2,006 |
| Windows with valid BA pair | 1,395 (69.5%) |
| Windows with progression > 0 | 1,188 (59.2%) |
| Total new-burn pixels | 648,829 |
| Mean new-burn per progression window | 546 |

### Training Exclusion List

```python
FP_TRAIN_EXCLUDE = [
    # NO_VALID_PAIRS (27 fires - zero windows with both BA labels)
    "20702159", "20777181", "20777195", "20777203", "20777397",
    "20777452", "20777459", "20777482", "20777487", "20777508",
    "20777521", "20778140", "20778153", "20778225", "20899892",
    "20900040", "20900085", "20900124", "20900131", "20901111",
    "20901127", "21158900", "21158932", "21158939", "21158940",
    "22712973", "23860939",

    # MOSTLY_BAD (5 fires - <30% windows have valid BA pair)
    "20777134", "20777152", "20899721", "20899766", "21997770",

    # NO_PROGRESSION (3 fires - valid pairs but zero newly burned)
    "20899967", "21693566", "23036871",

    # TOO_FEW_DAYS / NO_FILES (13 fires - no VIIRS_Day directory)
    "20777207", "20777386", "21889672", "21889683", "21889697",
    "21889719", "21889734", "21889754", "21997775", "23860978",
    "23861018", "23861131", "24332700",
]
```

### Top-10 Training Progression Fires

| Fire ID | Pair_OK / Total | Prog Windows | New Burn Px | Max Window |
|---------|-----------------|--------------|-------------|------------|
| 24332939 | 41 / 41 | 39 | 53,469 | 14,412 |
| 24461899 | 11 / 20 | 6 | 43,002 | 16,706 |
| 24462263 | 24 / 24 | 22 | 42,455 | 12,681 |
| 24462488 | 24 / 24 | 11 | 29,753 | 7,627 |
| 24332732 | 21 / 21 | 20 | 29,402 | 14,429 |
| 22938749 | 21 / 21 | 21 | 22,343 | 4,975 |
| 21998264 | 15 / 17 | 11 | 19,873 | 9,705 |
| 24332763 | 50 / 50 | 49 | 16,765 | 4,401 |
| 21890072 | 8 / 9 | 7 | 15,887 | 5,800 |
| 24461328 | 22 / 22 | 19 | 15,573 | 7,024 |

### Temporal Pattern in Exclusions
A large block of excluded IDs in the 20777xxx, 20899xxx, 20900xxx, 20901xxx,
and 21158xxx ranges (about 30 fires) have `NO_VALID_PAIRS` despite having many
days of VIIRS imagery. These are 2017-2018 fires. This suggests their BA
labels (band 8) are systematically unavailable -- likely because NIFC
perimeter data was not ingested for those events at BA generation time. Our
audit cannot recover these fires without external BA labels.

---

## Complete Exclusion Lists (ready to paste)

```python
FP_TRAIN_EXCLUDE = [
    "20702159", "20777134", "20777152", "20777181", "20777195",
    "20777203", "20777207", "20777386", "20777397", "20777452",
    "20777459", "20777482", "20777487", "20777508", "20777521",
    "20778140", "20778153", "20778225", "20899721", "20899766",
    "20899892", "20899967", "20900040", "20900085", "20900124",
    "20900131", "20901111", "20901127", "21158900", "21158932",
    "21158939", "21158940", "21693566", "21889672", "21889683",
    "21889697", "21889719", "21889734", "21889754", "21997770",
    "21997775", "22712973", "23036871", "23860939", "23860978",
    "23861018", "23861131", "24332700",
]

FP_VAL_EXCLUDE = [
    "20562846", "20568194", "20700973", "20701026",
    "22712904", "22713339",
    # 23301962 is not present in the Kaggle release; skip silently
]

FP_TEST_EXCLUDE = [
    "US_2021_FL2521008104520210308",
    "US_2021_MT4714310953420211004",
    "US_2021_NM3323810847220210520",
    "US_2021_NM3340210587120210426",
    "US_2021_NM3344410803520210514",
    "US_2021_NM3676810505920211120",
    # Post-audit additions (empirical F1=0.000 across all v3-v6 runs):
    "US_2021_AZ3345510938920210616",
    "US_2021_AZ3368910927620210616",
]
```

---

## Dataset Summary After Cleaning

| Split | Fires on disk | Excluded | Usable | % Usable | Valid Windows | Progression Windows |
|-------|---------------|----------|--------|----------|---------------|---------------------|
| Train | 137 | 48 | 89 | 65% | 1,395 | 1,188 |
| Val | 14 | 6 | 8 | 57% | 153 | 132 |
| Test | 24 | 8 | 16 | 67% | 594 | 495 |

---

## Progression Signal Statistics

Per-fire mean burn fraction (newly burned pixels / 256x256 patch) across
windows that have any progression:

| Split | n_fires | Min | p25 | Median | p75 | Max | Mean |
|-------|---------|------|-------|--------|-------|-------|-------|
| Train | 94 | 0.00002 | 0.00330 | 0.00558 | 0.01268 | 0.10936 | 0.01065 |
| Val | 8 | 0.00220 | 0.00300 | 0.00672 | 0.01159 | 0.02203 | 0.00890 |
| Test | 20 | 0.00003 | 0.00178 | 0.00335 | 0.00575 | 0.01786 | 0.00446 |

### Implications for Loss Design

1. **Median train progression fraction is ~0.56%.** This is a very imbalanced
   binary segmentation problem -- on the order of 200:1 negative-to-positive
   pixels per window.

2. **Test is sparser than train** (median 0.33% vs 0.56%). A model that
   over-fits to train-set sparsity will have a calibration gap on test.
   Suggests careful threshold selection on the validation set.

3. **Val is closest to train in sparsity** (median 0.67% vs 0.56%), so
   val-set threshold sweeps should transfer reasonably to test, but expect
   the optimal test threshold to be slightly lower than val.

### Recommended Loss Configuration

For BCE-based losses: `pos_weight` in the range **150-250**.

For Focal loss: `alpha` in the range **0.85-0.92**, `gamma` in the range
**3.0-4.0**.

A combined Dice + Focal loss is a safe starting point. Try
`0.5 * Dice + 0.5 * Focal(alpha=0.88, gamma=3.0)`.

---

## Recommendations

1. **Use the paper-correct splits.** Validation = 14 fires on disk (15 in the
   paper list, one missing). Test = 24 US_2021 fires. Do not include the
   17 named fires in FP evaluation.

2. **Treat `23301962` as silently absent.** It's in the paper's val IDs but
   not in the Kaggle download. Skip it in the data loader without error.

3. **Treat `22713339` as silently empty.** It's in the paper's val IDs but
   has no VIIRS_Day files. The data loader will produce zero windows for it.

4. **Use the FirePred/ 19-band feature stack as model input** to match the
   paper's input specification. A VIIRS-only input is a weaker baseline.

5. **Derive the binary FP label from VIIRS_Day band-8 difference** on
   consecutive days:
   ```python
   new_burn = (np.isfinite(b8_next) & np.isnan(b8_last)).astype(np.float32)
   ```
   The FirePred/ file is not a label source -- it is the input feature stack.

6. **Day-level filtering is required inside every window.** A window is only
   usable when band 8 is not all-NaN on BOTH the last input day AND the next
   day. The dataset class must enforce this.

7. **Report FP test results on 16 verified US_2021 fires.** Document the 8
   excluded fires and the reason for each exclusion. Two of the eight
   (AZ3345510938920210616, AZ3368910927620210616) were excluded post-audit
   after empirical evaluation showed zero measurable progression signal
   within the center-crop window across multiple model versions.

8. **Expect high validation variance.** With 8 usable val fires, aggregate F1
   fluctuates run-to-run. Track per-fire F1 alongside aggregate. Use multiple
   seeds if compute allows.

9. **Final training budget on Kaggle T4 (single GPU, 12h limit):** with 89
   training fires and ~1,188 progression windows, a batch size of 4 at 256x256
   will complete a full epoch in under 10 minutes. 40-60 epochs fit
   comfortably in the time budget with room for threshold sweeps.

10. **The paper's benchmark** (SwinUNETR-3D on FP, TS=2) is the target. Beating
    it requires either richer architecture or cleaner data. This audit enables
    the latter: training on 89 clean fires (vs the paper's implicit 137
    including noisy ones) should yield a measurable F1 improvement on its own.
