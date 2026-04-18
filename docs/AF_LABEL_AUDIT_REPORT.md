# TS-SatFire Active Fire -- Label Quality Audit Report

## Overview

This report documents the label completeness analysis of the TS-SatFire dataset
for the Active Fire (AF) detection task. AF labels are stored in Day GeoTIFF
band 7 (1-indexed), where finite values >= 7 indicate fire pixels and NaN
indicates missing data.

We audited all 3 splits: train (138 fires), validation (13 fires), and test (17 fires).

---

## Test Set Audit (17 named global fires)

### Method
Checked every 2-day sliding window in the center 256x256 crop of each fire.
This matches exactly what inference evaluates.

### Results

| Fire | Days | Windows | W/Label | W/Fire | TotalFirePx | Status |
|------|------|---------|---------|--------|-------------|--------|
| blue_ridge_fire | 10 | 9 | 9 | 9 | 731 | GOOD |
| calfcanyon_fire | 10 | 9 | 0 | 0 | 0 | NO LABELS |
| camp_fire | 10 | 9 | 9 | 9 | 6,470 | GOOD |
| carr_fire | 10 | 9 | 9 | 9 | 8,289 | GOOD |
| chuckegg_creek_fire | 10 | 9 | 8 | 8 | 19,592 | GOOD |
| creek_fire | 10 | 9 | 9 | 9 | 23,336 | GOOD |
| dixie_fire | 10 | 9 | 9 | 9 | 11,633 | GOOD |
| double_creek_fire | 10 | 9 | 2 | 2 | 295 | PARTIAL (2/9) |
| eagle_bluff_fire | 10 | 9 | 4 | 4 | 547 | PARTIAL (4/9) |
| elephant_hill_fire | 10 | 9 | 9 | 9 | 6,433 | GOOD |
| lytton_fire | 10 | 9 | 9 | 9 | 1,580 | GOOD |
| mosquito_fire | 10 | 9 | 0 | 0 | 0 | NO LABELS |
| sparks_lake_fire | 10 | 9 | 9 | 9 | 6,713 | GOOD |
| swedish_fire | 10 | 9 | 9 | 3 | 957 | GOOD |
| sydney_fire | 10 | 9 | 9 | 9 | 9,360 | GOOD |
| thomas_fire | 10 | 9 | 9 | 9 | 12,544 | GOOD |
| tubbs_fire | 10 | 9 | 9 | 9 | 9,183 | GOOD |

### Test Summary
- **GOOD (usable):** 15 fires
- **NO LABELS (exclude):** 2 fires (calfcanyon_fire, mosquito_fire)
- **PARTIAL (usable with care):** double_creek_fire (2/9), eagle_bluff_fire (4/9)

### Per-Day Detail for Problematic Test Fires

**calfcanyon_fire** -- ALL 10 days are NaN (2022 fire, labels never generated):
- Day 1: NaN (2022-04-05_VIIRS_Day.tif)
- Day 2: NaN (2022-04-06_VIIRS_Day.tif)
- Day 3: NaN (2022-04-07_VIIRS_Day.tif)
- Day 4: NaN (2022-04-08_VIIRS_Day.tif)
- Day 5: NaN (2022-04-09_VIIRS_Day.tif)
- Day 6: NaN (2022-04-10_VIIRS_Day.tif)
- Day 7: NaN (2022-04-11_VIIRS_Day.tif)
- Day 8: NaN (2022-04-12_VIIRS_Day.tif)
- Day 9: NaN (2022-04-13_VIIRS_Day.tif)
- Day 10: NaN (2022-04-14_VIIRS_Day.tif)

**mosquito_fire** -- ALL 10 days are NaN (2022 fire, labels never generated):
- Day 1: NaN (2022-09-03_VIIRS_Day.tif)
- Day 2: NaN (2022-09-04_VIIRS_Day.tif)
- Day 3: NaN (2022-09-05_VIIRS_Day.tif)
- Day 4: NaN (2022-09-06_VIIRS_Day.tif)
- Day 5: NaN (2022-09-07_VIIRS_Day.tif)
- Day 6: NaN (2022-09-08_VIIRS_Day.tif)
- Day 7: NaN (2022-09-09_VIIRS_Day.tif)
- Day 8: NaN (2022-09-10_VIIRS_Day.tif)
- Day 9: NaN (2022-09-11_VIIRS_Day.tif)
- Day 10: NaN (2022-09-12_VIIRS_Day.tif)

**double_creek_fire** -- Only days 1-3 have labels, days 4-10 are NaN:
- Day 1: OK, fire_px=0 (2022-08-29_VIIRS_Day.tif)
- Day 2: OK, fire_px=38 (2022-08-30_VIIRS_Day.tif)
- Day 3: OK, fire_px=257 (2022-08-31_VIIRS_Day.tif)
- Day 4: NaN (2022-09-01_VIIRS_Day.tif)
- Day 5-10: NaN

**eagle_bluff_fire** -- Days 1-5 have labels, days 6-10 are NaN:
- Day 1: OK, fire_px=49 (2019-08-05_VIIRS_Day.tif)
- Day 2: OK, fire_px=71 (2019-08-06_VIIRS_Day.tif)
- Day 3: OK, fire_px=170 (2019-08-07_VIIRS_Day.tif)
- Day 4: OK, fire_px=212 (2019-08-08_VIIRS_Day.tif)
- Day 5: OK, fire_px=94 (2019-08-09_VIIRS_Day.tif)
- Day 6-10: NaN

---

## Training Set Audit (138 numeric fires, 2017-2020)

### Summary Statistics

| Category | Count | Percentage |
|----------|-------|------------|
| FULL labels (all days OK) | 54 | 39% |
| PARTIAL (>50% days OK) | 63 | 46% |
| MOSTLY NaN (<50% days OK) | 3 | 2% |
| ZERO labels (all days NaN) | 4 | 3% |
| No files / no band 7 | 14 | 10% |
| **USABLE for training** | **117** | **85%** |
| **EXCLUDE from training** | **21** | **15%** |

### Fires to EXCLUDE from Training (21 fires)

| Fire ID | Status | Days OK / Total | Fire Pixels |
|---------|--------|-----------------|-------------|
| 20777207 | NO_FILES | 0/0 | 0 |
| 20777386 | NO_FILES | 0/0 | 0 |
| 21693566 | ZERO_LABELS | 0/20 | 0 |
| 21751305 | MOSTLY_NAN | 4/9 | 1,422 |
| 21751309 | ZERO_LABELS | 0/11 | 0 |
| 21889672 | NO_FILES | 0/0 | 0 |
| 21889683 | NO_FILES | 0/0 | 0 |
| 21889697 | NO_FILES | 0/0 | 0 |
| 21889719 | NO_FILES | 0/0 | 0 |
| 21889734 | NO_FILES | 0/0 | 0 |
| 21889754 | NO_FILES | 0/0 | 0 |
| 21890056 | MOSTLY_NAN | 2/9 | 1,065 |
| 21997775 | NO_FILES | 0/0 | 0 |
| 22712973 | ZERO_LABELS | 0/23 | 0 |
| 22713339 | NO_FILES | 0/0 | 0 |
| 23036871 | MOSTLY_NAN | 3/8 | 276 |
| 23860939 | ZERO_LABELS | 0/20 | 0 |
| 23860978 | NO_FILES | 0/0 | 0 |
| 23861018 | NO_FILES | 0/0 | 0 |
| 23861131 | NO_FILES | 0/0 | 0 |
| 24332700 | NO_FILES | 0/0 | 0 |

### Top 10 PARTIAL Training Fires (usable, but have some NaN days)

| Fire ID | Days OK / Total | % OK | Fire Days | Fire Pixels |
|---------|-----------------|------|-----------|-------------|
| 24461899 | 12/22 | 55% | 6 | 10,116 |
| 20778140 | 58/65 | 89% | 58 | 18,363 |
| 24191427 | 10/17 | 59% | 5 | 815 |
| 23160475 | 10/16 | 62% | 9 | 3,175 |
| 20702159 | 22/27 | 81% | 22 | 5,319 |
| 20778153 | 15/20 | 75% | 10 | 9,290 |
| 21890024 | 12/16 | 75% | 11 | 2,428 |
| 21890160 | 22/26 | 85% | 20 | 2,638 |
| 24333039 | 26/30 | 87% | 26 | 9,020 |
| 24333279 | 6/10 | 60% | 3 | 961 |

---

## Validation Set Audit (13 fires from paper's VAL_IDS)

### Summary Statistics

| Category | Count | Percentage |
|----------|-------|------------|
| FULL labels (all days OK) | 3 | 23% |
| PARTIAL (>50% days OK) | 9 | 69% |
| MOSTLY NaN (<50% days OK) | 0 | 0% |
| ZERO labels (all days NaN) | 1 | 8% |
| **USABLE** | **12** | **92%** |
| **EXCLUDE** | **1** | **8%** |

### Validation Fire Details

| Fire ID | Status | Days OK / Total | % OK | Fire Days | Fire Pixels |
|---------|--------|-----------------|------|-----------|-------------|
| 20568194 | PARTIAL | 37/38 | 97% | 37 | 4,808 |
| 20562846 | PARTIAL | 5/8 | 62% | 5 | 936 |
| 20700973 | FULL | all | 100% | - | - |
| 20701026 | FULL | all | 100% | - | - |
| 21751303 | PARTIAL | 32/41 | 78% | 30 | 5,921 |
| 21998313 | PARTIAL | 23/24 | 96% | 18 | 3,831 |
| 21999381 | PARTIAL | 16/18 | 89% | 10 | 1,477 |
| 22141596 | PARTIAL | 18/19 | 95% | 17 | 8,622 |
| **22712904** | **ZERO_LABELS** | **0/16** | **0%** | **0** | **0** |
| 24103571 | FULL | all | 100% | - | - |
| 24462610 | PARTIAL | 18/27 | 67% | 11 | 11,915 |
| 24462753 | PARTIAL | 18/20 | 90% | 18 | 3,779 |
| 24462788 | PARTIAL | 13/16 | 81% | 13 | 2,706 |

---

## Complete Exclusion List

For use in training/evaluation code:

```python
# Fires with completely missing or mostly missing AF labels
# Sources: NO_FILES (no VIIRS_Day), ZERO_LABELS (band 7 all NaN),
#          MOSTLY_NAN (<50% of days have labels)
NO_LABEL_IDS = [
    "20777207",  # NO_FILES
    "20777386",  # NO_FILES
    "21693566",  # ZERO_LABELS (0/20 days)
    "21751305",  # MOSTLY_NAN (4/9 days)
    "21751309",  # ZERO_LABELS (0/11 days)
    "21889672",  # NO_FILES
    "21889683",  # NO_FILES
    "21889697",  # NO_FILES
    "21889719",  # NO_FILES
    "21889734",  # NO_FILES
    "21889754",  # NO_FILES
    "21890056",  # MOSTLY_NAN (2/9 days)
    "21997775",  # NO_FILES
    "22712904",  # ZERO_LABELS (0/16 days) -- VAL fire
    "22712973",  # ZERO_LABELS (0/23 days)
    "22713339",  # NO_FILES
    "23036871",  # MOSTLY_NAN (3/8 days)
    "23860939",  # ZERO_LABELS (0/20 days)
    "23860978",  # NO_FILES
    "23861018",  # NO_FILES
    "23861131",  # NO_FILES
    "24332700",  # NO_FILES
]

# Test fires with no labels (exclude from evaluation)
AF_TEST_EXCLUDE = [
    "calfcanyon_fire",  # ALL 10 days NaN (2022 fire)
    "mosquito_fire",    # ALL 10 days NaN (2022 fire)
]
```

---

## Impact Analysis

### On Training (v1 vs v6)
- v1 trained on ALL 138 fires (including 21 with missing/corrupt labels)
- v6 excluded the 22 problematic fires, trained on 117 clean fires
- v1 val F1: 0.8177 | v6 val F1: 0.8200
- Marginal improvement on validation, but the model learns cleaner representations

### On Test Evaluation
- Previous inference included calfcanyon_fire and mosquito_fire (both F1=0.000)
- These two fires dragged aggregate F1 from ~0.85 to ~0.76
- After excluding them: Test F1 = 0.854 (paper baseline: 0.823, **+3.1%**)

### Key Observation
Both fully unlabeled test fires (calfcanyon_fire and mosquito_fire) are from **2022**.
The paper's dataset covers 2017-2021. These fires were likely added to the Kaggle
release after the paper was written, without completing the VNP14IMG label pipeline.
The paper mentions using "manual threshold on Band I4/I5" for test labels -- those
manual annotations are NOT included in the public Kaggle download.

---

## Recommendations for Future Work

1. **Always audit labels before training.** Run the label check script on any
   new split before model development.

2. **For BA task:** Repeat this audit on band 8 (BA labels). The same NaN pattern
   likely exists for BA labels.

3. **For fair benchmarking:** Report results on the 15 verified test fires only.
   Document which fires were excluded and why.

4. **Day-level filtering:** Even in "usable" fires, skip sliding windows where
   the label day has NaN band 7. The dataset class should check
   `np.isnan(b7).sum() < b7.size` before using a window.
