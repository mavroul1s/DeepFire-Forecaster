# Audit Run — Results Summary

Source: `audit_and_crop_kaggle.ipynb`, run on the TS-SatFire Kaggle release.
Runtime 10 minutes, 192 fire directories scanned, 0 errors.
Raw outputs: `audit_per_fire.csv`, `audit_summary_table.csv`, `crop_coverage.csv`,
`excluded_af_train.json`, `excluded_ba_train.json`, `firepred_band_check.json`.

This file records what the run established. Every number here is measured, not
recalled. Use it as the source of truth when rewriting Sections 3 and 4.

---

## 1. Headline findings

1. **More than a quarter of the labelled fire pixels lie outside the evaluation
   crop for AF, and more than half for BA/FP.** This was previously undisclosed
   and directly answers Reviewer 3's question about the 256×256 centre crop.
2. **Crop truncation strongly predicts per-fire FP performance**
   (Spearman ρ = −0.76, p = 0.0007). This explains the FP variability that
   Reviewer 3 asked us to account for.
3. **Table 1 in the manuscript is correct; the abstract is wrong.** The audit
   reproduces 117 usable AF training fires. The abstract's "18" does not match
   any definition the audit supports.
4. **The stated FP exclusion criterion does not match the fires excluded.**
   Five of the eight excluded fires meet the "< 0.001 %" criterion as measured;
   three do not.
5. **The FirePred band we drop is not corrupt.** It is a precipitation variable
   that is legitimately zero in fires with no rainfall.
6. **The "missing directory" fires are not a data-quality defect.** They are
   empty placeholders outside the dataset's stated 179 events.

---

## 2. Split accounting

| Split | Directories on disk | Note |
|---|---|---|
| Numeric IDs (train + val) | 151 | |
| AF/BA validation | 13 | present, complete |
| FP validation | 15 listed, **14 present** | `23301962` absent from the Kaggle release |
| AF test | 17 | present, complete |
| BA/FP test | 24 | present, complete |
| **Total directories** | **192** | |

**192 directories minus the 13 with no `VIIRS_Day` folder = 179**, exactly the
event count stated by Zhao et al. So the empty directories are placeholders,
not events with missing labels.

**Implication for the manuscript.** Section 4.1 and 4.2 currently count
"14 have no VIIRS_Day directory" as a label-quality failure. That framing is
not defensible — the dataset never claimed those were events. Reclassify them
as "directories present in the release but outside the documented 179 events"
and report the label-quality findings separately. This makes the audit more
precise and less accusatory, which helps with Reviewer 3's tone concerns.

Training-count definition: the manuscript's 138 AF/BA training fires include
`22713339`, which the dataset paper moves into FP validation. The audit script
used 137 (excluding it). Both are defensible; state which one is used and be
consistent. This single fire accounts for the 20-vs-21 difference below.

---

## 3. Authoritative exclusion counts

Measured (audit script definition: 137 training fires, `< 50 %` usable-days criterion):

| Task | Split | Total | Usable | No dir | All-NaN | < 50 % days | Excluded |
|---|---|---|---|---|---|---|---|
| AF | train | 137 | **117** | 13 | 4 | 3 | 20 |
| AF | val | 14 | 12 | 1 | 1 | 0 | 2 |
| AF | test | 17 | **14** | 0 | 2 | 1 | 3 |
| BA | train | 137 | **89** | 13 | 18 | 17 | 48 |
| BA | val | 14 | 8 | 1 | 5 | 0 | 6 |
| BA | test (24 US_2021) | 24 | **18** | 0 | 2 | 4 | 6 |

### 3.1 The 18-vs-21 question is settled — and I had it backwards

Earlier I advised that the code's "18" was authoritative and Table 1's
"21 excluded / 117 usable" was unsupported. **That was wrong.** The audit
reproduces **117 usable AF training fires exactly**, and 20 excluded from 137,
which becomes 21 from 138 once `22713339` is included. Manuscript Table 1 is
correct as printed.

The abstract's "18 training fires" comes from the length of `NO_LABEL_IDS` in
the training notebook, which is a hand-maintained list, not an audit result.
It matches neither 20 nor 21.

**Action:** correct the abstract to match Table 1. Do not change Table 1.
Also correct `results_v6.json`'s `train_fires_clean: 120`, which is likewise
derived from the hand-maintained list rather than from the audit.

### 3.2 A third AF test fire is only partially labelled

The manuscript excludes two AF test fires (Calf Canyon, Mosquito). The audit
flags **three**: those two have no AF labels at all, and one further fire has
AF labels on fewer than half its days.

Note this is the training-split criterion applied to a test fire, which is
arguably the wrong test — at evaluation time we only score days that have
labels, so partial labelling is not disqualifying. **Recommendation:** keep the
15-fire test set, but disclose in Section 4.1 that one of the 15 has labels on
fewer than half its days, and report its per-fire F1 separately. Identify it
from `audit_per_fire.csv` (filter `split == "af_test"`, `0 < af_frac_days < 0.5`).

### 3.3 BA counts confirm the manuscript

BA test 18 usable / 6 excluded matches Table 2 exactly. BA train 89 usable
matches. These rows need no change.

---

## 4. Crop coverage — new, and significant

Percentage of labelled positive pixels falling **outside** the 256×256 centre crop:

| Split | Mean outside | Worst cases |
|---|---|---|
| AF test (fire pixels) | **26.8 %** | Lytton 86.2 %, Swedish 76.8 %, Double Creek 70.3 % |
| BA/FP test (burned pixels) | **56.3 %** | ID-4762 83.3 %, WA-4877 92.7 %, AZ-3368 87.9 % |

All rasters are 596 × ~595, so the crop retains roughly 19 % of the scene area.

### 4.1 This explains the FP variability Reviewer 3 asked about

Correlating the 16 published per-fire FP F1 values against the percentage of
burned pixels outside the crop:

- Pearson r = **−0.650**
- Spearman ρ = **−0.759**, p = **0.0007**
- Fires scoring below the 0.375 baseline (n = 8): mean **66.7 %** outside crop
- Fires scoring at or above it (n = 8): mean **34.6 %** outside crop

The manuscript currently explains the low performers as "stochastic ember
activity" and "no-signal scenes". The measured explanation is simpler and
defensible: **the model is scored on a crop that excludes most of the fire.**

**Action:** replace the speculative explanation in Section 6.3 with this
analysis, and add a scatter plot of per-fire F1 against crop truncation. This
converts a weakness into a quantified, honest limitation.

### 4.2 Two AF test fires have no AF-positive pixels at all

`af_outside_pct` is undefined (NaN) for Mosquito and Calf Canyon, confirming
they contain zero AF-positive pixels anywhere in the scene, not merely inside
the crop. This independently corroborates the AF exclusion.

Separately, `eagle_bluff_fire` has BA labels of which **100 %** fall outside the
crop, and six AF test fires have no BA labels at all — irrelevant to the AF task
but worth noting if BA is ever revisited.

---

## 5. Exclusion-threshold sensitivity

Burn-fraction cut-off applied to the 24 BA/FP test fires:

| Cut-off | Fires excluded |
|---|---|
| 0 % | 0 / 24 |
| 0.0001 % | 3 / 24 |
| **0.001 % (manuscript)** | **5 / 24** |
| 0.01 % | 5 / 24 |
| 0.1 % | 8 / 24 |
| 1.0 % | 16 / 24 |

Usable-days criterion on the training split:

| Criterion | AF usable / excluded | BA usable / excluded |
|---|---|---|
| ≥ 25 % of days | 119 / 18 | 97 / 40 |
| **≥ 50 % (manuscript)** | **117 / 20** | **89 / 48** |
| ≥ 75 % of days | 104 / 33 | 82 / 55 |

The AF result is insensitive between 25 % and 50 % (two fires) and moderately
sensitive at 75 %. BA is materially sensitive throughout. Report this table
directly — it is what Reviewer 3 asked for.

### 5.1 The stated FP exclusion criterion does not match the excluded fires

Manuscript Section 4.3 excludes eight fires whose "burned-area fraction inside
the 256 × 256 crop is below 0.001 %". Measured values:

| Excluded fire | Measured burn fraction in crop | Meets stated criterion |
|---|---|---|
| FL-2521 | 0.000 % | yes |
| NM-3323 | 0.000 % | yes |
| NM-3340 | 0.000 % | yes |
| NM-3344 | 0.000 % | yes |
| NM-3676 | 0.000 % | yes |
| MT-4714 | 0.156 % | **no** |
| AZ-3345 | 0.056 % | **no** |
| AZ-3368 | 0.052 % | **no** |

**Caveat before acting on this.** The audit measures cumulative burned-area
presence per day; the FP label is the day-to-day *increment*
`BA(T+1) \ BA(T)`. A fire can carry a non-trivial cumulative burn fraction while
having near-zero daily increments inside the crop. So this is not proof the
exclusions were wrong — it is proof that **the criterion as written in the
manuscript does not describe what was actually done.**

**Action:** recompute the progression-increment fraction per test fire (a small
addition to the audit script), then state the real criterion, with the real
numbers, for all eight fires. Section 7's claim that the two Arizona fires have
"zero measurable progression signal within the center crop" must be checked
against that recomputation. If any of the three cannot be justified, either
reinstate them or justify them on a stated alternative ground.

This is exactly the item Reviewer 3 flagged ("the criteria used to exclude fire
events should be better justified"). Getting it wrong twice would be costly.

---

## 6. FirePred auxiliary bands

Checked across 62 fires. Only two of the 19 bands are ever entirely zero:

| Band index (0-based) | All-zero in | Dataset channel | Variable |
|---|---|---|---|
| 2 | **12 / 62** | 11 | Total Precipitation |
| 14 | 5 / 62 | 23 | Total Precipitation Surface |

All 17 other bands are non-constant in every fire checked.

### 6.1 The justification for dropping band 3 is wrong

The manuscript drops FirePred band 3 (index 2) "because it is all zeros in our
probe fire". It is all-zero in 12 of 62 fires — roughly 19 % — and it is
**Total Precipitation**. Fires that burn during dry spells legitimately record
zero rainfall. The band is not corrupt; we discarded a real meteorological
predictor on the basis of a single fire.

That the *other* occasionally-zero band is also a precipitation variable
confirms the physical reading.

**Action, two options:**
- **Preferred:** retrain FP with all 19 FirePred bands (28 input channels) and
  report it as an ablation arm. This removes the objection entirely and may help
  performance, since precipitation is a plausible progression driver.
- **Minimum:** keep 18 channels but replace the justification with the correct
  statement and acknowledge it as a limitation.

Either way, Section 5.3 and the Figure 3 caption must stop calling it "all zeros".

### 6.2 Full FirePred band mapping for Section 3

Reviewer 3 asked for better documentation. The FirePred rasters carry channels
9–27 of the dataset paper's Table 1, in order:

| Index | Channel | Variable | Index | Channel | Variable |
|---|---|---|---|---|---|
| 0 | 9 | NDVI | 10 | 19 | Aspect |
| 1 | 10 | EVI | 11 | 20 | Elevation |
| 2 | 11 | Total Precipitation | 12 | 21 | PDSI |
| 3 | 12 | Wind Speed | 13 | 22 | Land Cover |
| 4 | 13 | Wind Direction | 14 | 23 | Total Precipitation Surface |
| 5 | 14 | Min Temperature | 15 | 24 | Forecast Wind Speed |
| 6 | 15 | Max Temperature | 16 | 25 | Forecast Wind Direction |
| 7 | 16 | Energy Release Component | 17 | 26 | Forecast Temperature |
| 8 | 17 | Specific Humidity | 18 | 27 | Forecast Specific Humidity |
| 9 | 18 | Slope | | | |

Reproduce this as a table in Section 3. It answers the reviewer completely and
replaces the current text, which says the bands are unnamed in the metadata —
they are named, in the dataset paper's Table 1.

---

## 7. Corrections to the revision plan

The following entries in `REVISION_PLAN.md` change as a result of this run:

| Item | Previous status | Now |
|---|---|---|
| C2 (18 vs 21) | "Table 1 unsupported, use 18" | **Reversed.** Table 1 is correct; fix the abstract to 21/117 and state the 138-fire definition. |
| R3.10 (FirePred docs) | "document the 18 bands used" | Band mapping now known (§6.2); the drop justification is wrong (§6.1) and needs a new experiment or a corrected statement. |
| R3.11 (crop) | "measure it" | **Done.** 26.8 % AF, 56.3 % BA/FP outside crop. |
| R3.12 (sensitivity) | "run it" | **Done.** §5. |
| R3.19 (FP variability) | "expand using crop numbers" | **Done and stronger than expected**: ρ = −0.76, p = 0.0007. |
| New item | — | The stated FP exclusion criterion does not match three of the eight excluded fires (§5.1). Must be reconciled before resubmission. |

---

## 8. Next steps arising from this run

1. Recompute the **progression-increment** fraction per BA/FP test fire, so the
   FP exclusion criterion can be stated accurately (§5.1). Small script, no GPU.
2. Identify the third partially-labelled AF test fire from `audit_per_fire.csv`
   and decide how to report it (§3.2).
3. Decide on the FirePred precipitation band: retrain with 19 bands, or correct
   the justification (§6.1).
4. Produce the scatter plot of per-fire FP F1 against crop truncation for
   Section 6.3 (§4.1).
5. Still outstanding and unchanged: the protocol evaluation (E1), which needs
   the two checkpoints and `fp_stats.npz` attached as a Kaggle dataset.
